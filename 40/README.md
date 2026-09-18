# 40 — OpenClaw (asistente personal 24/7)

Agente personal desplegado como **Docker Compose** en el servidor consolidado de Alma (16GB), dentro del esquema numerado `/data/odoo/<NN>/` del repo `Docker`. Acceso inicial por **Telegram** (solo usuario autorizado); integración Google (Gmail/Drive) queda prevista para una fase posterior (ver `docs/brain/arquitectura-contenedores.md`).

> **Historia:** esta carpeta contenía antes un `openclaw.json`/`docker-compose.yml` **nunca desplegados** y que **filtraban tokens en claro a git**. Ambos fueron eliminados y el token de Telegram quedó referenciado como revocable en BotFather (bot **@Aserprem_bot**).

## Decisiones de seguridad (validadas)

| Decisión | Elección |
|---|---|
| Imagen | `ghcr.io/openclaw/openclaw:2026.9.4` (pin inamovible; nunca `:latest`) |
| Sandbox contenedor | **NO** — se descarta montar `/var/run/docker.sock`; compensación: rootfs `read_only`, `cap_drop: [ALL]`, `no-new-privileges`, `tmpfs`, política de tools restrictiva |
| Exposición | Solo `127.0.0.1:8040` (loopback) + SSH tunnel. Telegram = long-polling saliente, sin puertos entrantes |
| Secretos | `/data/odoo/40/.env` (`chmod 600`), no versionado; credenciales del agente en `config/` (se respaldan como credencial) |
| LLM | Pendiente de elección (fase 2) |

## Estructura

```
40/
├── docker-compose.yml   # gateway + cli, endurecido, puerto 8040 loopback
├── .env.example         # plantilla de secretos (versionado, sin valores)
├── README.md            # este runbook
├── .env                 # SERVIDOR, no versionado (chmod 600)
├── config/              # estado del agente (openclaw.json, SQLite) = CREDENCIAL
├── workspace/           # área de trabajo del agente
├── secrets/             # auth-profile / OAuth (futuro)
└── backups/             # respaldos del proyecto (cuando se habilite)
```

## Primer arranque (en el servidor)

Requisitos: `2.29.11.73` es el servidor de destino; los archivos llegan por `git pull` (GitHub Actions) en `/data/odoo`.

```bash
cd /data/odoo/40
cp .env.example .env
chmod 600 .env
# Completar: OPENCLAW_GATEWAY_TOKEN=$(openssl rand -hex 32) y TELEGRAM_BOT_TOKEN (BotFather)
```

Onboarding headless (no interactivo, referencias por `--secret-input-mode ref`):

```bash
docker compose run -T --rm --no-deps --entrypoint node openclaw-gateway \
  dist/index.js onboard --non-interactive --accept-risk --skip-health --mode local \
  --auth-choice openai-api-key --secret-input-mode ref --gateway-auth token \
  --gateway-token-ref-env OPENCLAW_GATEWAY_TOKEN --skip-channels --no-install-daemon
```

Canal Telegram (usa `TELEGRAM_BOT_TOKEN` del `.env`; falla si falta):

```bash
docker compose run -T --rm --no-deps --entrypoint node openclaw-gateway \
  dist/index.js channels add --channel telegram --use-env
```

Restringir Telegram al dueño (ID `1561962049`) y exigir mención en grupos:

```bash
docker compose run --rm openclaw-cli config set --batch-json '[
  {"path":"channels.telegram.enabled","value":true},
  {"path":"channels.telegram.dmPolicy","value":"allowlist"},
  {"path":"channels.telegram.allowFrom","value":["1561962049"]},
  {"path":"channels.telegram.groups","value":{"*":{"requireMention":true}}}
]'
```

Levantar el gateway y verificar:

```bash
docker compose up -d openclaw-gateway
docker compose ps
docker compose run --rm openclaw-cli doctor --json
curl -fsS http://127.0.0.1:8040/healthz     # solo alcanzable desde el servidor
```

## Operación diaria

| Acción | Comando |
|---|---|
| Estado | `docker compose ps` ; `docker compose run --rm openclaw-cli doctor --json` |
| Logs | `docker compose logs -f --tail 100 openclaw-gateway` (rotación 10m×5) |
| Parar | `docker compose stop` (conserva datos) |
| Reanudar | `docker compose up -d openclaw-gateway` |
| Reiniciar gateway | `docker compose restart openclaw-gateway` |
| SSH tunnel (máquina local) | `ssh -N -L 8040:127.0.0.1:8040 root@2.29.11.73` → Control UI en `http://127.0.0.1:8040` |

## Actualizar / rollback

Las versiones de imagen son inmutables (etiqueta = pin). Nunca usar `:latest`.

```bash
# Actualizar: cambiar el tag EN ESTE COMPOSE al nuevo pin estable (ej. 2026.x.y),
cd /data/odoo/40 && docker compose pull openclaw-gateway openclaw-cli
docker compose up -d                                  # recrea con el pin nuevo
docker compose run --rm openclaw-cli doctor --json    # validar
```

Rollback = `git checkout` del compose anterior (o editar el tag) + `docker compose up -d`.

## Validaciones de seguridad (recomendadas tras el primer arranque)

```bash
docker inspect openclaw-40 --format '{{json .Config.CapDrop}} {{.HostConfig.ReadonlyRootfs}} {{.HostConfig.Privileged}} {{.HostConfig.NetworkMode}}'
docker inspect openclaw-40 --format '{{json .HostConfig.SecurityOpt}} {{json .HostConfig.Binds}}'
docker exec openclaw-40 sh -c 'id; ls /root /etc/shadow; test -r /var/run/docker.sock && echo RISK-DOCKER || echo OK-NO-DOCKER'
docker exec openclaw-40 sh -c 'cat /proc/1/status | grep -E "CapEff|NoNewPrivs"'
```

## Plan de backup (PENDIENTE — no activado aún)

- Backups: `backup_contenedor.sh 40` → tar a `/mnt/hetzner-backup/40/` (stop/start del compose).
- Ampliar `backup_todos.sh` para incluir `40` en la rotación.
- ⚠️ `config/` y `secrets/` contienen credenciales del agente → el backup resultante ES material sensible.
- Prune: ya cubierto por `prune_backups.py` (retención semanal/mensual/6 meses).

## Fase 2 (futuro)

- Elegir proveedor LLM y configurar modelo (`openclaw auth`, clave en `.env`, nunca en git).
- Google (Gmail read-only, Drive por carpetas) con scopes restringidos requiere el binario `gog` **hornearse dentro de la imagen** — no se puede añadir en runtime con el rootfs read-only salvo extender/rebuild de imagen. Fuera de alcance ahora.