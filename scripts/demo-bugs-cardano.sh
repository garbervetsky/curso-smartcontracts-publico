#!/usr/bin/env bash
# Demo en vivo (Clase 8): el catálogo de bugs EUTXO, con los validators reales decidiendo.
#
#   ./scripts/demo-bugs-cardano.sh              # las 6 escenas, pausando entre una y otra
#   ./scripts/demo-bugs-cardano.sh --escena 2   # sólo una (para volver sobre ella)
#   ./scripts/demo-bugs-cardano.sh --sin-pausa  # de corrido (para revisar antes de la clase)
#   ./scripts/demo-bugs-cardano.sh --sin-color
#
# Qué hace, y por qué está armado así:
#
# La Clase 8 enumera lo que un validator se olvida de verificar. Este script arma
# esas transacciones —la que paga a Eve con la firma de Bob, la que gasta dos
# UTXOs del escrow con un solo output, la que no tiene cotas de tiempo, la que
# acuña un millón de tokens— y las pone en pantalla. Después ejecuta el validator
# real sobre cada una y muestra qué devolvió.
#
# Mismo mecanismo que scripts/demo-tx-cardano.sh (Clase 4): el resultado NO está
# escrito acá. Para cada corrida se generan DOS tests, uno que afirma el
# resultado y otro que afirma su negación, y se le pregunta a `aiken check` cuál
# pasa. Si alguien arregla escrow_vulnerable.ak, la demo lo delata.
#
# Escenas:
#   1  escrow.ak            Bob firma, la plata va a Eve → True        (1b, outputs)
#   2  escrow_vulnerable.ak dos UTXOs, un solo pago: A → True, B → True (1a, double satisfaction)
#   3  escrow_fixed.ak      la misma tx → False                        (mitigación 1)
#      (sólo si el archivo existe: está en el repo del curso, no en el público)
#   4  escrow.ak            rango sin cotas → False                    (1g, tiempo)
#   5  un escrow hipotético que mira un solo borde → True              (1g, el error típico)
#   6  una minting policy que sólo pide firma: acuña 1.000.000 → True  (1e, minting)
#
# No toca la red: no hay nodo, ni testnet, ni claves, ni faucet. Corre offline
# y dentro del contenedor del curso. Ver docs/guia-profesor/clase-08.md §6.

set -euo pipefail
cd "$(dirname "$0")/.."

# --- Datos (los mismos hashes de la demo de la Clase 4) -----------------------
ALICE_HASH='11223344'   # owner
BOB_HASH='aabbccdd'     # beneficiary
EVE_HASH='deadbeef'     # la que arma las transacciones malas
EMISOR_HASH='c0ffee00'  # quien puede acuñar en la policy frágil
POLICY_ID='facade00'    # el "policy id" de la policy frágil (de fantasía)
DEADLINE=10000          # POSIX time en ms (valor de juguete, como en los tests)
UTXO_REF='4a3f0c9e21b7d5486fa10c33e9b7742d0ab5c61f8e93d24c7a0b15e6f8c3d29b'
SCRIPT_HASH='5c0107'    # el "hash" de la dirección del escrow (de fantasía)
LOVELACE=100000000      # 100 ADA
MINT_QTY=1000000

N_ESCENAS=6
FIXED=cardano/validators/escrow_fixed.ak
[ -f "$FIXED" ] && HAY_FIXED=si || HAY_FIXED=no

# --- Flags -------------------------------------------------------------------
SOLO=""; PAUSA="auto"; COLOR="auto"
while [ $# -gt 0 ]; do
  case "$1" in
    --escena)    SOLO="${2:-}"; shift 2 ;;
    --escena=*)  SOLO="${1#*=}"; shift ;;
    --sin-pausa) PAUSA="no"; shift ;;
    --pausa)     PAUSA="si"; shift ;;
    --sin-color) COLOR="no"; shift ;;
    -h|--help)   awk 'NR>1 { if ($0 !~ /^#/) exit; sub(/^# ?/,""); print }' "$0"; exit 0 ;;
    *) echo "arg desconocido: $1 (usá --escena N | --sin-pausa | --sin-color)" >&2; exit 1 ;;
  esac
done

[ "$PAUSA" = "auto" ] && { [ -t 1 ] && PAUSA=si || PAUSA=no; }
[ "$COLOR" = "auto" ] && { [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && COLOR=si || COLOR=no; }

if [ "$COLOR" = "si" ]; then
  B=$'\033[1m'; D=$'\033[2m'; R=$'\033[0m'
  VERDE=$'\033[32m'; ROJO=$'\033[31m'; AMAR=$'\033[33m'; CIAN=$'\033[36m'
else
  B=""; D=""; R=""; VERDE=""; ROJO=""; AMAR=""; CIAN=""
fi

if [ -n "$SOLO" ]; then
  case "$SOLO" in
    ''|*[!0-9]*) echo "ERROR: --escena espera un número (1..${N_ESCENAS})" >&2; exit 1 ;;
  esac
  if [ "$SOLO" -lt 1 ] || [ "$SOLO" -gt "$N_ESCENAS" ]; then
    echo "ERROR: no hay escena $SOLO (hay ${N_ESCENAS})" >&2; exit 1
  fi
fi

# --- Motor: aiken local, o el contenedor del curso ---------------------------
if ! command -v aiken >/dev/null 2>&1; then
  ENGINE=""
  for e in podman /opt/podman/bin/podman docker; do
    if command -v "$e" >/dev/null 2>&1 || [ -x "$e" ]; then
      "$e" info >/dev/null 2>&1 && { ENGINE="$e"; break; }
    fi
  done
  IMG=""
  if [ -n "$ENGINE" ]; then
    for tag in $("$ENGINE" images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null | grep 'curso-sc:' || true); do
      IMG="$tag"; break
    done
  fi
  if [ -z "$IMG" ]; then
    echo "ERROR: no encontré 'aiken' ni la imagen del curso." >&2
    echo "       Instalalo con:  curl -sSfL https://install.aiken-lang.org | bash && aikup install" >&2
    echo "       O construí la imagen:  ./scripts/build-image.sh amd64" >&2
    exit 1
  fi
  echo "${D}→ sin aiken local; corriendo dentro de ${IMG}${R}" >&2
  exec "$ENGINE" run --rm -i -v "$PWD":/curso:Z -w /curso "$IMG" \
       bash -lc "scripts/demo-bugs-cardano.sh --sin-pausa $([ -n "$SOLO" ] && echo "--escena $SOLO") $([ "$COLOR" = no ] && echo --sin-color)"
fi

# --- Generar el módulo de tests ----------------------------------------------
# Vive en validators/ (desde lib/ no se resuelven los imports de los validators)
# y se borra al salir, pase lo que pase. Cada corrida genera dos tests:
# demo_<escena>_<corrida>_true y demo_<escena>_<corrida>_false.
GEN="cardano/validators/demo_bugs_tmp.ak"
trap 'rm -f "$GEN"' EXIT INT TERM

{
  echo "// Generado por scripts/demo-bugs-cardano.sh — se borra solo. No editar."
  echo "use aiken/collection/list"
  echo "use aiken/interval"
  echo "use cardano/address.{Address, Script, VerificationKey}"
  echo "use cardano/assets"
  echo "use cardano/transaction.{Input, NoDatum, Output, OutputReference,"
  echo "  Transaction, placeholder}"
  echo "use escrow"
  echo "use escrow_vulnerable"
  [ "$HAY_FIXED" = si ] && echo "use escrow_fixed"
  echo ""
  echo "fn demo_ref(idx: Int) -> OutputReference {"
  echo "  OutputReference { transaction_id: #\"${UTXO_REF}\", output_index: idx }"
  echo "}"
  echo ""
  echo "fn demo_pago(hash: ByteArray) -> Output {"
  echo "  Output {"
  echo "    address: Address { payment_credential: VerificationKey(hash), stake_credential: None },"
  echo "    value: assets.from_lovelace(${LOVELACE}),"
  echo "    datum: NoDatum,"
  echo "    reference_script: None,"
  echo "  }"
  echo "}"
  echo ""
  echo "// Un UTXO en la dirección del escrow, en el índice idx."
  echo "fn demo_input(idx: Int) -> Input {"
  echo "  Input {"
  echo "    output_reference: demo_ref(idx),"
  echo "    output: Output {"
  echo "      address: Address { payment_credential: Script(#\"${SCRIPT_HASH}\"), stake_credential: None },"
  echo "      value: assets.from_lovelace(${LOVELACE}),"
  echo "      datum: NoDatum,"
  echo "      reference_script: None,"
  echo "    },"
  echo "  }"
  echo "}"
  echo ""
  echo "fn datum_base() -> escrow.Datum {"
  echo "  escrow.Datum { beneficiary: #\"${BOB_HASH}\", owner: #\"${ALICE_HASH}\", deadline: ${DEADLINE} }"
  echo "}"
  echo ""
  echo "fn datum_v() -> escrow_vulnerable.Datum {"
  echo "  escrow_vulnerable.Datum {"
  echo "    beneficiary: #\"${BOB_HASH}\", owner: #\"${ALICE_HASH}\", deadline: ${DEADLINE}, amount: ${LOVELACE},"
  echo "  }"
  echo "}"
  if [ "$HAY_FIXED" = si ]; then
    echo ""
    echo "fn datum_f() -> escrow_fixed.Datum {"
    echo "  escrow_fixed.Datum {"
    echo "    beneficiary: #\"${BOB_HASH}\", owner: #\"${ALICE_HASH}\", deadline: ${DEADLINE}, amount: ${LOVELACE},"
    echo "  }"
    echo "}"
  fi
  echo ""
  echo "// Escena 5: un escrow HIPOTÉTICO que sólo mira el borde inferior del rango."
  echo "// No es el del repo: es el error típico de la Clase 8, 1g, escrito a propósito."
  echo "fn escrow_un_solo_borde(d: escrow.Datum, tx: Transaction) -> Bool {"
  echo "  let signed = list.has(tx.extra_signatories, d.beneficiary)"
  echo "  let lower_ok ="
  echo "    when tx.validity_range.lower_bound.bound_type is {"
  echo "      interval.Finite(t) -> t < d.deadline"
  echo "      _ -> False"
  echo "    }"
  echo "  signed && lower_ok"
  echo "}"
  echo ""
  echo "// Escena 6: la minting policy frágil de la Clase 8, 1e: sólo pide la firma."
  echo "fn token_fragil(emisor: ByteArray, tx: Transaction) -> Bool {"
  echo "  list.has(tx.extra_signatories, emisor)"
  echo "}"
  echo ""

  # Las transacciones de cada escena, como expresiones Aiken.
  TX1="Transaction { ..placeholder, inputs: [demo_input(0)], outputs: [demo_pago(#\"${EVE_HASH}\")], extra_signatories: [#\"${BOB_HASH}\"], validity_range: interval.between(1_000, 5_000) }"
  TX2="Transaction { ..placeholder, inputs: [demo_input(0), demo_input(1)], outputs: [demo_pago(#\"${BOB_HASH}\"), demo_pago(#\"${EVE_HASH}\")], extra_signatories: [#\"${BOB_HASH}\"], validity_range: interval.between(1_000, 5_000) }"
  TX4="Transaction { ..placeholder, inputs: [demo_input(0)], outputs: [demo_pago(#\"${BOB_HASH}\")], extra_signatories: [#\"${BOB_HASH}\"], validity_range: interval.everything }"
  TX5="Transaction { ..placeholder, inputs: [demo_input(0)], outputs: [demo_pago(#\"${BOB_HASH}\")], extra_signatories: [#\"${BOB_HASH}\"], validity_range: interval.after(1_000) }"
  TX6A="Transaction { ..placeholder, mint: assets.from_asset(#\"${POLICY_ID}\", \"VALE\", ${MINT_QTY}), extra_signatories: [#\"${EMISOR_HASH}\"] }"
  TX6B="Transaction { ..placeholder, mint: assets.from_asset(#\"${POLICY_ID}\", \"OTRO\", ${MINT_QTY}), extra_signatories: [#\"${EMISOR_HASH}\"] }"

  par() {  # par <nombre> <expresión Bool> → los dos tests
    for signo in true false; do
      [ "$signo" = "true" ] && neg="" || neg="!"
      echo "test demo_$1_${signo}() {"
      echo "  ${neg}($2)"
      echo "}"
      echo ""
    done
  }
  par 1_1 "escrow.escrow.spend(Some(datum_base()), escrow.Claim, demo_ref(0), ${TX1})"
  par 2_1 "escrow_vulnerable.escrow_vulnerable.spend(Some(datum_v()), escrow_vulnerable.Claim, demo_ref(0), ${TX2})"
  par 2_2 "escrow_vulnerable.escrow_vulnerable.spend(Some(datum_v()), escrow_vulnerable.Claim, demo_ref(1), ${TX2})"
  [ "$HAY_FIXED" = si ] && par 3_1 "escrow_fixed.escrow_fixed.spend(Some(datum_f()), escrow_fixed.Claim, demo_ref(0), ${TX2})"
  par 4_1 "escrow.escrow.spend(Some(datum_base()), escrow.Claim, demo_ref(0), ${TX4})"
  par 5_1 "escrow_un_solo_borde(datum_base(), ${TX5})"
  par 6_1 "token_fragil(#\"${EMISOR_HASH}\", ${TX6A})"
  par 6_2 "token_fragil(#\"${EMISOR_HASH}\", ${TX6B})"
} > "$GEN"

printf '%s\n' "${D}Compilando los validators y ejecutándolos sobre cada transacción…${R}" >&2
JSON="$(cd cardano && aiken check -m demo_ 2>/dev/null || true)"

if [ -z "$JSON" ]; then
  echo "ERROR: 'aiken check' no devolvió resultados. Probá a mano:" >&2
  echo "       cd cardano && aiken check -m demo_" >&2
  exit 1
fi

RES="$(printf '%s\n' "$JSON" | awk '
  /"title"/  { t=$0; sub(/.*"title"[^"]*"/,"",t);  sub(/".*/,"",t) }
  /"status"/ { s=$0; sub(/.*"status"[^"]*"/,"",s); sub(/".*/,"",s) }
  /"mem"/    { m=$0; sub(/.*"mem"[^0-9]*/,"",m);   sub(/[^0-9].*/,"",m) }
  /"cpu"/    { c=$0; sub(/.*"cpu"[^0-9]*/,"",c);   sub(/[^0-9].*/,"",c); print t "|" s "|" m "|" c }
')"

campo() { printf '%s\n' "$RES" | awk -F'|' -v k="$1" -v n="$2" '$1==k {print $n; exit}'; }
miles() { printf '%s' "$1" | awk '{ s=$0; o=""; while (length(s)>3) { o="." substr(s,length(s)-2) o; s=substr(s,1,length(s)-3) } print s o }'; }
linea() { printf '%s\n' "${D}────────────────────────────────────────────────────────────────${R}"; }
pausa() { if [ "$PAUSA" = "si" ]; then printf '%s' "${D}  [enter]${R}"; read -r _ </dev/tty || true; printf '\n'; fi; }
quiero() { [ -z "$SOLO" ] || [ "$SOLO" = "$1" ]; }

# veredicto <corrida> <qué se ejecutó>: imprime True / False / aborta, y los ExUnits
veredicto() {
  local k="$1" que="$2" st_true st_false mem cpu
  st_true="$(campo "demo_${k}_true" 2)"; st_false="$(campo "demo_${k}_false" 2)"
  mem="$(campo "demo_${k}_true" 3)"; cpu="$(campo "demo_${k}_true" 4)"
  if [ "$st_true" != "pass" ]; then mem="$(campo "demo_${k}_false" 3)"; cpu="$(campo "demo_${k}_false" 4)"; fi
  printf '  %s\n' "${B}EJECUCIÓN${R}  ${D}${que}${R}"
  if [ "$st_true" = "pass" ] && [ "$st_false" != "pass" ]; then
    printf '    %s\n' "devuelve       ${VERDE}${B}True${R}"
  elif [ "$st_false" = "pass" ] && [ "$st_true" != "pass" ]; then
    printf '    %s\n' "devuelve       ${ROJO}${B}False${R}"
  elif [ -z "$st_true" ] && [ -z "$st_false" ]; then
    printf '    %s\n' "${ROJO}no se pudo determinar (¿falló la compilación?)${R}"
  else
    printf '    %s\n' "no devuelve    ${ROJO}${B}aborta${R}"
  fi
  if [ -n "$mem" ] && [ -n "$cpu" ]; then
    printf '    %s\n' "${D}ExUnits        mem $(miles "$mem")   cpu $(miles "$cpu")${R}"
  fi
}

cabecera() { printf '\n%s\n' "${B}${CIAN}ESCENA $1 · $2${R}"; printf '%s\n\n' "${D}catálogo de la Clase 8: $3${R}"; }
porque()   { printf '\n  %s\n\n' "${B}POR QUÉ${R}  $1"; linea; pausa; }
REF8="${UTXO_REF:0:8}…${UTXO_REF: -4}"

# --- Escena 1 ----------------------------------------------------------------
if quiero 1; then
  cabecera 1 "Bob firma, la plata va a Eve (el gancho de la Clase 4)" "1b · validación insuficiente de outputs"
  printf '  %s\n' "${B}EL UTXO BLOQUEADO${R}  escrow.ak, 100 ADA, datum { beneficiary = Bob, owner = Alice, deadline = ${DEADLINE} }"
  printf '\n  %s\n' "${B}LA TRANSACCIÓN${R}  ${D}(la arma Eve)${R}"
  printf '    %s\n' "inputs         ${REF8} # 0   ← el UTXO del escrow"
  printf '    %s\n' "redeemer       Claim"
  printf '    %s\n' "outputs        ${AMAR}100 ADA → Eve  #${EVE_HASH}${R}"
  printf '    %s\n' "signatories    [ Bob  #${BOB_HASH} ]"
  printf '    %s\n\n' "validity_range [ 1000 , 5000 ]"
  veredicto 1_1 "escrow.spend(datum, Claim, ref, tx)"
  porque "El escrow verifica la firma y el tiempo, y nunca mira los outputs. Autoriza bien y no constata el efecto: el checklist, primer bloque."
fi

# --- Escena 2 ----------------------------------------------------------------
if quiero 2; then
  cabecera 2 "Double satisfaction: dos UTXOs, un solo pago" "1a · double satisfaction"
  printf '  %s\n' "${B}LOS UTXOS BLOQUEADOS${R}  escrow_vulnerable.ak: valida que un output pague \`amount\` al beneficiario"
  printf '    %s\n' "A   ${REF8} # 0   100 ADA   datum { beneficiary = Bob, amount = 100 ADA, … }"
  printf '    %s\n' "B   ${REF8} # 1   100 ADA   datum { beneficiary = Bob, amount = 100 ADA, … }"
  printf '\n  %s\n' "${B}LA TRANSACCIÓN${R}  ${D}(la arma Eve; Bob firma)${R}"
  printf '    %s\n' "inputs         A, B               ← los DOS UTXOs del escrow: se liberan 200 ADA"
  printf '    %s\n' "redeemers      A: Claim   B: Claim"
  printf '    %s\n' "outputs        100 ADA → Bob  #${BOB_HASH}     ${AMAR}← UN solo pago${R}"
  printf '    %s\n' "               ${AMAR}100 ADA → Eve  #${EVE_HASH}${R}"
  printf '    %s\n' "signatories    [ Bob  #${BOB_HASH} ]"
  printf '    %s\n\n' "validity_range [ 1000 , 5000 ]"
  printf '  %s\n\n' "${D}El validator corre una vez por cada input del script. Las dos corridas ven la MISMA tx.${R}"
  veredicto 2_1 "escrow_vulnerable.spend(datum, Claim, ref A, tx)"
  printf '\n'
  veredicto 2_2 "escrow_vulnerable.spend(datum, Claim, ref B, tx)"
  porque "Cada corrida busca \"un output que pague 100 a Bob\" y encuentra el mismo. Las dos aprueban: se liberan 200, Bob cobra 100, Eve se queda con 100. Ninguna corrida sabe que la otra ya contó ese output."
fi

# --- Escena 3 ----------------------------------------------------------------
if quiero 3; then
  cabecera 3 "El fix: un único input de script" "mitigación 1 · exigir un solo input del script"
  if [ "$HAY_FIXED" = si ]; then
    printf '  %s\n' "${B}LA MISMA TRANSACCIÓN${R} de la escena 2, contra escrow_fixed.ak, que suma \`single_script_input\`."
    printf '    %s\n\n' "${D}resuelve su OutputReference → saca la dirección del script → cuenta los inputs con esa dirección → exige 1${R}"
    veredicto 3_1 "escrow_fixed.spend(datum, Claim, ref A, tx)"
    porque "Hay dos inputs con la dirección del script, así que la corrida del input A devuelve False, y con un False se cae la transacción entera. Cada UTXO del escrow necesita su propia tx, con su propio pago."
  else
    printf '  %s\n' "${AMAR}escrow_fixed.ak no está en este repo${R} (es la solución; está sólo en el repo del curso)."
    printf '  %s\n' "Con él, la misma tx de la escena 2 devuelve False para el input A: hay dos inputs"
    printf '  %s\n\n' "con la dirección del script y \`single_script_input\` exige uno."
    linea; pausa
  fi
fi

# --- Escena 4 ----------------------------------------------------------------
if quiero 4; then
  cabecera 4 "Tiempo: un rango sin cotas" "1g · el validator ve un intervalo, no un reloj"
  printf '  %s\n' "${B}EL UTXO BLOQUEADO${R}  escrow.ak, datum { beneficiary = Bob, deadline = ${DEADLINE} }"
  printf '\n  %s\n' "${B}LA TRANSACCIÓN${R}  ${D}(la arma Bob, y no puso invalidBefore ni invalidHereafter)${R}"
  printf '    %s\n' "inputs         ${REF8} # 0"
  printf '    %s\n' "redeemer       Claim"
  printf '    %s\n' "outputs        100 ADA → Bob  #${BOB_HASH}"
  printf '    %s\n' "signatories    [ Bob  #${BOB_HASH} ]"
  printf '    %s\n\n' "validity_range ${AMAR}(-∞ , +∞)${R}"
  veredicto 4_1 "escrow.spend(datum, Claim, ref, tx)"
  porque "interval.before(deadline) |> includes(validity_range) exige que TODO el rango esté antes del deadline. (-∞, +∞) no lo está: el escrow lo rechaza. Mira los dos bordes, y eso es lo correcto."
fi

# --- Escena 5 ----------------------------------------------------------------
if quiero 5; then
  cabecera 5 "El error típico: mirar un solo borde" "1g · tiempo"
  printf '  %s\n' "${B}UN ESCROW HIPOTÉTICO${R}  ${D}(no es el del repo; está escrito en el módulo que genera esta demo)${R}"
  printf '    %s\n\n' "chequea:  firma de Bob  &&  lower_bound < deadline      ← sólo el borde inferior"
  printf '  %s\n' "${B}LA TRANSACCIÓN${R}  ${D}(la arma Bob)${R}"
  printf '    %s\n' "inputs         ${REF8} # 0"
  printf '    %s\n' "outputs        100 ADA → Bob  #${BOB_HASH}"
  printf '    %s\n' "signatories    [ Bob  #${BOB_HASH} ]"
  printf '    %s\n\n' "validity_range ${AMAR}[ 1000 , +∞)${R}     ← empieza antes del deadline, no termina nunca"
  veredicto 5_1 "escrow_un_solo_borde(datum, tx)"
  porque "El borde inferior está antes del deadline, así que aprueba. Pero el nodo sólo garantiza que el bloque cae DENTRO del rango, no en qué parte: esta tx puede entrar en cualquier momento futuro. Un solo borde no dice nada."
fi

# --- Escena 6 ----------------------------------------------------------------
if quiero 6; then
  cabecera 6 "Minting policy frágil: un millón de vales" "1e · seguridad de minting policies"
  printf '  %s\n' "${B}LA POLICY${R}  ${D}(la de la Clase 8, 1e: aprueba si firma el emisor, y nada más)${R}"
  printf '    %s\n\n' "mint(_r, _policy, tx) { list.has(tx.extra_signatories, emisor) }"
  printf '  %s\n' "${B}LA TRANSACCIÓN A${R}  ${D}(la arma el emisor)${R}"
  printf '    %s\n' "mint           ${AMAR}$(miles ${MINT_QTY}) VALE${R}   (policy #${POLICY_ID})"
  printf '    %s\n\n' "signatories    [ emisor  #${EMISOR_HASH} ]"
  veredicto 6_1 "token_fragil(emisor, tx)"
  printf '\n  %s\n' "${B}LA TRANSACCIÓN B${R}  ${D}(igual, pero con otro nombre de token)${R}"
  printf '    %s\n\n' "mint           ${AMAR}$(miles ${MINT_QTY}) OTRO${R}   (policy #${POLICY_ID})"
  veredicto 6_2 "token_fragil(emisor, tx)"
  porque "La policy no mira tx.mint: ni cuánto se acuña, ni con qué nombre, ni si es acuñar o quemar. Con la firma, cualquier cantidad de cualquier token bajo esta policy es válida."
fi

# --- Remate ------------------------------------------------------------------
if [ -z "$SOLO" ]; then
  printf '\n%s\n\n' "${B}Lo que hay que llevarse${R}"
  printf '  %s\n' "· Ningún validator hizo una operación incorrecta. Cada uno ${B}verificó bien lo que verificó${R}."
  printf '  %s\n' "· Los bugs son ${B}lo que no verificó${R}: los outputs (1), cuántos inputs del script hay (2),"
  printf '  %s\n' "  los dos bordes del tiempo (5), qué y cuánto se acuña (6)."
  printf '  %s\n' "· La transacción la arma el adversario. ${B}Lo que el validator no verifica, no está garantizado.${R}"
  printf '  %s\n\n' "· Y el fix (3) es verificar una cosa más. Nada de lo demás cambia."
fi
