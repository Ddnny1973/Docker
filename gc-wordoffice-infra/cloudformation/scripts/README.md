# Reset RDS Grace Period - Windows Server 2025

## Descripción

Script PowerShell que reseta el período de gracia de Remote Desktop Services (RDS) en Windows Server 2025.

**Nota:** El período de gracia tiene un máximo de 3 resets. Cada reset otorga 120 días adicionales.

## Requisitos

- Windows Server 2025
- Acceso como Administrador
- PowerShell 5.0 o superior

## ¿Cuándo usar?

Cuando recibas la alerta:
Remote Desktop Services will stop working in X days

Y no tengas licencias RDS CALs instaladas.

## Instalación

1. Copia el script `reset-rds-grace-period.ps1` al servidor
2. Abre PowerShell como Administrador
3. Navega a la carpeta donde está el script

## Uso

### Opción 1: Ejecutar directamente

```powershell
powershell -ExecutionPolicy Bypass -File reset-rds-grace-period.ps1
```

### Opción 2: Desde PowerShell Admin

```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
.\reset-rds-grace-period.ps1
```

## ¿Qué hace el script?

1. **Verifica permisos Admin** - Asegura que se ejecute como administrador
2. **Consulta clave GracePeriod** - Valida que existe en el registro
3. **Toma ownership** - Toma propiedad de la clave del registro
4. **Otorga permisos** - Da permisos de lectura/escritura
5. **Elimina clave** - Elimina `GracePeriod` del registro
6. **Reinicia servicio** - Reinicia TermService
7. **Reinicia servidor** - Reinicia el servidor para aplicar cambios

## Resultado

✅ Período de gracia reseteado a 120 días
✅ RDS funcionará sin restricciones por otros 120 días
✅ Puedes hacer este proceso hasta 3 veces máximo

## Ubicación de la clave en registro
HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\RCM\GracePeriod

## Validar resultado

Después de ejecutar:

1. Abre **RD Licensing Diagnoser**
2. Verifica que muestre ~120 días disponibles
3. Intenta conectar via RDP

## Limitaciones

⚠️ **Solo 3 resets permitidos** - Microsoft limita esto a 3 resets máximo
⚠️ **No es indefinido** - Después de 3 resets (360 días), necesitas licencias reales
⚠️ **Solo para testing** - No usar en producción sin licencias CALs

## Alternativas

Si necesitas RDS indefinidamente en producción:
- Instalar licencias RDS CALs
- Usar Windows Server sin RDS (máximo 2 sesiones)
- Contratar servicios cloud con RDS incluido

## Troubleshooting

### Error: "Access denied"
```powershell
# Ejecutar como Administrador nuevamente
# O manualmente:
takeown /F "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\RCM\GracePeriod" /A
reg delete "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\RCM\GracePeriod" /f
Restart-Computer
```

### Script no ejecuta
```powershell
# Permitir ejecución de scripts
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### RDS sigue sin funcionar después del reset
1. Reinicia manualmente el servidor
2. Abre RD Licensing Diagnoser nuevamente
3. Valida que el período se haya reseteado

## Información técnica

| Parámetro | Valor |
|-----------|-------|
| Período inicial | 120 días |
| Máximo de resets | 3 |
| Días totales posibles | 480 días (4 × 120) |
| Archivo de clave | Registry: GracePeriod |
| Servicio asociado | TermService |

## Referencias

- [Microsoft - RDS Licensing Troubleshooting](https://learn.microsoft.com/en-us/troubleshoot/windows-server/remote/troubleshoot-rds-licensing-guidance)
- [Windows Server 2025 Remote Desktop Services](https://learn.microsoft.com/en-us/windows-server/remote/remote-desktop-services/)

---

**Autor:** Grupo Contable  
**Versión:** 1.0  
**Última actualización:** Abril 2026  
**Servidor:** gcusers-v2 (Windows Server 2025)