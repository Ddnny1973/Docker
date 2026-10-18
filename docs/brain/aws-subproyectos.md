---
title: "Sub-proyectos AWS"
type: infra
app: infra-contenedores
repo: DOCKER
tags: [aws, lambda, sam, cloudformation, snapshots, windows]
related:
  - "[[_index]]"
updated: 2026-10-18
owner: dueño del repo
---

# Sub-proyectos AWS

Son dominios separados de los contenedores del servidor Hetzner: viven en este
repo pero se despliegan en AWS con su **propio flujo** (no copiar a `/data/odoo/`).

## `ebs-snapshot-rotation/` — Lambda de snapshots EBS

Rotación de snapshots de dos instancias EC2 en `us-east-2`:

- **BD** (`gcdatos-v2-r`, `i-0e04b97a8d5031545`): snapshot diario (Lun–Sáb)
  sobrescribiendo el `daily` anterior; los sábados además un `weekly`.
- **Users** (`gcusers-v2`, `i-04d6abcd755fe89b5`): snapshot solo los sábados
  (`weekly`), sobrescribiendo el de la semana anterior.
- Domingo no corre nada. Todo (rol IAM, Lambda, regla EventBridge `cron(0 8 ? * MON-SAT *)`)
  está en `template.yaml`.

Deploy (detalle en su `README.md`):
- `Compress-Archive lambda_function.py -> function.zip` (¡solo ese archivo en la raíz del zip!).
- `aws s3 cp function.zip s3://grpcntbl-backup/lambda-artifacts/snapshot-rotation/`.
- Actualizar el código (`aws lambda update-function-code`) o el stack de
  CloudFormation desde la consola.

Gotchas (conocimiento duro, ver commits recientes):
- IAM de EC2: el ARN de snapshot **no lleva Account ID**
  (`arn:aws:ec2:REGION::snapshot/*`). Faltaba ese quirk en `DeleteSnapshot`
  → los borrados fallaban con `UnauthorizedOperation` y los snapshots se acumulaban.
- AWS limita la tasa de `CreateSnapshot` **por volumen**: crear `daily` y `weekly`
  del mismo volumen en segundos lanza `SnapshotCreationPerVolumeRateExceeded`.
  El código reintenta con backoff y `Timeout: 300`.
- La lambda acepta payload `{"accion": "semanal"}` (fuerza `weekly` de BD + Users)
  o `{"accion": "completa"}` (todo), sin romper la invocación del cron.

## `gc-wordoffice-infra/` — Infra Windows Server

- Plantillas CloudFormation para las instancias Windows (`gcbdatos-ec2.yaml`,
  `parameters.yaml`) + scripts PowerShell de operación
  (`cloudformation/scripts/deploy.ps1`, `validate.ps1`,
  `reset-rds-grace-period.ps1` + `install-rds-grace-reset-task.ps1` — el par de
  scripts mantiene viva la gracia RDS de 120 días de forma automática: la tarea
  `Reset-RDS-GracePeriod` (SYSTEM) borra la clave `GracePeriod` a las 18:59 COT
  (antes del apagado de las 00:00 UTC) y al arranque cuando quedan ≤30 días; no
  hay tope de resets; el borrado requiere
  SYSTEM porque la clave bloquea a Administrators, `takeown`/`icacls` no sirven
  para registro).
- `monitor-gcusers-v2.ps1` + `install-gcusers-monitor.ps1` — monitoreo interno
  del servidor sin CloudWatch: la tarea `GCMonitor` (SYSTEM) muestrea cada
  5 min (al arranque + repetición `Once` de duración `P9999D`; PS 5.1 no permite
  repetición sobre triggers diarios, y `[TimeSpan]::MaxValue` falla en
  Register con 0x80041318) y agrega una línea a `monitor\monitor-YYYYMMDD.csv`
  (un archivo por día, retención 30 días) con CPU, memoria/commit, latencia de
  disco, sesiones RDP (`activas/totales` + desconectadas `ses_disc` + usuarios
  activos `usuarios`) y top-5 procesos por CPU/RAM. Usa clases CIM
  (`Win32_PerfFormattedData_*`) en vez de `Get-Counter`, porque los nombres de
  contador en inglés no resuelven en Windows Server en español.
- `limpiar-sesiones-desconectadas.ps1` + `install-limpieza-sesiones.ps1` —
  libera RAM cerrando con `logoff` las sesiones RDP (`rdp-tcp*`) en estado
  `Disc` con más de 30 min de inactividad (tarea `GCLimpiezaSesiones`, SYSTEM,
  al arranque + cada 5 min). Primera acción para aliviar la presión de memoria
  detectada antes de decidir un aumento de capacidad; el monitor (`ses_disc`)
  mide el efecto y los logs van a `log\limpiar-sesiones-YYYYMMDD.log`.

### Hallazgo del monitoreo 14–28 sep (baseline)

- **Memoria**: días hábiles el uso llegó a **11–13.1 GB de 16 GB** (quedan solo
  ~3 GB) al mediodía/tarde; 8–10 sesiones activas y varias desconectadas que
  seguían consumiendo RAM (varios `explorer` en el top). Sábados ~7 GB.
- **CPU/disco**: NO medidos en el baseline — el servidor tenía los **contadores
  de rendimiento rotos** (todas las clases `Win32_PerfFormattedData_*` y
  `Get-Counter` fallan con "Invalid class"), no era un tema de idioma. Se
  reparó con `lodctr /R` + `winmgmt /resyncperf` (2026-09-28) y las columnas
  recuperaron valores. Además, el monitor ahora tiene un fallback que estima la
  CPU por diferencia de tiempo de proceso entre muestras
  (`monitor-state.json`, desde la 2ª muestra) para que nunca queden vacías en
  silencio si los contadores vuelven a romperse.
- Soporte: Excel consolidado en
  `gc-wordoffice-infra\monitor\monitoreo-gcusers-v2-consolidado.xlsx` (hojas
  `Resumen_diario`, `Resumen_semanal`, `Datos`; regenerado el 2026-10-18 con datos
  hasta esa fecha).

### Seguimiento 28 sep – 18 oct (3 semanas con CPU medida)

- **Memoria**: pico semanal de RAM usada 11.3 / 11.6 / 12.3 GB (baseline 13.1 GB);
  RAM libre mínima 4.9 / 4.6 / 3.9 GB (baseline 3.1 GB). Ninguna muestra con
  <2.5 GB libres. La semana del 13–16 oct sube un poco frente a las dos anteriores.
- **CPU**: promedio 21–23 %; solo ~1.5 % de las muestras 8–18 h pasan del 80 %. Los
  picos los causan procesos `MSACCESS` (varios usuarios), a veces `MsMpEng`. Disco:
  latencia 0.
- **Limpieza de sesiones NO verificada**: `ses_disc` crece a 6–8 en la tarde
  (17–19 h) y no baja, y la carpeta `log\` del servidor está vacía → la tarea
  `GCLimpiezaSesiones` probablemente nunca se instaló o no actúa. Revisar con
  `schtasks /Query /TN GCLimpiezaSesiones /V /FO LIST` y probar `-WhatIf`.
- **Decisión (2026-10-18)**: sin razón técnica hoy para subir RAM ni CPU. Reevaluar
  si la RAM libre mínima baja de ~2.5 GB, aparecen >15 sesiones activas o el
  commit supera ~90 %. Cambiar el tipo de instancia EC2 exige stop/start (el
  servidor ya se apaga cada noche); no cambia IP elástica ni EBS.
### Defender y archivos de World Office en gcusers-v2 (2026-10-18)

- Antes no había **ninguna** exclusión de Defender; escaneo en tiempo real activo
  (`MsMpEng` aparece en algunos picos de CPU, p. ej. 13‑oct 11:30). Último escaneo
  rápido 6‑oct, nunca uno completo.
- World Office cliente: `C:\Program Files (x86)\World Office\WO10` (`WoServiceControl.exe`;
  los `MSACCESS#N` son Access Runtime, uno por usuario). La carpeta `_Emp` pesa
  ~10 GB: un `WProg.afs` de 400–570 MB por empresa (+ `WProg_Backup.afs`), con
  escrituras diarias. `Base de Datos`, `Backup` y `Sincronizacion` están vacías.
  No hay `.mdb/.accdb` de usuario ni recursos compartidos (`Get-SmbShare` vacío).
- **Aplicado**: `Add-MpPreference -ExclusionPath "...\WO10\_Emp"` (solo `_Emp`; se dejó
  escaneado el código `.dll/.exe` de `WO10`). Revertir con `Remove-MpPreference`.
- Pendiente: grabación `New-MpPerformanceRecording` en horario de uso (la del
  domingo salió vacía), comparar la presencia de `MsMpEng` en `top5_cpu` tras
  una semana, y programar un escaneo completo semanal (el servidor se apaga
  19:00 COT, la hora debe caer antes).
- Pendiente: el monitor no mide latencia de disco útil (`disk_*` siempre 0);
  evaluar monitor equivalente para `gcbdatos-v2` (SQL Server) y revisar tipo de
  volumen EBS (gp3, IOPS/throughput). Tipo de instancia real de gcusers-v2:
  t3a.xlarge (16 GB), no t3.large como dice `MIGRACION_STATUS.md`.

- Instalado en `C:\scripts\Monitoreo\` el 2026-09-14.
- Docs de arquitectura y planes de migración en `gc-wordoffice-infra/docs/`.
- Este repo no contiene credenciales AWS; los stacks se actualizan con credenciales
  temporales (los scripts lo documentan).
