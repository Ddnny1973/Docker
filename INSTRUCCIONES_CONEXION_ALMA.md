# Conexión al servidor Docker Alma 16GB

## Datos del servidor

| Dato | Valor |
| :--- | :--- |
| **Nombre** | Docker - Alma - 16GB (Hetzner Helsinki) |
| **IP pública** | `2.29.11.73` |
| **IP interna** | `10.0.0.6` |
| **Usuario** | `root` |
| **Specs** | 8 vCPU / 16 GB RAM / 160 GB disco |
| **OS** | AlmaLinux 10.2 |

## Estado del servidor (20 de agosto de 2026)

| Componente | Estado |
| :--- | :--- |
| Docker CE | `29.7.2` — data-root en `/data/docker` |
| Docker Compose | `v5.5.0` |
| Storage Box | Montado en `/mnt/hetzner-backup` (1TB, 89% usado) |
| Firewall | `firewalld` activo — SSH, cockpit, dhcpv6-client |
| Clave SSH local | `~/.ssh/docker-alma-16gb` (PC) → alias `docker-alma` |

## Conexión SSH

```bash
ssh docker-alma
```

Alias configurado en `~/.ssh/config`:

```
Host docker-alma
    HostName 2.29.11.73
    User root
    IdentityFile ~/.ssh/docker-alma-16gb
    IdentitiesOnly yes
```
