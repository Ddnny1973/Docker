# Arquitectura — Prospectum (ai-mindnovation)

## Diagrama

```
            INTERNET
               │
    prospectum.ai-mindnovation.com
               │
        ┌──────┴──────┐
        │   BASTION   │  65.109.240.180 (10.0.0.3)
        │    nginx    │
        └──────┬──────┘
               │
        proxy_pass → 10.0.0.5:8041
               │
        ┌──────┴──────┐
        │ Docker - 02 │  77.42.26.60 (10.0.0.5)
        └──────┬──────┘
               │
        ┌──────┴──────┐
        │  41-web     │  Odoo 18 (:8069)
        │  41-db-41   │  PostgreSQL 16 (:5432)
        └─────────────┘
```

## Puertos

| Servicio | Interno | Externo (host) |
| :--- | :--- | :--- |
| Odoo web | `:8069` | `:8041` |
| Odoo longpoll | `:8072` | `:8079` |
| PostgreSQL | `:5432` | `:9041` |

## Rutas en el servidor

| Ruta | Contenido |
| :--- | :--- |
| `/data/odoo/41/` | Compose, config, datos del proyecto |
| `/data/odoo/41/docker-compose.yml` | Definición de contenedores |
| `/data/odoo/41/config/odoo.conf` | Configuración de Odoo |
| `/data/odoo/41/extra-addons/prospectum/` | Módulos custom (versionados en GitHub) |
| `/data/odoo/41/postgresql/data/` | Datos de PostgreSQL |

## Comandos útiles

```bash
# Conectar al servidor
ssh prospectum  # (si configuraste el alias)

# Entrar a la carpeta del proyecto
cd /data/odoo/41

# Ver estado de contenedores
docker compose ps

# Reiniciar Odoo (después de actualizar código)
docker compose restart web

# Ver logs
docker compose logs -f web
```

## Sincronización de código

```bash
# En el servidor, después de hacer push desde local:
cd /data/odoo/41/extra-addons/prospectum
git pull origin main

# Reiniciar para cargar cambios
cd /data/odoo/41
docker compose restart web
```
