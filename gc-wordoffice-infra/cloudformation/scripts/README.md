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

## Referencias

- [Microsoft - RDS Licensing Troubleshooting](https://learn.microsoft.com/en-us/troubleshoot/windows-server/remote/troubleshoot-rds-licensing-guidance)
- [Windows Server Remote Desktop Services](https://learn.microsoft.com/en-us/windows-server/remote/remote-desktop-services/)

---

**Autor:** Grupo Contable
**Versión:** 2.0
**Última actualización:** Agosto 2026
**Servidor:** gcusers-v2 (Windows Server 2025)
