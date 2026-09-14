<#
.SYNOPSIS
    Monitoreo interno de gcusers-v2: muestrea el estado del servidor y lo
    agrega a un CSV diario (diseñado para correr como tarea programada SYSTEM).

.DESCRIPTION
    Captura en cada ejecución: CPU total, memoria libre/total, uso de commit
    (pagefile), latencia de disco (Avg. Disk sec/Read y /Write), número de
    sesiones RDP y top-5 de procesos por CPU y por RAM. Agrega una línea al CSV
    diario. No requiere intervención manual: install-gcusers-monitor.ps1 lo
    programa cada 5 minutos mientras el servidor esté encendido.

    El objetivo es dejar evidencia histórica interna (sin CloudWatch) durante
    los días hábiles, para correlacionar reportes de lentitud con el estado
    del servidor en ese momento y ver qué proceso dispara la CPU o la RAM.

.PARAMETER LogDir
    Carpeta de los CSV (default: 'monitor' dentro de la carpeta del script;
    p. ej. C:\Scripts\monitor\). Se crea sola.

.PARAMETER RetainDays
    Días de retención de los CSV (default 30). Los archivos más viejos se
    borran automáticamente en cada ejecución.

.EXAMPLE
    .\monitor-gcusers-v2.ps1

.EXAMPLE
    .\monitor-gcusers-v2.ps1 -LogDir D:\monitor -RetainDays 7
.NOTES
    Usa clases WMI/CIM (Win32_PerfFormattedData_*) en lugar de Get-Counter
    para que funcione igual en Windows Server en español (los nombres de
    contador en inglés no resuelven en instalaciones localizadas).
#>

param(
    [string]$LogDir = '',
    [int]$RetainDays = 30
)

$ErrorActionPreference = 'Continue'   # un contador que falle no debe matar la muestra

if (-not $LogDir) {
    $LogDir = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'monitor'
}
if (-not (Test-Path -LiteralPath $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

$fecha  = Get-Date
$csv    = Join-Path $LogDir ('monitor-{0:yyyyMMdd}.csv' -f $fecha)
$header = 'timestamp;cpu_pct;mem_libre_mb;mem_total_mb;commit_pct;disk_read_s;disk_write_s;sessions_rdp;usuarios;top5_cpu;top5_ram'

# CPU total (%)
$cpuPct = ''
try {
    $cpuPct = (Get-CimInstance -ClassName Win32_PerfFormattedData_PerfOS_Processor -Filter 'Name="_Total"').PercentProcessorTime
} catch {}

# Memoria libre / total (MB)
$memLibre = $memTotal = ''
try {
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $memLibre = [int]($os.FreePhysicalMemory / 1KB)
    $memTotal = [int]($os.TotalVisibleMemorySize / 1KB)
} catch {}

# Commit / pagefile usado (%)
$commitPct = ''
try {
    $mem = Get-CimInstance -ClassName Win32_PerfFormattedData_PerfOS_Memory
    if ($mem.CommitLimit -gt 0) {
        $commitPct = 100.0 * $mem.CommittedBytes / $mem.CommitLimit
    }
} catch {}

# Latencia de disco (segundos por operación)
$diskRead  = ''
$diskWrite = ''
try {
    $disk = Get-CimInstance -ClassName Win32_PerfFormattedData_PerfDisk_PhysicalDisk -Filter 'Name="_Total"'
    $diskRead  = $disk.AvgDiskSecPerRead
    $diskWrite = $disk.AvgDiskSecPerWrite
} catch {}

# Sesiones RDP (activas/totales + nombres de usuarios activos)
$sessionsRdp = ''
$usuarios   = ''
try {
    $lines = @(& query.exe session 2>$null | Where-Object { $_.Trim() })
    $total = 0; $activas = 0; $nombres = @()
    foreach ($line in ($lines | Select-Object -Skip 1)) {
        $parts = ($line.Trim().TrimStart('>')) -split '\s{2,}'
        if ($parts.Count -lt 2) { continue }
        $total++
        $username = ''
        if ($parts.Count -ge 3 -and $parts[1] -notmatch '^\d+$') { $username = $parts[1] }
        $state = ($parts | Where-Object { $_ -in @('Active', 'Conn', 'Disc', 'Listen') } | Select-Object -First 1)
        if ($state -eq 'Active') {
            $activas++
            if ($username) { $nombres += $username }
        }
    }
    $sessionsRdp = "$activas/$total"
    $usuarios = ($nombres -join '|')
} catch { $sessionsRdp = ''; $usuarios = '' }

# Top-5 procesos por CPU (vía CIM para funcionar en servidores localizados)
$top5Cpu = ''
try {
    $procs = Get-CimInstance -ClassName Win32_PerfFormattedData_PerfProc_Process |
        Where-Object { $_.Name -notin @('_Total', '_Idle', 'Idle') -and $_.PercentProcessorTime -gt 0 } |
        Sort-Object -Property PercentProcessorTime -Descending |
        Select-Object -First 5
    $top5Cpu = (($procs | ForEach-Object { '{0}:{1:N0}%' -f $_.Name, $_.PercentProcessorTime }) -join '|')
} catch { $top5Cpu = '' }

# Top-5 procesos por RAM (working set)
$top5Ram = ''
try {
    $procs = Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 5
    $top5Ram = (($procs | ForEach-Object { '{0}:{1:N0}MB' -f $_.ProcessName, ($_.WorkingSet64 / 1MB) }) -join '|')
} catch { $top5Ram = '' }

$fields = @(
    $fecha.ToString('yyyy-MM-dd HH:mm:ss'),
    ("{0:N1}" -f $cpuPct),
    $memLibre,
    $memTotal,
    ("{0:N1}" -f $commitPct),
    $diskRead,
    $diskWrite,
    $sessionsRdp,
    ('"{0}"' -f $usuarios),
    ('"{0}"' -f $top5Cpu),
    ('"{0}"' -f $top5Ram)
)

$line = $fields -join ';'

if (-not (Test-Path -LiteralPath $csv)) {
    Add-Content -LiteralPath $csv -Value $header -Encoding UTF8
}
Add-Content -LiteralPath $csv -Value $line -Encoding UTF8

# Retención: borra CSV diarios más viejos que $RetainDays
try {
    Get-ChildItem -LiteralPath $LogDir -Filter 'monitor-*.csv' |
        Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$RetainDays) } |
        Remove-Item -Force -ErrorAction SilentlyContinue
} catch {}