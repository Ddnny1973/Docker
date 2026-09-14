<#
.SYNOPSIS
    Instala el monitoreo interno de gcusers-v2: muestra por CSV cada 5 minutos.

.DESCRIPTION
    Crea la tarea programada 'GCMonitor' corriendo como SYSTEM con dos
    disparadores:
      1. Al arranque del sistema (muestra inmediata en cada boot).
      2. Cada $IntervalMinutes minutos con duración ilimitada
         (disparador Once a medianoche + repetición; con StartWhenAvailable
         retoma después de cada boot sin necesidad de trigger diario).
    La tarea ejecuta monitor-gcusers-v2.ps1, que agrega una línea por muestra
    a C:\Scripts\monitor\monitor-YYYYMMDD.csv. No requiere intervención manual:
    solo se revisa la evidencia el fin de semana.

.PARAMETER IntervalMinutes
    Minutos entre muestras (default 5).

.EXAMPLE
    .\install-gcusers-monitor.ps1

.EXAMPLE
    .\install-gcusers-monitor.ps1 -IntervalMinutes 10
#>

param(
    [int]$IntervalMinutes = 5
)

$ErrorActionPreference = 'Stop'

if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
    throw 'Debe ejecutar este script como Administrador.'
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$monitorScript = Join-Path $scriptDir 'monitor-gcusers-v2.ps1'
if (-not (Test-Path -LiteralPath $monitorScript)) {
    throw "No se encuentra el script de monitoreo: $monitorScript"
}

$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$monitorScript`""
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest

# Once a medianoche + repetición cada N minutos, duración ~ilimitada.
# El repetición en PS 5.1 solo aplica al trigger -Once (no al -Daily).
# OJO: [TimeSpan]::MaxValue serializa como P99999999DT23H59M59S y el Task
# Scheduler lo rechaza (0x80041318); por eso se usa una duración amplia finita.
$triggers = @(
    (New-ScheduledTaskTrigger -AtStartup),
    (New-ScheduledTaskTrigger -Once -At (Get-Date).Date `
        -RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes) `
        -RepetitionDuration (New-TimeSpan -Days 9999))
)

$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 4) `
    -MultipleInstances IgnoreNew

Register-ScheduledTask -TaskName 'GCMonitor' `
    -Description "Monitoreo interno de gcusers-v2: muestra automatica cada $IntervalMinutes minutos (CSV diario en <script>\monitor). Corre como SYSTEM." `
    -Action $action -Trigger $triggers -Principal $principal -Settings $settings -Force | Out-Null

Start-ScheduledTask -TaskName 'GCMonitor'

Write-Host "Tarea GCMonitor instalada (muestreo cada $IntervalMinutes minutos) y primera muestra tomada."
Write-Host ''
Write-Host 'Comandos utiles:'
Write-Host "  Verificar tarea:  schtasks /Query /TN GCMonitor /V /FO LIST"
Write-Host "  Muestra manual:   schtasks /Run /TN GCMonitor"
Write-Host "  Ver CSV:          Get-Content `"$scriptDir\monitor\monitor-*.csv`" | Select-Object -Last 5"
Write-Host ''
Write-Host 'Nota: revisar la evidencia (monitor\monitor-*.csv) al final de la semana.'