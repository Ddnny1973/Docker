# Contexto Migración Infraestructura Wordoffice - Abril 2026

## Estado General

**Objetivo:** Migrar infraestructura Wordoffice de t3.xlarge a t3.large (optimizar costos).

**Servidores involucrados:**
- `gcbdatos` (antiguo) → `gcbdatos-v2` (nuevo, t3.large, Windows Server 2022)
- `gcusers` (antiguo) → `gcusers-v2` (nuevo, t3.large, Windows Server 2025)

**Ahorro esperado:** ~$86/mes ($1,032/año)

---

## ✅ Completado

### gcbdatos-v2 (Servidor BD)
- ✅ CloudFormation template creado
- ✅ Instancia deployada (t3.large, 200GB EBS)
- ✅ Windows Server 2022 instalado
- ✅ CloudWatch Agent instalado (configuración pendiente de métricas)
- ✅ Usuario gcadmin creado (GrupoContable2025)
- ✅ Zona horaria Colombia configurada
- ✅ Idioma español (Colombia) configurado

### gcusers-v2 (Servidor Usuarios)
- ✅ CloudFormation template creado
- ✅ Instancia deployada (t3.large, 100GB EBS)
- ✅ Windows Server 2025 instalado
- ✅ Usuario gcadmin creado (GrupoContable2025)
- ✅ Zona horaria Colombia configurada
- ✅ Idioma español (Colombia) en configuración (aplicado a nuevos usuarios)
- ✅ RDS habilitado (fDenyTSConnections = 0)
- ✅ RDS período de gracia: 119 días (Mode 5 Per Device)
- ✅ Script reset-rds-grace-period.ps1 creado (permite 3 resets = 480 días totales)
- ✅ Usuario test-rds creado y probado

### Documentación
- ✅ `docs/gcbdatos-configuracion-antigua.md` - Configuración servidor BD actual
- ✅ `docs/gcusers-migracion-plan.md` - Plan migración usuario RDS
- ✅ `README.md` script RDS reset

---

## ⏳ PENDIENTE - Validaciones y Backup

### 1. Extraer Configuración del Servidor Usuarios Actual (gcusers)

**Qué extraer:**
```powershell
# Perfiles de usuarios (documentar)
Get-LocalUser | Select Name, FullName, Enabled | Export-Csv "usuarios.csv"

# Membresías grupos
Get-LocalGroupMember "Remote Desktop Users" | Export-Csv "rds_users.csv"
Get-LocalGroupMember "Administrators" | Export-Csv "admin_users.csv"

# Configuración especial (permisos NTFS, políticas)
Get-Acl "C:\Users" -Recurse

# Configuración RDS actual
reg export "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" "rds_config.reg"

# Permisos de firewall RDP
Get-NetFirewallRule -DisplayName "*Remote Desktop*" | Export-Csv "firewall_rules.csv"
```

**Dónde guardar:**
- En servidor gcusers actual: `C:\Migration\Backup`
- O en S3 de AWS: `s3://gc-wordoffice-backups/gcusers-config/`

---

### 2. Backup de Usuarios

**Opción A: Copiar perfiles completos**
```powershell
# Desde gcusers actual (requiere acceso)
robocopy "C:\Users" "D:\UsersBackup" /E /COPYALL /R:3 /W:3

# Comprimir
Compress-Archive -Path "D:\UsersBackup" -DestinationPath "D:\UsersBackup.zip"

# Transferir a gcusers-v2 o almacenamiento externo
```

**Opción B: Snapshot EBS**
AWS Console → EC2 → Volumes → vol-xxxxx (gcusers) → Create Snapshot
Nombre: gc-wordoffice-gcusers-users-backup-20260415

**Qué incluye:**
- Perfiles de usuario (C:\Users\usuario1-21)
- Documentos, Desktop, etc. de cada usuario
- Configuración local (NTFS perms, app settings)

**Almacenamiento:** S3 o EBS snapshot

---

### 3. Validar Conectividad gcusers → gcbdatos-v2

**Objetivo:** Confirmar que servidor usuarios ANTIGUO puede conectar a BD NUEVA (Plan B).

```powershell
# Desde gcusers (antiguo)
# 1. Conectar a gcbdatos-v2
Test-NetConnection -ComputerName 172.31.x.x -Port 1433 -Verbose

# 2. Si Wordoffice está instalado
sqlcmd -S 172.31.x.x\WORLDOFFICE17 -Q "SELECT @@VERSION"

# 3. Test aplicación Wordoffice
# Abrir cliente Wordoffice y conectar a server BD nuevo
```

**Resultado esperado:**
- ✅ Puerto 1433 abierto
- ✅ SQL Server responde
- ✅ Wordoffice se conecta sin errores

**Plan B si falla:**
- Revisar Security Group (permitir SQL Server desde gcusers)
- Revisar Firewall en gcbdatos-v2
- Revisar SQL Server está escuchando en puerto 1433

---

### 4. Validar Conectividad gcusers-v2 → gcbdatos-v2

**Objetivo:** Confirmar que servidor usuarios NUEVO puede conectar a BD NUEVA.

```powershell
# Desde gcusers-v2 (nuevo)
# 1. Conectar a gcbdatos-v2
Test-NetConnection -ComputerName 172.31.x.x -Port 1433 -Verbose

# 2. Test SQL Server
sqlcmd -S 172.31.x.x\WORLDOFFICE17 -Q "SELECT @@VERSION"

# 3. Test RDP desde gcusers-v2 a gcbdatos-v2
mstsc /v:172.31.x.x /admin
```

**Resultado esperado:**
- ✅ Conectividad OK
- ✅ RDS funciona entre servidores

---

## 📋 Plan Ejecución Completo

### Fase 1: Validaciones (ESTA SEMANA)
1. ⏳ Extraer configuración gcusers actual
2. ⏳ Crear backup usuarios (opción A o B)
3. ⏳ Test: gcusers (antiguo) → gcbdatos-v2
4. ⏳ Test: gcusers-v2 → gcbdatos-v2

### Fase 2: Migración Usuarios (PROXIMA SEMANA)
1. Crear 23 usuarios en gcusers-v2
2. Asignar permisos RDS (20 usuarios)
3. Asignar permisos Administrators (14 usuarios)
4. Restaurar perfiles si es necesario

### Fase 3: Validación Funcional (SEMANA 3)
1. 2-3 usuarios prueba con gcusers-v2 + gcbdatos-v2
2. Validar acceso Wordoffice
3. Validar permisos NTFS
4. Validar impresoras (si aplica)

### Fase 4: Cutover (SEMANA 4)
1. Cambiar IP Elástica de gcusers → gcusers-v2
2. Usuarios finales se conectan a nuevo servidor
3. Monitoreo 24h
4. Mantener gcusers antiguo como rollback 2 semanas

---

## ⚠️ Datos Críticos a Validar Antes de Cutover

| Item | Ubicación | Crítico |
|------|-----------|---------|
| Backups BD | gcbdatos actual | SÍ |
| Usuarios RDS | gcusers actual | SÍ |
| Licencia RDS | gcusers-v2 (119 días) | ALTO |
| SQL Server instancia | gcbdatos-v2 | SÍ |
| Wordoffice app | Ambos servidores | SÍ |
| Configuración regional | Ambos servidores | NO |

---

## 🔑 IPs y Credenciales Referencia

| Servidor | IP Privada | Usuario Admin | Contraseña |
|----------|-----------|---------------|-----------|
| gcbdatos (antiguo) | 172.31.10.151 | gcadmin | (actual) |
| gcbdatos-v2 | 172.31.x.x | gcadmin | GrupoContable2025 |
| gcusers (antiguo) | 172.31.10.xxx | gcadmin | (actual) |
| gcusers-v2 | 172.31.4.223 | gcadmin | GrupoContable2025 |

---

## 📍 Estado Actual

**Estamos en:** Transición Fase 1 → Fase 2

**Bloqueador actual:** Validaciones pendientes (conectividad entre servidores)

**Próximo paso:** Ejecutar los 4 tests de conectividad para validar que la migración es posible

---

## 📚 Documentos de Referencia

- `/docs/gcbdatos-configuracion-antigua.md` - Config servidor BD
- `/docs/gcusers-migracion-plan.md` - Plan usuario RDS
- `cloudformation/templates/gcbdatos-ec2.yaml` - Template BD
- `cloudformation/templates/gcusers-ec2.yaml` - Template usuarios (por crear)
- `reset-rds-grace-period.ps1` - Script reset licencia RDS

---

**Última actualización:** 13 Abril 2026  
**Responsable:** Grupo Contable - Infrastructure Team  
**Estado:** En Progreso