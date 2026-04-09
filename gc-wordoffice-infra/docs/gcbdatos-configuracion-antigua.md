# Resumen Configuración gcbdatos (Antiguo)

## Sistema Operativo
- **SO:** Windows Server 2016 Datacenter (Build 14393)
- **Arquitectura:** X64
- **Processor:** AMD64 Family 23 Model 1, 4 CPUs

## SQL Server
- **Versión:** SQL Server 2017 Express (RTM) - 14.0.1000.169
- **Instancia:** WORLDOFFICE17
- **Estado:** Running

## Wordoffice
- **Ubicación:** `C:\Program Files (x86)\World Office\WO10`
- **Backups:** `C:\Program Files (x86)\World Office\WO10\Backup\DDMMYYYY`
- **Tarea Automática:** "Copia Backup" (diaria)
  - Script: `C:\Datos Sistemas\MoverBackup.bat`
  - Destino: `C:\Users\gcadmin\OneDrive\AAwsServer\Backup\DDMMYYYY`

## Bases de Datos SQL Server
**Instancia:** WORLDOFFICE17

Bases de datos principales:
- Múltiples BD "Aceite" (Data + Log)
- WOAuditoriaTmp (Data + Log)
- WOProgramasDescargados (Data + Log)

## Directorios Especiales
- `C:\Datos Sistemas` - Scripts de administración (incluyendo MoverBackup.bat)

## Aplicaciones Instaladas
- Microsoft Office 2010 (64-bit)
- Microsoft OneDrive
- Chrome, Edge
- SQL Server 2017 Client Tools
- Visual C++ 2022 Runtime

## Servicios Programados
**Tarea crítica:**
- **Copia Backup:** Ejecuta diariamente
  - Comando: `C:\Datos Sistemas\MoverBackup.bat`
  - Copia backups a OneDrive por fecha

## Consideraciones para Migración
1. Wordoffice reside en `Program Files (x86)` - revisar permisos
2. Backups diarios automáticos - mantener política
3. Múltiples BD Aceite - validar todas antes de cutover
4. OneDrive activo - considerar en nueva instancia
5. SQL Server 2017 Express - registrar instancia en nueva máquina

---
**Fecha recopilación:** 07 Abril 2026
**Servidor antiguo:** gcbdatos (i-047ee523d5d8)
**Servidor nuevo:** gcbdatos-v2 (t3.large, Windows Server 2022)