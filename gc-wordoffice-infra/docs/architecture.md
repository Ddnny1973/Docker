# Arquitectura - Grupo Contable Wordoffice Infrastructure

## 1. Contexto General

**Proyecto:** Migración de infraestructura Wordoffice en AWS  
**Cliente:** Grupo Contable (pequeña firma contable)  
**Fecha:** Abril 2026  
**Objetivo:** Optimizar costos manteniendo estabilidad operacional  

---

## 2. Arquitectura Actual

### 2.1 Topología
```
┌─────────────────────────────────────────────────────────────┐
│                    USUARIOS (RDP)                           │
│            Conectan vía IP Elástica                          │
│            Lunes-Viernes: 7am-5/6pm                         │
│            Sábados: Medio día (7am-1pm)                     │
└────────────────────────┬────────────────────────────────────┘
                         │
                         │
          ┌──────────────┴──────────────┐
          │                             │
    ┌─────▼──────┐             ┌──────▼─────┐
    │  gcusers   │             │ gcbdatos   │
    │            │             │            │
    │ Windows    │             │ Windows    │
    │ Server     │             │ Server     │
    │ (antiguo)  │             │ (antiguo)  │
    │            │             │            │
    │ Cliente    │             │ SQL Server │
    │ Wordoffice │─────────────│ Community  │
    │ RDP Server │   Red VPC   │ Wordoffice │
    │            │             │ Server     │
    │ t3.xlarge  │             │ t3.xlarge  │
    │ 32GB RAM   │             │ 32GB RAM   │
    └────────────┘             └────────────┘
```

### 2.2 Detalles Instancia gcbdatos (Servidor de Base de Datos)

| Aspecto | Valor |
|--------|-------|
| Nombre | gcbdatos (i-047ee523d5d8) |
| Tipo Instancia | t3.xlarge (4 vCPU, 32 GB RAM) |
| SO | Windows Server (antiguo) |
| Base de Datos | SQL Server Community Edition |
| Aplicación | Wordoffice Server |
| Estado Operacional | Activa (horario laboral) |
| Almacenamiento EBS | ~50-100GB |

### 2.3 Detalles Instancia gcusers (Servidor de Usuarios)

| Aspecto | Valor |
|--------|-------|
| Nombre | gcusers (i-020129531c07d9a106) |
| Tipo Instancia | t3.xlarge (4 vCPU, 32 GB RAM) |
| SO | Windows Server (antiguo) |
| Aplicación | Cliente Wordoffice + RDP Server |
| Usuarios Simultáneos | ~3-5 típicos |
| Estado Operacional | Activa (horario laboral) |
| Acceso | IP Elástica asociada |

### 2.4 Horario de Operación
```
Lunes a Viernes:  7:00 AM - 5:00/6:00 PM (10 horas/día)
Sábados:          7:00 AM - 1:00 PM (6 horas)
Domingos:         Apagadas

Total Semanal:    ~56 horas de 168 posibles = 33% de operación
Encendido/Apagado: Automático
```

### 2.5 Costos Actuales

**Basado en Cost Explorer (Marzo 2026):**
```
EC2 Instances (compute):    $131.41 USD/mes
EC2 Others (almacenamiento):$31.51 USD/mes
VPC:                        $5.16 USD/mes
Systems Manager:            $0.64 USD/mes
Otros:                      $0.03 USD/mes
───────────────────────────────────────
TOTAL MENSUAL:              $168.75 USD
TOTAL ANUAL:                $2,025 USD

Promedio último 6 meses:    $169.41 USD/mes
```

### 2.6 Análisis CloudWatch - Últimos 90 Días

#### gcbdatos (Servidor BD)
```
CPU Utilization:
  - Máximo:    47.5%
  - Promedio:  5-10%
  - Patrón:    Picos ocasionales, mayormente idle

Network:
  - In:        ~39-78 MB típico (saludable)
  - Out:       ~889 MB - 1.7 GB (normal)

CPU Credits:
  - Saldo:     ~2.3K (abundantes, nunca se agotan)
  - Conclusión: Severamente sobredimensionado
```

#### gcusers (Servidor Usuarios RDP)
```
CPU Utilization:
  - Máximo:    44.1%
  - Promedio:  10-15%
  - Patrón:    Más activo que BD, aún muy bajo

Network:
  - In:        ~34-69 MB típico
  - Out:       ~9-18 MB (muy bajo)

CPU Credits:
  - Saldo:     ~2.3K (abundantes incluso en picos)
  - Conclusión: Sobredimensionado
```

### 2.7 Limitaciones Actuales

⚠️ **Datos de Memoria Faltantes:**
- CloudWatch básico NO captura RAM en Windows automáticamente
- Necesario instalar CloudWatch Agent para obtener uso real de memoria
- Crítico para confirmar que t3.large (8GB) es suficiente

---

## 3. Arquitectura Propuesta

### 3.1 Cambios Principales
```
ANTES (Actual):
┌──────────────────────────────────────────┐
│ 2 × t3.xlarge (4 vCPU, 32 GB c/u)       │
│ Costo: $168.75/mes                       │
│ Operación: 33% del tiempo (horario lab)  │
└──────────────────────────────────────────┘

DESPUÉS (Propuesto):
┌──────────────────────────────────────────┐
│ 2 × t3.large (2 vCPU, 8 GB c/u)          │
│ Costo: ~$108/mes (estimado)              │
│ Ahorro: ~$60/mes = $720/año              │
│ Operación: Misma (horario laboral)       │
└──────────────────────────────────────────┘
```

### 3.2 Nueva Topología

Idéntica a actual en estructura, pero con instancias optimizadas:
```
┌─────────────────────────────────────────────────────────────┐
│                    USUARIOS (RDP)                           │
│            Conectan vía IP Elástica (misma)                 │
│            Lunes-Viernes: 7am-5/6pm                         │
└────────────────────────┬────────────────────────────────────┘
                         │
          ┌──────────────┴──────────────┐
          │                             │
    ┌─────▼──────┐             ┌──────▼─────┐
    │ gcusers-v2 │             │gcbdatos-v2 │
    │            │             │            │
    │ Windows    │             │ Windows    │
    │ Server     │             │ Server     │
    │ 2022       │             │ 2022       │
    │            │             │            │
    │ Cliente    │             │ SQL Server │
    │ Wordoffice │─────────────│ Community  │
    │ RDP Server │   Red VPC   │ Wordoffice │
    │            │             │ Server     │
    │ t3.large   │             │ t3.large   │
    │ 8GB RAM    │             │ 8GB RAM    │
    │ 2 vCPU     │             │ 2 vCPU     │
    └────────────┘             └────────────┘
    
    CloudWatch Agent instalado en ambas
    (monitoreo RAM, CPU, Disk, Processes)
```

### 3.3 Justificación del Cambio

| Métrica | Actual | Propuesto | Razón |
|---------|--------|-----------|-------|
| CPU Max | 47.5% (BD), 44.1% (Users) | Cómodo en t3.large | CloudWatch mostró subutilización |
| vCPU | 4 c/instancia | 2 c/instancia | Suficiente para cargas observadas |
| RAM | 32 GB c/instancia | 8 GB c/instancia | **Pendiente validar con datos reales** |
| Costo Mensual | $168.75 | ~$108 | Ahorro de $60-65/mes |
| Horario Op. | 33% del tiempo | 33% del tiempo | Sin cambios operacionales |

### 3.4 Riesgos y Mitigación

| Riesgo | Probabilidad | Impacto | Mitigación |
|--------|--------------|---------|-----------|
| RAM insuficiente en t3.large (8GB) | Media | Alto | Instalar CloudWatch Agent PRIMERO (esta fase) |
| Lentitud en BD después cambio | Baja (CPU muestra margen) | Medio | Rollback en 10 min (snapshot disponible) |
| SQL Server requiere >8GB | Baja (promedio usa poco) | Alto | Monitoreo 1 semana con agente + datos históricos |

---

## 4. Fases de Implementación

### Fase 1: Validación de Memoria (Esta Semana)

**Entrada:**
- CloudWatch Agent instalado en gcbdatos actual
- Monitoreo 1 semana (capturar patrón laboral típico)
- Recolectar datos: RAM máx, promedio, mín
- Identificar picos (si hay)

**Salida:**
- Confirmación si 8GB es suficiente o necesita más
- Datos reales para decisión final

### Fase 2: Preparación IaC (Próxima)

**Entrada:**
- Datos de memoria validados
- CloudFormation template para gcbdatos-v2 (t3.large o ajustado)

**Salida:**
- Template deployable
- Documentación de parámetros

### Fase 3: Crear Nueva Instancia

**Entrada:**
- Template CloudFormation listo
- Decision final sobre tipo de instancia

**Salida:**
- gcbdatos-v2 creada con:
  - SQL Server 2019 Community
  - Wordoffice Server
  - CloudWatch Agent activo
  - BD restaurada desde snapshot

### Fase 4: Validar y Cutover

**Entrada:**
- gcbdatos-v2 estable 48h

**Salida:**
- Migración de datos completada
- IP asociada (si es necesario)
- gcbdatos antiguo como backup 2 semanas

---

## 5. Decisiones de Arquitectura

### 5.1 Por qué CloudFormation (IaC)

✅ **Ventajas:**
- Cambiar tipo de instancia = 1 línea código
- Reproducible si falla
- Versionable en Git
- Automático (menos errores manuales)
- Documentación código = documentación viva

❌ **Alternativa (Console):**
- Cambiar tipo = detener/modificar/esperar (30 min)
- Manual y propenso a errores
- Sin documentación clara

### 5.2 Por qué t3.large Inicial

✅ **Datos:**
- CPU máximo 47.5% = cómodo en t3.large (2 vCPU)
- CPU credits abundantes (nunca se agotan)
- Horario laboral = 33% operación (no 24/7)

⚠️ **Pendiente:**
- Validar RAM con CloudWatch Agent
- Si datos muestran <6GB promedio → t3.large OK
- Si datos muestran >8GB máximo → reconsidera t3.xlarge

### 5.3 Por qué Windows Server 2022

✅ **Razones:**
- Último LTS disponible
- Soporte extendido (hasta 2026+)
- Compatible con SQL Server 2019 Community
- Compatible con Wordoffice

---

## 6. Monitoreo Post-Implementación

### 6.1 Métricas Clave (CloudWatch Agent)
```
- Memory Available (GB)
- Memory % Utilization
- Disk Free Space (%)
- CPU User Time (%)
- Process: sqlservr.exe (RAM)
- Process: Wordoffice Server (RAM)
```

### 6.2 Alertas Recomendadas

- ⚠️ RAM disponible < 1 GB
- ⚠️ CPU sostenido > 70%
- ⚠️ Disk < 10% libre
- ✅ Alertas enviadas a CloudWatch SNS topic

---

## 7. Próximos Pasos

### Inmediato (Esta semana)

1. ✅ Autorización CloudWatch Agent (confirmada)
2. ⏳ Instalar agente en gcbdatos actual
3. ⏳ Monitorear 1 semana completa
4. ⏳ Recolectar datos de RAM

### Próxima semana

1. ⏳ Análisis datos de memoria
2. ⏳ Crear CloudFormation template (gc-wordoffice-infra repo)
3. ⏳ Validar template (dry-run)

### Semana 3

1. ⏳ Deploy gcbdatos-v2
2. ⏳ Instalar SQL Server + Wordoffice
3. ⏳ Restaurar BD

### Semana 4

1. ⏳ Validación 48h
2. ⏳ Cutover (migración datos)
3. ⏳ Monitoreo intensivo

---

## 8. Referencias

- **CloudWatch Data:** Cost Explorer, marzo 2026
- **Wordoffice Docs:** Requisitos SO Windows Server 2008 R2+
- **AWS Sizing:** t3.large = 2 vCPU, 8 GB; t3.xlarge = 4 vCPU, 16 GB
- **Migration Plan:** Documento separado (docs/migration-plan.md)
- **Costs:** Documento separado (docs/costs-analysis.md)

---

**Autor:** [Tu nombre]  
**Última actualización:** Abril 2026  
**Estado:** En progreso - Fase 1 (Validación Memoria)