---
title: "Comandos destructivos — Validación y seguridad"
type: reference
app: infra-contenedores
repo: DOCKER
tags: [rm, rsync, delete, seguridad, despliegue, validacion]
related:
  - "[[_index]]"
  - "[[deploy-y-sync]]"
  - "[[operaciones-incidentes]]"
updated: 2026-08-21
owner: dueño del repo
---

# Comandos destructivos — Validación y seguridad

⚠️ **CRÍTICO:** Cualquier comando que borre, elimine o sincronice **DEBE** tener:
1. **Descripción explícita** de QUÉ puede borrar
2. **Validación previa** de scope (simulación / dry-run)
3. **Confirmación manual** antes de ejecutar en producción

## Patrones peligrosos

### ❌ rsync con `--delete`

```bash
rsync -avz --delete \
  -e "ssh -i ~/.ssh/key" \
  /source/ \
  user@host:/dest/
```

**¿Por qué es peligroso?**
- Compara source vs destination
- Borra en destination TODO lo que NO está en source
- Si source NO tiene `postgresql/`, `filestore/`, etc. → **los borra del servidor**

**Ejemplo del desastre (2026-08-21):**
- Source (GitHub): solo código, NO tiene `/43/postgresql/`, `/43/filestore/`
- Destination (servidor): tiene datos de producción
- Rsync con `--delete` → ⚠️ **BORRÓ TODOS LOS DATOS** de proyecto 43 y pgadmin4

**¿Cuándo es seguro?**
- SOLO cuando source y destination son idénticos en estructura
- O cuando proteges explícitamente con `--exclude`:
  ```bash
  rsync -avz \
    --exclude='postgresql/' \
    --exclude='filestore/' \
    # ... más exclusiones ...
  ```

**Alternativa segura:** Git pull (ver [[deploy-y-sync]])

---

### ❌ rm / rmdir sin validación

```bash
rm -rf /data/odoo/42/filestore/
rm -rf /mnt/hetzner-backup/2026-01-*/  # Patrón arriesgado
```

**Regla de oro:**
```bash
# ❌ NUNCA sin validar antes:
rm -rf /path/to/data/

# ✅ SIEMPRE:
# 1. Listar primero
ls -lh /path/to/data/
du -sh /path/to/data/

# 2. Si el tamaño es correcto, ENTONCES borrar
rm -rf /path/to/data/
```

---

### ❌ docker rm / docker rmi sin backup

```bash
docker rm postgres-data-volume
docker rmi myimage:latest
```

**Validación previa:**
```bash
# Ver qué contenedores/imágenes existen
docker ps -a
docker images

# Ver tamaño antes de borrar
docker inspect <container-id> | jq '.Size'

# Hacer backup si es crítico
docker commit <container-id> backup-$(date +%Y%m%d):latest

# LUEGO borrar
docker rm <container-id>
```

---

### ❌ tar extraction sin verificar

```bash
tar -xzf /mnt/hetzner-backup/43/backup_43_*.tar.gz
```

**Problema:** ¿Y si el archivo está corrupto? ¿O tiene rutas absolutas que sobreescriben datos?

**Validación:**
```bash
# 1. Verificar integridad
tar -tzf /mnt/hetzner-backup/43/backup_43_*.tar.gz > /dev/null
if [ $? -ne 0 ]; then echo "❌ BACKUP CORRUPTO"; exit 1; fi

# 2. Listar contenido (primeras 20 líneas)
tar -tzf /mnt/hetzner-backup/43/backup_43_*.tar.gz | head -20

# 3. Ver tamaño
ls -lh /mnt/hetzner-backup/43/backup_43_*.tar.gz

# 4. LUEGO extraer
cd /data/odoo
tar -xzf /mnt/hetzner-backup/43/backup_43_*.tar.gz
```

---

### ❌ prune_backups.py con DRY_RUN=False

```python
# /data/odoo/prune_backups.py
DRY_RUN = False  # ❌ BORRA PARA REAL
```

**Regla obligatoria:**
```python
# Siempre:
DRY_RUN = True  # ✅ Simula
# Ver output, validar lista de borrado
# LUEGO cambiar a:
DRY_RUN = False  # ✅ Ejecutar
```

---

## Checklist: Antes de ejecutar comandos destructivos

Siempre validar:

```
[ ] ¿Qué exactamente va a borrar? (listar archivos)
[ ] ¿Cuánto espacio libero? (du -sh)
[ ] ¿Hay backup reciente? (ls -lh /mnt/hetzner-backup/)
[ ] ¿El comando tiene --dry-run / -n / simulation? (ejecutar primero)
[ ] ¿Confirmé manualmente el scope?
[ ] ¿Documenté la acción en operaciones-incidentes.md?
[ ] ¿Puedo revertir si falla? (backup disponible)
```

---

## Incidentes registrados

### 2026-08-21: rsync --delete data loss

**Incident:** GitHub Actions workflow usaba `rsync -avz --delete` sin protecciones.
**Impact:** Borró `/43/postgresql/`, `/43/filestore/`, `/pgadmin4/private/` (TODOS LOS DATOS de proyecto 43 y pgadmin4).
**Root cause:** Source (GitHub) no tenía datos de runtime → rsync los borró de destination.
**Fix:** Cambiar workflow a `git pull` (modelo Trading).
**Lección:** **NUNCA rsync con --delete en depósitos de runtime.**

Ver: [[operaciones-incidentes]]

---

## Matriz de seguridad

| Comando | Riesgo | Validación | Alternativa segura |
|---------|--------|------------|-------------------|
| `rsync --delete` | 🔴 CRÍTICO | Excluir TODOS los directorios de datos | `git pull` |
| `rm -rf /path` | 🔴 CRÍTICO | `ls -lh` + `du -sh` primero | Backup, validar, borrar |
| `docker rm/rmi` | 🟡 ALTO | `docker ps -a`, `docker inspect` | Commit antes si es necesario |
| `tar -xzf` | 🟡 ALTO | `tar -tzf` (verificar integridad) | Validar contenido primero |
| `prune_backups.py` | 🟡 ALTO | `DRY_RUN=True` primero | Revisar lista, confirmar |

---

## Regla de oro

> **Si un comando PUEDE borrar datos, DEBE explicar QUÉ borra, y el usuario DEBE validar y confirmar antes de ejecutar en producción.**

Aplicar SIEMPRE a:
- GitHub Actions workflows
- Scripts de backup/prune
- Operaciones manuales en servidor
- Restauración desde backup

---

Última actualización: 2026-08-21
Contexto: Incident 2026-08-21 rsync --delete data loss
