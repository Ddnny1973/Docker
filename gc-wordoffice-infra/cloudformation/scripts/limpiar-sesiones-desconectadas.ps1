<#
.SYNOPSIS
    Cierra sesiones RDS desconectadas (estado Disc) que llevan mas de N minutos
    de inactividad. Diseñado para correr como tarea programada (SYSTEM).

.DESCRIPTION
    Detecta via `query user` las sesiones de tipo rdp-tcp* en estado Disc (el
    usuario se desconectó pero la sesión quedó viva consumiendo memoria) y las
    cierra con `logoff`. Usa el tiempo de inactividad como criterio: solo toca
    sesiones Disc con mas de $IdleMinutes de inactividad. Nunca cierra sesiones
    activas, ni la consola ni las de sistema.

    Objetivo: liberar la memoria que ocupan las sesiones abandonadas y poder
    medir el efecto (la columna ses_disc del monitor muestra el antes/después).

.PARAMETER IdleMinutes
    Minutos de inactividad minimos para considerar la sesion desconectada
    (default 30).

.PARAMETER LogDir
    Carpeta del log (default 'log' dentro de la carpeta del script).

.PARAMETER WhatIf
    Solo muestra lo que cerraria, sin ejecutar logoff.

.EXAMPLE
    .\limpiar-sesiones-desconectadas.ps1

.EXAMPLE
    .\limpiar-sesiones-desconectadas.ps1 -IdleMinutes 15 -WhatIf
#>

param(
    [int]$IdleMinutes = 30,
    [string]$LogDir = '',
    [switch]$WhatIf
)

$ErrorActionPreference = 'Continue'

if (-not $LogDir) {
    $LogDir = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'log'
}
if (-not (Test-Path -LiteralPath $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

function Convert-Idle {
    param([string]$s)
    # Formatos: "." (menos de 1 min), "22:05" (hh:mm), "1+12:05" (dias+hh:mm)
    if (-not $s -or $s -eq '.') { return 0 }
    if ($s -match '^(\d+)\+(\d+):(\d+)$') {
        return [int]$matches[1] * 1440 + [int]$matches[2] * 60 + [int]$matches[3]
    }
    if ($s -match '^(\d+):(\d+)$') {
        return [int]$matches[1] * 60 + [int]$matches[2]
    }
    return 0
}

$ahora = Get-Date
$sesiones = @()

foreach ($line in (& query.exe user 2>$null)) {
    $t = $line.Trim().TrimStart('>')
    if (-not $t -or $t -match '^USERNAME') { continue }
    $cols = $t -split '\s+'
    if ($cols.Count -lt 5) { continue }
    $session = $cols[1]
    $id      = $cols[2]
    $state   = $cols[3]
    $idleMin = Convert-Idle $cols[4]
    $username = $cols[0]

    if ($session -notmatch '(?i)^rdp-tcp') { continue }   # solo sesiones RDP de usuarios
    if ($state -ne 'Disc') { continue }                    # solo desconectadas
    if ($idleMin -lt $IdleMinutes) { continue }            # solo las realmente abandonadas

    $sesiones += [pscustomobject]@{
        Session  = $session
        Id       = $id
        User     = $username
        IdleMin  = $idleMin
        State    = $state
    }
}

$log = Join-Path $LogDir ('limpiar-sesiones-{0:yyyyMMdd}.log' -f $ahora)
if ($sesiones.Count -eq 0) {
    return
}

foreach ($s in $sesiones) {
    $msg = '{0:yyyy-MM-dd HH:mm:ss} | CERRANDO {1} (usuario {2}, sesion {3}, idle {4} min, estado {5})' -f $ahora, $s.Session, $s.User, $s.Id, $s.IdleMin, $s.State
    if ($WhatIf) {
        $msg += ' [SIMULACION]'
        Add-Content -LiteralPath $log -Value $msg -Encoding UTF8
        Write-Host $msg
        continue
    }
    & logoff.exe $s.Id 2>$null
    if ($LASTEXITCODE -eq 0) {
        Add-Content -LiteralPath $log -Value "$msg OK" -Encoding UTF8
        Write-Host "$msg OK"
    } else {
        Add-Content -LiteralPath $log -Value "$msg FALLO (codigo $LASTEXITCODE)" -Encoding UTF8
        Write-Host "$msg FALLO (codigo $LASTEXITCODE)"
    }
}