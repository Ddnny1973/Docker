<#
.SYNOPSIS
    Resetea el período de gracia de licencia RDS (120 días) en un RD Session Host.

.DESCRIPTION
    Borra la "time bomb" L$RTMTIMEBOMB bajo
    HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\RCM\GracePeriod.
    Esa clave está protegida incluso contra Administrators: solo SYSTEM puede
    borrarla. Si el script se lanza como admin normal, se auto-relanza vía una
    tarea programada temporal que corre como SYSTEM.

    Tras borrar la clave reinicia TermService para que se regenere el contador
    de 120 días. Verifica el resultado y avisa si aún hace falta reiniciar el
    servidor (el arranque de cada mañana lo completa).

    No existe un tope de resets: se puede repetir indefinidamente. Cada reset
    devuelve exactamente 120 días (el período no es configurable).

.PARAMETER Check
    Solo muestra los días restantes de gracia y termina (no modifica nada).

.PARAMETER Force
    Fuerza el reset aunque queden más de $Threshold días.

.PARAMETER Threshold
    Días restantes por debajo de los cuales se dispara el reset (default 30).

.PARAMETER LogDir
    Carpeta del archivo de log (default: la subcarpeta `log` junto al script).

.EXAMPLE
    .\reset-rds-grace-period.ps1 -Check

.EXAMPLE
    .\reset-rds-grace-period.ps1 -Force
#>

param(
    [switch]$Check,
    [switch]$Force,
    [int]$Threshold = 30,
    [string]$LogDir = ''
)

$ErrorActionPreference = 'Stop'
if (-not $LogDir) { $LogDir = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'log' }
$logFile = Join-Path $LogDir 'rds-grace-period.log'
$gracePath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\RCM\GracePeriod'

function Write-Log {
    param([string]$Msg)
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Msg"
    try {
        if (-not (Test-Path -LiteralPath $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
        Add-Content -LiteralPath $logFile -Value $line
    } catch { }
    Write-Host $line
}

function Get-GraceDays {
    $ts = Get-CimInstance -Namespace 'root/CIMV2/TerminalServices' -ClassName 'Win32_TerminalServiceSetting'
    $r = Invoke-CimMethod -InputObject $ts -MethodName 'GetGracePeriodDays'
    return [int]$r.DaysLeft
}

# --- Auto-elevación a SYSTEM (la clave GracePeriod bloquea a Administrators) ---
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
if ($identity.Name -ne 'NT AUTHORITY\SYSTEM') {
    $me = $MyInvocation.MyCommand.Path
    if (-not $me) { throw 'No se pudo resolver la ruta de este script.' }

    $arg = "-NoProfile -ExecutionPolicy Bypass -File `"$me`""
    if ($Check) { $arg += ' -Check' }
    if ($Force) { $arg += ' -Force' }
    $arg += " -Threshold $Threshold"

    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arg
    $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    Register-ScheduledTask -TaskName 'gcw_rds_grace_temp' -Action $action -Principal $principal -Force | Out-Null
    Start-ScheduledTask -TaskName 'gcw_rds_grace_temp'
    Start-Sleep -Seconds 4
    Unregister-ScheduledTask -TaskName 'gcw_rds_grace_temp' -Confirm:$false

    Write-Host "Re-ejecutado como SYSTEM. Detalle en $logFile"
    exit 0
}

# --- Modo check ---
try { $daysLeft = Get-GraceDays } catch { Write-Log "ERROR leyendo días de gracia: $_"; exit 1 }
if ($Check) { Write-Log "Días restantes de gracia RDS: $daysLeft"; exit 0 }

if (-not $Force -and $daysLeft -gt $Threshold) {
    Write-Log "Sin acción: quedan $daysLeft días (umbral $Threshold)."
    exit 0
}

Write-Log "Iniciando reset (días restantes: $daysLeft, umbral: $Threshold, Force: $Force)"

# --- Borrar la time bomb de gracia ---
$deleted = $false
try {
    if (Test-Path -LiteralPath $gracePath) {
        Remove-Item -LiteralPath $gracePath -Recurse -Force -ErrorAction Stop
        $deleted = $true
        Write-Log 'Clave GracePeriod eliminada.'
    } else {
        Write-Log 'Clave GracePeriod no encontrada (ya reseteada o sin gracia activa).'
    }
} catch {
    Write-Log "Fallo borrando directamente: $($_.Exception.Message)"
    try {
        # Plan B: tomar ownership + FullControl vía ACL del registro y borrar
        $regPath = 'SYSTEM\CurrentControlSet\Control\Terminal Server\RCM\GracePeriod'
        $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($regPath, [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree, [System.Security.AccessControl.RegistryRights]::TakeOwnership)
        if ($key) {
            $acl = $key.GetAccessControl([System.Security.AccessControl.AccessControlSections]::None)
            $acl.SetOwner([System.Security.Principal.NTAccount]'Administrators')
            $key.SetAccessControl($acl)
            $key.Close()

            $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($regPath, [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree, [System.Security.AccessControl.RegistryRights]::ChangePermissions)
            $acl = $key.GetAccessControl()
            $rule = New-Object System.Security.AccessControl.RegistryAccessRule('Administrators', 'FullControl', 'Allow')
            $acl.SetAccessRule($rule)
            $key.SetAccessControl($acl)
            $key.Close()

            [Microsoft.Win32.Registry]::LocalMachine.DeleteSubKeyTree($regPath, $false)
            $deleted = $true
            Write-Log 'Clave GracePeriod eliminada tras tomar ownership.'
        } else {
            Write-Log 'Clave GracePeriod no existe (plan B).'
        }
    } catch {
        Write-Log "Fallo definitivo borrando GracePeriod: $($_.Exception.Message)"
        exit 1
    }
}

# --- Regenerar el contador ---
try {
    Restart-Service TermService -Force -ErrorAction Stop
    Start-Sleep -Seconds 5
} catch {
    Write-Log "ERROR reiniciando TermService: $($_.Exception.Message)"
}

try { $daysNew = Get-GraceDays } catch { $daysNew = -1 }
Write-Log "Reset finalizado. Días de gracia después: $daysNew"

if ($daysNew -le $Threshold) {
    Write-Log 'ADVERTENCIA: el contador no se reinició con el reinicio de TermService. Se recomienda reiniciar el servidor (se completa en el próximo arranque, ya que el servidor se apaga de noche).'
}

exit 0
