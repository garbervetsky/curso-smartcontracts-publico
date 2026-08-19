# shellcheck shell=bash
#
# asegurar_node_moderno <version_minima> <para_que>
#
# Antepone al PATH un `node` lo bastante nuevo, o falla con un mensaje que se
# entienda.
#
# Por qué existe: todo lo que corre sobre node en este repo (marp, tsx, Mesh) se
# ejecuta con el `node` del PATH, y en más de una máquina el default de nvm quedó
# en v11. Ese node no parsea optional chaining, así que la herramienta muere con
#
#     SyntaxError: Unexpected token .      (o "Unexpected token {")
#         at new Script (vm.js:80:7)
#
# que no menciona a node por ningún lado y manda a buscar el problema en la
# herramienta. Ya nos costó el diagnóstico dos veces; de ahí este helper.
#
# Uso:
#     . "$(dirname "$0")/lib/node-moderno.sh"
#     asegurar_node_moderno 18 marp

_node_major() {
  local v
  v="$("$1" --version 2>/dev/null)" || return 1
  v="${v#v}"
  [ -n "${v%%.*}" ] && printf '%s' "${v%%.*}"
}

asegurar_node_moderno() {
  local min="${1:-18}" para="${2:-esto}" viejo mejor cand m

  _node_ok() {
    local n
    n="$(_node_major "$1")" || return 1
    [ -n "$n" ] && [ "$n" -ge "$min" ]
  }

  if _node_ok node; then return 0; fi

  viejo="$(node --version 2>/dev/null || echo 'ninguno')"
  mejor=""
  for cand in "$HOME/.nvm/versions/node"/*/bin/node; do
    [ -x "$cand" ] && _node_ok "$cand" || continue
    if [ -z "$mejor" ] || [ "$(_node_major "$cand")" -gt "$(_node_major "$mejor")" ]; then
      mejor="$cand"
    fi
  done

  if [ -z "$mejor" ]; then
    echo "ERROR: ${para} necesita node >= ${min} y el del PATH es ${viejo}." >&2
    echo "       Instalá uno moderno (nvm install 24) o usá el contenedor del curso." >&2
    return 1
  fi

  export PATH="$(dirname "$mejor"):$PATH"
  echo "→ node del PATH era ${viejo}; uso $("$mejor" --version)" >&2
}
