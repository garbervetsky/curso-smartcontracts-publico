#!/usr/bin/env bash
# Construye la imagen del curso para una o ambas arquitecturas.
#
#   ./scripts/build-image.sh amd64     # labs Intel  (el target de clase)
#   ./scripts/build-image.sh arm64     # Apple Silicon (preparar/demos locales)
#   ./scripts/build-image.sh both
#   FULL=1 ./scripts/build-image.sh amd64    # + Aderyn, Medusa, halmos, Chromium
#
# Notas:
#  - amd64 sobre Apple Silicon se construye por EMULACIÓN: anda, pero es lento.
#    Si tenés una máquina Intel a mano, construir ahí es mucho más rápido.
#  - arm64 compila Aiken desde fuente (no hay binario aarch64-linux oficial),
#    así que la primera vez tarda bastante más.

set -euo pipefail

TARGET="${1:-both}"
IMAGE="${IMAGE:-curso-sc}"

# Usa podman si está; si no, docker. En macOS el .pkg lo deja en /opt/podman/bin.
if command -v podman >/dev/null 2>&1; then
    ENGINE=podman
elif [ -x /opt/podman/bin/podman ]; then
    ENGINE=/opt/podman/bin/podman
elif command -v docker >/dev/null 2>&1; then
    ENGINE=docker
else
    echo "ERROR: no encontré podman ni docker." >&2
    exit 1
fi

EXTRA=()
if [ "${FULL:-0}" = "1" ]; then
    EXTRA=(--build-arg INSTALL_ADERYN=true
           --build-arg INSTALL_MEDUSA=true
           --build-arg INSTALL_HALMOS=true
           --build-arg INSTALL_CHROMIUM=true)
fi

build_arch() {
    local arch="$1"
    echo ""
    echo "=== Construyendo ${IMAGE}:${arch} (linux/${arch}) con ${ENGINE} ==="
    "$ENGINE" build \
        --platform "linux/${arch}" \
        -t "${IMAGE}:${arch}" \
        "${EXTRA[@]+"${EXTRA[@]}"}" \
        .
    echo "=== OK: ${IMAGE}:${arch} ==="
    "$ENGINE" run --rm --platform "linux/${arch}" "${IMAGE}:${arch}" cat /home/curso/VERSIONES.txt
}

case "$TARGET" in
    amd64|arm64) build_arch "$TARGET" ;;
    both)        build_arch amd64; build_arch arm64 ;;
    *) echo "uso: $0 [amd64|arm64|both]" >&2; exit 1 ;;
esac

echo ""
echo "Listo. Para distribuir a los labs:"
echo "  ${ENGINE} save ${IMAGE}:amd64 -o curso-sc-amd64.tar   # y en el lab: podman load -i ..."
