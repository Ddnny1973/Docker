---
title: "Deploy y sincronización"
type: process
app: infra-contenedores
repo: DOCKER
tags: [git, deploy, nginx, hetzner, trunk, github-actions]
related:
  - "[[_index]]"
  - "[[arquitectura-contenedores]]"
updated: 2026-08-21
owner: dueño del repo
---

# Deploy y sincronización

## GitHub Actions: Auto-Deploy a servidor Alma

Para el servidor **Docker Alma 16GB** (`2.29.11.73`), el repo usa GitHub Actions
para sincronizar y desplegar automáticamente:

- **Workflow:** `.github/workflows/auto-deploy.yml`
- **Trigger:** `push` a rama `trunk`
- **Método:** `appleboy/ssh-action` (SSH Key) → `git pull origin trunk` → `docker compose up -d`
- **SSH Key:** `DEPLOY_SSH_KEY` (almacenada en GitHub Secrets)
- **Usuario servidor:** `root@2.29.11.73:22`
- **Directorio trabajo:** `/data/odoo/`

### Flujo

1. GitHub Actions detecta push a `trunk`
2. Carga SSH key desde `${{ secrets.DEPLOY_SSH_KEY }}`
3. Ejecuta en servidor: `git pull origin trunk`
4. Ejecuta: `docker compose up -d` (reinicia todos los servicios)
5. Muestra estado: `docker compose ps`

### Seguridad

✅ **NO usa rsync con `--delete`** (ver [[comandos-destructivos]]).
✅ **Usa `git pull`** (mismo modelo que Trading repo).
✅ **Preserva datos** — solo sincroniza código, nunca toca `/data/odoo/postgresql/`, `/data/odoo/*/filestore/`, etc.

### Desactivar workflow

Si necesitas pushear a `trunk` sin disparar deploy:
- Cambiar nombre de rama temporalmente
- O aguardar hasta que el workflow esté configurado manualmente en GitHub

### Sincronización manual (si es necesario)

```bash
# En el servidor
cd /data/odoo
git pull origin trunk
docker compose up -d
```

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
