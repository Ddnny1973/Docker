---
title: "Credenciales y convenciones"
type: decision
app: infra-contenedores
repo: DOCKER
tags: [credenciales, seguridad, convenciones, docs]
related:
  - "[[_index]]"
updated: 2026-08-02
owner: dueño del repo
---

# Credenciales y convenciones

## Norma de credenciales (decisión explícita del repo)

Las contraseñas y API keys **se almacenan en texto plano** dentro de los archivos
`docker-compose.yml` y en `INFRAESTRUCTURA.md`. Es la norma del repo para un
entorno privado de un solo servidor — **no "arreglar" esto** cambiando a secrets
sin pedirlo, pero tampoco duplicar secretos en documentos nuevos:

- Referenciar la ubicación existente (compose file / `INFRAESTRUCTURA.md`), no
  copiar el valor a otros archivos ni a `docs/brain/`.
- `34/.env` contiene `VSCODE_PASSWORD` en texto plano; `32` lee `OPENAI_API_KEY`
  del entorno del shell.
- No commitear credenciales nuevas fuera de esa norma sin avisar.

## Documentos maestros

- `README.md` — índice del repo + receta de init de Odoo 18 sin demo.
- `INFRAESTRUCTURA.md` — estado del servidor, BDs, credenciales, perfil de consumo
  de cada contenedor y plan de migración. **Fuente de verdad del estado actual.**
- `CX23_PLANTILLA_SETUP.md` — setup de servidor Hetzner nuevo (Docker en
  `/data/docker`, Storage Box por SSHFS, firewall).
- `AGENTS.md` — instrucciones operativas para agentes (este cerebro digital se
  enlaza desde ahí).

## Entorno de trabajo

- Este checkout se trabaja desde **Windows** (PowerShell 5.1), pero los scripts
  de backup (`*.sh`), `prune_backups.py` y los `docker compose` corren en el
  servidor Linux. Un comando de backup desde la máquina local NO afecta al
  servidor real.
- Repos hermanos en el mismo workspace: `../Trading` (usa la infra de n8n `32` y
  los vhosts de este repo; su backend vive en `/data/odoo/43`).
