---
title: "Arquitectura de contenedores"
type: infra
app: infra-contenedores
repo: DOCKER
tags: [docker, docker-compose, odoo, n8n, puertos]
related:
  - "[[_index]]"
  - "[[deploy-y-sync]]"
updated: 2026-08-20
owner: dueño del repo
---

# Arquitectura de contenedores

## Layout: un proyecto compose por instancia

Cada carpeta numerada (`16`, `29`–`42`) es un proyecto `docker compose` independiente.
Se levanta desde dentro de la carpeta: `docker compose up -d`. No hay un compose
raíz que orqueste todo; cada instancia coexiste en el mismo host gracias a que los
nombres de contenedor de BD son únicos (`db-<NN>`).

Inventario por proyecto (ver `INFRAESTRUCTURA.md` para estado actualizado):

- Odoo 16: `29` (aserprem), `30` (ai-mindnovation).
- Odoo 18: `35` (condominium), `36` (sicone), `37` (spt), `38` (gestor),
  `41` (prospectum), `42` (showcase).
- `32` — stack n8n + IA (n8n, redis, postgres:12, pgvector pg14, ocr,
  transcription/whisper, pdf2img, 4x `whatsapp-web-api`).
- `39` — Metabase. `16` — Odoo 13 (CANCELADO).
- `33` (wetty), `34` (code-server), `40` (OpenClaw gateway) — **inactivos**;
  solo están definidos, no corriendo.

## Convención de puertos

- Proyecto `N` publica su app principal en host `80NN` y su Postgres en `90NN`.
  Ejemplos verificados: `30`→8030/9030, `35`→8035/9035, `39`→8039/9039,
  `41`→8041/9041, `42`→8042/9042, `16`→8016/9016.
- En `32`: n8n→8032, `db`→9032, `pgvectordb`→9033. Los servicios `ocr`,
  `transcription`, `pdf2img` usan 5001–5003.
- **Longpoll de Odoo 18**: el puerto host del longpolling (contenedor 8072)
  **NO sigue fórmula** — es distinto por instancia y hay que mirar el compose:
  `36`→8076, `37`→8077, `38`→8078, `41`→8079, `42`→8090.

## Patrón de instancias Odoo

- Servicios `web` (imagen `odoo:16`/`odoo:18`, `user: root`) + `db-<NN>`
  (imagen `postgres:12`/`postgres:16`, siempre hostname `db-<NN>`).
- Montajes típicos: `./config`→`/etc/odoo` (debe contener `odoo.conf`),
  `./filestore`, `./extra-addons`→`/mnt/extra-addons`,
  `./postgresql/data/compartida`→`/mnt/compartida` (volumen compartido entre
  instancias) y `/var/run/docker.sock`.
- Los módulos custom de Odoo viven bajo `extra-addons/` del proyecto
  (`35/condominium`, `36/sicone`, `37/spt`, `38/gestor`, `41/prospectum`,
  `42/showcase`).

## Stack `32` (n8n + IA) — particularidades

- `n8n` monta `/` y el docker.sock del host (`/host:ro`, `/var/run/docker.sock`).
- `transcription` (Whisper) lee `OPENAI_API_KEY` **del entorno del shell**, no de
  un `.env` del proyecto: si se levanta sin la variable, el servicio falla.
- Los contenedores `wppapi*` se construyen desde `32/whatsapp-web-api/`
  (Node + whatsapp-web.js v1.34.7 + Puppeteer); cada uno tiene su sesión y carpeta de
  media propia (`wppapi-*-media`).
- `wppapi_ai` y `wppapi_ai_2` están **deshabilitados** (comentados en compose).

### Resource limits (agos 2026)

Todos los servicios activos tienen `deploy.resources.limits`:

| Servicio | CPU limit | RAM limit | CPU reservation | RAM reservation |
|----------|-----------|-----------|-----------------|-----------------|
| n8n | 3.0 | 4000M | 1.0 | 1000M |
| ocr | 3.0 | 4000M | 0.5 | 2000M |
| pdf2img | 2.0 | 2000M | 0.5 | 500M |
| wppapi | 1.5 | 1500M | 1.0 | 500M |
| wppapi_mb | 1.5 | 1200M | 1.0 | 400M |

Total reservations: 4.0 CPU (server tiene 4 cores). Servicios `wppapi*` y `n8n`
tienen healthchecks configurados.

### Fixes aplicados a whatsapp-web-api (index.js v0.05)

- **SingletonLock cleanup**: al iniciar, borra automáticamente archivos
  `SingletonLock` de Chromium para evitar "profile in use" tras crashes.
- **Cola serializada de envíos**: `enqueueSend()` procesa envíos uno a la vez
  para no saturar Puppeteer/Chromium con requests concurrentes.
- **protocolTimeout 300s**: subido de 120s para evitar timeouts en envíos largos.
- **Endpoint `/restart`**: reinicia el cliente WhatsApp sin borrar sesión ni
  contenedor. Útil cuando el Store no carga.
- **Endpoint `/status`**: muestra estado, cola de envíos y si está enviando.
- **whatsapp-web.js 1.34.7**: actualizado de 1.34.6 para fix de Store loading.

### Monitoreo de CPU

Scripts en `32/script/` (commit `acfee39`):
- `monitor_cpu.sh` — cron cada 5 min, logs en `/data/odoo/32/logs/`
- `install_monitor_cron.sh` — instala el cron
- `analizar_cpu.sh` — analiza logs históricos

El principal culpable de CPU era `wppapi_mb` con memory leak en Puppeteer/Chromium
(crecimiento lineal de 520MB a 1.6GB+ antes de crash). Los resource limits
previenen que consuma todo el host.
