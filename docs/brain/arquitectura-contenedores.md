---
title: "Arquitectura de contenedores"
type: infra
app: infra-contenedores
repo: DOCKER
tags: [docker, docker-compose, odoo, n8n, puertos]
related:
  - "[[_index]]"
  - "[[deploy-y-sync]]"
updated: 2026-08-02
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
  (Node + whatsapp-web.js + Puppeteer); cada uno tiene su sesión y carpeta de
  media propia (`wppapi-*-media`).
