# reset-rds-grace-period.ps1

Write-Host "=== RDS Grace Period Reset Script ===" -ForegroundColor Green
Write-Host "Este script reseteará el período de gracia de RDS (otros 120 días)" -ForegroundColor Yellow

# Verificar si es admin
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "ERROR: Debe ejecutar como Administrador" -ForegroundColor Red
    Exit 1
}

# Paso 1: Verificar clave actual
Write-Host "`nVerificando clave GracePeriod..." -ForegroundColor Cyan
$gracePeriod = reg query "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\RCM\GracePeriod" 2>$null

if ($gracePeriod) {
    Write-Host "Clave GracePeriod encontrada" -ForegroundColor Green
} else {
    Write-Host "Clave GracePeriod no encontrada" -ForegroundColor Yellow
}

# Paso 2: Tomar ownership
Write-Host "`nTomando ownership de GracePeriod..." -ForegroundColor Cyan
takeown /F "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\RCM\GracePeriod" /A | Out-Null

if ($LASTEXITCODE -eq 0) {
    Write-Host "Ownership tomado exitosamente" -ForegroundColor Green
} else {
    Write-Host "Error al tomar ownership" -ForegroundColor Red
    Exit 1
}

# Paso 3: Otorgar permisos
Write-Host "`nOtorgando permisos..." -ForegroundColor Cyan
icacls "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\RCM\GracePeriod" /grant:r "Administrators:F" | Out-Null

# Paso 4: Eliminar clave
Write-Host "`nEliminando clave GracePeriod..." -ForegroundColor Cyan
reg delete "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\RCM\GracePeriod" /f

if ($LASTEXITCODE -eq 0) {
    Write-Host "Clave eliminada exitosamente" -ForegroundColor Green
} else {
    Write-Host "Error al eliminar clave" -ForegroundColor Red
    Exit 1
}

# Paso 5: Reiniciar servicio RDS
Write-Host "`nReiniciando servicio TermService..." -ForegroundColor Cyan
Restart-Service TermService -Force

Write-Host "`nScript completado exitosamente" -ForegroundColor Green
Write-Host "El período de gracia ha sido reseteado por 120 días más" -ForegroundColor Green
Write-Host "`nReiniciando servidor en 30 segundos..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

Write-Host "Reiniciando ahora..." -ForegroundColor Red
Restart-Computer -Force