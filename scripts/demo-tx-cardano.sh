#!/usr/bin/env bash
# Demo en vivo: una transacción EUTXO en pantalla, con el validator real decidiendo.
#
#   ./scripts/demo-tx-cardano.sh              # las 6 escenas, pausando entre una y otra
#   ./scripts/demo-tx-cardano.sh --escena 6   # sólo una escena (para volver sobre ella)
#   ./scripts/demo-tx-cardano.sh --sin-pausa  # de corrido (para revisar antes de la clase)
#   ./scripts/demo-tx-cardano.sh --sin-color
#
# Qué hace, y por qué está armado así:
#
# La Clase 4 explica que en EUTXO el validator NO mueve fondos: sólo mira la
# transacción y dice sí/no. Eso se cuenta bien, pero se VE mucho mejor. Este
# script pone la transacción en pantalla —inputs, outputs, datum, redeemer,
# firmantes, validity_range— y después ejecuta `escrow.spend` sobre ella.
#
# El resultado NO está escrito acá: para cada escena se generan DOS tests, uno
# que afirma el resultado y otro que afirma su negación, y se le pregunta a
# `aiken check` cuál pasa. Si pasa el primero, el validator devolvió True; si
# pasa el segundo, False; si fallan los dos, el validator ABORTÓ (que es lo que
# pasa con un UTXO sin datum). O sea: la pantalla muestra lo que el validator
# realmente hace, no lo que el guion dice que hace. Si alguien rompe escrow.ak,
# la demo lo delata.
#
# No toca la red: no hay nodo, ni testnet, ni claves, ni faucet. Corre offline
# y dentro del contenedor del curso. Ver docs/guia-profesor/clase-04.md §5.

set -euo pipefail
cd "$(dirname "$0")/.."

# --- Datos de la escena (los mismos hashes que los tests de cardano/validators/escrow.ak) ---
ALICE_HASH='11223344'   # owner
BOB_HASH='aabbccdd'     # beneficiary
EVE_HASH='deadbeef'     # una tercera que no figura en el datum
EVE_NOMBRE='Eve'
DEADLINE=10000          # POSIX time en ms (valor de juguete, como en los tests)
UTXO_REF='4a3f0c9e21b7d5486fa10c33e9b7742d0ab5c61f8e93d24c7a0b15e6f8c3d29b'
SCRIPT_HASH='5c0107'    # el "hash" de la dirección del escrow (de fantasía)
LOVELACE=100000000      # 100 ADA

# --- Escenas -----------------------------------------------------------------
# Un registro por escena, campos separados por '|':
#
#   1 titulo
#   2 redeemer            Claim | Cancel
#   3 datum               SI | NO           (NO = el UTXO no tiene datum)
#   4 quién firma (nombre, para pantalla)
#   5 quién firma (hash, va a extra_signatories)
#   6 validity (para pantalla)
#   7 validity (expresión Aiken)
#   8 a dónde van los fondos (nombre, para pantalla)
#   9 a dónde van los fondos (hash, va al output de verdad)
#  10 por qué             la explicación que acompaña al resultado
#
# Los inputs y outputs se construyen de verdad y viajan en la Transaction que
# recibe el validator: lo que se ve en pantalla es lo que el validator recibió.
# Para agregar una escena, agregá un renglón. El script se encarga del resto.
ESCENAS=(
"Bob reclama a tiempo|Claim|SI|Bob|${BOB_HASH}|[ 1000 , 5000 ]|interval.between(1_000, 5_000)|Bob|${BOB_HASH}|Firmó el beneficiario y la validity_range entera cae antes del deadline."
"Eve intenta reclamar|Claim|SI|Eve|${EVE_HASH}|[ 1000 , 5000 ]|interval.between(1_000, 5_000)|Eve|${EVE_HASH}|Eve no está en extra_signatories. El beneficiario del datum es Bob."
"Bob reclama tarde|Claim|SI|Bob|${BOB_HASH}|[ 10001 , 15000 ]|interval.between(10_001, 15_000)|Bob|${BOB_HASH}|La firma está bien, pero la validity_range arranca después del deadline (${DEADLINE})."
"Alice cancela|Cancel|SI|Alice|${ALICE_HASH}|(-∞ , +∞)|interval.everything|Alice|${ALICE_HASH}|can_cancel sólo pide la firma del owner: no mira el tiempo. Alice recupera lo bloqueado."
"UTXO sin datum|Claim|NO|Bob|${BOB_HASH}|[ 1000 , 5000 ]|interval.between(1_000, 5_000)|Bob|${BOB_HASH}|El validator hace 'expect Some(d) = datum'. Sin datum no hay nada que evaluar: aborta."
"Bob firma… y la plata va a Eve|Claim|SI|Bob|${BOB_HASH}|[ 1000 , 5000 ]|interval.between(1_000, 5_000)|Eve|${EVE_HASH}|Misma firma y mismo tiempo que la escena 1, pero el output va a Eve. El validator NUNCA mira los outputs: aprueba igual. Este es el gancho de la Clase 9."
)

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
    ''|*[!0-9]*) echo "ERROR: --escena espera un número (1..${#ESCENAS[@]})" >&2; exit 1 ;;
  esac
  if [ "$SOLO" -lt 1 ] || [ "$SOLO" -gt "${#ESCENAS[@]}" ]; then
    echo "ERROR: no hay escena $SOLO (hay ${#ESCENAS[@]})" >&2; exit 1
  fi
fi

# --- Motor: aiken local, o el contenedor del curso ---------------------------
# En la máquina del profe puede no haber aiken instalado; si está la imagen del
# curso, nos volvemos a lanzar adentro y listo.
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
       bash -lc "scripts/demo-tx-cardano.sh --sin-pausa $([ -n "$SOLO" ] && echo "--escena $SOLO") $([ "$COLOR" = no ] && echo --sin-color)"
fi

# --- Generar el módulo de tests ----------------------------------------------
# Tiene que vivir en validators/: desde lib/ el compilador no resuelve el import
# del validator. Se borra al salir, pase lo que pase.
GEN="cardano/validators/demo_tx_tmp.ak"
trap 'rm -f "$GEN"' EXIT INT TERM

{
  echo "// Generado por scripts/demo-tx-cardano.sh — se borra solo. No editar."
  echo "use aiken/interval"
  echo "use cardano/address.{Address, VerificationKey}"
  echo "use cardano/assets"
  echo "use cardano/transaction.{Input, NoDatum, Output, OutputReference,"
  echo "  Transaction, placeholder}"
  echo "use escrow.{Cancel, Claim, Datum}"
  echo ""
  echo "fn demo_ref() -> OutputReference {"
  echo "  OutputReference { transaction_id: #\"${UTXO_REF}\", output_index: 0 }"
  echo "}"
  echo ""
  echo "fn demo_datum() -> Datum {"
  echo "  Datum { beneficiary: #\"${BOB_HASH}\", owner: #\"${ALICE_HASH}\", deadline: ${DEADLINE} }"
  echo "}"
  echo ""
  echo "fn demo_out(hash: ByteArray) -> Output {"
  echo "  Output {"
  echo "    address: Address {"
  echo "      payment_credential: VerificationKey(hash),"
  echo "      stake_credential: None,"
  echo "    },"
  echo "    value: assets.from_lovelace(${LOVELACE}),"
  echo "    datum: NoDatum,"
  echo "    reference_script: None,"
  echo "  }"
  echo "}"
  echo ""
  i=0
  for esc in "${ESCENAS[@]}"; do
    i=$((i+1))
    IFS='|' read -r _t red dat _fd fh _vd va _od oh _pq <<<"$esc"
    [ "$dat" = "SI" ] && dexpr="Some(demo_datum())" || dexpr="None"
    for signo in true false; do
      [ "$signo" = "true" ] && neg="" || neg="!"
      echo "test demo_${i}_${signo}() {"
      echo "  let tx ="
      echo "    Transaction {"
      echo "      ..placeholder,"
      # El input es el UTXO del escrow; el output, a dónde se lleva los fondos
      # quien gasta. Los dos van de verdad en la tx que ve el validator.
      echo "      inputs: ["
      echo "        Input {"
      echo "          output_reference: demo_ref(),"
      echo "          output: demo_out(#\"${SCRIPT_HASH}\"),"
      echo "        },"
      echo "      ],"
      echo "      outputs: [demo_out(#\"${oh}\")],"
      echo "      extra_signatories: [#\"${fh}\"],"
      echo "      validity_range: ${va},"
      echo "    }"
      echo "  ${neg}escrow.escrow.spend(${dexpr}, ${red}, demo_ref(), tx)"
      echo "}"
      echo ""
    done
  done
} > "$GEN"

printf '%s\n' "${D}Compilando el validator y ejecutándolo sobre cada transacción…${R}" >&2
JSON="$(cd cardano && aiken check -m demo_ 2>/dev/null || true)"

if [ -z "$JSON" ]; then
  echo "ERROR: 'aiken check' no devolvió resultados. Probá a mano:" >&2
  echo "       cd cardano && aiken check -m demo_" >&2
  exit 1
fi

# title|status|mem|cpu, uno por línea. Se evita depender de jq.
RES="$(printf '%s\n' "$JSON" | awk '
  /"title"/  { t=$0; sub(/.*"title"[^"]*"/,"",t);  sub(/".*/,"",t) }
  /"status"/ { s=$0; sub(/.*"status"[^"]*"/,"",s); sub(/".*/,"",s) }
  /"mem"/    { m=$0; sub(/.*"mem"[^0-9]*/,"",m);   sub(/[^0-9].*/,"",m) }
  /"cpu"/    { c=$0; sub(/.*"cpu"[^0-9]*/,"",c);   sub(/[^0-9].*/,"",c); print t "|" s "|" m "|" c }
')"

campo() { printf '%s\n' "$RES" | awk -F'|' -v k="$1" -v n="$2" '$1==k {print $n; exit}'; }

# 103096 -> 103.096
miles() { printf '%s' "$1" | awk '{ s=$0; o=""; while (length(s)>3) { o="." substr(s,length(s)-2) o; s=substr(s,1,length(s)-3) } print s o }'; }

linea() { printf '%s\n' "${D}────────────────────────────────────────────────────────────────${R}"; }

# --- Escena 0: el LOCK, que no ejecuta nada ----------------------------------
if [ -z "$SOLO" ]; then
  printf '\n%s\n\n' "${B}${CIAN}ESCENA 0 · Alice bloquea 100 ADA${R}"
  printf '  %s\n' "Alice arma una transacción común cuyo output va a la dirección del"
  printf '  %s\n\n' "escrow, con el datum pegado."
  printf '    %s\n' "${B}outputs${R}        100 ADA → dirección del escrow"
  printf '    %s\n' "${B}datum${R}          beneficiary = Bob    #${BOB_HASH}"
  printf '    %s\n' "               owner       = Alice  #${ALICE_HASH}"
  printf '    %s\n\n' "               deadline    = ${DEADLINE}"
  printf '  %s\n' "${AMAR}El validator NO se ejecuta.${R} Depositar no requiere permiso de nadie:"
  printf '  %s\n' "es una transferencia común. No hay nada que ejecutar acá — por eso"
  printf '  %s\n\n' "esta escena no le pregunta nada a Aiken."
  printf '  %s\n\n' "${D}El validator es un portero de salida, no de entrada.${R}"
  linea
  if [ "$PAUSA" = "si" ]; then printf '%s' "${D}  [enter]${R}"; read -r _ </dev/tty || true; printf '\n'; fi
fi

# --- Escenas con validator ---------------------------------------------------
i=0
for esc in "${ESCENAS[@]}"; do
  i=$((i+1))
  [ -n "$SOLO" ] && [ "$SOLO" != "$i" ] && continue

  IFS='|' read -r titulo red dat fd fh vd _va od oh pq <<<"$esc"

  st_true="$(campo "demo_${i}_true" 2)"
  st_false="$(campo "demo_${i}_false" 2)"
  mem="$(campo "demo_${i}_true" 3)"; cpu="$(campo "demo_${i}_true" 4)"
  if [ "$st_true" != "pass" ]; then
    mem="$(campo "demo_${i}_false" 3)"; cpu="$(campo "demo_${i}_false" 4)"
  fi

  printf '\n%s\n\n' "${B}${CIAN}ESCENA ${i} · ${titulo}${R}"

  printf '  %s\n' "${B}EL UTXO BLOQUEADO${R}  ${D}(lo creó Alice; el validator no corrió)${R}"
  printf '    %s\n' "ref            ${UTXO_REF:0:8}…${UTXO_REF: -4} # 0"
  printf '    %s\n' "valor          100 ADA"
  if [ "$dat" = "SI" ]; then
    printf '    %s\n' "datum          beneficiary = Bob    #${BOB_HASH}"
    printf '    %s\n' "               owner       = Alice  #${ALICE_HASH}"
    printf '    %s\n' "               deadline    = ${DEADLINE}"
  else
    printf '    %s\n' "datum          ${AMAR}(ninguno)${R}"
  fi
  printf '\n'

  printf '  %s\n' "${B}LA TRANSACCIÓN${R}  ${D}(la arma ${fd}, off-chain)${R}"
  printf '    %s\n' "inputs         ${UTXO_REF:0:8}…${UTXO_REF: -4} # 0   ← el UTXO del escrow"
  printf '    %s\n' "redeemer       ${red}"
  if [ "$od" != "$fd" ]; then
    printf '    %s\n' "outputs        ${AMAR}100 ADA → ${od}  #${oh}${R}"
  else
    printf '    %s\n' "outputs        100 ADA → ${od}  #${oh}"
  fi
  printf '    %s\n' "signatories    [ ${fd}  #${fh} ]"
  printf '    %s\n' "validity_range ${vd}"
  printf '\n'

  printf '  %s\n' "${B}EJECUCIÓN${R}  ${D}escrow.spend(datum, ${red}, ref, tx)${R}"
  if [ "$st_true" = "pass" ] && [ "$st_false" != "pass" ]; then
    printf '    %s\n' "devuelve       ${VERDE}${B}True${R}"
    printf '    %s\n' "la tx          ${VERDE}es VÁLIDA — el UTXO se consume${R}"
  elif [ "$st_false" = "pass" ] && [ "$st_true" != "pass" ]; then
    printf '    %s\n' "devuelve       ${ROJO}${B}False${R}"
    printf '    %s\n' "la tx          ${ROJO}se rechaza ENTERA — el UTXO queda intacto${R}"
  elif [ -z "$st_true" ] && [ -z "$st_false" ]; then
    printf '    %s\n' "${ROJO}no se pudo determinar (¿falló la compilación?)${R}"
  else
    printf '    %s\n' "no devuelve    ${ROJO}${B}el validator ABORTA${R}"
    printf '    %s\n' "la tx          ${ROJO}se rechaza ENTERA${R}"
  fi
  if [ -n "$mem" ] && [ -n "$cpu" ]; then
    pm="$(awk -v m="$mem" 'BEGIN{printf "%.2f", m*100/16500000}')"
    pc="$(awk -v c="$cpu" 'BEGIN{printf "%.2f", c*100/10000000000}')"
    printf '    %s\n' "${D}ExUnits        mem $(miles "$mem") (${pm}% del tope)   cpu $(miles "$cpu") (${pc}%)${R}"
  fi
  printf '\n'

  printf '  %s\n\n' "${B}POR QUÉ${R}  ${pq}"
  linea

  if [ "$PAUSA" = "si" ]; then printf '%s' "${D}  [enter]${R}"; read -r _ </dev/tty || true; printf '\n'; fi
done

# --- Remate ------------------------------------------------------------------
if [ -z "$SOLO" ]; then
  printf '\n%s\n\n' "${B}Lo que hay que llevarse${R}"
  printf '  %s\n' "· El validator ${B}no movió un solo ADA${R}. Sólo dijo True o False."
  printf '  %s\n' "· Quién recibe los 100 ADA lo decidió ${B}la transacción${R}, que armó quien gasta."
  printf '  %s\n' "· Un False ${B}invalida la transacción entera${R}, no sólo ese input."
  printf '  %s\n\n' "· Depositar ni siquiera consultó al validator (escena 0)."
  printf '  %s\n' "${AMAR}Y la escena 6, que conviene dejar picando:${R} el validator verificó que"
  printf '  %s\n' "Bob ${B}firmara${R}, pero nunca miró ${B}a dónde van los 100 ADA${R} — y aprobó una"
  printf '  %s\n' "tx que se los lleva a ${EVE_NOMBRE}. Ese output estaba de verdad en la"
  printf '  %s\n\n' "transacción: el validator simplemente no lo mira. Clase 9."
fi
