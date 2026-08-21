---
title: "Operaciones — Incidentes y resoluciones"
type: reference
tags: [operaciones, incidentes, troubleshooting, docker, migracion]
related:
  - "[[arquitectura-servidores]]"
  - "[[deploy-y-sync]]"
updated: 2026-08-21
owner: dueño del repo
---

# Operaciones — Registro de Incidentes

Documento para registrar problemas operacionales, causas raíz y resoluciones en la infraestructura de Docker.

---

## 2026-08-21 — 🔴 CRÍTICO: GitHub Actions rsync --delete borra datos de producción

### Contexto

Primera ejecución del workflow de GitHub Actions `.github/workflows/auto-deploy.yml` (antes llamado `sync-deploy.yml`). El flujo estaba diseñado para sincronizar cambios de código automáticamente al servidor `2.29.11.73:/data/odoo/` usando rsync.

### Problema

El workflow incluía el flag `--delete` en rsync:
```bash
rsync -avz --delete \
  --exclude='.git/' \
  --exclude-from=.gitignore \
  -e "ssh -i ~/.ssh/ci-deploy ..." \
  . \
  root@2.29.11.73:/data/odoo/
```

**Resultado:** ⚠️ **BORRÓ TODOS LOS DATOS** de proyecto 43 (Trading) y pgadmin4:

**Archivos eliminados:**
- `43/postgres-trading-data/` (base de datos completa)
- `43/redis-trading-data/` (datos Redis completa)
- `43/scripts/`, `43/tests/`
- `pgadmin4/private/` (configuración + sesiones + BD)
- Sesiones HTTP de pgadmin4 (~45 archivos)

### Causa Raíz

**Comportamiento de rsync con `--delete`:**
1. Source (GitHub repo): contiene SOLO código, NO tiene `/data/odoo/43/postgresql/`, `/data/odoo/43/filestore/`, etc.
2. Destination (servidor): contiene datos de producción en esos directorios
3. rsync **compara source vs destination** y borra en destination TODO lo que NO está en source
4. **`.gitignore` no protege contra rsync --delete** — `.gitignore` solo afecta a git, no a rsync

### Timeline

1. **2026-08-21 ~09:00:** Workflow se dispara en push a `trunk`
2. **~09:01:** GitHub Actions ejecuta rsync con `--delete`
3. **~09:02:** Centenares de archivos de producción borrados:
   ```
   deleting 43/postgres-trading-data/...
   deleting 43/redis-trading-data/...
   deleting pgadmin4/private/...
   ```
4. **~10:00:** Descubrimiento del problema en GitHub Actions logs
5. **~10:15:** Identificación de causa raíz: `--delete` en rsync
6. **~10:30:** Commit de emergencia **fa3e911** para remover `--delete`

### Intento de Recuperación

1. **Comando usado:**
   ```bash
   cd /data/odoo
   for dir in 29 30 32 35 36 37 41 42 43; do
     BACKUP=$(ls -t /mnt/hetzner-backup/$dir/backup_${dir}_*.tar.gz 2>/dev/null | head -1)
     if [ -n "$BACKUP" ]; then
       tar -xzf "$BACKUP"
     fi
   done
   docker compose up -d
   ```

2. **Restauración:** pgadmin4 y proyecto 43 se restauraron desde backup (timestamp 2026-08-21 ~05:00)
3. **Pérdida de datos:** ~5 horas de cambios entre última copia de seguridad y el incident

### Solución Implementada

**Commit fa3e911:** Remover `--delete` de rsync
- Ya no borra archivos en destination
- Solo sincroniza código (lo que está en source)
- Mantiene todos los datos de runtime

**Commit c1a9285:** Cambio a modelo appleboy (SEGURO)
- Cambiar de `rsync --delete` a `git pull origin trunk`
- Modelo idéntico al usado en Trading repo (probado, seguro)
- No hay riesgo de borrado destructivo

### Lecciones Aprendidas

1. ⚠️ **NUNCA rsync con `--delete` en infraestructura de datos** — Demasiado peligroso, sin margen de error
2. ⚠️ **`.gitignore` NO protege contra rsync --delete** — `.gitignore` solo es para git; rsync ignora completamente
3. ✅ **Usar `git pull` es más seguro** — Requiere clonar primero, preserva histórico git, nunca borra
4. ✅ **Backup previo es salvavidas** — Recuperación posible PORQUE existía `/mnt/hetzner-backup/43/` con snapshots recientes
5. ✅ **Validar scripts con DRY_RUN primero** — Para cualquier comando destructivo, siempre simular antes

### Checklist: Prevención Futura

- ✅ Remover `--delete` de rsync en TODOS los workflows
- ✅ Documentar en [[comandos-destructivos]] con checklist obligatorio
- ✅ Usar `git pull` en lugar de rsync para deploy de código
- ✅ Requerir validación + confirmación para cualquier comando que borre
- ✅ Mantener backups recientes y verificables

### Estado Final

- ✅ Workflow corregido (commits fa3e911, c1a9285)
- ✅ Datos recuperados desde backup
- ✅ Servicios operacionales
- ✅ Documentación de prevención creada

### Impacto

- **Criticidad:** 🔴 **CRÍTICA** — Borrado masivo de datos de producción
- **Duración:** ~1 hora (desde ejecución hasta descubrimiento y fix)
- **Datos perdidos:** ~5 horas (entre backup 05:00 y incident 10:00)
- **Recuperación:** Exitosa, sin corrupción

---

## 2026-08-20 — Migración Alma-16GB: Chromium Profile Lock en wppapi_mb

### Contexto
Migración completada de todos los proyectos (29, 30, 32, 35–43) a Docker-Alma-16GB (`2.29.11.73`). El proyecto 32 (n8n + IA + WhatsApp APIs) se migró desde Docker-New-03 sin incidentes **excepto** `wppapi_mb`.

### Problema
```
Failed to launch the browser process: Code: 21
The profile appears to be in use by another Chromium process (19) on another computer (d8fdbd39741d)
Chromium has locked the profile so that it doesn't get corrupted
```

**Sintomatología:**
- Contenedor `wppapi_mb` genera error de Puppeteer/Chromium
- Lock file persiste incluso tras restart del contenedor
- El servicio nunca levanta exitosamente
- Otros contenedores del proyecto 32 (n8n, wppapi, wppapi_ai, wppapi_ai_2) funcionan normalmente

### Causa Raíz

1. **Post-migración:** El contenedor anterior en Docker-New-03 dejó el perfil de Chrome locked
2. **Volumen persistente:** El archivo de lock está en `./wppapi_mb_data:/app/.wwebjs_auth` (volumen local del host)
3. **Migración física:** El directorio se copió completo al nuevo servidor, preservando el estado corrupto
4. **Reintentos fallidos:** Limpiar solo el directorio de Chromium (`/root/.config/chromium`) no es suficiente; el lock está en `.wwebjs_auth`

### Intento de Resolución

**Comandos ejecutados:**
```bash
# Intento 1: Limpiar directorio de caché de Chromium dentro del contenedor
docker exec wppapi_mb rm -rf /root/.config/chromium/Singleton*
docker restart wppapi_mb
# Resultado: FALLÓ — el lock persiste

# Intento 2: Eliminar volumen Docker
docker stop wppapi_mb
docker volume rm 32_wppapi_mb_tmp
# Resultado: PARCIAL — se limpió tmp pero sesión de WhatsApp se perdió
```

### Decisión Operacional

**Status:** ⚠️ **PAUSADO — Sesión Perdida**

- Contenedor `wppapi_mb` detenido (`docker stop wppapi_mb`)
- Volumen `32_wppapi_mb_tmp` eliminado, pero `.wwebjs_auth` (sesión de WhatsApp) comprometido
- **No se ejecutó** `docker compose up -d wppapi_mb` para evitar daño adicional

### Próximas Acciones

1. **Opción A (Recomendada):** Restaurar backup de `./wppapi_mb_data/` desde antes de migración
   - Buscar snapshot en `/mnt/hetzner-backup/32/` (si existe)
   - Restaurar directorio `.wwebjs_auth` completo
   - Reintentar `docker compose up -d wppapi_mb`

2. **Opción B:** Re-autenticar wppapi_mb desde cero
   - Eliminar `./wppapi_mb_data` completamente
   - Levantar contenedor: `docker compose up wppapi_mb`
   - Leer QR de WhatsApp nuevamente en logs
   - Volver a autenticar la sesión de `mb-asesores`

3. **Opción C:** Reconstruir imagen sin caché
   ```bash
   docker compose build --no-cache wppapi_mb
   docker compose up -d wppapi_mb
   ```

### Lecciones Aprendidas

- ⚠️ **Volúmenes locales en migraciones:** No es suficiente copiar directorios; hay que validar que no haya locks o archivos de estado corrompidos
- ⚠️ **Chromium en contenedores:** El perfil de Chromium es frágil; considerar usar `--disable-dev-shm-usage` o aumentar `/dev/shm` en futuras migraciones
- ✅ **Otros servicios resilientes:** wppapi, wppapi_ai, wppapi_ai_2 y el resto del proyecto 32 se recuperaron sin problemas

### Impacto

- **Funcionalidad:** Sesión de WhatsApp `mb-asesores` (wppapi_mb) inactiva
- **Otros WPP:** wppapi (default), wppapi_ai (ai), wppapi_ai_2 (ai_2) siguen funcionando ✅
- **n8n y IA:** No afectados ✅
- **Urgencia:** Media — pendiente decisión sobre restaurar backup vs re-autenticar

---

## Resumen de Migraciones Completadas (2026-08-20)

| Proyecto | Origen | Destino | Resultado | Notas |
|----------|--------|---------|-----------|-------|
| 29–30 (Odoo 16 legacy) | Docker-New-03 | Alma-16GB | ✅ Migrado | Ambos unhealthy pero funcionales |
| 32 (n8n + IA) | Docker-New-03 | Alma-16GB | ✅ Migrado* | *wppapi_mb problema post-migración |
| 35–37, 41–43, pgadmin4 | Varios | Alma-16GB | ✅ Migrado | Todos operational |

**Docker-New-02 y Docker-New-03:** Completamente vacíos, candidatos para desmantelación.
