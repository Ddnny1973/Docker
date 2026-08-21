#!/bin/bash
# Script de monitoreo de CPU y memoria cada 5 minutos
# Uso: Ejecutar vía cron cada 5 minutos
# */5 * * * * /data/odoo/monitor_resources.sh

LOG_FILE="/var/log/monitor_resources.log"
THRESHOLD_CPU=80      # Alerta si CPU > 80%
THRESHOLD_MEM=85      # Alerta si MEM > 85%

# Obtener porcentaje de CPU (promedio actual)
CPU_PERCENT=$(top -bn1 | grep "Cpu(s)" | awk '{print int($2)}')

# Obtener porcentaje de memoria
MEM_PERCENT=$(free | grep Mem | awk '{printf("%.0f", ($3/$2) * 100)}')

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Escribir en log (línea normal de monitoreo)
echo "$TIMESTAMP | CPU: ${CPU_PERCENT}% | MEM: ${MEM_PERCENT}%" >> "$LOG_FILE"

# Alertas si supera umbrales
if [ "$CPU_PERCENT" -gt "$THRESHOLD_CPU" ]; then
    echo "$TIMESTAMP [ALERTA] CPU ALTA: ${CPU_PERCENT}%" >> "$LOG_FILE"
fi

if [ "$MEM_PERCENT" -gt "$THRESHOLD_MEM" ]; then
    echo "$TIMESTAMP [ALERTA] MEMORIA ALTA: ${MEM_PERCENT}%" >> "$LOG_FILE"
fi
