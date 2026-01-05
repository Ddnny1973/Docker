# 📚 Documentación Completa - Módulo Property Owner Association (Condominium)

## 📋 Tabla de Contenidos
1. [Información General](#información-general)
2. [Módulos Dependientes](#módulos-dependientes)
3. [Funcionalidades Principales](#funcionalidades-principales)
4. [Modelos de Datos](#modelos-de-datos)
5. [Menús y Vistas](#menús-y-vistas)
6. [Configuración](#configuración)
7. [Automatizaciones](#automatizaciones)
8. [Productos y Servicios](#productos-y-servicios)
9. [Planes Analíticos](#planes-analíticos)
10. [Seguridad y Acceso](#seguridad-y-acceso)
11. [Internacionalización](#internacionalización)
12. [Instalación y Uso](#instalación-y-uso)

---

## Información General

**Nombre:** Property Owner Association (Condominium)  
**Versión:** 1.3-community  
**Categoría:** Services (Servicios)  
**Licencia:** LGPL-3 (Open Source)  
**Autor:** Odoo S.A. (Adaptado a Community)  
**Plataforma Compatible:** Odoo 18 Community Edition

### Descripción
Módulo completo para la gestión integral de **conjuntos residenciales, condominios y co-propiedades**. Proporciona herramientas para administración de propiedades, medidores, facturación automática, gestión de tareas y control de acceso basado en roles.

---

## Módulos Dependientes

El módulo requiere los siguientes módulos base de Odoo Community (ya incluidos en la instalación):

| Módulo | Descripción |
|--------|-------------|
| **account** | Contabilidad y facturas |
| **account_analytic** | Centros de costo analíticos |
| **account_followup** | Seguimiento de pagos vencidos |
| **calendar** | Gestión de calendarios |
| **contacts** | Gestión de contactos/partners |
| **mail** | Sistema de correos y notificaciones |
| **product** | Gestión de productos/servicios |
| **project** | Gestión de proyectos y tareas |
| **sale** | Gestión de órdenes de venta |

---

## Funcionalidades Principales

### 1️⃣ Gestión de Propiedades

**Objetivo:** Registrar y clasificar todas las propiedades del conjunto residencial.

#### Características:
- ✅ Registro de **edificios/torres**
- ✅ Clasificación de propiedades (apartamento, casa, local, parqueadero, etc.)
- ✅ Asignación de **áreas comunes** (piscina, gym, salas, etc.)
- ✅ Etiquetas personalizadas para agrupar propiedades
- ✅ Información de contacto del propietario
- ✅ Estado de cada propiedad (activa, inactiva, vendida)
- ✅ Historial de transacciones por propiedad

**Menú:** Propiedades > Propiedades

---

### 2️⃣ Gestión de Medidores

**Objetivo:** Registrar y controlar consumos de servicios (agua, luz, gas).

#### Características:
- ✅ Creación de medidores por propiedad
- ✅ Registro de **lecturas periódicas** (diarias, mensuales)
- ✅ Cálculo automático de consumo
- ✅ Detección de anomalías (consumo anormal)
- ✅ Reportes de consumo por período
- ✅ Historial completo de lecturas
- ✅ Integración con facturas (costo por consumo)

**Menú:** Propiedades > Medidores

---

### 3️⃣ Facturación Automatizada

**Objetivo:** Generar y gestionar facturas de servicios residenciales.

#### Características:
- ✅ **Facturación automática mensual** basada en coeficientes
- ✅ Cálculo de cuotas por:
  - Cuota de administración
  - Servicios (agua, electricidad, gas)
  - Mantenimiento
  - Seguros
  - Otros gastos comunes
- ✅ Aplicación de **intereses de mora** automáticos
- ✅ Desglose por concepto en cada factura
- ✅ Descuentos y recargos
- ✅ Estado de pago (pagado, parcial, vencido)
- ✅ Envío automático por correo electrónico
- ✅ Generación de PDF
- ✅ Historial completo de facturas

**Menú:** Facturas > Órdenes de Venta > Órdenes Recurrentes

---

### 4️⃣ Gestión de Suscripciones

**Objetivo:** Crear modelos de facturación recurrente para cuotas regulares.

#### Características:
- ✅ Plantillas de órdenes de venta recurrentes
- ✅ Configuración de **ciclos de facturación** (mensual, trimestral, anual)
- ✅ Líneas de suscripción con productos específicos
- ✅ Automatización de renovación
- ✅ Gestión de cambios de suscripción
- ✅ Suspensión temporal o cancelación
- ✅ Reportes de ingresos recurrentes

**Menú:** Ventas > Órdenes > Plantillas de Órdenes Recurrentes

---

### 5️⃣ Gestión de Proyectos y Tareas

**Objetivo:** Organizar y monitorear tareas de mantenimiento y mejoras.

#### Características:
- ✅ **Proyecto centralizado** "Property Management"
- ✅ Tipos de tareas predefinidas:
  - Mantenimiento preventivo
  - Reparaciones de emergencia
  - Mejoras estructurales
  - Limpieza y aseo
  - Seguridad
  - Vigilancia
- ✅ Asignación de responsables
- ✅ Prioridades (alta, media, baja)
- ✅ Estados (nuevo, en progreso, completado, cancelado)
- ✅ Fechas de inicio y vencimiento
- ✅ Seguimiento de horas invertidas
- ✅ Comentarios y archivos adjuntos
- ✅ Notificaciones automáticas

**Menú:** Proyectos > Proyectos > Property Management

---

### 6️⃣ Centros de Costo Analíticos

**Objetivo:** Desglosar costos por propiedad o departamento.

#### Características:
- ✅ Planes analíticos para:
  - Costo por propiedad
  - Costo por servicios
  - Costo por áreas comunes
- ✅ Etiquetas analíticas
- ✅ Distribución de gastos comunes
- ✅ Reportes analíticos de costos
- ✅ Comparativas por período

**Menú:** Contabilidad > Configuración > Planes Analíticos

---

### 7️⃣ Seguimiento de Cobros Vencidos

**Objetivo:** Automatizar cobro de cuotas atrasadas.

#### Características:
- ✅ Identificación automática de cuotas vencidas
- ✅ Generación de **cartas de cobro** automáticas
- ✅ Escalado de acciones:
  - 1er aviso (3 días después del vencimiento)
  - 2do aviso (7 días después)
  - 3er aviso (15 días después) + interés
  - Notificación a cobranza
- ✅ Registro de comunicaciones
- ✅ Historial de cobranza
- ✅ Reportes de morosidad

**Menú:** Contabilidad > Clientes > Seguimiento

---

### 8️⃣ Análisis y Reportes

**Objetivo:** Generar reportes ejecutivos de gestión.

#### Reportes Disponibles:
- ✅ **Estado de cartera** (quién debe y cuánto)
- ✅ **Morosidad por propiedad**
- ✅ **Ingresos vs. gastos mensuales**
- ✅ **Consumo de servicios**
- ✅ **Tareas pendientes por área**
- ✅ **Análisis de ocupación**
- ✅ **Histórico de pagos**
- ✅ **Proyecciones de ingresos**

**Menú:** Reportes > Contabilidad / Ventas / Proyectos

---

## Modelos de Datos

### Datos Personalizados Creados

El módulo crea o modifica los siguientes modelos:

#### 1. **x_buildings** (Edificios/Torres)
```
- Nombre del edificio
- Descripción
- Ubicación
- Tipo de construcción
- Año de construcción
- Altura (pisos)
- Identificador único
```

#### 2. **x_properties** (Propiedades)
```
- Nombre/Número
- Edificio (relación)
- Tipo de propiedad (apartamento, casa, local, etc.)
- Área (m²)
- Ubicación dentro del edificio
- Propietario actual (Partner)
- Coeficiente de participación (%)
- Estado (activa, inactiva, vendida)
- Fecha de adquisición
- Valor catastral
- Etiquetas
- Historial de propietarios
```

#### 3. **x_meters** (Medidores)
```
- Número de medidor
- Tipo (agua, electricidad, gas)
- Propiedad asociada
- Ubicación
- Lectura inicial
- Lectura actual
- Unidad de medida
- Responsable de lectura
- Fecha última lectura
- Consumo del período
```

#### 4. **sale_subscription** (Suscripciones/Cuotas Recurrentes)
```
- Partner (propietario)
- Plantilla de suscripción
- Fecha de inicio
- Fecha de término (si aplica)
- Estado (activa, pendiente, cancelada)
- Próxima fecha de facturación
- Valor mensual
```

#### 5. **project.project** (Proyecto Principal)
```
- Nombre: "Property Management"
- Descripción del conjunto
- Responsable de proyecto
- Equipo de trabajo
- Plantilla de tareas
```

#### 6. **project.task** (Tareas de Mantenimiento)
```
- Nombre/Descripción
- Tipo (mantenimiento, reparación, mejora, etc.)
- Propiedad afectada
- Prioridad
- Responsable
- Fechas (inicio, vencimiento)
- Estado
- Horas estimadas vs. reales
```

---

## Menús y Vistas

### Estructura de Menús

#### **MENÚ PRINCIPAL: Propiedades** 🏠

```
Propiedades/
├── Dashboard
│   └── Resumen ejecutivo del conjunto
├── Propiedades
│   ├── Mis Propiedades
│   └── Todas las Propiedades
├── Medidores
│   ├── Lecturas Mensuales
│   └── Consumos Acumulados
├── Propietarios
│   ├── Directorio
│   └── Cartera por Propietario
├── Tareas de Mantenimiento
│   ├── Por Hacer
│   ├── En Progreso
│   └── Completadas
└── Reportes
    ├── Estado de Cartera
    ├── Morosidad
    └── Consumo de Servicios
```

#### **MENÚ SECUNDARIO: Facturación** 📄

```
Facturación/
├── Órdenes de Venta
│   ├── Órdenes Nuevas
│   └── Órdenes Confirmadas
├── Plantillas Recurrentes
│   ├── Cuota de Administración
│   ├── Servicios Básicos
│   └── Mantenimiento
├── Seguimiento de Pagos
│   ├── Pagados
│   ├── Parciales
│   └── Vencidos
└── Análisis de Ingresos
    ├── Por Período
    ├── Por Concepto
    └── Proyecciones
```

### Vistas Disponibles

Cada módulo tiene vistas múltiples:

| Vista | Descripción |
|-------|-------------|
| **Lista (Tree)** | Tabla con todas las propiedades/medidores |
| **Formulario (Form)** | Detalle completo de cada registro |
| **Kanban** | Tarjetas agrupadas por estado/tipo |
| **Calendario** | Fechas importantes (vencimientos, lecturas) |
| **Gráfico** | Análisis visual de datos |
| **Pivot** | Análisis multidimensional |

---

## Configuración

### Configuración General del Sistema

**Menú:** Configuración > Ajustes > Propiedades

#### Parámetros Configurables:

1. **Datos del Conjunto Residencial**
   - Nombre oficial
   - NIT / RUC
   - Dirección
   - Teléfono y email de administración
   - Logo/Imagen

2. **Ciclo de Facturación**
   - Día de corte (ej: día 10 de cada mes)
   - Día de vencimiento (ej: día 20)
   - Períodos de gracia para pagos

3. **Intereses y Multas**
   - Tasa de interés moratorio (%)
   - A partir de cuántos días se cobra
   - Multa por cheque rechazado
   - Otros recargos

4. **Servicios Incluidos**
   - Cuota de administración base
   - Servicios (agua, electricidad, etc.)
   - Reserva para mantenimiento
   - Seguros
   - Otros

5. **Bancos y Métodos de Pago**
   - Cuenta bancaria del conjunto
   - Métodos de pago aceptados
   - Instrucciones de pago para propietarios

6. **Notificaciones y Comunicación**
   - Servidor SMTP
   - Plantillas de correo
   - Fechas de envío automático
   - Teléfonos de contacto

---

## Automatizaciones

### Flujos Automáticos Configurados

#### **Automatización 1: Facturación Mensual Automática**
```
Disparador: Día X del mes (configurable)
Acción: 
  - Crear órdenes de venta recurrentes
  - Calcular consumos de medidores
  - Aplicar intereses de mora
  - Enviar facturas por email
  - Registrar en contabilidad
```

#### **Automatización 2: Cálculo de Intereses Diarios**
```
Disparador: Cada día a las 6:00 AM (configurable)
Acción:
  - Identificar facturas vencidas
  - Calcular días de atraso
  - Aplicar interés = (Monto × Tasa% × Días / 30)
  - Registrar cargo automático
  - Generar notificación al propietario
```

#### **Automatización 3: Escalado de Cobro**
```
Disparador: Automático según días de atraso
Acciones Escalonadas:
  - Día 3: Enviar 1er aviso (correo)
  - Día 7: Enviar 2do aviso (llamada telefónica)
  - Día 15: Enviar 3er aviso + interés (carta certificada)
  - Día 30: Reportar a cobranza externa
```

#### **Automatización 4: Recordatorios de Lectura**
```
Disparador: Último día del mes
Acción:
  - Notificar a lectores de medidores
  - Recordar propiedades sin lectura
  - Generar reporte de medidas pendientes
```

#### **Automatización 5: Actualización de Suscripciones**
```
Disparador: Cada día
Acción:
  - Verificar suscripciones a renovar
  - Crear nuevas órdenes de venta
  - Actualizar estado de suscripciones expiradas
  - Generar alertas de cancelación próxima
```

---

## Limitaciones y Adaptaciones para Community Edition

### 🔴 Caso: Campo `base_automation_id` (Enterprise)

#### **Situación**
El módulo original está desarrollado para **Odoo Enterprise** y contiene una referencia a `base_automation_id` en el archivo `data/ir_actions_server.xml` (línea 96), que es un campo **exclusivo de Enterprise** que no existe en Community.

#### **Qué es `base_automation_id`?**

Es un campo que vincula una **acción de servidor** (`ir.actions.server`) a una **automatización** (`base.automation`). Permite que:

```xml
<field name="base_automation_id" ref="automation_set_usage_meter_reading"/>
```

Se traduce a: _"Esta acción se ejecutará automáticamente cuando se cumpla la condición definida en `automation_set_usage_meter_reading`"_

En este caso específico:
- **Acción:** Calcular consumo de medidores restando lecturas anteriores
- **Disparador:** Cuando se crea/actualiza una lectura de medidor (`x_meter_reading`)
- **Resultado:** Cálculo automático sin intervención manual

#### **¿Por qué está comentado?**

```python
<!-- Comentado: base_automation_id no existe en Community -->
<!-- <field name="base_automation_id" ref="automation_set_usage_meter_reading"/> -->
```

**Razones:**
1. El campo `base_automation_id` **no existe en Community Edition**
2. El registro `automation_set_usage_meter_reading` **no está definido en los datos Community**
3. Sin comentar, genera error: `ValueError: External ID not found in the system`
4. Afecta la instalación completa del módulo

#### **Implicaciones de Estar Comentado**

| Aspecto | Implicación |
|--------|------------|
| **Cálculo de consumo** | ❌ NO se ejecuta automáticamente |
| **Intervención manual** | ✅ Se debe ejecutar manualmente |
| **Ejecución de la acción** | ✅ Sigue siendo posible mediante botones |
| **Funcionalidad** | ⚠️ Parcialmente limitada |
| **Instalación del módulo** | ✅ Se completa sin errores |

#### **Soluciones Alternativas para Community**

##### **Opción 1: Automatización Manual (Recomendado)**

Crear la automatización directamente en la UI de Odoo:

```
Menú: Configuración > Automatizaciones > Crear
1. Nombre: "Calcular Consumo de Medidores"
2. Modelo: x_meter_reading
3. Disparador: Al crear o actualizar
4. Dominio (filtro): (Opcional) Solo ciertos medidores
5. Acción: Ejecutar la acción de servidor "Meter Reading"
```

**Ventajas:**
- ✅ Se configura sin tocar código
- ✅ Visible en la UI para administradores
- ✅ Fácil de modificar o desactivar
- ✅ No requiere restart de Odoo

##### **Opción 2: Implementar en el Modelo Python (Desarrollo)**

Agregar lógica en el modelo `x_meter_reading`:

```python
# models/x_meter_reading.py
from odoo import models, api

class XMeterReading(models.Model):
    _name = 'x_meter_reading'
    
    @api.model_create_multi
    def create(self, vals_list):
        """Calcula automáticamente el consumo al crear una lectura"""
        records = super().create(vals_list)
        for record in records:
            record._calculate_usage()
        return records
    
    def write(self, vals):
        """Recalcula consumo si cambia la cantidad"""
        result = super().write(vals)
        if 'x_quantity' in vals:
            for record in self:
                record._calculate_usage()
        return result
    
    def _calculate_usage(self):
        """Calcula el consumo restando la lectura anterior"""
        mrs = self.env['x_meter_reading'].search([
            ('id', 'in', self.x_account_analytic_account_id.x_property_meter_reading_ids.ids),
            ('x_meter_id', '=', self.x_meter_id.id)
        ], order='x_date')
        
        previous_mr = False
        for mr in mrs:
            mr.x_usage = mr.x_quantity - (previous_mr.x_quantity if previous_mr else 0)
            previous_mr = mr
```

**Ventajas:**
- ✅ Automático a nivel de base de datos
- ✅ No requiere configuración en UI
- ✅ Más robusto y rápido
- ✅ Mejor práctica de desarrollo

**Desventajas:**
- ❌ Requiere código Python
- ❌ Requiere reiniciar Odoo

##### **Opción 3: Botón Manual en la Vista**

Agregar un botón en la vista del medidor:

```xml
<button name="action_server_set_usage_meter_reading" 
        type="action" 
        string="Calcular Consumo"
        class="btn-primary"/>
```

**Ventajas:**
- ✅ Control manual del usuario
- ✅ Fácil de implementar

**Desventajas:**
- ❌ Requiere acción manual cada vez
- ❌ Menos automatizado

#### **Recomendación Final**

**Para tu instancia:** Implementar **Opción 1 (Automatización Manual)**
- Es la más equilibrada entre funcionalidad y facilidad
- No requiere desarrollo
- Se puede hacer desde la UI
- Fácil de mantener y auditar

**Pasos a seguir:**
```
1. Ir a: Configuración > Automatización > Crear
2. Completar formulario:
   - Nombre: "Calcular Consumo de Medidores"
   - Modelo: x_meter_reading
   - Trigger: Al crear o actualizar
3. En "Acciones": Seleccionar "Meter Reading" (ir.actions.server)
4. Guardar
5. Activar
```

#### **Referencias**
- Campo Enterprise: `ir.actions.server.base_automation_id`
- Archivo modificado: `condominium/data/ir_actions_server.xml` (línea 96)
- Automización referenciada: `automation_set_usage_meter_reading` (no existe en Community)
- Estado: Comentado para compatibilidad con Community

---

## Productos y Servicios

### Productos Predefinidos

El módulo crea automáticamente los siguientes servicios:

| Código | Nombre | Tipo | Categoría |
|--------|--------|------|-----------|
| ADM | Cuota de Administración | Servicio | Servicios Residenciales |
| AGUA | Servicio de Agua | Servicio | Servicios Básicos |
| LUZ | Servicio de Electricidad | Servicio | Servicios Básicos |
| GAS | Servicio de Gas | Servicio | Servicios Básicos |
| MANT | Mantenimiento | Servicio | Mantenimiento |
| SEG | Seguros | Servicio | Seguros |
| INTERES | Intereses de Mora | Servicio | Cargos Financieros |
| MULTA | Multa por Incumplimiento | Servicio | Cargos Financieros |
| LIMPIEZA | Limpieza Áreas Comunes | Servicio | Servicios Complementarios |
| VIGILANCIA | Servicio de Vigilancia | Servicio | Seguridad |

### Categorización de Productos

```
Servicios Residenciales/
├── Servicios Básicos
│   ├── Agua
│   ├── Electricidad
│   └── Gas
├── Mantenimiento
│   ├── Preventivo
│   └── Correctivo
├── Servicios Complementarios
│   ├── Limpieza
│   ├── Jardinería
│   └── Plagas
├── Seguridad
│   ├── Vigilancia
│   ├── Cámaras
│   └── Cerraduras
└── Cargos Financieros
    ├── Intereses Moratorio
    └── Multas
```

---

## Planes Analíticos

### Estructura de Centros de Costo

El módulo configura centros de costo para desglosar gastos:

#### **Dimensión 1: Por Propiedad**
```
- Apartamento 101
- Apartamento 102
- ... (una línea por cada propiedad)
```

#### **Dimensión 2: Por Concepto de Gasto**
```
- Administración
- Servicios Básicos
- Mantenimiento
- Seguros
- Vigilancia
```

#### **Dimensión 3: Por Área Común** (opcional)
```
- Áreas Verdes
- Piscina
- Gimnasio
- Salón Comunal
- Parqueadero
```

### Uso en Facturas

Cada línea de factura se etiqueta con:
```
Propiedad: Apt 301
Concepto: Servicios Básicos
Gasto: $150.000
```

Esto permite reportes como:
- "¿Cuánto gastó el Apt 301 en servicios?"
- "¿Cuál fue el gasto total en Vigilancia?"
- "¿Comparativa de gastos mensuales por concepto?"

---

## Seguridad y Acceso

### Grupos de Usuarios Predefinidos

#### **1. Administrador General**
```
Permisos Completos:
- Ver todas las propiedades
- Crear y editar facturas
- Gestionar usuarios
- Acceso a reportes confidenciales
- Configuración del sistema
```

#### **2. Gerente de Propiedades**
```
Permisos:
- Ver todas las propiedades
- Crear/editar tareas de mantenimiento
- Ver estado de pagos
- Crear medidores y registrar lecturas
- No puede: borrar facturas, cambiar configuración
```

#### **3. Contador**
```
Permisos:
- Ver facturas
- Ver pagos recibidos
- Generar reportes contables
- Ver análisis de ingresos
- No puede: crear facturas, editar propiedades
```

#### **4. Propietario** (Portal Web)
```
Permisos:
- Ver solo su propiedad
- Ver sus facturas
- Ver estado de pagos
- Descargar recibos
- Contactar administración
- No puede: ver otras propiedades
```

#### **5. Lector de Medidores**
```
Permisos:
- Registrar lecturas de medidores
- Ver lista de medidores asignados
- Reportar anomalías
- No puede: crear propiedades, ver facturas
```

### Reglas de Acceso (Access Rules)

```
- Cada usuario ve solo sus propias propiedades asignadas
- Los reportes contables están restringidos a contadores
- Los datos de pagos no se muestran a propietarios de otras unidades
- El administrador ve todo
```

---

## Internacionalización

### Idiomas Soportados

El módulo incluye traducciones para:

- ✅ **Español** (es) - Completo
- ✅ **Inglés** (en_US) - Completo
- ✅ **Francés** (fr) - Disponible
- ✅ **Portugués** (pt) - Disponible
- ✅ **Holandés** (nl) - Disponible
- ✅ **Alemán** (de) - Disponible
- ✅ **Árabe** (ar) - Disponible
- ✅ Otros idiomas: Húngaro, Indonesio, Croata, Hindi, Hebreo, Finlandés

### Configuración de Idioma

**Menú:** Configuración > Usuarios y Compañías > Usuarios > Seleccionar Usuario > Idioma

Cada usuario puede tener su idioma preferido.

---

## Instalación y Uso

### Requisitos Previos

```
✅ Odoo 18 Community Edition instalado
✅ Módulos base (account, contacts, sale, project)
✅ PostgreSQL 12+ funcionando
✅ Acceso administrativo a Odoo
```

### Pasos de Instalación

#### **Paso 1: Copiar el módulo**
```bash
cd /ruta/a/odoo/extra-addons
cp -r condominium ./
```

#### **Paso 2: Actualizar lista de módulos**
```
Odoo > Aplicaciones > Actualizar lista de módulos
```

#### **Paso 3: Buscar e instalar**
```
Odoo > Aplicaciones > Buscar "Property Owner Association"
Clic en botón "Instalar"
```

#### **Paso 4: Configuración inicial**
```
Odoo > Configuración > Ajustes > Pestaña Propiedades
Completar datos del conjunto residencial
```

#### **Paso 5: Crear datos maestros**
```
1. Crear edificios/torres
2. Crear propiedades
3. Crear medidores
4. Crear productos/servicios
5. Crear suscripciones
```

### Uso Básico - Primer Mes

#### **Semana 1: Configuración**
```
1. Configurar datos generales del conjunto
2. Crear edificios y propiedades
3. Asignar propietarios
4. Crear medidores
5. Configurar productos y servicios
```

#### **Semana 2: Datos Maestros**
```
1. Crear plantillas de suscripción
2. Asignar suscripciones a propietarios
3. Crear tareas de mantenimiento
4. Asignar responsables
5. Configurar automatizaciones
```

#### **Semana 3-4: Pruebas**
```
1. Registrar lecturas de medidores
2. Generar primera factura (manual)
3. Registrar pagos
4. Generar reportes
5. Enviar facturas por correo
```

#### **Mes 2+: Operación Normal**
```
1. Automatización de facturación
2. Monitoreo de pagos
3. Gestión de tareas
4. Análisis de reportes
5. Comunicación con propietarios
```

---

## Casos de Uso Comunes

### **Caso 1: Generar Factura Mensual**

**Flujo:**
```
1. Ir a: Propiedades > Dashboard
2. Hacer clic en "Generar Facturas del Mes"
3. Sistema calcula automáticamente:
   - Cuota base × coeficiente
   - Consumo de servicios × precio
   - Intereses moratorios (si aplica)
4. Se crea una orden de venta por propietario
5. Sistema envía PDF por correo automáticamente
```

### **Caso 2: Registrar Lectura de Medidor**

**Flujo:**
```
1. Ir a: Propiedades > Medidores
2. Seleccionar medidor
3. Ingresa nueva lectura (ej: 12.550)
4. Sistema calcula consumo = lectura nueva - lectura anterior
5. Saldo se registra automáticamente
6. Se genera cargo en siguiente factura
```

### **Caso 3: Crear Tarea de Mantenimiento**

**Flujo:**
```
1. Ir a: Proyectos > Property Management
2. Crear nueva tarea
3. Especificar:
   - Descripción (ej: "Reparar tubería Apt 202")
   - Tipo (Emergencia)
   - Prioridad (Alta)
   - Responsable (Juan Pérez)
   - Fecha vencimiento (hoy + 2 días)
4. Sistema notifica al responsable
5. Responsable marca completada cuando termine
```

### **Caso 4: Consultar Deuda de Propietario**

**Flujo:**
```
1. Ir a: Contactos
2. Buscar y abrir contacto del propietario
3. Ver pestaña "Facturas" para historial
4. Ver campo "Saldo Pendiente"
5. Sistema muestra:
   - Facturas pagadas
   - Facturas parciales
   - Facturas vencidas
   - Intereses acumulados
```

### **Caso 5: Generar Reporte de Morosidad**

**Flujo:**
```
1. Ir a: Reportes > Morosidad
2. Seleccionar período (mes/año)
3. Filtrar por estado (vencidas > 30 días)
4. Sistema genera tabla con:
   - Propietario
   - Factura
   - Monto
   - Días vencida
   - Interés acumulado
5. Exportar a Excel o PDF
6. Enviar por correo a administrador
```

---

## Alertas y Notificaciones

### Notificaciones Automáticas Generadas

| Evento | Destinatario | Contenido |
|--------|--------------|-----------|
| Factura Generada | Propietario | Adjunta PDF de factura |
| 3 días antes de vencer | Propietario | Recordatorio de pago |
| Factura vencida | Propietario + Admin | Aviso de cobro |
| Interés aplicado | Propietario | Detalle de interés moratorio |
| Lectura faltante | Lector de medidores | Lista de propiedades sin lectura |
| Tarea asignada | Responsable | Detalles y fechas de tarea |
| Tarea vencida | Responsable + Admin | Alerta de atraso |
| Pago recibido | Propietario | Recibo y saldo actualizado |

---

## Soporte y Mantenimiento

### Verificación Periódica Recomendada

**Mensual:**
- [ ] Verificar que facturas se generan correctamente
- [ ] Revisar pagos registrados
- [ ] Validar lecturas de medidores
- [ ] Revisar tareas completadas

**Trimestral:**
- [ ] Revisar análisis de morosidad
- [ ] Auditar cambios de propietarios
- [ ] Validar suscripciones activas
- [ ] Revisar intereses aplicados

**Anual:**
- [ ] Backup completo de base de datos
- [ ] Revisión de configuración general
- [ ] Auditoría de seguridad y accesos
- [ ] Capacitación de nuevos usuarios

---

## Preguntas Frecuentes (FAQ)

**P: ¿Cómo cambio la tasa de interés moratorio?**
A: Configuración > Ajustes > Propiedades > Campo "Tasa de Interés (%)"

**P: ¿Puedo cambiar el día de corte de facturas?**
A: Sí, en Configuración > Ajustes > Propiedades > "Día de Corte"

**P: ¿Cómo genero un recibo de pago?**
A: Al registrar pago > Imprimir > Seleccionar "Recibo de Pago"

**P: ¿Qué pasa si una propiedad no tiene lectura de medidor?**
A: Se factura con el promedio del período anterior (configurable)

**P: ¿Puedo dar acceso a propietarios al sistema?**
A: Sí, Portal Web habilitado con acceso restringido a su propiedad

---

## Recursos y Documentación

- 📖 Manual de Usuario: `USER_MANUAL.md`
- 🔧 Guía de Configuración: `CONFIGURATION_GUIDE.md`
- 🐛 Troubleshooting: `TROUBLESHOOTING.md`
- 📞 Soporte: soporte@ejemplo.com

---

**Documento generado:** Enero 2026  
**Versión:** 1.0  
**Última actualización:** 2026-01-04
