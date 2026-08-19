#!/bin/bash
# Analiza el archivo de resumen de CPU del monitor
# Uso: ./analizar_cpu.sh [ultimas_N_lineas]

LOG_DIR="/data/odoo/32/logs"
RESUMEN="$LOG_DIR/cpu_resumen.log"
DETALLADO="$LOG_DIR/cpu_monitor.log"

if [ ! -f "$RESUMEN" ]; then
    echo "No hay datos de monitoreo aún. Espera al menos 5 minutos después de instalar el cron."
    echo "Los datos se guardan en: $RESUMEN"
    exit 1
fi

LINEAS="${1:-20}"

echo "============================================"
echo "  ANÁLISIS DE CPU - Stack 32 (n8n)"
echo "  Últimas $LINEAS muestras"
echo "============================================"
echo ""

echo "--- Datos crudos (últimas $LINEAS muestras) ---"
tail -n "$LINEAS" "$RESUMEN"
echo ""

echo "--- Promedio de CPU por contenedor ---"
tail -n "$LINEAS" "$RESUMEN" | awk -F'|' '{
    for (i=2; i<=NF; i++) {
        split($i, parts, "=")
        gsub(/^[ \t]+|[ \t]+$/, "", parts[1])
        gsub(/^[ \t]+|[ \t]+$/, "", parts[2])
        gsub(/%/, "", parts[2])
        if (parts[1] != "" && parts[2] != "") {
            sum[parts[1]] += parts[2]
            count[parts[1]]++
        }
    }
}
END {
    for (name in sum) {
        avg = sum[name] / count[name]
        printf "  %-25s Promedio: %6.1f%%  (muestras: %d)\n", name, avg, count[name]
    }
}' | sort -t':' -k2 -rn
echo ""

echo "--- Pico máximo de CPU por contenedor ---"
tail -n "$LINEAS" "$RESUMEN" | awk -F'|' '{
    for (i=2; i<=NF; i++) {
        split($i, parts, "=")
        gsub(/^[ \t]+|[ \t]+$/, "", parts[1])
        gsub(/^[ \t]+|[ \t]+$/, "", parts[2])
        gsub(/%/, "", parts[2])
        if (parts[1] != "" && parts[2] != "") {
            gsub(/ /, "", parts[2])
            val = parts[2] + 0
            if (val > max[parts[1]]) max[parts[1]] = val
        }
    }
}
END {
    for (name in max) {
        printf "  %-25s Pico: %6.1f%%\n", name, max[name]
    }
}' | sort -t':' -k2 -rn
echo ""

echo "--- Alertas de CPU > 80% ---"
grep -c "ALERTA" "$DETALLADO" 2>/dev/null | xargs -I{} echo "  Total de alertas en el log: {}"
grep "ALERTA" "$DETALLADO" 2>/dev/null | tail -5
echo ""

echo "--- Errores frecuentes (top 10) ---"
grep -o -E '\[ERROR\].*|error.*|Error.*|SIGTERM|OOM|killed|fatal' "$DETALLADO" 2>/dev/null | sort | uniq -c | sort -rn | head -10
echo ""
