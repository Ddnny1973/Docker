# Conexión al servidor Docker Alma 16GB

## Datos del servidor

| Dato | Valor |
| :--- | :--- |
| **Nombre** | Docker - Alma - 16GB (Hetzner Helsinki) |
| **IP pública** | `2.29.11.73` |
| **IP interna** | `10.0.0.6` |
| **Usuario** | `root` |
| **Specs** | 8 vCPU / 16 GB RAM / 160 GB disco |
| **OS** | AlmaLinux 9 |

## Configurar la clave SSH

### 1. Generar la clave en el servidor

```bash
ssh-keygen -t ed25519 -f /root/.ssh/docker-alma-16gb -C "docker-alma-16gb@2.29.11.73"
```

### 2. Copiar la clave pública a la máquina local

```bash
cat /root/.ssh/docker-alma-16gb.pub
```

Copiar la salida y pegarla en `~/.ssh/docker-alma-16gb.pub` en la máquina local.

### 3. Permisos de la clave (servidor)

```bash
chmod 600 /root/.ssh/docker-alma-16gb
chmod 644 /root/.ssh/docker-alma-16gb.pub
```

### 4. Probar la conexión

```bash
ssh -i ~/.ssh/docker-alma-16gb root@2.29.11.73
```

### 5. (Opcional) Configurar alias SSH

Para no tener que escribir la ruta de la clave cada vez, agregar a `~/.ssh/config`:

```
Host docker-alma
    HostName 2.29.11.73
    User root
    IdentityFile ~/.ssh/docker-alma-16gb
```

Y después simplemente:

```bash
ssh docker-alma
```
