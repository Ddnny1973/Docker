#!/bin/bash
# Script para backup de contenedores Docker
# Uso: ./backup_contenedor.sh <carpeta_contenedor>

set -e

if [ -z "$1" ]; then
  echo "Uso: $0 <carpeta_contenedor>"
  exit 1
fi


CARPETA="$1"
NUMERO=$(basename "$CARPETA")
CARPETA_ABS="/data/odoo/$CARPETA"
BACKUP_DIR="/mnt/hetzner-backup/$NUMERO"
FECHA=$(date +"%Y%m%d_%H%M%S")
ARCHIVO_BACKUP="$BACKUP_DIR/backup_${NUMERO}_$FECHA.tar.gz"


# Crear carpeta de backup si no existe
mkdir -p "$BACKUP_DIR"

cd "$CARPETA_ABS"

echo "Deteniendo contenedores en $CARPETA..."
docker compose stop

echo "Realizando backup comprimido de $CARPETA a $ARCHIVO_BACKUP..."
tar -czf "$ARCHIVO_BACKUP" .

echo "Levantando contenedores en $CARPETA..."
docker compose start

echo "Backup completado: $ARCHIVO_BACKUP"
