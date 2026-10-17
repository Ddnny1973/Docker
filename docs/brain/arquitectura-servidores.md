---
title: "Arquitectura de servidores"
type: infra
app: infra-contenedores
repo: DOCKER
tags: [servidores, bastion, nginx, hetzner, alma]
related:
  - "[[_index]]"
  - "[[nginx-vhosts]]"
  - "[[arquitectura-contenedores]]"
updated: 2026-10-17
owner: dueño del repo
---

# Arquitectura de Infraestructura

> **Estado 2026-10:** los proyectos se consolidaron en **Docker - Alma - 16GB**
> (`10.0.0.6`). New-02 y New-03 figuran vacíos (desmantelables) y New-01 está "por
> confirmar" (puede seguir alojando Metabase `39`). Detalle y dudas en
> [[auditoria-repo-2026-10]]; destino real de cada dominio en [[nginx-vhosts]].

## Diagrama general

```
                         INTERNET
                            │
             ┌──────────────┼──────────────┐
             │              │              │
      95.217.165.80   65.109.240.180   5.75.214.38
             │              │              │
             └──────────────┼──────────────┘
                            │
                     ┌──────┴──────┐
                     │   BASTION   │  10.0.0.3
                     │   (nginx)   │
                     └──────┬──────┘
                            │
           ┌────────────────┼────────────────┬────────────────┐
           │                │                │                │
    ┌──────┴──────┐  ┌──────┴──────┐  ┌──────┴──────┐  ┌──────┴──────┐
    │  Docker 01  │  │  Docker 02  │  │  Docker 03  │  │  Docker 04  │
    │ 10.0.0.4    │  │ 10.0.0.5    │  │ 10.0.0.2    │  │ 10.0.0.6    │
    │46.224.72.175│  │77.42.26.60  │  │37.27.190.155│  │ 2.29.11.73  │
    └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘
           │                │                │                │
     ┌─────┴─────┐    ┌─────┴─────┐    ┌─────┴─────┐    ┌─────┴─────┐
     │ Contened. │    │ Contened. │    │ Contened. │    │ Contened. │
     │  Docker   │    │  Docker   │    │  Docker   │    │  Docker   │
     └───────────┘    └───────────┘    └───────────┘    └───────────┘
```

## Capas

### 1. Bastion (proxy reverso)

- **IP pública:** `95.217.165.80`, `65.109.240.180`, `5.75.214.38`
- **IP interna:** `10.0.0.3`
- **Función:** Nginx recibe todo el tráfico HTTP/HTTPS de los dominios y lo redirige a los contenedores en los nodos Docker vía la red interna (`10.0.0.x`).
- **No tiene contenedores Docker.** Solo corre nginx.
- Los vhosts están en `sites-available/` del repo y se despliegan en `/etc/nginx/conf.d/` del Bastion.

### 2. Nodos Docker (hosts)

Cada nodo corre Docker con los contenedores de los proyectos. No exponen puertos directamente a internet — solo el Bastion tiene IPs públicas.

| Nodo | IP pública | IP interna | Proyectos conocidos |
| :--- | :--- | :--- | :--- |
| **Docker - New - 01** | `46.224.72.175` | `10.0.0.4` | Por confirmar (¿`39` Metabase? su vhost aún apunta aquí) |
| **Docker - New - 02** | `77.42.26.60` | `10.0.0.5` | Vacío — desmantelable (el vhost apex de `ai-mindnovation.com` aún apunta aquí) |
| **Docker - New - 03** | `37.27.190.155` | `10.0.0.2` | Vacío — desmantelable (vhosts de `gc-pruebas`/`38`, `team`, `vsc`, `wetty` aún apuntan aquí) |
| **Docker - Alma - 16GB** | `2.29.11.73` | `10.0.0.6` | **Consolidado:** `29`, `30`, `32`, `35`, `36`, `37`, `40`, `41`, `42`, `43`, `pgadmin4` (AlmaLinux 9, 8 vCPU / 16 GB / 160 GB) |

### 3. Contenedores

Cada proyecto vive en `/data/odoo/<NN>/` dentro de su nodo y se compone de:

- **`web`** — aplicación (Odoo, n8n, etc.)
- **`db-<NN>`** — base de datos PostgreSQL

Los contenedores se comunican entre sí por la red Docker interna. El Bastion accede a ellos por la IP del nodo + puerto mapeado (ej. `10.0.0.5:8041`).

## Flujo de una petición web

```
Usuario → prospectum.ai-mindnovation.com
    │
    ├─ DNS resuelve a 65.109.240.180 (Bastion)
    │
    ├─ Bastion (nginx) recibe la petición en :443
    │   └─ proxy_pass → http://10.0.0.5:8041
    │
    ├─ Docker - New - 02 recibe en :8041
    │   └─ redirige al contenedor web (Odoo :8069)
    │
    └─ Contenedor web responde → Bastion → Usuario
```

## Convención de puertos

- **`80NN`** — puerto de la aplicación del proyecto `NN`
- **`90NN`** — puerto de PostgreSQL del proyecto `NN`
- **Longpoll Odoo 18** — puerto variable por instancia (`35`→`8072`, `36`→`8076`,
  `37`→`8077`, `38`→`8078`, `41`→`8079`, `42`→`8090`)

Ejemplo: proyecto `41` → app en `:8041`, DB en `:9041`, longpoll en `:8079`.

El flujo de ejemplo de arriba (prospectum → `10.0.0.5:8041`) es histórico: hoy el
vhost de prospectum apunta a Alma (`10.0.0.6:8041`).
