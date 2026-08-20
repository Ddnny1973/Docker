# Conexión al servidor de Prospectum

## Datos del servidor

| Dato | Valor |
| :--- | :--- |
| **IP pública** | `77.42.26.60` |
| **IP interna** | `10.0.0.5` |
| **Usuario** | `root` |
| **Proyecto** | Prospectum (Odoo 18) — carpeta `/data/odoo/41/` |

## Configurar la clave SSH

### 1. Guardar la clave privada

Crear el archivo `~/.ssh/ai-mindnovation` (sin extensión) con el siguiente contenido:

```
-----BEGIN OPENSSH PRIVATE KEY-----
[Tu clave privada aquí]
-----END OPENSSH PRIVATE KEY-----
```

### 2. Permisos de la clave

```bash
chmod 600 ~/.ssh/ai-mindnovation
```

### 3. Probar la conexión

```bash
ssh -i ~/.ssh/ai-mindnovation root@77.42.26.60
```

### 4. (Opcional) Configurar alias SSH

Para no tener que escribir la ruta de la clave cada vez, agregar a `~/.ssh/config`:

```
Host prospectum
    HostName 77.42.26.60
    User root
    IdentityFile ~/.ssh/ai-mindnovation
```

Y después simplemente:

```bash
ssh prospectum
```

---

## Versionamiento del código (Prospectum)

El código custom de Prospectum vive en `/data/odoo/41/extra-addons/prospectum` y se versiona con Git + GitHub.

### 1. Inicializar el repositorio en el servidor

```bash
cd /data/odoo/41/extra-addons/prospectum

git init
git add .
git commit -m "feat: initial commit prospectum"
```

### 2. Crear el repositorio en GitHub

Crear un repo nuevo en GitHub (por ejemplo `prospectum-addons`). **No inicializar con README ni .gitignore.**

### 3. Conectar el servidor con GitHub

```bash
git remote add origin https://github.com/USUARIO/prospectum-addons.git
git branch -M main
git push -u origin main
```

> **Nota:** Si el repo es privado, GitHub pedirá credenciales. Se puede configurar con un Personal Access Token (PAT) desde GitHub → Settings → Developer settings → Tokens.

### 4. Flujo de trabajo (desarrollo)

Cuando se genera código nuevo desde el agente o localmente:

**En la máquina de desarrollo (local):**
```bash
# Clonar el repo (solo la primera vez)
git clone https://github.com/USUARIO/prospectum-addons.git
cd prospectum-addons

# Trabajar en el código, luego:
git add .
git commit -m "feat: descripción del cambio"
git push
```

**En el servidor (sincronizar):**
```bash
cd /data/odoo/41/extra-addons/prospectum
git pull origin main
```

### 5. Reiniciar el contenedor

Después de sincronizar el código, reiniciar el servicio para que Odoo cargue los cambios:

```bash
cd /data/odoo/41
docker compose restart web
```

### 6. Verificar que el contenedor levantó

```bash
docker compose ps
```

El estado de `web` debe ser `Up`.
