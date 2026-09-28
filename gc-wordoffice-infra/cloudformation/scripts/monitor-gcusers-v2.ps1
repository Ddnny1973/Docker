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

    Si los contadores de rendimiento del SO no están disponibles (esas clases
    fallan con "Invalid class", como ocurre cuando la base de contadores se
    rompe), mide la CPU por diferencia del tiempo de proceso entre muestras
    consecutivas (monitor-state.json, promedio del intervalo) para que las
    columnas cpu_pct / top5_cpu nunca se queden en blanco en silencio.
#>

param(
    [string]$LogDir = '',
    [int]$RetainDays = 30
)

$ErrorActionPreference = 'Continue'   # un contador que falle no debe matar la muestra

# Suma de "ticks" de CPU de todos los procesos (agrupados por nombre).
# Usa la API de procesos de .NET (no los contadores de rendimiento del SO), por
# lo que sigue funcionando aunque Win32_PerfFormattedData_* esté roto.
function Get-TotalProcessorTicks {
    $sum = @{}
    $total = 0.0
    Get-Process -ErrorAction SilentlyContinue | ForEach-Object {
        $t = $_.TotalProcessorTime.TotalSeconds
        $total += $t
        if ($sum.ContainsKey($_.ProcessName)) { $sum[$_.ProcessName] += $t } else { $sum[$_.ProcessName] = $t }
    }
    [pscustomobject]@{ Total = $total; ByName = $sum }
}

if (-not $LogDir) {
    $LogDir = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'monitor'
}
if (-not (Test-Path -LiteralPath $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

$fecha  = Get-Date
$csv    = Join-Path $LogDir ('monitor-{0:yyyyMMdd}.csv' -f $fecha)
$header = 'timestamp;cpu_pct;mem_libre_mb;mem_total_mb;commit_pct;disk_read_s;disk_write_s;sessions_rdp;ses_disc;usuarios;top5_cpu;top5_ram'

# Estado previo y ticks actuales de los procesos (fallback de CPU por delta)
$statePath = Join-Path $LogDir 'monitor-state.json'
$statePrev = $null
if (Test-Path -LiteralPath $statePath) {
    try { $statePrev = Get-Content -LiteralPath $statePath -Raw -ErrorAction Stop | ConvertFrom-Json } catch { $statePrev = $null }
}
$curTicks  = Get-TotalProcessorTicks
$prevTs    = $null
$elapsed   = 0.0
$cores     = [Environment]::ProcessorCount
if ($statePrev -and $statePrev.PSObject.Properties.Name -contains 'ts') {
    try {
        $prevTs  = [datetime]::Parse([string]$statePrev.ts)
        $elapsed = ($fecha - $prevTs).TotalSeconds
    } catch { $prevTs = $null; $elapsed = 0.0 }
}

# CPU total (%): primero el valor CIM (instantáneo). Si los contadores están
# rotos (Win32_PerfFormattedData_* no disponibles) cae al delta de ticks entre
# la muestra anterior y esta (promedio del intervalo, desde la 2ª muestra).
$cpuPct = ''
try {
    $cpuPct = (Get-CimInstance -ClassName Win32_PerfFormattedData_PerfOS_Processor -Filter 'Name="_Total"').PercentProcessorTime
} catch {}
$cpuOk = $false
$dbl = 0.0
if ($cpuPct -ne '' -and [double]::TryParse([string]$cpuPct, [ref]$dbl)) {
    if ($dbl -ge 0 -and $dbl -le 100) { $cpuOk = $true; $cpuPct = [math]::Round($dbl, 1) }
}
if (-not $cpuOk) {
    $cpuPct = ''
    if ($statePrev -and $curTicks.Total -gt 0 -and $prevTs -and $elapsed -gt 0 -and $statePrev.PSObject.Properties.Name -contains 'totalTicks') {
        $dTotal = $curTicks.Total - [double]$statePrev.totalTicks
        if ($dTotal -gt 0) {
            $cpuPct = [math]::Min(100, [math]::Round(100.0 * $dTotal / $elapsed / $cores, 1))
        }
    }
}

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

# Sesiones RDP (activas/totales/desconectadas + nombres de usuarios activos)
$sessionsRdp = ''
$sesDisc     = 0
$usuarios   = ''
try {
    $lines = @(& query.exe session 2>$null | Where-Object { $_.Trim() })
    $total = 0; $activas = 0; $disc = 0; $nombres = @()
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
        } elseif ($state -eq 'Disc') {
            $disc++
        }
    }
    $sessionsRdp = "$activas/$total"
    $sesDisc     = $disc
    $usuarios = ($nombres -join '|')
} catch { $sessionsRdp = ''; $sesDisc = 0; $usuarios = '' }

# Top-5 procesos por CPU (vía CIM para funcionar en servidores localizados)
$top5Cpu = ''
try {
    $procs = Get-CimInstance -ClassName Win32_PerfFormattedData_PerfProc_Process |
        Where-Object { $_.Name -notin @('_Total', '_Idle', 'Idle') -and $_.PercentProcessorTime -gt 0 } |
        Sort-Object -Property PercentProcessorTime -Descending |
        Select-Object -First 5
    $top5Cpu = (($procs | ForEach-Object { '{0}:{1:N0}%' -f $_.Name, $_.PercentProcessorTime }) -join '|')
} catch { $top5Cpu = '' }

# Fallback del top-5 por CPU: delta de ticks entre muestras (si CIM no aplica)
if (-not $top5Cpu -and $statePrev -and $prevTs -and $elapsed -gt 0 -and $statePrev.PSObject.Properties.Name -contains 'procs') {
    $items = @()
    foreach ($p in $statePrev.procs.PSObject.Properties) {
        if ($curTicks.ByName.ContainsKey($p.Name)) {
            $d = $curTicks.ByName[$p.Name] - [double]$p.Value
            if ($d -gt 0) {
                $pp = [math]::Min(100, [math]::Round(100.0 * $d / $elapsed / $cores, 1))
                if ($pp -gt 0) { $items += [pscustomobject]@{ Name = $p.Name; Pct = $pp } }
            }
        }
    }
    $top5Cpu = (($items | Sort-Object Pct -Descending | Select-Object -First 5 | ForEach-Object { '{0}:{1:N0}%' -f $_.Name, $_.Pct }) -join '|')
}

# Top-5 procesos por RAM (working set)
$top5Ram = ''
try {
    $procs = Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 5
    $top5Ram = (($procs | ForEach-Object { '{0}:{1:N0}MB' -f $_.ProcessName, ($_.WorkingSet64 / 1MB) }) -join '|')
} catch { $top5Ram = '' }

# Estado para los deltas de la siguiente muestra (también capturado cuando CIM
# funciona, para que el fallback esté siempre disponible)
try {
    $state = [pscustomobject]@{ ts = $fecha.ToString('o'); totalTicks = $curTicks.Total; procs = $curTicks.ByName }
    $state | ConvertTo-Json -Depth 4 -Compress | Set-Content -LiteralPath $statePath -Encoding UTF8
} catch {}

$fields = @(
    $fecha.ToString('yyyy-MM-dd HH:mm:ss'),
    ("{0:N1}" -f $cpuPct),
    $memLibre,
    $memTotal,
    ("{0:N1}" -f $commitPct),
    $diskRead,
    $diskWrite,
    $sessionsRdp,
    $sesDisc,
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