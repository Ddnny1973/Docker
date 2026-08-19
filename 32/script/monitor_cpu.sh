#!/bin/bash
# Monitoreo de CPU/memoria para el stack 32 (n8n)
# Ejecutar con cron cada 5 minutos:
#   */5 * * * * /data/odoo/32/script/monitor_cpu.sh
#
# Los logs quedan en /data/odoo/32/logs/cpu_monitor.log
# Para detener: quitar la línea del crontab
# Para ver en tiempo real: tail -f /data/odoo/32/logs/cpu_monitor.log

PROYECTO="32"
COMPOSE_DIR="/data/odoo/$PROYECTO"
LOG_DIR="$COMPOSE_DIR/logs"
LOG_FILE="$LOG_DIR/cpu_monitor.log"
RESUMEN_FILE="$LOG_DIR/cpu_resumen.log"
TOPProcesses="$LOG_DIR/top_processes.log"

mkdir -p "$LOG_DIR"

# Obtener IDs de contenedores del proyecto
CONTAINERS=$(docker compose -f "$COMPOSE_DIR/docker-compose.yml" ps -q 2>/dev/null)

if [ -z "$CONTAINERS" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] No se encontraron contenedores activos en el proyecto $PROYECTO" >> "$LOG_FILE"
    exit 1
fi

NOMBRES=$(docker compose -f "$COMPOSE_DIR/docker-compose.yml" ps --format '{{.Name}}' 2>/dev/null)

echo "========================================" >> "$LOG_FILE"
echo "MUESTRA: $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE"
echo "========================================" >> "$LOG_FILE"

# Capturar stats de CPU y memoria de cada contenedor (sin streaming, una sola muestra)
echo "--- CPU y Memoria por contenedor ---" >> "$LOG_FILE"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}\t{{.PIDs}}" $CONTAINERS >> "$LOG_FILE" 2>&1
echo "" >> "$LOG_FILE"

# Resumen rápido: contenedor con mayor CPU en esta muestra
echo "--- Contenedor con mayor CPU ---" >> "$LOG_FILE"
docker stats --no-stream --format "{{.Name}} {{.CPUPerc}}" $CONTAINERS 2>/dev/null | sort -t'%' -k1 -rn | head -3 >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# Verificar si algún contenedor tiene más del 80% de CPU
HIGH_CPU=$(docker stats --no-stream --format "{{.Name}} {{.CPUPerc}}" $CONTAINERS 2>/dev/null | awk -F'[% ]' '{if ($3 > 80) print $2, $3"%"}')
if [ -n "$HIGH_CPU" ]; then
    echo "[ALERTA] Contenedores con CPU > 80%:" >> "$LOG_FILE"
    echo "$HIGH_CPU" >> "$LOG_FILE"

    # Si hay contenedor con alta CPU, capturar sus procesos internos
    HIGH_CPU_CONTAINER=$(docker stats --no-stream --format "{{.Name}} {{.CPUPerc}}" $CONTAINERS 2>/dev/null | sort -t'%' -k1 -rn | head -1 | awk '{print $1}')
    echo "--- Procesos dentro de $HIGH_CPU_CONTAINER (por CPU) ---" >> "$LOG_FILE"
    docker exec "$HIGH_CPU_CONTAINER" sh -c "ps aux --sort=-%cpu 2>/dev/null | head -15" >> "$LOG_FILE" 2>&1
    echo "" >> "$LOG_FILE"
fi

# Verificar contenedores que se reiniciaron (puede indicar crash loop)
echo "--- Estado de reinicios ---" >> "$LOG_FILE"
docker compose -f "$COMPOSE_DIR/docker-compose.yml" ps --format '{{.Name}}\t{{.Status}}' >> "$LOG_FILE" 2>&1
echo "" >> "$LOG_FILE"

# Logs recientes de errores (últimas 5 líneas de stderr por contenedor)
echo "--- Errores recientes por contenedor ---" >> "$LOG_FILE"
for CONTAINER in $CONTAINERS; do
    NOMBRE=$(docker inspect --format '{{.Name}}' "$CONTAINER" 2>/dev/null | sed 's/^\///')
    ERRORES=$(docker logs --tail=5 --since=5m "$CONTAINER" 2>&1 | grep -i -E "error|exception|fatal|killed|oom|sigterm|restart" | tail -3)
    if [ -n "$ERRORES" ]; then
        echo "  [$NOMBRE]" >> "$LOG_FILE"
        echo "$ERRORES" >> "$LOG_FILE"
    fi
done
echo "" >> "$LOG_FILE"

# Resumen historial: append al archivo resumen (una línea por muestra)
TIEMPO=$(date '+%Y-%m-%d %H:%M:%S')
STATS_LINE=$(docker stats --no-stream --format "{{.Name}}={{.CPUPerc}}" $CONTAINERS 2>/dev/null | tr '\n' ' ')
echo "$TIEMPO | $STATS_LINE" >> "$RESUMEN_FILE"

echo "$(date '+%Y-%m-%d %H:%M:%S') [OK] Muestra registrada en $LOG_FILE" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"
