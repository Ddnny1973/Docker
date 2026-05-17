import os
import re
from datetime import datetime, timedelta, date
import calendar
import logging

# ==========================================
# CONFIGURACIÓN
# ==========================================
BACKUP_ROOT = "/mnt/hetzner-backup"
DRY_RUN = False  # CAMBIAR A False PARA BORRAR REALMENTE
MESES_RETENCION = 6

LOG_FILE = "/mnt/hetzner-backup/backup.log"  # <--- Ruta donde se guardará el log

# Configuración del sistema de logs para que escriba en archivo y en pantalla
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    handlers=[
        logging.FileHandler(LOG_FILE),     # Guarda en el archivo
        logging.StreamHandler()            # Muestra en la pantalla
    ]
)

def obtener_reglas_retencion():
    hoy = date.today()
    
    # 1. Rango de la semana actual (de lunes a domingo)
    # hoy.weekday() devuelve 0 para lunes, 6 para domingo
    inicio_semana = hoy - timedelta(days=hoy.weekday())
    fin_semana = inicio_semana + timedelta(days=6)
    
    # 2. Límite de 6 meses atrás
    hace_6_meses = hoy - timedelta(days=MESES_RETENCION * 30)
    
    return inicio_semana, fin_semana, hace_6_meses

def es_ultimo_dia_del_mes(fecha: date) -> bool:
    # calendar.monthrange devuelve (dia_semana_primer_dia, cantidad_dias_mes)
    _, ultimo_dia = calendar.monthrange(fecha.year, fecha.month)
    return fecha.day == ultimo_dia

def evaluar_backup(nombre_archivo, inicio_semana, fin_semana, hace_6_meses):
    # Expresión regular para capturar la fecha en formato yyyymmdd
    # Ejemplo: backup_30_20260516_042152.tar.gz -> 20260516
    match = re.search(r'_(\d{8})_\d{6}\.tar\.gz$', nombre_archivo)
    if not match:
        return "IGNORAR"  # No cumple con el formato de backup esperado
    
    fecha_str = match.group(1)
    try:
        fecha_file = datetime.strptime(fecha_str, "%Y%m%d").date()
    except ValueError:
        return "IGNORAR"

    # Regla de obsolescencia absoluta (más de 6 meses)
    if fecha_file < hace_6_meses:
        return "BORRAR"

    # Regla 1: Semana actual
    if inicio_semana <= fecha_file <= fin_semana:
        return "CONSERVAR (Semana actual)"

    # Regla 2: Es domingo de una semana anterior
    # weekday() == 6 significa Domingo
    if fecha_file.weekday() == 6:
        return "CONSERVAR (Domingo histórico)"

    # Regla 3: Es el último día del mes
    if es_ultimo_dia_del_mes(fecha_file):
        return "CONSERVAR (Fin de mes)"

    # Si no cumple ninguna, se elimina
    return "BORRAR"

def main():
    print(f"=== INICIANDO DEPURACIÓN DE BACKUPS (DRY_RUN = {DRY_RUN}) ===")
    logging.info(f"=== INICIANDO DEPURACIÓN DE BACKUPS (DRY_RUN = {DRY_RUN}) ===")
    inicio_semana, fin_semana, hace_6_meses = obtener_reglas_retencion()
    
    if not os.path.exists(BACKUP_ROOT):
        print(f"Error: La ruta {BACKUP_ROOT} no existe.")
        logging.error(f"Error: La ruta {BACKUP_ROOT} no existe.")
        return

    # Enumerar subcarpetas numéricas
    for entrada in os.listdir(BACKUP_ROOT):
        ruta_carpeta = os.path.join(BACKUP_ROOT, entrada)
        
        # Filtrar solo carpetas que sean numéricas (ej. 16, 30, 34)
        if os.path.isdir(ruta_carpeta) and entrada.isdigit():
            print(f"\n📁 Procesando carpeta: {entrada}")
            logging.info(f"Procesando carpeta: {entrada}")
            
            archivos = os.listdir(ruta_carpeta)
            # Ordenamos para ver la salida cronológicamente si es necesario
            archivos.sort() 
            
            for archivo in archivos:
                ruta_archivo = os.path.join(ruta_carpeta, archivo)
                
                # Solo procesar archivos, no subcarpetas
                if os.path.isfile(ruta_archivo):
                    decision = evaluar_backup(archivo, inicio_semana, fin_semana, hace_6_meses)
                    
                    if decision.startswith("CONSERVAR"):
                        print(f"  [Mantener] {archivo} -> Razón: {decision}")
                        logging.info(f"[Mantener] {archivo} -> Razón: {decision}")
                    elif decision == "BORRAR":
                        if DRY_RUN:
                            print(f"  [SIMULADO] Borraría: {archivo}")
                            logging.info(f"[SIMULADO] Borraría: {archivo}")
                        else:
                            try:
                                os.remove(ruta_archivo)
                                print(f"  [ELIMINADO] {archivo}")
                                logging.info(f"[ELIMINADO] {archivo}")
                            except Exception as e:
                                print(f"  [ERROR] No se pudo borrar {archivo}: {e}")
                                logging.error(f"[ERROR] No se pudo borrar {archivo}: {e}")

if __name__ == "__main__":
    main()