---
title: "Hub — Cerebro digital de DOCKER (infraestructura de contenedores)"
type: hub
app: infra-contenedores
repo: DOCKER
tags: [hub, docker, odoo, n8n, nginx, aws, prospectum, arquitectura, trading]
related:
  - "[[arquitectura-contenedores]]"
  - "[[deploy-y-sync]]"
  - "[[backups-retencion]]"
  - "[[aws-subproyectos]]"
  - "[[credenciales-convenciones]]"
updated: 2026-08-21
owner: dueño del repo
---

# DOCKER — Cerebro digital

## Qué es este repo

Repo de **configuración de infraestructura** (no un codebase): `docker-compose.yml`,
`Dockerfile` y vhosts nginx para las aplicaciones desplegadas en 5 servidores
Linux (Bastion + 4 Docker nodes). Sin tests, sin lint, sin build tooling y
**sin deploy automatizado**: este checkout es la fuente de verdad y los cambios
llegan a los servidores copiando/pusheando archivos a `/data/odoo/`.

Ver `INFRAESTRUCTURA.md` para IPs, distribución de proyectos y credenciales.

Rutas del servidor (hardcodeadas en scripts, no "arreglarlas"):
- Proyectos: `/data/odoo/<NN>/`
- Docker data-root: `/data/docker`
- Backups: `/mnt/hetzner-backup/<NN>/`

## Mapa de contenido

- [Arquitectura de servidores](arquitectura-servidores.md) — diagrama de la infraestructura: Bastion (nginx) + 4 nodos Docker, flujo de peticiones, convención de puertos.
- [[arquitectura-contenedores]] — layout de proyectos numerados, convención de
  puertos `80NN`/`90NN`, patrón Odoo `web` + `db-<NN>`, stack n8n de `32`,
  proyectos inactivos/cancelados.
- [[deploy-y-sync]] — cómo llegan los cambios al servidor: GitHub Actions sincroniza
  con `git pull` vía `appleboy/ssh-action` a `2.29.11.73:/data/odoo/`. Vhosts nginx
  en `sites-available/` se despliegan manualmente al Bastion.
- [[backups-retencion]] — `backup_contenedor.sh`/`backup_todos.sh`,
  `prune_backups.py` y el gotcha crítico de `DRY_RUN = False`.
- [[comandos-destructivos]] — **⚠️ CRÍTICO** — Validación y seguridad de comandos
  que borran/sincronizan: rsync --delete, rm, docker rm, tar extraction. Checklist
  obligatorio. Incluye incident 2026-08-21.
- [[aws-subproyectos]] — `ebs-snapshot-rotation/` (Lambda + SAM) y
  `gc-wordoffice-infra/` (CloudFormation + scripts PowerShell): cada uno con su
  propio flujo de deploy, ajeno a los contenedores del servidor.
- [[credenciales-convenciones]] — norma del repo de credenciales en texto plano,
  dónde están las contraseñas/API keys y qué docs maestros existen.

## Estado de migración a Docker-Alma-16GB (2026-08-20) — ✅ **COMPLETADA**

### ✅ Todos los Proyectos Migrados
| Proyecto | Carpeta | Servicio | Puerto | Estado | Vhost |
|----------|---------|----------|--------|--------|-------|
| **29** | `29/` | Odoo 16 (legacy) | 8029 | ⚠️ Unhealthy | No hay vhost |
| **30** | `30/` | Odoo 16 (heredada) | 8030 | ⚠️ Unhealthy | No hay vhost |
| **32** | `32/` | **n8n + Stack IA** | 8032 | ⚠️ Unhealthy | ✅ n8n.gestorconsultoria.com.co |
| 35 | `35/` | Condominium (Odoo 18) | 8035 | ✅ Healthy | ✅ propiedades + ocreterraverde |
| 36 | `36/` | Sicone (Odoo 18) | 8036 | ✅ Healthy | ✅ sicone.ai-mindnovation.com |
| 37 | `37/` | SPT (Odoo 18) | 8037 | ✅ Healthy | ✅ spt.ai-mindnovation.com |
| 41 | `41/` | Prospectum (Odoo 18) | 8041 | ✅ Healthy | ✅ prospectum.ai-mindnovation.com |
| 42 | `42/` | Showcase (Odoo 18) | 8042 | ✅ Healthy | ✅ showcase.ai-mindnovation.com |
| 43 | `43/` | Trading (FastAPI) | 8043 | ✅ Healthy | ✅ trading.gestorconsultoria.com.co |
| pgadmin4 | `pgadmin4/` | pgAdmin4 | 8010 | ⚠️ Unhealthy | ✅ pgadmin.gestorconsultoria.com.co |

### Contenedores de Proyecto 32 (n8n + IA)
- `32-n8n-1` — n8n (⚠️ unhealthy, ver logs)
- `32-db-1` — PostgreSQL 12 (9032)
- `32-redis-1` — Redis (interno)
- `32-pgvectordb-1` — pgvector + PostgreSQL 14 (9033)
- `32-ocr-1` — Servicio OCR (5001)
- `32-pdf2img-1` — Servicio pdf2img (5002)
- `transcription` — Servicio transcripción (5003)
- `wppapi`, `wppapi_mb` — WhatsApp APIs

### 🧹 Limpieza Pendiente
- **Proyectos 29 y 30** (Odoo 16, ambos unhealthy) — considerar eliminar si no se usan.
- **n8n unhealthy** — revisar logs para diagnosticar.
- **Docker-New-03** (`10.0.0.2`) — confirmar si está vacío y puede desmantelarse.

## Documentación por proyecto

- **41 (Prospectum):**
  - [Arquitectura del proyecto](../../41/ARQUITECTURA.md) — diagrama, puertos, rutas y comandos.
  - [Instrucciones de conexión](../../41/INSTRUCCIONES_CONEXION.md) — cómo conectarse al servidor y configurar el versionamiento del código.
- **Docker Alma 16GB (nuevo):**
  - [Instrucciones de conexión](../../INSTRUCCIONES_CONEXION_ALMA.md) — cómo conectarse al servidor `2.29.11.73` y configurar la clave SSH.

## Puntos de entrada existentes (no duplicar, solo enlazar)

- [README.md](../../README.md) — índice maestro (incluye init de Odoo 18 sin demo).
- [INFRAESTRUCTURA.md](../../INFRAESTRUCTURA.md) — estado de servidores, BDs,
  credenciales y perfil de consumo de los contenedores.
- [CX23_PLANTILLA_SETUP.md](../../CX23_PLANTILLA_SETUP.md) — setup de un servidor
  Hetzner nuevo (Docker en `/data`, Storage Box, firewall).
- [ebs-snapshot-rotation/README.md](../../ebs-snapshot-rotation/README.md) —
  flujo completo de deploy de la Lambda.

## Relación con otros repos (misma aplicación)

Este repo aloja la infraestructura que usa el repo hermano
`../Trading` (backend FastAPI en `/data/odoo/43` y vhost `trading.*` con WebSockets).
El repositorio Trading tiene su propio cerebro digital en
`../Trading/docs/brain/_index.md` — si se toca infra compartida (n8n `32`, vhosts),
revisar ambos cerebros.
