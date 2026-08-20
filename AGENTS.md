# AGENTS.md

## What this repo is

Docker Compose / Dockerfile configs for containerized apps deployed across 4 Linux servers (Bastion + 3 Docker nodes). It is infrastructure config, not a codebase: no tests, no lint, no build tooling. There is no automated deploy — this checkout is a source of truth; changes reach the servers by copying/pushing files into `/data/odoo/`. See `INFRAESTRUCTURA.md` for server IPs and project distribution.

Server-side paths (hardcoded in scripts, do not "fix" them):
- Projects live at `/data/odoo/<NN>/`
- Docker data-root is `/data/docker`
- Backups go to `/mnt/hetzner-backup/<NN>/`

Docs and git commits are in **Spanish** — keep that convention. Push to `origin/trunk` (origin/HEAD); commits use conventional prefixes (`feat:`, `fix:`, ...).

## Cerebro digital del repo

- Antes de responder preguntas sobre este repo, revisa `docs/brain/_index.md` y sigue sus enlaces si el tema es relevante.
- Si tu cambio de código deja desactualizado, incorrecto o incompleto algún archivo de `docs/brain/`, actualízalo como parte del mismo PR (no lo dejes para después) y actualiza su campo `updated` en el frontmatter.
- Si detectas que falta documentar un concepto nuevo relevante (componente, proceso, decisión), proponle al usuario crear un archivo nuevo en `docs/brain/` en vez de dejarlo sin documentar.

## Control de ramas

- Antes de modificar o crear archivos, valida la rama actual. Si estás en `trunk`, crea una rama de trabajo (ej. `feat/...`, `docs/...`). Si estás en otra rama, pregunta antes de operar.

## Layout

- Numbered dirs (`16`, `29`–`42`) = independent compose projects, one per app instance. Run from inside the dir: `docker compose up -d`.
  - Odoo instances: services `web` + `db-<NN>` (DB container names are unique so many instances coexist on one host). `config/odoo.conf` is mounted at `/etc/odoo`; custom Odoo modules live under the project's `extra-addons/` (e.g. `35/condominium`, `36/sicone`, `37/spt`, `38/gestor`, `41/prospectum`, `42/showcase`). Some projects include their own docs (e.g. `41/ARQUITECTURA.md`, `41/INSTRUCCIONES_CONEXION.md`).
  - `32` = n8n stack (n8n, redis, postgres:12, pgvector, ocr, whisper transcription, pdf2img, 4x `whatsapp-web-api`). The `transcription` service reads `OPENAI_API_KEY` from the shell env; the `wppapi*` containers build from `32/whatsapp-web-api`.
  - `34` code-server reads `VSCODE_PASSWORD` from `.env`; `39` Metabase; `40` OpenClaw gateway. `16` (Odoo 13) is CANCELLED, and `33`, `34`, `40` are inactive (see `INFRAESTRUCTURA.md`).
- `sites-available/` = nginx vhosts that proxy domains to the host ports below. `nginex/` is a stray typo'd dir containing one conf — put new vhosts in `sites-available/`, not there.

## Port convention

Project `N` publishes its main app on host port `80NN` and its Postgres on `90NN` (`30`→8030/9030, `41`→8041/9041, `39`→8039/9039). Inside compose, Postgres is always hostname `db-<NN>`. Odoo 18 instances also map longpoll 8072 to a host port that varies per instance (no formula — check the compose: `36`→8076, `37`→8077, `38`→8078, `41`→8079, `42`→8090).

## Backup / retention

- `backup_contenedor.sh <NN>`: `docker compose stop`, tars the project folder to `/mnt/hetzner-backup/<NN>/`, then `docker compose start`. `backup_todos.sh` loops a hardcoded list. Both assume `/data/odoo/` as the working root — run them on the server, not from this checkout.
- `prune_backups.py`: retention prune (keep current week, historical Sundays, month-ends; delete older than 6 months). ⚠️ `DRY_RUN = False` at the top deletes for real — set it to `True` to simulate first.

## Credentials

Passwords and API keys are intentionally stored in plaintext inside compose files and `INFRAESTRUCTURA.md` — that is the repo norm. Don't duplicate them into AGENTS.md, docs, or new files; reference the existing location instead.

## AWS sub-projects (separate domains, own deploy flows)

- `ebs-snapshot-rotation/`: Lambda + SAM template. Update flow (see its README): `Compress-Archive lambda_function.py -> function.zip`, `aws s3 cp` to `s3://grpcntbl-backup/lambda-artifacts/snapshot-rotation/`, then update the CloudFormation stack from the console.
- `gc-wordoffice-infra/`: CloudFormation templates for Windows Server infra plus PowerShell ops scripts (e.g. `cloudformation/scripts/reset-rds-grace-period.ps1`).

## Odoo 18 fresh init without demo data

From the root README (run in the project dir; `config/odoo.conf` must exist):

```
docker compose up -d
docker compose stop web
docker run --rm --network <NN>_default -v ./config:/etc/odoo odoo:18 --init=base --without-demo=all --stop-after-init -d odoo
docker compose start web
```
