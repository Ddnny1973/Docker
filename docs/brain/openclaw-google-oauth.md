---
title: "Proyecto 40 — OpenClaw Google Workspace OAuth"
type: reference
tags: [openclaw, google, oauth, gmail, calendar, drive, docs, sheets, slides, least-privilege]
related:
  - "[[_index]]"
  - "[[operaciones-incidentes]]"
updated: 2026-09-19
owner: dueño del repo
---

# OpenClaw — Google Workspace OAuth

## Estado actual

- **Plugin:** `@jason-vaughan/openclaw-google-oauth@0.4.0`.
- **ID registrado en OpenClaw:** `tangleclaw-google-oauth`.
- **Estado:** instalado y habilitado; OAuth todavía pendiente.
- **Ubicación en el servidor:** `/home/node/.openclaw/extensions/tangleclaw-google-oauth`.
- **Proyecto:** `40/`, imagen OpenClaw `2026.9.4`.
- **OpenRouter:** API key personal actualizada correctamente en OpenClaw; el secreto no se documenta ni se versiona.

El plugin utiliza directamente las APIs oficiales de Google mediante `googleapis`.
La extensión y sus tokens viven en el estado persistente del servidor; no forman parte del checkout versionado de este repo.

## Credencial OpenRouter

La API key se actualizó en el Gateway mediante el flujo oficial de onboarding:

```bash
docker compose exec openclaw-gateway openclaw onboard \
   --auth-choice apiKey \
   --token-provider openrouter \
   --token "TU_NUEVA_API_KEY_PERSONAL"
```

El valor mostrado es únicamente un placeholder. La API key real permanece en el estado persistente del servidor y no debe escribirse en este cerebro, en `.env`, en commits ni en mensajes de diagnóstico.

## Scopes actuales

Se modificó en el servidor:

```text
/home/node/.openclaw/extensions/tangleclaw-google-oauth/dist/auth.js
```

Los scopes activos quedaron deliberadamente en modo solo lectura:

```javascript
export const SCOPES = [
    "https://www.googleapis.com/auth/gmail.readonly",
    "https://www.googleapis.com/auth/calendar.readonly",
    "https://www.googleapis.com/auth/drive.readonly",
    "https://www.googleapis.com/auth/documents.readonly",
    "https://www.googleapis.com/auth/spreadsheets.readonly",
    "https://www.googleapis.com/auth/presentations.readonly",
];
```

| Servicio | Permiso actual |
|---|---|
| Gmail | Solo lectura |
| Calendar | Solo lectura |
| Drive | Solo lectura |
| Docs | Solo lectura |
| Sheets | Solo lectura |
| Slides | Solo lectura |

No se han autorizado permisos de escritura.

## Backup y rollback

Antes de modificar el archivo original se creó en el servidor:

```bash
cp /home/node/.openclaw/extensions/tangleclaw-google-oauth/dist/auth.js \
   /home/node/.openclaw/extensions/tangleclaw-google-oauth/dist/auth.js.bak
```

Para regresar al estado anterior:

```bash
cp /home/node/.openclaw/extensions/tangleclaw-google-oauth/dist/auth.js.bak \
   /home/node/.openclaw/extensions/tangleclaw-google-oauth/dist/auth.js
docker compose restart openclaw-gateway
```

El backup conserva los scopes originales del plugin. No contiene credenciales documentadas aquí.

## Regla para ampliar permisos

Aplicar **least privilege** y aumentar un solo permiso cuando exista una necesidad concreta:

1. Identificar la función exacta que necesita el agente.
2. Identificar la herramienta del plugin que la realiza.
3. Determinar el scope mínimo necesario.
4. Cambiar solamente ese scope.
5. Reiniciar el Gateway.
6. Reautorizar OAuth si Google solicita consentimiento nuevo.
7. Probar la función.
8. Mantener los demás servicios en modo solo lectura.

No pasar directamente de solo lectura a todos los scopes originales.

### Scopes de escritura considerados

| Necesidad | Cambio mínimo recomendado |
|---|---|
| Enviar correos | `gmail.readonly` → `gmail.send` |
| Crear o modificar eventos | `calendar.readonly` → `calendar.events` |
| Modificar archivos de Drive | `drive.readonly` → `drive` (amplio; revisar con especial cuidado) |
| Editar documentos | `documents.readonly` → `documents` |
| Editar hojas | `spreadsheets.readonly` → `spreadsheets` |
| Editar presentaciones | `presentations.readonly` → `presentations` |

El token OAuth queda asociado a los scopes autorizados. Al agregar scopes, Google puede solicitar nuevamente consentimiento.

## Capacidades previstas en el nivel actual

Con los permisos actuales se pueden probar:

- Leer correos.
- Consultar el calendario.
- Buscar archivos.
- Leer documentos y hojas.
- Consultar presentaciones.

## Instalación original

```bash
docker compose exec openclaw-gateway openclaw plugins install clawhub:@jason-vaughan/openclaw-google-oauth@0.4.0
```

Cualquier modificación de la extensión debe hacerse en el servidor y registrarse aquí; no se debe asumir que el cambio está reproducido por `docker-compose.yml`.
