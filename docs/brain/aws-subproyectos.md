---
title: "Sub-proyectos AWS"
type: infra
app: infra-contenedores
repo: DOCKER
tags: [aws, lambda, sam, cloudformation, snapshots, windows]
related:
  - "[[_index]]"
updated: 2026-09-14
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
  disco, sesiones RDP (`activas/totales` + usuarios activos en `usuarios`) y
  top-5 procesos por CPU/RAM. Usa clases CIM
  (`Win32_PerfFormattedData_*`) en vez de `Get-Counter`, porque los nombres de
  contador en inglés no resuelven en Windows Server en español. Instalado en
  `C:\scripts\Monitoreo\` el 2026-09-14 para capturar la semana antes de
  resolver el reporte de lentitud de gcusers-v2 (revisión el fin de semana).
  ⚠️ Pendiente confirmar que las muestras posteriores al fix CIM traen
  `cpu_pct`/`disk_*` con valores (las de madrugada salieron vacías).
- Docs de arquitectura y planes de migración en `gc-wordoffice-infra/docs/`.
- Este repo no contiene credenciales AWS; los stacks se actualizan con credenciales
  temporales (los scripts lo documentan).
