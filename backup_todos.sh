#!/bin/bash
# Script para hacer backup de varios contenedores
# Uso: ./backup_todos.sh

# Lista de carpetas de contenedores a respaldar (modifica según tus necesidades)
CONTAINERS=(16 29 30 32 33 34)



for CONT in "${CONTAINERS[@]}"; do
  echo "\n==============================="
  echo "Iniciando backup de carpeta: $CONT"
  /data/odoo/backup_contenedor.sh "$CONT"
  echo "Backup de $CONT finalizado."
done

echo "\nTodos los backups han finalizado."
