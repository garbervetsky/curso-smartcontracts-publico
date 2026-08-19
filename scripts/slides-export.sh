#!/usr/bin/env bash
# Exporta los decks de docs/slides/ a PPTX (imágenes) o PDF, con Marp.
#
#   ./scripts/slides-export.sh            # PPTX (imágenes) de todas las clases
#   ./scripts/slides-export.sh --pdf      # PDF de todas
#   ./scripts/slides-export.sh --pdf 06   # solo la clase 06
#
# La fuente editable de un deck es su `slides.md`: editá ahí y re-exportá.
# El PPTX de Marp es de IMÁGENES (fiel al diseño, no editable) — es a propósito;
# ver docs/slides/README.md para por qué no hay una exportación editable que sirva
# con estos decks (los diagramas son SVG).

set -euo pipefail
cd "$(dirname "$0")/.."

FMT="--pptx"; ONLY=""
for arg in "$@"; do
  case "$arg" in
    --pdf)      FMT="--pdf" ;;
    --pptx)     FMT="--pptx" ;;
    [0-9][0-9]) ONLY="$arg" ;;
    *) echo "arg desconocido: $arg (usá --pptx | --pdf | NN)" >&2; exit 1 ;;
  esac
done

# Marp corre con el `node` del PATH y muere feo si es viejo. Ver el helper.
# shellcheck source=lib/node-moderno.sh
. "$(dirname "$0")/lib/node-moderno.sh"
asegurar_node_moderno 18 marp

# Ojo: el marp instalado bajo un node viejo queda roto igual, así que sólo lo
# aceptamos si resuelve al node bueno que acabamos de anteponer.
if command -v marp >/dev/null 2>&1; then MARP=(marp); else MARP=(npx --yes @marp-team/marp-cli@latest); fi
EXT="pptx"; [ "$FMT" = "--pdf" ] && EXT="pdf"

for dir in docs/slides/clase-*/; do
  n="${dir#docs/slides/clase-}"; n="${n%/}"
  [ -n "$ONLY" ] && [ "$ONLY" != "$n" ] && continue
  src="${dir}slides.md"; [ -f "$src" ] || continue
  echo "→ clase-$n → ${dir}slides.${EXT}"
  # --html es OBLIGATORIO: los diagramas son <svg> inline (HTML crudo); sin este
  # flag Marp los descarta y las slides salen sin gráficos.
  "${MARP[@]}" "$src" $FMT --html --allow-local-files -o "${dir}slides.${EXT}"
done
echo "Listo."
