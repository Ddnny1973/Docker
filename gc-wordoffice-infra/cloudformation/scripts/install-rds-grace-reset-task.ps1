<#
.SYNOPSIS
    Instala la tarea programada que mantiene viva la gracia RDS indefinidamente.

.DESCRIPTION
    Crea la tarea 'Reset-RDS-GracePeriod' corriendo como SYSTEM con dos
    disparadores:
      1. Al arranque del sistema (red de seguridad: se ejecuta en cada boot).
      2. Diaria a las 18:59 (hora local Colombia = 5 min antes del apagado
         automático de las 00:00 UTC / 19:00 COT, cuando ya no hay usuarios).
    La tarea llama a reset-rds-grace-period.ps1, que solo hace el reset cuando
    quedan <= $Threshold días. Como corre como SYSTEM, puede borrar la clave
    GracePeriod (bloqueada a Administrators) sin trucos adicionales.

.PARAMETER Threshold
    Días restantes bajo los cuales se dispara el reset (default 30).

.PARAMETER Hour
    Hora (local, Colombia) del disparador diario (default 18).

.PARAMETER Minute
    Minuto del disparador diario (default 59).

.EXAMPLE
    .\install-rds-grace-reset-task.ps1

.EXAMPLE
    .\install-rds-grace-reset-task.ps1 -Threshold 15 -Hour 05 -Minute 45
#>

param(
    [int]$Threshold = 30,
    [string]$Hour = '18',
    [string]$Minute = '59'
)

$ErrorActionPreference = 'Stop'

# Debe correr como Administrador
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
    throw 'Debe ejecutar este script como Administrador.'
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$resetScript = Join-Path $scriptDir 'reset-rds-grace-period.ps1'
if (-not (Test-Path -LiteralPath $resetScript)) {
    throw "No se encuentra el script de reset: $resetScript"
}

$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$resetScript`" -Threshold $Threshold"
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$triggerTime = Get-Date -Hour ([int]$Hour) -Minute ([int]$Minute) -Second 0
$triggers = @(
    (New-ScheduledTaskTrigger -AtStartup),
    (New-ScheduledTaskTrigger -Daily -At $triggerTime)
)
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 10) `
    -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 5) `
    -MultipleInstances IgnoreNew

Register-ScheduledTask -TaskName 'Reset-RDS-GracePeriod' `
    -Description 'Mantiene viva la gracia de licencia RDS: resetea el contador de 120 dias cuando quedan <= umbral dias. Corre como SYSTEM.' `
    -Action $action -Trigger $triggers -Principal $principal -Settings $settings -Force | Out-Null

Start-ScheduledTask -TaskName 'Reset-RDS-GracePeriod'

Write-Host 'Tarea Reset-RDS-GracePeriod instalada y ejecutada una vez.'
Write-Host ''
Write-Host 'Comandos utiles:'
Write-Host "  Verificar tarea:  schtasks /Query /TN Reset-RDS-GracePeriod /V /FO LIST"
Write-Host "  Reset manual:     schtasks /Run /TN Reset-RDS-GracePeriod"
Write-Host ''
Write-Host 'Dias restantes de gracia RDS:'
& $resetScript -Check
