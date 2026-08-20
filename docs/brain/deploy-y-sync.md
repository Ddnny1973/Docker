---
title: "Deploy y sincronización"
type: process
app: infra-contenedores
repo: DOCKER
tags: [git, deploy, nginx, hetzner, trunk, github-actions]
related:
  - "[[_index]]"
  - "[[arquitectura-contenedores]]"
updated: 2026-08-20
owner: dueño del repo
---

# Deploy y sincronización

## GitHub Actions: sync de archivos de despliegue

Para el servidor **Docker Alma 16GB** (`2.29.11.73`), el repo usa GitHub Actions
para sincronizar automáticamente archivos de despliegue:

- **Workflow:** `.github/workflows/sync-deploy.yml`
- **Trigger:** push a `trunk` que modifique `35/`, `36/` o `37/`
- **Qué sync:** `docker-compose.yml` y `config/` de cada proyecto
- **Qué NO sync:** `postgresql/`, `filestore/`, `extra-addons/`, `.env`, backups
- **Método:** SCP con SSH key dedicada (`ci-deploy@github-actions`)
- **Servidor destino:** `/data/odoo/<NN>/`

El workflow solo copia archivos. **No reinicia servicios** — el usuario decide
cuándo hacer `docker compose up -d` manualmente.

### Workflow manual

También se puede ejecutar manualmente desde GitHub Actions → "Sync Deploy Files" → "Run workflow".

## Otros servidores (sin CI/CD)

Los demás servidores (Docker-New-01/02/03) **no tienen Actions**. Los cambios
siguen el flujo manual: copiar/pushear a `/data/odoo/` en el servidor.

## Flujo git

- Rama principal de integración: **`origin/trunk`** (origin/HEAD). Los commits
  usan prefijos convencionales en español (`feat:`, `fix:`, `docs:`, ...).
- Flujo habitual para cambios: validar que se está en `trunk`; si es así, crear
  rama de trabajo (ej. `docs/cerebro-digital`); hacer el cambio; commit; fusionar
  a `trunk` y push. Si ya se está en otra rama, preguntar antes de crear/operar.
- La documentación y los commits van en **español**.

## Nginx: vhosts de proxy

- `sites-available/` = vhosts que hacen proxy de dominios a los puertos del host
  (y en varios casos a IPs internas `10.0.0.x`). Los certificados los gestiona
  **Certbot** (bloque `listen 443 ssl`, redirect 301 de `:80`).
- Los vhosts nuevos van en `sites-available/`, nunca en `nginex/`.
- Los vhosts se despliegan **manualmente** al Bastion (copiar a `/etc/nginx/conf.d/`
  y ejecutar `nginx -t && systemctl reload nginx`).

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
