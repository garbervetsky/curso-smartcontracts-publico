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
