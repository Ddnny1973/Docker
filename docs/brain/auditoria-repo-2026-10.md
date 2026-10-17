---
title: "Auditoría del repo — hallazgos y plan de orden (2026-10-17)"
type: reference
app: infra-contenedores
repo: DOCKER
tags: [auditoria, organizacion, deuda, seguridad, limpieza]
related:
  - "[[_index]]"
  - "[[nginx-vhosts]]"
  - "[[deploy-y-sync]]"
  - "[[credenciales-convenciones]]"
  - "[[comandos-destructivos]]"
updated: 2026-10-17
owner: dueño del repo
---

# Auditoría del repo (2026-10-17)

Revisión completa del checkout. **Solo se documenta; no se borró ni movió nada.**
Todo lo que borre archivos requiere validación previa ([[comandos-destructivos]]).

## Seguridad

- 🔴 `34/vsc.ppk` y `34/cc-pruebas-2.ppk` están **versionados**: claves privadas
  PuTTY con `Encryption: none`. `.gitignore` no cubre `*.ppk`. Acción propuesta:
  confirmar si siguen en uso, rotarlas, agregar `*.ppk` al `.gitignore` y sacarlas
  del índice (`git rm --cached`; siguen en el historial).
- 🟡 `INFRAESTRUCTURA.md` y varios docs de `gc-wordoffice-infra/docs/` contienen
  contraseñas en texto plano (norma del repo, ver [[credenciales-convenciones]]).
  No copiarlas a otros documentos.

## Deploy

- Hay **dos workflows** en `.github/workflows/`:
  - `auto-deploy.yml` — todo push a `trunk`: `git pull` + `docker compose up -d`
    en `/data/odoo`.
  - `sync-deploy.yml` — push a `trunk` que toque `35/**`, `36/**`, `37/**` o
    `pgadmin4/**` (o manual): copia por `scp` los compose (y `config/` de 35 y 37)
    a Alma. Solo cubre esos proyectos.
- En el repo no existe un `docker-compose.yml` en la raíz, por lo que el paso
  `docker compose up -d` de `auto-deploy.yml` en `/data/odoo` podría fallar o no
  hacer nada. **Por verificar** en los logs de Actions.

## Archivos y carpetas a ordenar

| Elemento | Situación | Propuesta |
|---|---|---|
| `nginex/` | Directorio con typo y un vhost de trading obsoleto (`10.0.0.4`) | Borrar tras validar que `sites-available/` tiene el vigente |
| `sites-available/*.bk`, `*.bk2` | Respaldos manuales de n8n | Mover fuera del repo o borrar (git ya versiona) |
| `36/sicone...conf` | Copia del vhost | Eliminar duplicado |
| `43/TRADING` | Archivo vacío (marcador); el código vive en repo `../Trading` | Documentar o quitar |
| `monitor_resources.sh` | Está en `.gitignore` pero versionado | Decidir: versionar (quitar de `.gitignore`) o dejar de rastrear |
| `pgadmin4/` | `.gitignore` lo excluye pero su compose está versionado | Ajustar `.gitignore` para permitir solo el compose |
| `*/config/` | Ignorado en `.gitignore` pero `odoo.conf` está versionado (35, 37, 38, 41, 42) | Alinear regla y realidad |
| `ebs-snapshot-rotation/function.zip`, `gc-wordoffice-infra/monitor_sin_cpu.rar`, `36/ARQUITECTURA_INTERNET.pdf`, `gc-wordoffice-infra/monitor/*.xlsx`, `*.csv`, `*.png` | Binarios/datos en git | Ignorar artefactos de build (`function.zip`) y mover datos de monitoreo a otro lugar |
| `gc-wordoffice-infra/monitor/dashboard-gcusers-v2.png` | Sin rastrear | Decidir commit o ignorar |
| `35/Gestor Propiedades`, `41/lista_de_librerias.txt`, `41/requirements.txt` | Nombres/ubicaciones sueltas | Revisar si siguen vigentes |

## Documentación desactualizada fuera del cerebro

- `README.md` raíz: describe una estructura (`/dockerfiles/`, `/compose/`) que no
  existe; solo la receta de Odoo 18 sigue siendo útil.
- `AGENTS.md`: dice "4 servidores (Bastion + 3 nodos Docker)"; hoy son 5 (Bastion
  + 4 nodos, incluido Alma). También omite el segundo workflow y que `29`, `30`,
  `32`, `35`–`37`, `40`–`43` están consolidados en Alma.
- `INFRAESTRUCTURA.md`: sección 2 apunta a `37.27.218.117` (servidor retirado);
  "Proyectos activos (Junio 2026)"; pendientes sin resolver (distribución de nodos,
  ubicación de las BDs del 32).

## Inconsistencias de infraestructura por resolver

- `38` (Gestor) y `39` (Metabase): no figuran en Alma; sus vhosts apuntan a New-03
  y New-01. Confirmar en qué nodo corren de verdad (ver [[nginx-vhosts]]).
- Vhosts de `16`, `33`, `34` siguen publicados aunque los proyectos están
  cancelados/inactivos.
- `39` usa `metabase/metabase:latest` y `32` usa `n8nio/n8n` sin tag: considerar
  pinnar versión como se hizo con OpenClaw.
- Proyectos `29`/`30` y `n8n`/`pgadmin4` marcados `unhealthy` en el índice;
  pendiente diagnóstico.
- `docker-compose.yml` de Odoo montan `/var/run/docker.sock` y `n8n` monta `/` del
  host: decisión de diseño documentada, revisar si sigue siendo necesaria.
