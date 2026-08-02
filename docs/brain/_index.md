---
title: "Hub — Cerebro digital de DOCKER (infraestructura de contenedores)"
type: hub
app: infra-contenedores
repo: DOCKER
tags: [hub, docker, odoo, n8n, hetzner, nginx, aws]
related:
  - "[[arquitectura-contenedores]]"
  - "[[deploy-y-sync]]"
  - "[[backups-retencion]]"
  - "[[aws-subproyectos]]"
  - "[[credenciales-convenciones]]"
updated: 2026-08-02
owner: dueño del repo
---

# DOCKER — Cerebro digital

## Qué es este repo

Repo de **configuración de infraestructura** (no un codebase): `docker-compose.yml`,
`Dockerfile` y vhosts nginx para las aplicaciones desplegadas en un único servidor
Hetzner (`docker-alma-32gb-hel1-1`, AlmaLinux 9, `37.27.218.117`). Sin tests, sin
lint, sin build tooling y **sin deploy automatizado**: este checkout es la fuente
de verdad y los cambios llegan al servidor copiando/pusheando archivos a
`/data/odoo/`.

Rutas del servidor (hardcodeadas en scripts, no "arreglarlas"):
- Proyectos: `/data/odoo/<NN>/`
- Docker data-root: `/data/docker`
- Backups: `/mnt/hetzner-backup/<NN>/`

## Mapa de contenido

- [[arquitectura-contenedores]] — layout de proyectos numerados, convención de
  puertos `80NN`/`90NN`, patrón Odoo `web` + `db-<NN>`, stack n8n de `32`,
  proyectos inactivos/cancelados.
- [[deploy-y-sync]] — cómo llegan los cambios al servidor (sin CI/CD), flujo git
  hacia `trunk`, vhosts nginx (`sites-available/` vs `nginex/`), despliegue por
  proyecto y init de Odoo 18 sin demo.
- [[backups-retencion]] — `backup_contenedor.sh`/`backup_todos.sh`,
  `prune_backups.py` y el gotcha crítico de `DRY_RUN = False`.
- [[aws-subproyectos]] — `ebs-snapshot-rotation/` (Lambda + SAM) y
  `gc-wordoffice-infra/` (CloudFormation + scripts PowerShell): cada uno con su
  propio flujo de deploy, ajeno a los contenedores del servidor.
- [[credenciales-convenciones]] — norma del repo de credenciales en texto plano,
  dónde están las contraseñas/API keys y qué docs maestros existen.

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
