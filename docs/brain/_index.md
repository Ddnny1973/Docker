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
updated: 2026-08-20
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
  `docker-compose.yml` y `config/` de proyectos 35, 36, 37 y pgadmin4 vía SCP a
  `2.29.11.73:/data/odoo/`. Vhosts nginx en `sites-available/` se despliegan
  manualmente al Bastion.
- [[backups-retencion]] — `backup_contenedor.sh`/`backup_todos.sh`,
  `prune_backups.py` y el gotcha crítico de `DRY_RUN = False`.
- [[aws-subproyectos]] — `ebs-snapshot-rotation/` (Lambda + SAM) y
  `gc-wordoffice-infra/` (CloudFormation + scripts PowerShell): cada uno con su
  propio flujo de deploy, ajeno a los contenedores del servidor.
- [[credenciales-convenciones]] — norma del repo de credenciales en texto plano,
  dónde están las contraseñas/API keys y qué docs maestros existen.

## Estado de migración a Docker-Alma-16GB (2026-08-20)

### Migrados y corriendo
| Proyecto | Carpeta | Servicio | Puerto | Firewall | Vhost |
|----------|---------|----------|--------|----------|-------|
| 35 | `35/` | Condominium (Odoo 18) | 8035 | ✅ 8035, 8072 | ✅ propiedades + ocreterraverde |
| 36 | `36/` | Sicone (Odoo 18) | 8036 | ✅ 8036, 8076 | ✅ sicone.ai-mindnovation.com |
| 37 | `37/` | SPT (Odoo 18) | 8037 | ✅ 8037, 8077 | ✅ spt.ai-mindnovation.com |
| pgadmin4 | `pgadmin4/` | pgAdmin4 | 8010 | ✅ 8010 | ✅ pgadmin.gestorconsultoria.com.co |
| 43 | `43/` | Trading (FastAPI) | 8043 | ⏳ pendiente | ✅ trading.gestorconsultoria.com.co |

### Pendientes
- **43 (Trading):** Backup restaurado, compose listo, red `infra_shared` creada. Falta levantar servicio y abrir firewall 8043.
- **36, 37:** Contenedores corriendo pero backups nocturnos pendientes para refrescar datos.
- **Bastion:** Copiar vhosts actualizados y recargar nginx.

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
