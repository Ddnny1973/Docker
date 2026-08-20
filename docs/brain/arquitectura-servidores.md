# Arquitectura de Infraestructura

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
| **Docker - New - 01** | `46.224.72.175` | `10.0.0.4` | `35`, `39` (Metabase), `42` (Showcase), Trading (`43`) |
| **Docker - New - 02** | `77.42.26.60` | `10.0.0.5` | `41` (Prospectum) |
| **Docker - New - 03** | `37.27.190.155` | `10.0.0.2` | `29`, `32` (n8n), `36` (Sicone), `37` (SPT), `38` (Gestor) |
| **Docker - Alma - 16GB** | `2.29.11.73` | `10.0.0.6` | *Por asignar* |

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
- **Longpoll Odoo 18** — puerto variable por instancia (`8076`, `8077`, `8078`, `8079`, `8090`)

Ejemplo: proyecto `41` → app en `:8041`, DB en `:9041`, longpoll en `:8079`.
