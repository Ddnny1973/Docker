---
title: "Operaciones — Incidentes y resoluciones"
type: reference
tags: [operaciones, incidentes, troubleshooting, docker, migracion]
related:
  - "[[arquitectura-servidores]]"
  - "[[deploy-y-sync]]"
updated: 2026-08-20
owner: dueño del repo
---

# Operaciones — Registro de Incidentes

Documento para registrar problemas operacionales, causas raíz y resoluciones en la infraestructura de Docker.

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
