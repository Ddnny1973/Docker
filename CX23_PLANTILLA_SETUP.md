# Guía de Inicialización para Servidor Plantilla CX23 (AlmaLinux 9)

Esta guía detalla los pasos y comandos necesarios para configurar un nuevo servidor `CX23` de Hetzner con AlmaLinux 9 como plantilla base. La configuración incluye la optimización del sistema, instalación de Docker configurado en una ruta personalizada, y el montaje seguro y automático del Storage Box de Hetzner.

---

## Paso 1: Configurar el Almacenamiento `/data` (Opcional pero Recomendado)

Si has contratado un **Volumen** adicional en Hetzner Cloud para almacenar los contenedores (por ejemplo, `/dev/sdb`):

1. Identifica el nombre del dispositivo de almacenamiento adicional:
   ```bash
   lsblk
   ```
2. Dale formato al volumen (usaremos `ext4`):
   ```bash
   mkfs.ext4 -F /dev/sdb
   ```
3. Crea el directorio de montaje `/data`:
   ```bash
   mkdir -p /data
   ```
4. Añade el montaje permanente en el `/etc/fstab` para que se monte al reiniciar:
   ```bash
   echo '/dev/sdb /data ext4 defaults,nofail 0 2' >> /etc/fstab
   mount -a
   ```

*Nota: Si prefieres no usar un volumen adicional en un principio y trabajar directamente sobre el SSD de 40 GB de la instancia, simplemente ejecuta:*
```bash
mkdir -p /data
```

---

## Paso 2: Actualización y Limpieza de Servicios Innecesarios

Actualizamos el sistema y desactivamos servicios de red y de impresión no requeridos en un servidor de producción headless, liberando así memoria RAM.

```bash
# 1. Actualizar el sistema operativo
dnf update -y

# 2. Desactivar servicios innecesarios (impresión, mdns y modem)
systemctl disable --now cups.service avahi-daemon.service ModemManager.service
```

---

## Paso 3: Instalar y Configurar Docker en `/data`

Instalaremos la versión comunitaria oficial de Docker y redirigiremos su carpeta de trabajo a `/data` para evitar llenar la partición del sistema operativo `/`.

```bash
# 1. Instalar el repositorio oficial de Docker
dnf install -y yum-utils
dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

# 2. Instalar Docker CE, CLI y plugins de compilación/compose
dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 3. Configurar Docker para almacenar datos en /data/docker
mkdir -p /etc/docker
cat <<EOF > /etc/docker/daemon.json
{
  "data-root": "/data/docker"
}
EOF

# 4. Iniciar y habilitar Docker al arranque
systemctl daemon-reload
systemctl enable --now docker.service containerd.service
```

---

## Paso 4: Configurar la Conexión Segura al Storage Box (SSHFS)

Usaremos SSHFS con llaves SSH (sin almacenar contraseñas en texto plano) y Systemd Automount para un montaje automático autorreparable.

```bash
# 1. Instalar repositorio EPEL y SSHFS
dnf install -y epel-release
dnf install -y fuse-sshfs

# 2. Generar llave SSH exclusiva para el Storage Box
ssh-keygen -t ed25519 -f /root/.ssh/id_storagebox -N ""
```

3. **Subir la llave pública al Storage Box:**
   * Ejecuta: `cat /root/.ssh/id_storagebox.pub`
   * Copia la clave resultante.
   * Ve al panel de control de Hetzner -> **Storage Box** -> Selecciona tu ID (`u289217`) -> **SSH Keys** -> Haz clic en **Add SSH Key** y pega la llave.

4. **Configurar el Automontaje Permanente:**
   ```bash
   # Crear punto de montaje
   mkdir -p /mnt/hetzner-backup

   # Agregar regla en fstab para automontaje inteligente por Systemd
   echo 'u289217@u289217.your-storagebox.de:/backup /mnt/hetzner-backup fuse.sshfs x-systemd.automount,allow_other,reconnect,IdentityFile=/root/.ssh/id_storagebox,ServerAliveInterval=15,ServerAliveCountMax=3,StrictHostKeyChecking=no,nofail 0 0' >> /etc/fstab

   # Recargar systemd para aplicar la regla
   systemctl daemon-reload
   systemctl restart remote-fs.target
   ```

---

## Paso 5: Configurar el Firewall (`firewalld`)

Configuraremos el firewall para bloquear todo el tráfico externo excepto el tráfico web estándar, la administración por SSH y los puertos específicos que decidas abrir.

```bash
# 1. Asegurar que firewalld está activo y habilitado
systemctl enable --now firewalld

# 2. Permitir servicios básicos (Web y SSH)
firewall-cmd --permanent --zone=public --add-service=ssh
firewall-cmd --permanent --zone=public --add-service=http
firewall-cmd --permanent --zone=public --add-service=https

# 3. Recargar reglas del firewall
firewall-cmd --reload
```

---

## Verificación

Para comprobar que todo está correctamente configurado:
* **Docker Root:** Ejecuta `docker info | grep "Docker Root"` (debe mostrar `/data/docker`).
* **Storage Box:** Ejecuta `ls -la /mnt/hetzner-backup`. Deberías poder ver la carpeta de backups de Hetzner inmediatamente (el sistema lo montará al vuelo en ese instante).
