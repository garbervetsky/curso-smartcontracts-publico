#!/usr/bin/env bash
# Lanzador de los scripts del off-chain.
#
# No se invoca a mano: lo usan los `npm run` de package.json.
#
# Existe porque `npm run` ejecuta tsx con el `node` del PATH, y si ese node es
# viejo (el default de nvm llegó a ser v11 en la máquina donde se prepara el
# curso) el error que sale es un "SyntaxError: Unexpected token {" adentro de
# tsx, que no dice nada sobre node. Acá elegimos un node usable antes de
# arrancar. Ver scripts/lib/node-moderno.sh.

set -euo pipefail
cd "$(dirname "$0")"

# shellcheck source=../../scripts/lib/node-moderno.sh
. ../../scripts/lib/node-moderno.sh
asegurar_node_moderno 20 "el off-chain de Cardano (Mesh + tsx)"

# --- ¿El devnet está acá adentro? -------------------------------------------
# La imagen del curso trae YACI_API=http://host.containers.internal:8080/...,
# que es correcto cuando el devnet corre en el host. Pero `scripts/devnet.sh`
# también sabe levantarlo DENTRO del contenedor, y ahí esa dirección apunta al
# lugar equivocado: el alumno ve "No pude hablar con el devnet" con el devnet
# corriendo a un centímetro. Si el default de la imagen sigue puesto y hay un
# devnet contestando en localhost, gana localhost.
#
# Sólo se toca el valor de la imagen: si vos exportaste otro YACI_API, se
# respeta (es la forma de apuntar a un devnet remoto o a otro puerto).
case "${YACI_API:-}" in
  *host.containers.internal*|*host.docker.internal*)
    if command -v curl >/dev/null 2>&1 &&
       curl -s -m 2 http://localhost:8080/api/v1/blocks/latest 2>/dev/null | grep -q '"height"'; then
      echo "→ hay un devnet en localhost (adentro del contenedor): uso ese, no el del host." >&2
      export YACI_API="http://localhost:8080/api/v1/"
      export YACI_ADMIN="http://localhost:10000/local-cluster/api/"
    fi
    ;;
esac

# Se invocan los binarios locales en vez de `npx`: si el npm que lanzó esto es
# viejo, exporta un montón de npm_config_* que el npx moderno no entiende y
# llena la pantalla de warnings antes de que arranque la demo.
if [ ! -x node_modules/.bin/tsx ]; then
  echo "ERROR: falta node_modules. Corré:  npm install" >&2
  exit 1
fi

if [ "${1:-}" = "tsc" ]; then
  exec node_modules/.bin/tsc --noEmit
fi
exec node_modules/.bin/tsx "$@"
