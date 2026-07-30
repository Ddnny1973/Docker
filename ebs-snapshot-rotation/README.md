# Rotación de snapshots EBS (Lun-Sáb)

Lambda que crea snapshots automáticos de los volúmenes EBS críticos, sin
guardar llaves de acceso en ningún sitio (usa un rol de IAM).

## Reglas de retención

- **Instancia BD** (`gcdatos-v2-r`, `i-0e04b97a8d5031545`): snapshot todos
  los días (Lun-Sáb) de todos sus volúmenes, sobrescribiendo (borrando) el
  del día anterior. Los sábados, además, se genera/actualiza un snapshot
  "weekly" aparte que se conserva toda la semana hasta el sábado siguiente.
- **Instancia Users** (`gcusers-v2`, `i-04d6abcd755fe89b5`): solo se
  snapshotea los sábados, sobrescribiendo el snapshot semanal anterior.
- Domingo: no corre nada.

Todo (rol IAM, permisos, función Lambda y regla de EventBridge) está
definido en [template.yaml](template.yaml). Solo hay 2 pasos manuales:
subir el código a S3 y lanzar el stack desde la consola.

## 1. Empaquetar y subir el código a S3

Usamos el bucket que ya existe `grpcntbl-backup`, en una carpeta aparte para
no mezclarlo con los backups. Desde esta carpeta:

```powershell
Compress-Archive -Path lambda_function.py -DestinationPath function.zip -Force
aws s3 cp function.zip s3://grpcntbl-backup/lambda-artifacts/snapshot-rotation/function.zip --region us-east-2
```

(Puedes hacer este `aws s3 cp` con las credenciales temporales que ya usaste antes;
solo sirve para subir el archivo, no queda nada expuesto en la Lambda).

## 2. Desplegar el stack desde la consola de CloudFormation

1. Consola AWS → CloudFormation → **Create stack** → "With new resources".
2. Sube el archivo [template.yaml](template.yaml).
3. Completa los parámetros:
   - `BDInstanceId`: `i-0e04b97a8d5031545` (gcdatos-v2-r).
   - `UsersInstanceId`: `i-04d6abcd755fe89b5` (gcusers-v2).
   - `CodeS3Bucket`: `grpcntbl-backup` (ya viene por defecto).
   - `CodeS3Key`: `lambda-artifacts/snapshot-rotation/function.zip` (ya viene por defecto).
   - `CodeS3Key`: `snapshot-rotation/function.zip` (o la ruta que usaste).
   - `ScheduleExpression`: déjalo por defecto (`cron(0 8 ? * MON-SAT *)` = 03:00 Colombia, Lun-Sáb).
4. En el paso de permisos, marca la casilla **"I acknowledge that AWS CloudFormation might create IAM resources"** (el template crea el rol de la Lambda).
5. Crear el stack. Cuando termine (estado `CREATE_COMPLETE`), la rotación ya queda activa.

## Actualizar el código después de un cambio

```powershell
Compress-Archive -Path lambda_function.py -DestinationPath function.zip -Force
aws s3 cp function.zip s3://grpcntbl-backup/lambda-artifacts/snapshot-rotation/function.zip --region us-east-2
aws lambda update-function-code --function-name snapshot-rotation --s3-bucket grpcntbl-backup --s3-key lambda-artifacts/snapshot-rotation/function.zip --region us-east-2
```

(O simplemente vuelve a subir el zip a la misma key en S3 y en la consola de
CloudFormation haz "Update stack" con el mismo template para que Lambda tome
el nuevo código).

## Notas de seguridad

- El rol puede crear snapshots de cualquier volumen de la cuenta (necesario
  porque el volume-id de cada instancia se resuelve en runtime, no se conoce
  al desplegar), pero solo puede **borrar** snapshots que él mismo etiquetó
  (`ManagedBy=snapshot-rotation-lambda`). Esto está definido dentro del
  propio `template.yaml`, no necesitas archivos de política sueltos.
- No requiere `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` guardadas en ningún
  lado para la ejecución diaria; solo usas tus credenciales temporales para
  el paso puntual de subir el zip a S3 y crear el stack.
