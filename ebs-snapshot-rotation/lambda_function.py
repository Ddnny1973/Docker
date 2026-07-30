"""
Rotación diaria de snapshots EBS (Lunes-Sábado), por instancia.

Reglas:
- Instancia "BD" (gcdatos-v2-r): snapshot todos los días que corre esta
  función (Lun-Sáb) de TODOS sus volúmenes, sobrescribiendo (borrando) el
  snapshot "daily" anterior. Además, los Sábados se crea/sobrescribe un
  snapshot "weekly" independiente que persiste toda la semana.
- Instancia "Users" (gcusers-v2): solo se le crea snapshot los Sábados,
  sobrescribiendo el snapshot "weekly" de la semana anterior.

No se necesitan llaves de acceso: la función corre con un rol de IAM
(Lambda execution role) con permisos mínimos sobre EC2 (ver template.yaml).

Configuración vía variables de entorno de la Lambda:
- BD_INSTANCE_ID       (obligatorio)  -> ej. i-0e04b97a8d5031545
- USERS_INSTANCE_ID    (opcional)     -> ej. i-04d6abcd755fe89b5
- REGION               (default us-east-2)
"""

import os
import logging
from datetime import datetime, timezone

import boto3

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger()

REGION = os.environ.get("REGION", "us-east-2")
BD_INSTANCE_ID = os.environ.get("BD_INSTANCE_ID")
USERS_INSTANCE_ID = os.environ.get("USERS_INSTANCE_ID")

MANAGED_BY_TAG = "snapshot-rotation-lambda"


def _ec2():
    return boto3.client("ec2", region_name=REGION)


def _weekday_hoy():
    """0=Lunes ... 5=Sábado, 6=Domingo (hora UTC)."""
    return datetime.now(timezone.utc).weekday()


def _volumenes_de_instancia(ec2, instance_id: str):
    """Devuelve los volume-id de todos los discos EBS adjuntos a la instancia."""
    if not instance_id:
        return []
    resp = ec2.describe_instances(InstanceIds=[instance_id])
    volumenes = []
    for reserva in resp["Reservations"]:
        for instancia in reserva["Instances"]:
            for bdm in instancia.get("BlockDeviceMappings", []):
                ebs = bdm.get("Ebs")
                if ebs:
                    volumenes.append(ebs["VolumeId"])
    return volumenes


def _snapshots_previos(ec2, volume_id: str, rotation_type: str):
    """Devuelve los snapshot-ids existentes (propios) para ese volumen y tipo."""
    resp = ec2.describe_snapshots(
        OwnerIds=["self"],
        Filters=[
            {"Name": "volume-id", "Values": [volume_id]},
            {"Name": "tag:ManagedBy", "Values": [MANAGED_BY_TAG]},
            {"Name": "tag:RotationType", "Values": [rotation_type]},
        ],
    )
    return [s["SnapshotId"] for s in resp["Snapshots"]]


def _crear_snapshot(ec2, volume_id: str, rotation_type: str, role: str):
    hoy_str = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    descripcion = f"{role}-{rotation_type} rotation {hoy_str}"
    resp = ec2.create_snapshot(
        VolumeId=volume_id,
        Description=descripcion,
        TagSpecifications=[
            {
                "ResourceType": "snapshot",
                "Tags": [
                    {"Key": "Name", "Value": f"{role}-{rotation_type}"},
                    {"Key": "ManagedBy", "Value": MANAGED_BY_TAG},
                    {"Key": "RotationType", "Value": rotation_type},
                    {"Key": "VolumeRole", "Value": role},
                    {"Key": "CreatedDate", "Value": hoy_str},
                ],
            }
        ],
    )
    logger.info("Snapshot creado: %s (%s / %s)", resp["SnapshotId"], role, rotation_type)
    return resp["SnapshotId"]


def _rotar(ec2, volume_id: str, rotation_type: str, role: str):
    """Crea un snapshot nuevo y borra los anteriores del mismo tipo/volumen."""
    anteriores = _snapshots_previos(ec2, volume_id, rotation_type)
    nuevo_id = _crear_snapshot(ec2, volume_id, rotation_type, role)

    for snap_id in anteriores:
        try:
            ec2.delete_snapshot(SnapshotId=snap_id)
            logger.info("Snapshot anterior borrado: %s", snap_id)
        except Exception as exc:  # noqa: BLE001
            logger.warning("No se pudo borrar snapshot %s: %s", snap_id, exc)

    return nuevo_id


def _rotar_instancia(ec2, instance_id: str, rotation_type: str, role: str):
    """Rota el snapshot de todos los volúmenes adjuntos a una instancia."""
    if not instance_id:
        logger.info("Instancia '%s' no configurada, se omite.", role)
        return []

    volumenes = _volumenes_de_instancia(ec2, instance_id)
    if not volumenes:
        logger.warning("La instancia %s (%s) no tiene volúmenes EBS adjuntos.", instance_id, role)
        return []

    return [_rotar(ec2, vol, rotation_type, role) for vol in volumenes]


def handler(event, context):
    weekday = _weekday_hoy()
    es_sabado = weekday == 5
    es_domingo = weekday == 6

    if es_domingo:
        logger.info("Hoy es Domingo, no se toma ningún snapshot.")
        return {"status": "skipped", "reason": "sunday"}

    ec2 = _ec2()
    resultado = {}

    # Instancia BD: snapshot diario Lun-Sáb (rotación "daily")
    resultado["bd_daily"] = _rotar_instancia(ec2, BD_INSTANCE_ID, "daily", "bd")

    # Instancia BD: además, snapshot semanal solo los Sábados (rotación "weekly")
    if es_sabado:
        resultado["bd_weekly"] = _rotar_instancia(ec2, BD_INSTANCE_ID, "weekly", "bd")
        # Instancia Users: solo se snapshotea los Sábados
        resultado["users_weekly"] = _rotar_instancia(ec2, USERS_INSTANCE_ID, "weekly", "users")

    return {"status": "ok", "weekday": weekday, "snapshots": resultado}
