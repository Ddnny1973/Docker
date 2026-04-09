@echo off
setlocal enabledelayedexpansion

:: Obtiene la fecha actual en el formato deseado (DDMMYYYY)
for /f "tokens=1-3 delims=/" %%a in ('echo %date%') do (
    set "day=%%a"
    set "month=%%b"
    set "year=%%c"
)

:: Ajusta el formato del día y mes para asegurar que tengan dos dígitos
if 1%day% LSS 10 set "day=0%day%"
if 1%month% LSS 10 set "month=0%month%"

set "date_stamp=%day%%month%%year%"

:: Directorio de destino
set "destination_folder=C:\Users\gcadmin\OneDrive\AAwsServer\Backup\%date_stamp%"

echo destination_folder !destination_folder!

mkdir "C:\Users\gcadmin\OneDrive\AAwsServer\Backup\%date_stamp%"

:: Verifica si la carpeta de origen existe
if not exist "%destination_folder%" (
    :: Carpeta de destino no existe, se crea
    :: mkdir "%destination_folder%"
    echo La carpeta de destino ha sido creada.
)

:: Directorio de origen
set "source_folder=C:\Program Files (x86)\World Office\WO10\Backup\%date_stamp%"

echo source_folder: !source_folder!

:: Verifica si la carpeta de origen existe
if exist "%source_folder%" (
    :: Copia la carpeta de origen a la carpeta de destino usando robocopy
    robocopy "%source_folder%" "%destination_folder%" /E /COPYALL /R:3 /W:3 /ETA /LOG+:robocopy.log
    
    echo Carpeta copiada exitosamente.
    :: Borra la carpeta de origen después de la copia
    rmdir /s /q "%source_folder%"

) else (
    echo La carpeta de origen no existe.
)

