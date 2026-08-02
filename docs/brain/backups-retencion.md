---
title: "Backups y retención"
type: process
app: infra-contenedores
repo: DOCKER
tags: [backup, retencion, hetzner, storagebox]
related:
  - "[[_index]]"
updated: 2026-08-02
owner: dueño del repo
---

# Backups y retención

## Scripts de backup (corren en el servidor)

- `backup_contenedor.sh <NN>`: hace `docker compose stop` del proyecto, empaqueta
  la carpeta completa en `/mnt/hetzner-backup/<NN>/backup_<NN>_YYYYMMDD_HHMMSS.tar.gz`
  y vuelve a hacer `docker compose start`. Asume `/data/odoo/` como raíz de
  trabajo: **ejecutarlo en el servidor, no desde este checkout**.
- `backup_todos.sh`: itera una lista **hardcodeada** de proyectos
  (`16 29 30 32 33 34`) llamando a `backup_contenedor.sh`. Si se agrega un
  proyecto nuevo que deba respaldarse, hay que añadirlo a esa lista.

## Depuración por retención

- `prune_backups.py`: aplica reglas de retención sobre los `.tar.gz` de
  `/mnt/hetzner-backup/<NN>/` (solo carpetas numéricas):
  - Conservar la semana actual.
  - Conservar domingos históricos y últimos días de mes.
  - Borrar todo lo que tenga más de 6 meses.
- ⚠️ **Gotcha crítico**: `DRY_RUN = False` está arriba del archivo y **borra de
  verdad**. Antes de cualquier corrida, poner `DRY_RUN = True` para simular y
  revisar la salida.
- Escribe log en `/mnt/hetzner-backup/backup.log`.

## Topología de almacenamiento

- Proyectos en `/data/odoo/<NN>/` (volumen/partición de datos).
- Docker data-root en `/data/docker` (imágenes y volúmenes).
- Backups en el Storage Box de Hetzner montado por SSHFS en
  `/mnt/hetzner-backup` (automontaje por Systemd, ver `CX23_PLANTILLA_SETUP.md`).
