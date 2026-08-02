---
title: "Deploy y sincronización"
type: process
app: infra-contenedores
repo: DOCKER
tags: [git, deploy, nginx, hentzer, trunk]
related:
  - "[[_index]]"
  - "[[arquitectura-contenedores]]"
updated: 2026-08-02
owner: dueño del repo
---

# Deploy y sincronización

## Sin CI/CD ni deploy automatizado

Este repo **no tiene pipeline** (no hay `.github/workflows` ni scripts de deploy).
Es la fuente de verdad: los cambios se versionan y luego **se copian/pegan
manualmente** en el servidor dentro de `/data/odoo/`. Asumir que un cambio
commiteado NO está desplegado hasta que alguien lo sube al servidor.

## Flujo git

- Rama principal de integración: **`origin/trunk`** (origin/HEAD). Los commits
  usan prefijos convencionales en español (`feat:`, `fix:`, `docs:`, ...).
- Flujo habitual para cambios: validar que se está en `trunk`; si es así, crear
  rama de trabajo (ej. `docs/cerebro-digital`); hacer el cambio; commit; fusionar
  a `trunk` y push. Si ya se está en otra rama, preguntar antes de crear/operar.
- La documentación y los commits van en **español**.

## Nginx: vhosts de proxy

- `sites-available/` = vhosts que hacen proxy de dominios a los puertos del host
  (y en varios casos a IPs internas `10.0.0.x`, p. ej. `analytics.*`→`10.0.0.2:8039`,
  `trading.*`→`10.0.0.4:8043`). Los certificados los gestiona **Certbot**
  (bloque `listen 443 ssl`, redirect 301 de `:80`).
- `nginex/` es un directorio **sobrante con typo** que contiene un solo conf
  (`trading.*`). Los vhosts nuevos van en `sites-available/`, nunca en `nginex/`.
- Hay archivos de respaldo acumulados en `sites-available/` (`.bk`, `.bk2`,
  `.save`) de vhosts en evolución — no borrarlos sin confirmar.

## Despliegue de un proyecto

1. Copiar/pushear la carpeta del proyecto a `/data/odoo/<NN>/` en el servidor.
2. `cd /data/odoo/<NN>` y `docker compose up -d`.
3. Servicios que leen del entorno del shell o `.env` (p. ej. `transcription` de
   `32`, `34` con `VSCODE_PASSWORD`) requieren que la variable esté presente al
   levantar.

## Init de Odoo 18 sin datos demo

Desde el README raíz, ejecutado en el dir del proyecto (debe existir
`config/odoo.conf`):

```bash
docker compose up -d
docker compose stop web
docker run --rm --network <NN>_default -v ./config:/etc/odoo odoo:18 --init=base --without-demo=all --stop-after-init -d odoo
docker compose start web
```
