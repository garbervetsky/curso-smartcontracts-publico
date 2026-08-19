#!/usr/bin/env bash
# Devnet local de Cardano (Yaci DevKit) para la demo de transacciones reales.
#
#   ./scripts/devnet.sh up       # levantar (la primera vez baja el cardano-node)
#   ./scripts/devnet.sh estado   # ¿está vivo? ¿en qué slot va?
#   ./scripts/devnet.sh logs     # seguir el log del nodo
#   ./scripts/devnet.sh reset    # borrar la cadena y empezar de cero
#   ./scripts/devnet.sh down     # apagar
#
# Es una cadena descartable que corre en tu máquina: bloques cada 1 segundo,
# 20 cuentas con 10.000 ADA cada una, y ningún faucet que mendigar. Ver
# cardano/offchain/README.md y docs/guia-profesor/clase-04.md §5bis.
#
# OJO: corre en el HOST, no adentro del contenedor del curso. Levanta el devnet
# como un contenedor más, al lado del contenedor del curso — no adentro de él.
# Desde adentro, el off-chain lo alcanza vía host.containers.internal (Podman)
# o host.docker.internal (Docker); esas variables ya vienen puestas en la imagen.

set -euo pipefail
cd "$(dirname "$0")/.."

IMAGEN="curso-devnet"
NOMBRE="curso-devnet"
VOLUMEN="curso-devnet-data"   # cachea el cardano-node entre arranques
API="http://localhost:8080/api/v1"
ADMIN="http://localhost:10000/local-cluster/api"

# --- ¿Nos están corriendo DENTRO del contenedor del curso? -------------------
# Este script levanta el devnet *como un contenedor*, así que es un script de
# HOST. Adentro de la imagen del curso no hay motor de contenedores (ni debería
# haberlo), y sin este chequeo el error que sale es el genérico de más abajo,
# que manda a `podman machine start` — consejo inútil si ya estás adentro.
if [ -f /run/.containerenv ] || [ -f /.dockerenv ]; then
  cat >&2 <<'FIN'
ERROR: esto hay que correrlo en tu máquina, no adentro del contenedor.

  `devnet.sh` levanta el devnet como un contenedor aparte. Acá adentro no hay
  motor de contenedores, así que no puede funcionar — y no falta instalar nada.

  1) En una terminal de tu máquina (el host), parado en tu clon del repo:

         ./scripts/devnet.sh up

  2) Volvé a esta terminal: el off-chain ya sabe encontrarlo, porque YACI_API
     apunta al host.

         cd /curso/cardano/offchain && npm run demo

  Con Docker en vez de Podman hay que pasarle la otra dirección del host:

         YACI_API=http://host.docker.internal:8080/api/v1/ npm run demo
FIN
  exit 1
fi

# --- Motor de contenedores ---------------------------------------------------
ENGINE=""
for e in podman /opt/podman/bin/podman docker; do
  if command -v "$e" >/dev/null 2>&1 || [ -x "$e" ]; then
    "$e" info >/dev/null 2>&1 && { ENGINE="$e"; break; }
  fi
done
if [ -z "$ENGINE" ]; then
  echo "ERROR: no encontré podman ni docker corriendo." >&2
  echo "       En macOS con Podman: podman machine start" >&2
  exit 1
fi

altura() { curl -s -m 5 "$API/blocks/latest" 2>/dev/null | sed -n 's/.*"height":\([0-9]*\).*/\1/p'; }

# "Vivo" es que ya haya bloques, no que el endpoint conteste: recién arrancado,
# Yaci Store responde antes de tener el primer bloque indexado.
vivo() { [ -n "$(altura)" ]; }
corriendo() { "$ENGINE" ps --format '{{.Names}}' 2>/dev/null | grep -qx "$NOMBRE"; }

# Que la API conteste NO alcanza: el nodo puede seguir vivo y haber dejado de
# forjar (le pasa a este devnet si queda corriendo horas). Desde afuera se ve
# igual, pero ninguna transacción entra nunca. La única prueba es que la altura
# suba.
avanza() {
  local a b i
  a="$(altura)"
  [ -n "$a" ] || return 1
  for i in 1 2 3 4 5 6; do
    sleep 1
    b="$(altura)"
    [ -n "$b" ] && [ "$b" -gt "$a" ] 2>/dev/null && return 0
  done
  return 1
}

construir_si_hace_falta() {
  if ! "$ENGINE" image exists "$IMAGEN" 2>/dev/null &&
     ! "$ENGINE" images --format '{{.Repository}}' 2>/dev/null | grep -q "^\(localhost/\)\?${IMAGEN}$"; then
    echo "→ construyendo la imagen ${IMAGEN} (una sola vez)…"
    "$ENGINE" build --platform linux/amd64 -f Containerfile.devnet -t "$IMAGEN" .
  fi
}

case "${1:-up}" in

  up)
    if vivo; then
      if avanza; then
        echo "El devnet ya está corriendo ($API)"
        exit 0
      fi
      echo "Hay un devnet levantado pero la cadena está detenida; lo recreo."
      "$0" reset
    fi
    construir_si_hace_falta
    "$ENGINE" rm -f "$NOMBRE" >/dev/null 2>&1 || true
    echo "→ levantando el devnet…"
    "$ENGINE" run -d --name "$NOMBRE" --platform linux/amd64 \
      -p 8080:8080 -p 10000:10000 -p 3001:3001 \
      -v "${VOLUMEN}:/root/.yaci-cli" \
      "$IMAGEN" >/dev/null
    echo "  (la primera vez baja el cardano-node: puede tardar unos minutos)"
    printf '  esperando'
    intentos=0
    until vivo; do
      intentos=$((intentos+1))
      if [ $intentos -gt 300 ]; then
        echo ""
        echo "ERROR: no arrancó en 5 minutos. Mirá el log:  $0 logs" >&2
        exit 1
      fi
      if ! corriendo; then
        echo ""
        echo "ERROR: el contenedor se murió. Log:" >&2
        "$ENGINE" logs "$NOMBRE" 2>&1 | tail -20 >&2
        exit 1
      fi
      printf '.'
      sleep 2
    done
    echo ""
    exec "$0" estado
    ;;

  estado)
    if ! vivo; then
      echo "El devnet NO está corriendo."
      echo "Levantalo con:  $0 up"
      exit 1
    fi
    b="$(curl -s "$API/blocks/latest")"
    slot="$(printf '%s' "$b" | sed -n 's/.*"slot":\([0-9]*\).*/\1/p')"
    alto="$(printf '%s' "$b" | sed -n 's/.*"height":\([0-9]*\).*/\1/p')"
    echo "  API (Blockfrost-compatible)  $API"
    echo "  admin API                    $ADMIN"
    echo "  bloque                       #${alto:-?}  (slot ${slot:-?})"
    echo ""
    if avanza; then
      echo "Devnet arriba y produciendo bloques."
      echo ""
      echo "Ahora:  cd cardano/offchain && npm run demo"
    else
      echo "ATENCIÓN: la API contesta pero la cadena NO avanza (sigue en el bloque #${alto:-?})."
      echo "El nodo dejó de forjar; ninguna transacción va a entrar."
      echo ""
      echo "Se arregla asi:  $0 reset && $0 up"
      exit 1
    fi
    ;;

  logs)
    exec "$ENGINE" logs -f "$NOMBRE"
    ;;

  reset)
    # Borra la cadena pero NO el volumen: ahí vive el cardano-node descargado, y
    # tirarlo obliga a bajar cientos de MB otra vez. Sólo se limpian los datos
    # del cluster, que es lo que se quiere recrear.
    echo "→ borrando la cadena…"
    "$ENGINE" rm -f "$NOMBRE" >/dev/null 2>&1 || true
    "$ENGINE" run --rm --platform linux/amd64 -v "${VOLUMEN}:/root/.yaci-cli" \
      "$IMAGEN" bash -c 'rm -rf /root/.yaci-cli/local-clusters' >/dev/null 2>&1 || true
    echo "→ listo; volvé a levantarlo con:  $0 up"
    ;;

  down)
    "$ENGINE" rm -f "$NOMBRE" >/dev/null 2>&1 && echo "Devnet apagado." || echo "No estaba corriendo."
    ;;

  *)
    echo "uso: $0 [up|estado|logs|reset|down]" >&2
    exit 1
    ;;
esac
