# Docker Repo

Este repositorio tiene como objetivo centralizar todos los archivos `Dockerfile` y `docker-compose.yml` de diferentes contenedores utilizados en distintos proyectos o entornos.

## Estructura sugerida

- `/dockerfiles/` — Aquí se almacenarán los diferentes `Dockerfile` organizados por contenedor o propósito.
- `/compose/` — Aquí se almacenarán los archivos `docker-compose.yml` para orquestar los contenedores.

## Objetivo

Facilitar la reutilización, mantenimiento y despliegue de contenedores Docker en distintos escenarios.

---

Agrega tus archivos siguiendo la estructura sugerida o proponiendo una nueva si lo consideras necesario.

## Instrucciones para iniciar un contenedor de Odoo 18 sin datos demo

Para iniciar un contenedor de Odoo 18 sin datos demo, puedes usar el siguiente comando:

```bash
docker-compose up -d
docker-compose stop web 
docker run --rm --network xx_default -v ./config:/etc/odoo odoo:18 --init=base --without-demo=all --stop-after-init -d odoo

```

Importante: La carpeta config debe contener el archivo odoo.conf

Puedes ajustar los parámetros según tus necesidades.
