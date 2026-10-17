---
title: "Mapa de vhosts nginx (Bastion)"
type: reference
app: infra-contenedores
repo: DOCKER
tags: [nginx, vhosts, bastion, proxy, dominios]
related:
  - "[[_index]]"
  - "[[arquitectura-servidores]]"
  - "[[deploy-y-sync]]"
  - "[[auditoria-repo-2026-10]]"
updated: 2026-10-17
owner: dueño del repo
---

# Mapa de vhosts nginx (Bastion)

Fuente: `sites-available/*.conf` (auditado 2026-10-17). Los vhosts se copian a mano
al Bastion (`/etc/nginx/conf.d/`, luego `nginx -t && systemctl reload nginx`).
Nodo `10.0.0.6` = Docker-Alma-16GB (consolidado); `10.0.0.2` = Docker-New-03;
`10.0.0.4` = Docker-New-01; `10.0.0.5` = Docker-New-02.

## Apuntan a Alma (`10.0.0.6`) — vigentes

| Dominio | Destino | Proyecto |
|---|---|---|
| `aserprem.gestorconsultoria.com.co` | `:8029` | 29 (Odoo 16) |
| `ai-mindnovation.com`, `www.ai-mindnovation.com` | `:8030` (www) / `10.0.0.5:8030` (apex) | 30 (Odoo 16) |
| `n8n.gestorconsultoria.com.co` | `:8032` | 32 (n8n) |
| `propiedades.gestorconsultoria.com.co` | `:8035` + longpoll `:8072` | 35 |
| `ocreterraverde.com` | `:8035` | 35 |
| `sicone.ai-mindnovation.com` | upstream `odoo36` `:8036` / longpoll `:8076` | 36 |
| `spt.ai-mindnovation.com` | upstream `odoo37` `:8037` / longpoll `:8077` | 37 |
| `prospectum.ai-mindnovation.com` | `:8041` | 41 |
| `showcase.ai-mindnovation.com` | `:8042` | 42 |
| `trading.gestorconsultoria.com.co` | `:8043` | 43 |
| `pgadmin.gestorconsultoria.com.co` | `:8010` | pgadmin4 |
| `ai-maindnovation.gestorconsultoria.com.co` | `:8130` | sin compose en el repo (¿legacy?) |

## Apuntan a nodos antiguos — revisar

| Dominio | Destino | Observación |
|---|---|---|
| `ai-mindnovation.com` (apex) | `10.0.0.5:8030` | Alma ya aloja el 30; el `www` sí apunta a Alma. Posible incoherencia entre los dos vhosts. |
| `gc-pruebas.gestorconsultoria.com.co` | `10.0.0.2:8038` / `:8078` | Proyecto 38 (Gestor): New-03 figura como vacío en `INFRAESTRUCTURA.md`. |
| `analytics.gestorconsultoria.com.co` | `10.0.0.4:8039` | Metabase (39): nodo New-01, "por confirmar". |
| `team.gestorconsultoria.com.co`, `teamcomunicaciones.net` | `10.0.0.2:8016` (y `10.0.0.4:8016`) | Proyecto 16 CANCELADO. |
| `vsc.gestorconsultoria.com.co` | `10.0.0.2:8034` | Proyecto 34 inactivo. |
| `wetty.gestorconsultoria.com.co` | `10.0.0.2:8033` | Proyecto 33 inactivo. |
| `www.gestorconsultoria.com.co` | `192.168.100.200:8081` | IP privada fuera de la red `10.0.0.x`; origen no documentado. |

## Sin vhost

- `40` (OpenClaw): solo loopback + túnel SSH; Telegram por long-polling saliente.
- `32` servicios internos (`ocr` 5001, `pdf2img` 5002, `transcription` 5003).

## Duplicados y restos en el repo

- `nginex/sites-available/trading...conf` → apunta a `10.0.0.4:8043` (obsoleto;
  el vigente está en `sites-available/` y apunta a Alma). Ver [[auditoria-repo-2026-10]].
- `36/sicone.ai-mindnovation.com.conf` es copia del vhost de `sites-available/`.
- `sites-available/n8n...conf.bk`, `...conf.bk2`: respaldos manuales.
- `sites-available/ai-maindnovation...` tiene el nombre con typo (`maind`).
