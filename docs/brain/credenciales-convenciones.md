---
title: "Credenciales y convenciones"
type: decision
app: infra-contenedores
repo: DOCKER
tags: [credenciales, seguridad, convenciones, docs]
related:
  - "[[_index]]"
updated: 2026-08-20
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

## Claves SSH

Las claves SSH se generan directamente en el servidor y se documentan en el repo.
**Nunca se commitean claves privadas.** El `.gitignore` raíz excluye `*.pem`,
`*.key`, `*.pub` y `.env*`.

### Convención de nombres

| Clave | Servidor | Documentación |
| :--- | :--- | :--- |
| `ai-mindnovation` | Docker - New - 02 (`77.42.26.60`) | `41/INSTRUCCIONES_CONEXION.md` |
| `id_storagebox` | (generada en cada servidor para Hetzner Storage Box) | `CX23_PLANTILLA_SETUP.md` |
| `docker-alma-16gb` | Docker - Alma - 16GB (`2.29.11.73`) | `INSTRUCCIONES_CONEXION_ALMA.md` |

### Formato de documentación

Cada nueva conexión SSH documenta:
1. Datos del servidor (IP pública, IP interna, usuario, specs).
2. Generación de la clave (`ssh-keygen`).
3. Copia de la clave pública al servidor.
4. Prueba de conexión.
5. Alias SSH (opcional).

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
- Cuando el usuario pida comandos para ejecutar en un servidor, entregarlos
  **sin el prefijo `ssh docker-alma`** — el usuario los ejecuta directamente
  en la consola del servidor. Solo usar `ssh docker-alma` cuando se pida
  explícitamente o sea necesario ejecutar desde la PC local.
- Repos hermanos en el mismo workspace: `../Trading` (usa la infra de n8n `32` y
  los vhosts de este repo; su backend vive en `/data/odoo/43`).
