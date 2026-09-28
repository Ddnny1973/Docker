<#
.SYNOPSIS
    Instala la limpieza automatica de sesiones RDS desconectadas en gcusers-v2.

.DESCRIPTION
    Crea la tarea programada 'GCLimpiezaSesiones' corriendo como SYSTEM con dos
    disparadores:
      1. Al arranque del sistema.
      2. Cada $IntervalMinutes minutos (Once + repeticion, igual que el monitor;
         ver install-gcusers-monitor.ps1).
    La tarea ejecuta limpiar-sesiones-desconectadas.ps1, que cierra con logoff
    las sesiones de tipo rdp-tcp* en estado Disc con mas de $IdleMinutes de
    inactividad, liberando la RAM que ocupan sin afectar a sesiones activas.

.PARAMETER IdleMinutes
    Minutos de inactividad antes de cerrar una sesion desconectada (default 30).

.PARAMETER IntervalMinutes
    Minutos entre pasadas de limpieza (default 5).

.EXAMPLE
    .\install-limpieza-sesiones.ps1

.EXAMPLE
    .\install-limpieza-sesiones.ps1 -IdleMinutes 45 -IntervalMinutes 15
#>

param(
    [int]$IdleMinutes = 30,
    [int]$IntervalMinutes = 5
)

$ErrorActionPreference = 'Stop'

if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
    throw 'Debe ejecutar este script como Administrador.'
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$cleanerScript = Join-Path $scriptDir 'limpiar-sesiones-desconectadas.ps1'
if (-not (Test-Path -LiteralPath $cleanerScript)) {
    throw "No se encuentra el script de limpieza: $cleanerScript"
}

$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$cleanerScript`" -IdleMinutes $IdleMinutes"
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest

# Once + repeticion (PS 5.1 no soporta repeticion en triggers diarios).
$triggers = @(
    (New-ScheduledTaskTrigger -AtStartup),
    (New-ScheduledTaskTrigger -Once -At (Get-Date).Date `
        -RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes) `
        -RepetitionDuration (New-TimeSpan -Days 9999))
)

$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 4) `
    -MultipleInstances IgnoreNew

Register-ScheduledTask -TaskName 'GCLimpiezaSesiones' `
    -Description "Cierra sesiones RDP desconectadas con mas de $IdleMinutes min de inactividad (libera RAM). Corre como SYSTEM." `
    -Action $action -Trigger $triggers -Principal $principal -Settings $settings -Force | Out-Null

Start-ScheduledTask -TaskName 'GCLimpiezaSesiones'

Write-Host "Tarea GCLimpiezaSesiones instalada (cada $IntervalMinutes min, cierra Disc > $IdleMinutes min)."
Write-Host ''
Write-Host 'Comandos utiles:'
Write-Host '  Verificar tarea:      schtasks /Query /TN GCLimpiezaSesiones /V /FO LIST'
Write-Host '  Pasada manual:        schtasks /Run /TN GCLimpiezaSesiones'
Write-Host '  Ver log:              Get-Content "<script>\log\limpiar-sesiones-*.log"'
Write-Host '  Prueba sin cerrar:    .\limpiar-sesiones-desconectadas.ps1 -WhatIf'