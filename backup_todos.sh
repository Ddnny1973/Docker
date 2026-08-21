#!/bin/bash
# Script para hacer backup de varios contenedores
# Uso: ./backup_todos.sh

# Lista de carpetas de contenedores a respaldar (consolidados en Alma-16GB)
# Proyectos Odoo activos: 29, 30, 35, 36, 37, 41, 42, 43
# Proyectos especiales: 32 (n8n+IA), pgadmin4
CONTAINERS=(29 30 32 35 36 37 41 42 43 pgadmin4)



for CONT in "${CONTAINERS[@]}"; do
  echo "\n==============================="
  echo "Iniciando backup de carpeta: $CONT"
  /data/odoo/backup_contenedor.sh "$CONT"
  echo "Backup de $CONT finalizado."
done

echo "\nTodos los backups han finalizado."
