#!/bin/bash
# Script de monitoreo de CPU y memoria cada 2 minutos
# + Top 5 contenedores por consumo
# Uso: */2 * * * * /data/odoo/monitor_resources.sh

LOG_FILE="/mnt/hetzner-backup/monitor_resources.log"
THRESHOLD_CPU=80      # Alerta si CPU > 80%
THRESHOLD_MEM=85      # Alerta si MEM > 85%

# ===========================================
# 1. MONITOREO GLOBAL DEL SERVIDOR
# ===========================================
CPU_PERCENT=$(top -bn1 | grep "Cpu(s)" | awk '{print int($2)}')
MEM_PERCENT=$(free | grep Mem | awk '{printf("%.0f", ($3/$2) * 100)}')
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

echo "$TIMESTAMP | GLOBAL - CPU: ${CPU_PERCENT}% | MEM: ${MEM_PERCENT}%" >> "$LOG_FILE"

# ===========================================
# 2. TOP 5 CONTENEDORES POR CONSUMO (CPU + MEM)
# ===========================================
echo "$TIMESTAMP | TOP CONTENEDORES:" >> "$LOG_FILE"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemPerc}}" 2>/dev/null | tail -n +2 | head -5 >> "$LOG_FILE"

# ===========================================
# 3. ALERTAS
# ===========================================
if [ "$CPU_PERCENT" -gt "$THRESHOLD_CPU" ]; then
    echo "$TIMESTAMP [🚨 ALERTA] CPU ALTA: ${CPU_PERCENT}%" >> "$LOG_FILE"
fi

if [ "$MEM_PERCENT" -gt "$THRESHOLD_MEM" ]; then
    echo "$TIMESTAMP [🚨 ALERTA] MEMORIA ALTA: ${MEM_PERCENT}%" >> "$LOG_FILE"
fi
