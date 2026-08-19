#!/bin/bash
# Instala el cron de monitoreo de CPU para el stack 32
# Ejecutar como root o con sudo en el servidor

SCRIPT_DIR="/data/odoo/32/script"
SCRIPT="$SCRIPT_DIR/monitor_cpu.sh"
CRON_LINE="*/5 * * * * $SCRIPT"
LOG_DIR="$SCRIPT_DIR/logs"

# Verificar que el script existe
if [ ! -f "$SCRIPT" ]; then
    echo "Error: $SCRIPT no existe"
    exit 1
fi

chmod +x "$SCRIPT"
mkdir -p "$LOG_DIR"

# Verificar si ya está en el crontab
EXISTENTE=$(crontab -l 2>/dev/null | grep "monitor_cpu.sh")
if [ -n "$EXISTENTE" ]; then
    echo "El cron ya está instalado:"
    echo "$EXISTENTE"
    echo ""
    echo "Para eliminar: crontab -e (y borrar la línea)"
    echo "Para ver logs: tail -f $LOG_DIR/cpu_monitor.log"
    exit 0
fi

# Agregar al crontab
(crontab -l 2>/dev/null; echo "$CRON_LINE") | crontab -

echo "Cron instalado correctamente:"
echo "  $CRON_LINE"
echo ""
echo "Archivos de log:"
echo "  Detallado:  $LOG_DIR/cpu_monitor.log"
echo "  Resumen:    $LOG_DIR/cpu_resumen.log"
echo ""
echo "Verificar con: crontab -l"
echo "Ver logs:      tail -f $LOG_DIR/cpu_monitor.log"
echo "Detener:       crontab -e (borrar la línea de monitor_cpu.sh)"
