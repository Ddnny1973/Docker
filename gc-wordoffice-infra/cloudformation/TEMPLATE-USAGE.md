# CloudFormation Template - Uso y Limitaciones

## Propósito
Template unificado para crear/actualizar infraestructura EC2 de Wordoffice:
- **gcbdatos-v2** - Servidor de Base de Datos (Windows Server 2022, 100GB)
- **gcusers-v2** - Servidor de Usuarios RDP (Windows Server 2022, 100GB, RDS)

## Deploy Inicial
```bash
aws cloudformation create-stack \
  --stack-name gc-wordoffice-complete \
  --template-body file://gcbdatos-ec2.yaml \
  --parameters \
    ParameterKey=InstanceType,ParameterValue=t3.large \
    ParameterKey=EbsVolumeSize,ParameterValue=100
```

## Actualizaciones Permitidas
✅ **Cambio de tipo de instancia** (t3.large → t3.xlarge)
```bash
aws cloudformation update-stack \
  --stack-name gc-wordoffice-complete \
  --template-body file://gcbdatos-ec2.yaml \
  --parameters \
    ParameterKey=InstanceType,ParameterValue=t3.xlarge
```
Resultado: Detiene y reinicia ambas instancias con nuevo tipo (downtime ~5-10 min)

✅ **Cambio de tamaño EBS** (100GB → 200GB)
```bash
aws cloudformation update-stack \
  --stack-name gc-wordoffice-complete \
  --template-body file://gcbdatos-ec2.yaml \
  --parameters \
    ParameterKey=EbsVolumeSize,ParameterValue=200
```
Resultado: Amplía volumen (online, sin downtime)

## Limitaciones

⚠️ **UserData NO se re-ejecuta en updates**
- Solo se ejecuta en el primer launch de la instancia
- Cambios manuales en SO son persistentes
- Ejemplo: Si instalas software manualmente en gcusers-v2, persiste en updates

⚠️ **DisableApiTermination: true**
- Bloquea accidental deletion de instancias
- Pero también bloquea cambios que requieran recreación (ej: cambiar AMI, UserData)
- Previene actualizaciones descontroladas

## Cambios Manuales Documentar
Cualquier cambio manual en servidores debe registrarse aquí:

### gcbdatos-v2
- CloudWatch Agent ✅ (automático)
- Cargas SQL/configuración BD → **Manual**

### gcusers-v2
- CloudWatch Agent + RDS ✅ (automático)
- Usuarios locales (19 usuarios) → **Manual** (Fase 2)
- Cambios RDS/licencias → **Manual después del deploy**

## Workflow Recomendado

1. **Deploy inicial** → Crea ambas instancias
2. **Configuraciones post-deploy**:
   - gcbdatos-v2: Restaurar BD, aplicar patches
   - gcusers-v2: Crear usuarios, validar RDS (Fase 2-3)
3. **Cambios futuros de infraestructura** → Update stack (tipo instancia, EBS)
4. **Cambios SO** → Manual en servidor (persisten en updates)

## Referencias
- Documentación migración: [Migración servidor de usuarios.md](../docs/Migración%20servidor%20de%20usuarios.md)
- Requerimientos: [requerimientos-servidor.txt](../docs/requerimientos-servidor.txt)
