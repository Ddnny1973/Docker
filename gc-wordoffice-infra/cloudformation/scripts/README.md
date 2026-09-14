# Reset automático del período de gracia RDS - Windows Server

## Descripción

Mantiene viva la licencia temporal de Remote Desktop Services (RDS) borrando la
"time bomb" del registro (`L$RTMTIMEBOMB`), lo que reinicia el período de gracia
a **120 días**. No hay tope de resets: el proceso se puede repetir
indefinidamente. **Cada reset devuelve exactamente 120 días** (el período no es
configurable; los "180 días" que se ven en algunos clientes son la licencia
temporal del equipo cliente, no del servidor).

> ⚠️ Microsoft no soporta esto en producción (la gracia es para testing).
> La solución definitiva es comprar RDS CALs. Esto solo gana tiempo.

## Requisitos

- Windows Server (probado en 2025)
- Acceso como Administrador
- PowerShell 5.1 o superior

## ¿Cómo funciona?

La clave `HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\RCM\GracePeriod`
está protegida incluso contra Administrators: **solo SYSTEM puede borrarla**.
Por eso el script se ejecuta como SYSTEM (vía tarea programada) y no usa
`takeown`/`icacls` (esas herramientas solo operan sobre archivos y carpetas, no
sobre claves de registro).

## Instalación (una sola vez)

1. Copia los dos scripts al servidor (p. ej. a `C:\Scripts\`):
   - `reset-rds-grace-period.ps1`
   - `install-rds-grace-reset-task.ps1`
2. En PowerShell **como Administrador**:
   ```powershell
   powershell -ExecutionPolicy Bypass -File C:\Scripts\install-rds-grace-reset-task.ps1
   ```

Esto crea la tarea programada `Reset-RDS-GracePeriod` (SYSTEM) con dos disparadores:
- **Diaria a las 18:59** (hora local Colombia): 5 min antes del apagado
  automático de las 00:00 UTC / 19:00 COT, cuando ya no hay usuarios; el
  contador se completa con el arranque de la mañana siguiente.
- **Al arranque** del sistema: red de seguridad por si la cita diaria no corrió.

La tarea solo actúa cuando quedan **≤ 30 días** de gracia (configurable con
`-Threshold`). Para cambiar la hora de la cita diaria, re-ejecuta el instalador:

```powershell
powershell -ExecutionPolicy Bypass -File install-rds-grace-reset-task.ps1 -Hour 18 -Minute 50
```

## Uso manual

```powershell
# Ver días restantes de gracia (no modifica nada)
powershell -ExecutionPolicy Bypass -File reset-rds-grace-period.ps1 -Check

# Reset inmediato (aunque queden > 30 días)
powershell -ExecutionPolicy Bypass -File reset-rds-grace-period.ps1 -Force

# Ejecutar la tarea instalada
schtasks /Run /TN Reset-RDS-GracePeriod

# Verificar la tarea
schtasks /Query /TN Reset-RDS-GracePeriod /V /FO LIST
```

Si el script se lanza como usuario admin normal, se **auto-relanza como SYSTEM**
vía una tarea temporal (`gcw_rds_grace_temp`) y hace el trabajo igualmente.

## ¿Qué hace el reset?

1. Verifica los días restantes (`Win32_TerminalServiceSetting.GetGracePeriodDays`).
2. Si quedan más de 30 días (y sin `-Force`), no hace nada.
3. Borra la clave `GracePeriod` (corriendo como SYSTEM).
4. Reinicia el servicio `TermService` para regenerar el contador de 120 días.
5. Verifica el resultado y loguea; si el contador no se renovó, avisa que se
   complete con un reinicio (el arranque de cada mañana lo hace solo).

Todo queda registrado en `<carpeta del script>\log\rds-grace-period.log`
(p. ej. `C:\Scripts\log\rds-grace-period.log`; se crea sola).

## Datos técnicos

| Parámetro | Valor |
|-----------|-------|
| Período por reset | 120 días |
| Tope de resets | Sin tope (automatizable indefinidamente) |
| Clave de registro | `HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\RCM\GracePeriod` |
| Valor "time bomb" | `L$RTMTIMEBOMB_*` |
| Servicio asociado | TermService |
| Log | `<carpeta del script>\log\rds-grace-period.log` |

## Troubleshooting

### "Access denied" al borrar la clave
El script corre como SYSTEM; si se lanza como admin normal fallará. Usa la
tarea programada (`schtasks /Run /TN Reset-RDS-GracePeriod`) o el
auto-relanzamiento del propio script.

### El contador no se renueva tras el reset
A veces `TermService` debe reiniciarse con el sistema para regenerar la clave.
Como el servidor se apaga de noche, el arranque siguiente lo completa; si no,
reinicia el servidor manualmente.

### Script no ejecuta por ExecutionPolicy
```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
```

## Monitoreo interno de gcusers-v2 (muestreo por CSV)

Registro automático del estado del servidor **sin CloudWatch y sin intervención
manual**: una tarea programada muestra cada 5 minutos y agrega una línea a un
CSV diario. Su propósito es dejar evidencia histórica de los días hábiles para
correlacionar los reportes de lentitud con lo que ocurría en el equipo en ese
momento (qué proceso disparaba la CPU o la RAM).

### Instalación (una sola vez)

1. Copia los dos scripts al servidor (p. ej. a `C:\Scripts\`):
   - `monitor-gcusers-v2.ps1`
   - `install-gcusers-monitor.ps1`
2. En PowerShell **como Administrador**:
   ```powershell
   powershell -ExecutionPolicy Bypass -File C:\Scripts\install-gcusers-monitor.ps1
   ```

Esto crea la tarea `GCMonitor` (SYSTEM) con dos disparadores:
- **Al arranque**: muestra inmediata en cada boot.
- **Cada 5 min** (configurable con `-IntervalMinutes`) con duración `P9999D`
  (~27 años). PS 5.1 no permite repetición en triggers diarios, por eso se usa
  `Once` + repetición + `StartWhenAvailable`. ⚠️ No usar `[TimeSpan]::MaxValue`
  como duración: serializa a `P99999999DT23H59M59S` y `Register-ScheduledTask`
  lo rechaza con `HRESULT 0x80041318`.

> La tarea apunta al script por **ruta**, no lo embebe: si actualizas
> `monitor-gcusers-v2.ps1`, solo re-copia el archivo y la próxima muestra ya usa
> la versión nueva. Si cambias la cabecera del CSV, borra el CSV del día para
> que se regenere con la cabecera nueva.

### Datos capturados por muestra

| Campo | Descripción |
|-------|-------------|
| `timestamp` | Fecha y hora local |
| `cpu_pct` | CPU total del sistema |
| `mem_libre_mb` / `mem_total_mb` | Memoria física libre y total (MB) |
| `commit_pct` | Uso del commit/pagefile |
| `disk_read_s` / `disk_write_s` | Latencia de disco (Avg. Disk sec/Read, /Write) |
| `sessions_rdp` | Sesiones RDP `activas/totales` (no es un límite: `total` incluye sesiones de sistema como `console`/`services`) |
| `usuarios` | Nombres de los usuarios con sesión `Active` (separador "pipe") |
| `top5_cpu` | Top-5 procesos por CPU (nombre:% con separador "pipe") |
| `top5_ram` | Top-5 procesos por RAM (nombre:MB) |

> **Localización:** el script usa clases CIM (`Win32_PerfFormattedData_*`)
> para CPU, disco y commit en vez de `Get-Counter`, porque los caminos de
> contador en inglés (`\Processor(_Total)\% Processor Time`, etc.) no resuelven
> en instalaciones de Windows Server en español.

Los CSV quedan en `<carpeta del script>\monitor\monitor-YYYYMMDD.csv` (p. ej.
`C:\Scripts\monitor\monitor-20260914.csv`) con **retención de 30 días**.

### Uso / revisión

```powershell
# Muestra manual
schtasks /Run /TN GCMonitor

# Verificar tarea / última muestra
schtasks /Query /TN GCMonitor /V /FO LIST
Get-Content (Join-Path C:\Scripts monitor\monitor-*.csv) | Select-Object -Last 3
```

> Al abrir el CSV en Excel, el separador de columnas es `;` (compatible con
> config regional es-CO).

## Referencias

- [Microsoft - RDS Licensing Troubleshooting](https://learn.microsoft.com/en-us/troubleshoot/windows-server/remote/troubleshoot-rds-licensing-guidance)
- [Windows Server Remote Desktop Services](https://learn.microsoft.com/en-us/windows-server/remote/remote-desktop-services/)

---

**Autor:** Grupo Contable
**Versión:** 2.0
**Última actualización:** Agosto 2026
**Servidor:** gcusers-v2 (Windows Server 2025)
