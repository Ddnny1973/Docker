# Resumen Migración gcusers - Servidor de Usuarios RDP

## Estado Actual gcusers (Antiguo)

### Hardware
- **Instancia:** t3.xlarge (4 vCPU, 16 GB RAM)
- **Región:** us-east-2
- **AZ:** us-east-2a
- **SO:** Windows Server 2016 Datacenter (Build 14393)
- **Hostname:** EC2AMAZ-JOGGFCH

### Licencia Remote Desktop Services (RDS)
- **Modo:** Per Device (Modo 5)
- **Estado:** Activo
- **Días restantes:** 1682 días (~4.6 años)
- **fDenyTSConnections:** 0 (RDS habilitado)
- **Crítico:** Licencia válida. Debe transferirse al nuevo servidor.

### Usuarios
**Total:** 23 usuarios locales

**Grupos:**
- **Administrators:** 14 usuarios
  - gcadmin, gcsoporte, usuario11-21, Administrator
- **Remote Desktop Users:** 20 usuarios
  - usuario1-21 (excepto usuario22-25)
  - usuario7, usuario18, usuario19, usuario20 deshabilitados

**Usuarios activos con acceso RDS:**
1. usuario1 (contador1)
2. usuario2 (contador2)
3. usuario3
4. usuario4
5. usuario5
6. usuario6 (usuariio6)
7. usuario8
8. usuario9
9. usuario10
10. usuario11 (usuario21)
11. usuario12
12. usuario13
13. usuario14
14. usuario15
15. usuario16
16. usuario17
17. usuario21
18. gcadmin (Administrador)
19. gcsoporte (Grupo Contable Soporte)

**Total a migrar:** 19 usuarios activos + permisos administrativos

### Configuración RDS
- Conexiones remoto: Habilitadas
- MaxInstanceCount: No configurado (sin límite)
- Licencia: Transferible al nuevo servidor

## Optimización de Tipo de Instancia

### Análisis Actual
- **Actual:** t3.xlarge (4 vCPU, 16 GB RAM) = ~$0.2240/hora
- **Uso observado:** CPU <50%, sin datos de memoria (pendiente CloudWatch)
- **Usuarios:** 20 usuarios RDS simultáneos máximo (~3-5 típicos)

### Recomendación
**t3.large (2 vCPU, 8 GB RAM)**
- Costo: ~$0.1052/hora (~$76/mes)
- Ahorro: ~$81/mes vs t3.xlarge
- Suficiente para 20-25 usuarios RDS (típico: 3-5)
- CPU/RAM: Margen para picos

**Fallback:** r5a.large si RAM es insuficiente (16 GB, 2 vCPU)

### Nuevo Servidor gcusers-v2

| Parámetro | Valor |
|-----------|-------|
| Nombre | gcusers-v2 |
| Tipo Instancia | **t3.large** (recomendado) |
| SO | Windows Server 2022 Base |
| AMI | ami-08c41c6041bf318eb (us-east-2) |
| VPC/Subnet | Misma que actual (vpc-080595ca708f9c798, subnet-03cfca5de2aee6b11) |
| Security Group | sg-05b02a26f9b9a820b (reutilizar) |
| EBS | 100 GB, gp3 |
| Key Pair | GC-v2 |
| CloudWatch Agent | Sí (automático en UserData) |

## Pasos Ejecución

### Fase 1: Validación Licencia RDS (Esta semana)
1. **Verificar licencia actual en gcusers:**
```powershell
   Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\RCM\Licensing Core"
```
   Esperado: LicensingMode = 5, días restantes >= 1682

2. **Crear gcusers-v2** con Windows Server 2022 + CloudWatch Agent

3. **Configurar RDS en gcusers-v2:**
   - Instalar servicio RDS
   - Aplicar licencia (número de licencias = 20)
   - Validar que días restantes >= 1682

### Fase 2: Exportar Usuarios (Una vez RDS validado)
1. Exportar lista de usuarios + membresías
```powershell
   Get-LocalUser | Export-Csv "C:\usuarios_export.csv"
   Get-LocalGroupMember "Remote Desktop Users" | Export-Csv "C:\rds_users.csv"
   Get-LocalGroupMember "Administrators" | Export-Csv "C:\admin_users.csv"
```

2. Exportar permisos NTFS (si aplican)

### Fase 3: Crear Usuarios en gcusers-v2
1. Crear usuarios locales con FullName igual
2. Asignar a grupo "Remote Desktop Users" (19 usuarios)
3. Asignar a grupo "Administrators" (según lista)
4. Configurar contraseñas (mantener del antiguo o resetear)

### Fase 4: Validación y Cutover
1. Prueba: 2-3 usuarios conectan a gcusers-v2
2. Validar acceso a gcbdatos-v2 (servidor BD)
3. Migrar IP Elástica (si aplica)
4. Usuarios finales reconectan a gcusers-v2

## Consideraciones Críticas

### RDS Licensing
- ⚠️ **Transferencia de licencia:** La licencia per-device (Modo 5) debe validarse en nuevo servidor
- ⚠️ **CALs:** Confirmar si cliente tiene licencias CAL suficientes o si son license-included
- ⚠️ **Días de prueba:** Si no se transfiere bien, habrá período de prueba. Script de "reset" disponible pero limitado.

### Usuarios
- ✅ 19 usuarios activos a migrar
- ⚠️ 4 usuarios deshabilitados (usuario7, usuario18, usuario19, usuario20) - revisar si incluir
- ✅ Cuentas de servicio (gcadmin, gcsoporte) - críticas, mantener permisos admin

### Performance
- Actual: t3.xlarge, propuesto: t3.large
- ✅ CPU: Suficiente (nunca >50%)
- ⏳ RAM: Pendiente validar con CloudWatch (8GB debe ser OK para 20 usuarios)

## Próximos Pasos (Orden Ejecución)

1. **Crear CloudFormation template para gcusers-v2** (t3.large, Windows 2022, RDS habilitado)
2. **Deploy gcusers-v2**
3. **Configurar RDS y validar licencia (días >= 1682)**
4. **Exportar usuarios desde gcusers antiguo**
5. **Crear usuarios en gcusers-v2**
6. **Pruebas de acceso RDS**
7. **Cutover (asociar IP Elástica a gcusers-v2)**

---

**Estado:** Listo para crear gcusers-v2  
**Decisión pendiente:** ¿Confirmar t3.large o usar r5a.large?  
**Riesgo:** Licencia RDS - requiere validación post-deploy

**Documentado:** 12 Abril 2026
**Servidor antiguo:** gcusers (i-02012953c07d9a106, t3.xlarge)
**Servidor nuevo:** gcusers-v2 (por crear)