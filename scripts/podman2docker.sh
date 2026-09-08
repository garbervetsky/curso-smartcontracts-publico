#!/bin/bash

# Configuración por defecto (basada en tu comando)
IMAGE_ID=${1:-"417ca69bc749"}
OUTPUT_TAR=${2:-"curso-sc.tar"}

echo "1. Exportando la imagen desde Podman (Formato: docker-archive)..."
podman save --format docker-archive -o "$OUTPUT_TAR" "$IMAGE_ID"

if [ $? -eq 0 ]; then
    echo "¡Exportación exitosa! Archivo generado: $OUTPUT_TAR"
else
    echo "Error al exportar la imagen de Podman."
    exit 1
fi

echo "2. Cargando la imagen en Docker..."
docker load -i "$OUTPUT_TAR"

if [ $? -eq 0 ]; then
    echo "¡Listo! La imagen $IMAGE_ID se importó en Docker correctamente."
else
    echo "Error al cargar la imagen en Docker."
    exit 1
fi
