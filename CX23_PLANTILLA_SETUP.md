# Guía de Inicialización para Servidor Plantilla (AlmaLinux 9/10)

Esta guía detalla los pasos y comandos necesarios para configurar un nuevo servidor de Hetzner con AlmaLinux como plantilla base. La configuración incluye la optimización del sistema, instalación de Docker configurado en una ruta personalizada, y el montaje automático del Storage Box de Hetzner.

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

*Nota: Si no hay volumen adicional, simplemente ejecuta:*
```bash
mkdir -p /data
```

---

## Paso 2: Actualización y Limpieza de Servicios Innecesarios

Actualizamos el sistema y desactivamos servicios no requeridos en un servidor de producción headless.

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

# 3. Si iptables falla al iniciar Docker, instalar módulos del kernel
#    (común en AlmaLinux 10 con kernel 6.12+)
dnf install -y kernel-modules-extra-$(uname -r)

# 4. Configurar Docker para almacenar datos en /data/docker
mkdir -p /etc/docker /data/docker
printf '{"data-root":"/data/docker"}' > /etc/docker/daemon.json

# 5. Iniciar y habilitar Docker al arranque
systemctl daemon-reload
systemctl enable --now docker.service containerd.service

# 6. Verificar
docker info | grep "Docker Root"  # debe mostrar /data/docker
docker run --rm hello-world       # debe imprimir "Hello from Docker!"
```

> **Nota:** El JSON en `daemon.json` debe ser válido. Si `docker info` falla con
> "invalid JSON", verificar el archivo con `python3 -c "import json;
> json.load(open('/etc/docker/daemon.json'))"`.

---

## Paso 4: Configurar el Storage Box de Hetzner (SSHFS)

Usaremos un script + servicio systemd para montar el Storage Box por SSHFS con autenticación por contraseña (método usado en los servidores existentes).

```bash
# 1. Instalar repositorio EPEL y SSHFS
dnf install -y epel-release fuse-sshfs

# 2. Crear punto de montaje
mkdir -p /mnt/hetzner-backup

# 3. Crear script de montaje
cat <<'SCRIPT' > /usr/local/bin/mount-hetzner.sh
#!/bin/bash
if mountpoint -q /mnt/hetzner-backup; then
    echo "El almacenamiento ya está conectado."
    exit 0
fi
echo 'TU_PASSWORD_AQUI' | sshfs u289217@u289217.your-storagebox.de:/backup /mnt/hetzner-backup \
    -o password_stdin,allow_other,reconnect,ServerAliveInterval=15,ServerAliveCountMax=3,StrictHostKeyChecking=no
if [ $? -ne 0 ]; then
    echo "Error: No se pudo conectar al storage."
    exit 1
fi
echo "Almacenamiento conectado exitosamente."
SCRIPT
chmod +x /usr/local/bin/mount-hetzner.sh

# 4. Crear servicio systemd
cat <<'SERVICE' > /etc/systemd/system/mount-hetzner.service
[Unit]
Description=Montar almacenamiento Hetzner Backup
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/mount-hetzner.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
SERVICE

# 5. Habilitar e iniciar
systemctl daemon-reload
systemctl enable --now mount-hetzner.service

# 6. Verificar
df -h | grep backup        # debe mostrar 1TB / 89% usado
ls /mnt/hetzner-backup     # debe mostrar carpetas numéricas (02, 14, 16, etc.)
```

> **Nota:** Reemplazar `TU_PASSWORD_AQUI` con la contraseña real del Storage Box.
> La contraseña está en texto plano en el script (norma del repo para entorno
> privado).

---

## Paso 5: Configurar el Firewall (`firewalld`)

Configuraremos el firewall para permitir SSH y servicios básicos. Los puertos de aplicaciones se abren después, solo desde el Bastion.

```bash
# 1. Instalar y activar firewalld (no viene por defecto en AlmaLinux 10)
dnf install -y firewalld
systemctl enable --now firewalld

# 2. Permitir servicios básicos
firewall-cmd --permanent --zone=public --add-service=ssh
firewall-cmd --permanent --zone=public --add-service=cockpit
firewall-cmd --permanent --zone=public --add-service=dhcpv6-client

# 3. Recargar reglas del firewall
firewall-cmd --reload

# 4. Verificar
firewall-cmd --list-all
```

Los puertos de aplicaciones (80NN) se abren después con reglas ricas que
restringen el acceso al Bastion (`10.0.0.3`):
```bash
# Ejemplo: abrir puerto 8036 solo desde el Bastion
firewall-cmd --permanent --zone=public --add-rich-rule='rule family="ipv4" source address="10.0.0.3" port port="8036" protocol="tcp" accept'
firewall-cmd --reload
```

---

## Verificación

Para comprobar que todo está correctamente configurado:
* **Docker Root:** `docker info | grep "Docker Root"` (debe mostrar `/data/docker`).
* **Storage Box:** `ls -la /mnt/hetzner-backup` (debe mostrar carpetas de backups).
* **Firewall:** `firewall-cmd --list-all` (debe mostrar ssh, cockpit, dhcpv6-client).
* **Docker test:** `docker run --rm hello-world` (debe funcionar).
