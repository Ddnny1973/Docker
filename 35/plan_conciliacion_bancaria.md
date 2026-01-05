# Plan de Desarrollo - Sistema de Conciliación Bancaria para Unidades Residenciales

## 📋 RESUMEN EJECUTIVO

**Proyecto:** Sistema de administración y conciliación bancaria para conjuntos residenciales  
**Plataforma:** Odoo 18 Community Edition  
**Infraestructura:** Docker / Docker Compose  
**Modelo de despliegue:** Multi-tenant (un contenedor por unidad residencial)

---

## 🎯 OBJETIVOS DEL PROYECTO

1. Gestionar apartamentos como clientes bajo unidades residenciales
2. Calcular cuotas de administración basadas en coeficientes
3. Automatizar cálculo de intereses de mora
4. Gestionar y liquidar multas
5. Realizar conciliación bancaria automática
6. Generar y enviar facturas automáticamente

---

## 🔍 ANÁLISIS DE MÓDULOS ODOO DISPONIBLES

### Módulo Recomendado: **Property Owner Association (Condominio)**
- **Versión:** Compatible con Odoo 17 (necesita portarse a v18)
- **Licencia:** LGPLv3 (Open Source - FREE)
- **URL:** https://apps.odoo.com/apps/modules/17.0/condominium
- **Características:**
  - Gestión de co-propiedades
  - División justa de cargos
  - Manejo de propietarios y unidades
  - Facturación automatizada

### Módulos Base de Odoo 18 a Utilizar:
1. **Contacts (res.partner)** - Gestión de propietarios y apartamentos
2. **Invoicing & Accounting** - Facturación y contabilidad
3. **Products (stock)** - Productos/servicios (administración, multas, intereses)
4. **Recurring Documents** - Facturación automática mensual
5. **Bank Reconciliation** - Conciliación bancaria

---

## 🏗️ ARQUITECTURA DEL SISTEMA

### Estructura de Datos Principal

```
Unidad Residencial (Company)
    ├── Administrador (User/Partner)
    └── Apartamentos (Partners con categoría especial)
        ├── Propietario Principal
        │   ├── Nombre completo
        │   ├── Cédula
        │   ├── Email
        │   └── Teléfono
        ├── Datos del Apartamento
        │   ├── Número/Nombre
        │   ├── Coeficiente (%)
        │   ├── Área (m²)
        │   └── Estado (Activo/Inactivo)
        └── Información Financiera
            ├── Cuota base mensual
            ├── Saldo pendiente
            └── Historial de pagos
```

---

## 📦 FASE 1: CONFIGURACIÓN DE INFRAESTRUCTURA DOCKER

### 1.1 Estructura de Carpetas
```
proyecto-conciliacion/
├── docker-compose.yml
├── .env.example
├── addons/
│   └── custom_modules/
│       ├── condominium/          # Módulo portado
│       ├── property_billing/      # Módulo personalizado
│       └── bank_reconciliation_co/ # Conciliación Colombia
├── config/
│   └── odoo.conf
├── data/
│   ├── postgresql/
│   └── filestore/
└── scripts/
    ├── backup.sh
    └── restore.sh
```

### 1.2 Docker Compose Base

**Objetivo:** Crear docker-compose.yml que permita levantar múltiples instancias de Odoo.

**Especificaciones:**
- PostgreSQL 16 (un contenedor por unidad residencial o compartido con DBs separadas)
- Odoo 18 Community
- Volúmenes persistentes para datos y addons
- Variables de entorno para configuración
- Red interna para seguridad
- Nginx como reverse proxy (opcional pero recomendado)

**Archivos a crear:**
1. `docker-compose.yml` - Orquestación de servicios
2. `.env` - Variables de entorno sensibles
3. `odoo.conf` - Configuración específica de Odoo

---

## 📝 FASE 2: DESARROLLO DE MÓDULOS PERSONALIZADOS

### 2.1 Módulo: `property_management_co` (Gestión de Conjuntos)

**Prioridad:** ALTA  
**Depende de:** Condominium module (portado a v18)

**Modelos a crear:**

#### Model: `property.residential.unit` (Unidad Residencial)
```python
class PropertyResidentialUnit(models.Model):
    _name = 'property.residential.unit'
    _inherit = ['mail.thread', 'mail.activity.mixin']
    
    name = fields.Char('Nombre del Conjunto', required=True)
    nit = fields.Char('NIT', required=True)
    administrator_id = fields.Many2one('res.users', 'Administrador')
    company_id = fields.Many2one('res.company', 'Compañía')
    apartment_ids = fields.One2many('property.apartment', 'unit_id', 'Apartamentos')
    total_coefficient = fields.Float('Coeficiente Total', compute='_compute_total_coefficient')
```

#### Model: `property.apartment` (Apartamento)
```python
class PropertyApartment(models.Model):
    _name = 'property.apartment'
    _inherit = ['mail.thread', 'mail.activity.mixin']
    
    name = fields.Char('Número/Nombre', required=True)
    unit_id = fields.Many2one('property.residential.unit', 'Unidad Residencial')
    partner_id = fields.Many2one('res.partner', 'Propietario', required=True)
    owner_vat = fields.Char('Cédula Propietario', related='partner_id.vat')
    coefficient = fields.Float('Coeficiente (%)', required=True, digits=(5,4))
    area = fields.Float('Área (m²)')
    base_fee = fields.Monetary('Cuota Base Mensual', currency_field='currency_id')
    state = fields.Selection([
        ('active', 'Activo'),
        ('inactive', 'Inactivo'),
        ('suspended', 'Suspendido')
    ], default='active')
    balance = fields.Monetary('Saldo Pendiente', compute='_compute_balance')
    invoice_ids = fields.One2many('account.move', 'apartment_id', 'Facturas')
```

#### Model: `property.fee.calculation` (Cálculo de Cuotas)
```python
class PropertyFeeCalculation(models.Model):
    _name = 'property.fee.calculation'
    
    unit_id = fields.Many2one('property.residential.unit', 'Unidad')
    period = fields.Date('Período', required=True)
    total_expenses = fields.Monetary('Gastos Totales')
    apartment_fees = fields.One2many('property.apartment.fee', 'calculation_id')
    state = fields.Selection([
        ('draft', 'Borrador'),
        ('calculated', 'Calculado'),
        ('invoiced', 'Facturado'),
        ('done', 'Finalizado')
    ])
    
    def action_calculate_fees(self):
        """Calcula cuotas basadas en coeficiente"""
        for apartment in self.unit_id.apartment_ids:
            fee_amount = self.total_expenses * (apartment.coefficient / 100)
            # Crear línea de cuota
```

---

### 2.2 Módulo: `property_billing_co` (Facturación y Mora)

**Prioridad:** ALTA  
**Depende de:** property_management_co, account

**Modelos a crear:**

#### Model: `property.late.interest` (Intereses de Mora)
```python
class PropertyLateInterest(models.Model):
    _name = 'property.late.interest'
    
    apartment_id = fields.Many2one('property.apartment', 'Apartamento')
    invoice_id = fields.Many2one('account.move', 'Factura Original')
    due_date = fields.Date('Fecha Vencimiento')
    days_late = fields.Integer('Días de Mora', compute='_compute_days_late')
    interest_rate = fields.Float('Tasa de Interés (%)', default=1.5)  # Configurable
    base_amount = fields.Monetary('Monto Base')
    interest_amount = fields.Monetary('Interés Calculado', compute='_compute_interest')
    state = fields.Selection([
        ('pending', 'Pendiente'),
        ('invoiced', 'Facturado'),
        ('paid', 'Pagado')
    ])
    
    @api.depends('due_date')
    def _compute_days_late(self):
        today = fields.Date.today()
        for record in self:
            if record.due_date and record.due_date < today:
                record.days_late = (today - record.due_date).days
    
    def _compute_interest(self):
        """
        Cálculo: Monto_base * (tasa_mensual * días_mora / 30)
        Ejemplo: $100,000 * (1.5% * 45 días / 30) = $2,250
        """
        for record in self:
            if record.days_late > 0:
                monthly_rate = record.interest_rate / 100
                record.interest_amount = record.base_amount * (monthly_rate * record.days_late / 30)
```

#### Model: `property.penalty` (Multas)
```python
class PropertyPenalty(models.Model):
    _name = 'property.penalty'
    _inherit = ['mail.thread', 'mail.activity.mixin']
    
    name = fields.Char('Referencia', required=True)
    apartment_id = fields.Many2one('property.apartment', 'Apartamento', required=True)
    penalty_type_id = fields.Many2one('property.penalty.type', 'Tipo de Multa')
    date = fields.Date('Fecha', default=fields.Date.today)
    amount = fields.Monetary('Monto', required=True)
    description = fields.Text('Descripción')
    invoice_id = fields.Many2one('account.move', 'Factura Generada')
    state = fields.Selection([
        ('draft', 'Borrador'),
        ('confirmed', 'Confirmada'),
        ('invoiced', 'Facturada'),
        ('paid', 'Pagada'),
        ('cancelled', 'Cancelada')
    ], default='draft')
    
    def action_create_invoice(self):
        """Genera factura por la multa"""
```

#### Acción Programada: `Cron Job - Calcular Intereses Diarios`
```python
def _cron_calculate_late_interests(self):
    """
    Se ejecuta diariamente para calcular intereses de mora
    sobre facturas vencidas
    """
    overdue_invoices = self.env['account.move'].search([
        ('state', '=', 'posted'),
        ('payment_state', 'in', ['not_paid', 'partial']),
        ('invoice_date_due', '<', fields.Date.today()),
        ('apartment_id', '!=', False)
    ])
    
    for invoice in overdue_invoices:
        # Verificar si ya existe registro de interés para hoy
        existing = self.env['property.late.interest'].search([
            ('invoice_id', '=', invoice.id),
            ('create_date', '>=', fields.Date.today())
        ])
        if not existing:
            self.env['property.late.interest'].create({
                'apartment_id': invoice.apartment_id.id,
                'invoice_id': invoice.id,
                'due_date': invoice.invoice_date_due,
                'base_amount': invoice.amount_residual,
                'state': 'pending'
            })
```

#### Acción Programada: `Cron Job - Facturación Mensual Automática`
```python
def _cron_generate_monthly_invoices(self):
    """
    Se ejecuta el día 1 de cada mes para generar
    facturas de administración, incluidos intereses del mes anterior
    """
    units = self.env['property.residential.unit'].search([('state', '=', 'active')])
    
    for unit in units:
        for apartment in unit.apartment_ids.filtered(lambda a: a.state == 'active'):
            # Crear factura con cuota de administración
            invoice_lines = []
            
            # Línea de cuota base
            invoice_lines.append({
                'product_id': self.env.ref('property_billing_co.product_admin_fee').id,
                'quantity': 1,
                'price_unit': apartment.base_fee,
            })
            
            # Agregar intereses de mora del mes anterior
            pending_interests = self.env['property.late.interest'].search([
                ('apartment_id', '=', apartment.id),
                ('state', '=', 'pending')
            ])
            
            if pending_interests:
                total_interest = sum(pending_interests.mapped('interest_amount'))
                invoice_lines.append({
                    'product_id': self.env.ref('property_billing_co.product_late_interest').id,
                    'quantity': 1,
                    'price_unit': total_interest,
                })
            
            # Crear factura
            invoice = self.env['account.move'].create({
                'partner_id': apartment.partner_id.id,
                'apartment_id': apartment.id,
                'move_type': 'out_invoice',
                'invoice_line_ids': [(0, 0, line) for line in invoice_lines]
            })
```

---

### 2.3 Módulo: `bank_reconciliation_colombia` (Conciliación Bancaria)

**Prioridad:** MEDIA  
**Depende de:** account, property_billing_co

**Funcionalidades:**

#### Importadores de Bancos Colombianos

1. **Bancolombia**
   - Formato: Excel (.xlsx) / CSV
   - Campos: Fecha, Referencia, Descripción, Débito, Crédito, Saldo
   
2. **Wompi** (Pasarela de pagos)
   - Formato: API REST / Webhook
   - Integración mediante Webhook para pagos en línea

3. **Otros bancos** (Extensible)
   - Banco de Bogotá
   - Davivienda
   - BBVA

#### Model: `bank.statement.import.config`
```python
class BankStatementImportConfig(models.Model):
    _name = 'bank.statement.import.config'
    
    name = fields.Char('Nombre Configuración', required=True)
    bank = fields.Selection([
        ('bancolombia', 'Bancolombia'),
        ('wompi', 'Wompi'),
        ('davivienda', 'Davivienda'),
        ('bogota', 'Banco de Bogotá')
    ], required=True)
    file_format = fields.Selection([
        ('csv', 'CSV'),
        ('xlsx', 'Excel'),
        ('api', 'API')
    ])
    # Mapeo de columnas
    date_column = fields.Char('Columna Fecha')
    reference_column = fields.Char('Columna Referencia')
    amount_column = fields.Char('Columna Monto')
    description_column = fields.Char('Columna Descripción')
```

#### Wizard: `wizard.bank.statement.import`
```python
class WizardBankStatementImport(models.TransientModel):
    _name = 'wizard.bank.statement.import'
    
    config_id = fields.Many2one('bank.statement.import.config', 'Configuración')
    file = fields.Binary('Archivo', required=True)
    filename = fields.Char('Nombre Archivo')
    journal_id = fields.Many2one('account.journal', 'Diario Bancario')
    
    def action_import(self):
        """Importa y procesa el archivo bancario"""
        if self.config_id.file_format == 'xlsx':
            self._import_excel()
        elif self.config_id.file_format == 'csv':
            self._import_csv()
    
    def _import_excel(self):
        """Procesa archivo Excel"""
        import base64
        import openpyxl
        from io import BytesIO
        
        file_data = base64.b64decode(self.file)
        workbook = openpyxl.load_workbook(BytesIO(file_data))
        sheet = workbook.active
        
        # Lógica de importación...
```

#### Auto-conciliación Inteligente
```python
def _auto_reconcile_payments(self, statement_lines):
    """
    Intenta conciliar automáticamente pagos basándose en:
    1. Referencia de pago (número de factura)
    2. Monto exacto
    3. Rango de fechas
    4. Nombre del cliente
    """
    for line in statement_lines:
        # Buscar factura por referencia
        invoice = self.env['account.move'].search([
            ('name', '=', line.reference),
            ('state', '=', 'posted'),
            ('payment_state', 'in', ['not_paid', 'partial'])
        ], limit=1)
        
        if invoice and abs(invoice.amount_residual - line.amount) < 0.01:
            # Crear pago y conciliar
            payment = self.env['account.payment'].create({
                'payment_type': 'inbound',
                'partner_id': invoice.partner_id.id,
                'amount': line.amount,
                'journal_id': line.journal_id.id,
                'ref': line.reference
            })
            payment.action_post()
            
            # Conciliar con factura
            (invoice.line_ids + payment.line_ids).filtered(
                lambda l: l.account_id.reconcile
            ).reconcile()
```

---

## 🎨 FASE 3: CONFIGURACIÓN Y DATOS MAESTROS

### 3.1 Productos/Servicios a Crear

```python
# Datos a cargar en data/products.xml

productos = [
    {
        'name': 'Cuota de Administración',
        'type': 'service',
        'categ_id': 'Servicios Residenciales',
        'list_price': 0.0,  # Se calcula por apartamento
        'taxes_id': [(6, 0, [impuesto_iva_19.id])]  # Si aplica
    },
    {
        'name': 'Intereses de Mora',
        'type': 'service',
        'categ_id': 'Cargos Financieros',
        'list_price': 0.0
    },
    {
        'name': 'Multa - Uso Indebido Áreas Comunes',
        'type': 'service',
        'list_price': 50000.0
    },
    {
        'name': 'Multa - Ruido Excesivo',
        'type': 'service',
        'list_price': 100000.0
    }
]
```

### 3.2 Configuración de Facturación

- **Secuencias de facturas:** FAC-00001
- **Términos de pago:** Vencimiento día 10 de cada mes
- **Plantillas de correo:** 
  - Envío de factura mensual
  - Recordatorio de vencimiento (3 días antes)
  - Notificación de mora
  - Aviso de multa

---

## 🧪 FASE 4: PRUEBAS Y VALIDACIÓN

### 4.1 Casos de Prueba

#### TC-001: Cálculo de Cuota por Coeficiente
- **Input:** Apartamento con coeficiente 2.5%, gastos totales $10.000.000
- **Esperado:** Cuota = $250.000

#### TC-002: Cálculo de Intereses de Mora
- **Input:** Factura $250.000, vencida hace 30 días, tasa 1.5% mensual
- **Esperado:** Interés = $3.750

#### TC-003: Facturación Mensual Automática
- **Input:** 50 apartamentos activos, día 1 del mes
- **Esperado:** 50 facturas generadas con cuota + intereses previos

#### TC-004: Conciliación Bancaria
- **Input:** Archivo Excel con 20 transacciones
- **Esperado:** 18 conciliadas automáticamente, 2 requieren revisión manual

#### TC-005: Aplicación de Multa
- **Input:** Multa de $100.000 a apartamento 301
- **Esperado:** Multa registrada, factura generada en siguiente período

---

## 📅 CRONOGRAMA DE DESARROLLO

### Sprint 1 (Semana 1-2): Infraestructura
- [ ] Configurar Docker Compose
- [ ] Instalar Odoo 18
- [ ] Portar módulo Condominium a v18 (si es necesario)
- [ ] Configurar ambiente de desarrollo

### Sprint 2 (Semana 3-4): Módulo Base
- [ ] Desarrollar modelo property.residential.unit
- [ ] Desarrollar modelo property.apartment
- [ ] Crear vistas (form, tree, kanban)
- [ ] Implementar cálculo de coeficientes

### Sprint 3 (Semana 5-6): Facturación
- [ ] Desarrollar modelo property.late.interest
- [ ] Desarrollar modelo property.penalty
- [ ] Implementar Cron jobs de facturación
- [ ] Crear productos maestros
- [ ] Configurar plantillas de correo

### Sprint 4 (Semana 7-8): Conciliación Bancaria
- [ ] Desarrollar importadores Bancolombia
- [ ] Desarrollar importador Wompi
- [ ] Implementar auto-conciliación
- [ ] Crear vistas de conciliación

### Sprint 5 (Semana 9-10): Pruebas y Refinamiento
- [ ] Ejecutar casos de prueba
- [ ] Corregir bugs
- [ ] Optimizar performance
- [ ] Documentación de usuario

### Sprint 6 (Semana 11-12): Despliegue
- [ ] Preparar ambiente de producción
- [ ] Migración de datos de prueba
- [ ] Capacitación a administradores
- [ ] Go-live primer conjunto

---

## 🚀 ESTRATEGIA DE DESPLIEGUE

### Modelo Multi-Tenant

Cada conjunto residencial tendrá:
- Contenedor Docker independiente
- Base de datos PostgreSQL propia (o schema separado)
- Dominio único: `[nombre-conjunto].misistema.com`
- Backup independiente

### Ejemplo docker-compose para un conjunto:
```yaml
version: '3.8'

services:
  web_conjunto_a:
    image: odoo:18
    container_name: odoo_conjunto_a
    depends_on:
      - db_conjunto_a
    ports:
      - "8069:8069"
    volumes:
      - ./addons:/mnt/extra-addons
      - ./data/conjunto_a/filestore:/var/lib/odoo
    environment:
      - HOST=db_conjunto_a
      - USER=odoo_a
      - PASSWORD=${DB_PASSWORD_A}
    restart: unless-stopped
    
  db_conjunto_a:
    image: postgres:16
    container_name: postgres_conjunto_a
    environment:
      - POSTGRES_DB=odoo_conjunto_a
      - POSTGRES_USER=odoo_a
      - POSTGRES_PASSWORD=${DB_PASSWORD_A}
    volumes:
      - ./data/conjunto_a/postgresql:/var/lib/postgresql/data
    restart: unless-stopped
```

---

## 📊 INDICADORES DE ÉXITO (KPIs)

1. **Tiempo de facturación:** < 5 minutos para 100 apartamentos
2. **Tasa de conciliación automática:** > 85%
3. **Reducción de errores de facturación:** > 95%
4. **Tiempo de cálculo de intereses:** < 1 minuto diario
5. **Satisfacción del administrador:** > 4.5/5

---

## 🔐 CONSIDERACIONES DE SEGURIDAD

- Encriptación de datos sensibles (cédulas)
- Control de acceso por roles:
  - Superadmin (desarrollador)
  - Admin Conjunto (administrador)
  - Usuario Solo Lectura (contador)
- Backup diario automatizado
- Logs de auditoría en operaciones críticas

---

## 📚 DOCUMENTACIÓN A GENERAR

1. Manual de Usuario (Administrador)
2. Manual de Instalación (DevOps)
3. Documentación Técnica (Desarrollador)
4. Guía de Troubleshooting
5. Videos tutoriales

---

## 💰 ESTIMACIÓN DE RECURSOS

### Desarrollo
- 1 Desarrollador Odoo Senior: 12 semanas
- 1 Desarrollador Python (soporte): 4 semanas

### Infraestructura (por conjunto)
- VPS 2 CPU, 4GB RAM, 50GB SSD: ~$20-40 USD/mes
- Dominio: ~$15 USD/año
- Backups externos: ~$5-10 USD/mes

### Total estimado por conjunto: $25-50 USD/mes

---

## 🎯 PRÓXIMOS PASOS INMEDIATOS

1. ✅ **Validar este plan** con el equipo
2. 🔧 **Crear estructura Docker básica**
3. 🔍 **Revisar módulo Condominium** y evaluar portabilidad a v18
4. 📝 **Definir primer conjunto piloto** para pruebas
5. 🎨 **Diseñar mockups** de interfaces principales

---

## ❓ PREGUNTAS PENDIENTES DE ACLARAR

1. ¿Qué tasa de interés de mora se utilizará? (sugerido: 1.5% mensual)
2. ¿Desde qué día se consideran los intereses? (sugerido: día 11 si vence día 10)
3. ¿Se cobran multas automáticamente o requieren aprobación manual?
4. ¿Cuántos conjuntos se esperan tener en el primer año?
5. ¿Se requiere integración con WhatsApp para notificaciones?
6. ¿Se necesita portal web para que propietarios vean sus facturas?

---

**Versión:** 1.0  
**Fecha:** Enero 2026  
**Autor:** Plan generado para desarrollo con Claude/Haiku 4.5