# Estado de la Infraestructura de Contenedores

Este documento detalla el estado, credenciales y plan de migración de la infraestructura de contenedores del proyecto al día de hoy (**28 de junio de 2026**). Su propósito es servir de contexto para futuras sesiones de desarrollo y administración.

---

## 1. Servidor Host (Producción)

* **Proveedor:** Hetzner Cloud
* **Nombre del Servidor:** `docker-alma-32gb-hel1-1`
* **IP Pública:** `37.27.218.117`
* **Ubicación:** Helsinki (Región `hel1-1`)
* **Capacidad de Recursos:**
  * **CPU:** 4+ vCPUs
  * **RAM:** 30.35 GiB (~32 GB)
  * **Disco Principal (`/`):** 232.7 GB (~106 GB ocupados, ~126 GB libres)

---

## 2. Bases de Datos y Credenciales

### Servidor de Base de Datos Principal (Puerto 9032)
* **Tipo:** PostgreSQL 12 (Servicio `db` en proyecto `32`)
* **Acceso:** `37.27.218.117:9032`
* **Usuario:** `n8n`
* **Contraseña:** `Urantia73`
* **Base de Datos Destacada:** `n8n`
  * *Contenido clave:*
    * `metricas_personalizadas`: Logs de uso de IA (`gpt-4o-mini`), archivos procesados, etc. (~95,000 registros).
    * `execution_entity`: Historial de ejecuciones de n8n, duraciones y estados de error/éxito (~10,000 registros).
    * `workflow_statistics`: Conteo consolidado de éxitos/errores por flujo de n8n.

### Servidor de Base de Datos Vectorial / WhatsApp (Puerto 9033)
* **Tipo:** PostgreSQL 14 + pgvector (Servicio `pgvectordb` en proyecto `32`)
* **Acceso:** `37.27.218.117:9033`
* **Usuario:** `vector`
* **Contraseña:** `Urantia73`
* **Bases de Datos Destacadas:**
  1. **`vector`**:
     * *Contenido clave:* Colección `n8n_memoriales` con 93 registros de embeddings (OpenAI 1536 dimensiones) de documentos indexados.
  2. **`whatsapp`**:
     * *Contenido clave:* Tablas de monitoreo de rendimiento del servidor:
       * `monitoreo_recursos`: Datos de CPU/RAM del host (detenido el **29 de enero de 2026**).
       * `monitoreo_almacenamiento`: Espacio en disco del host (detenido el **29 de enero de 2026**).
       * `monitoreo_contenedores`: Tabla vacía (0 registros).
  3. **`postgres`**: BD administrativa.

---

## 3. Estado de los Proyectos y Contenedores

### Proyectos Inactivos (No están corriendo en Docker)
* **`33` (Wetty):** Terminal en navegador (Puerto 8033).
* **`34` (VSCode Web):** IDE online (Puerto 8034).
* **`40` (Openclaw-gateway):** Gateway para openclaw (Puerto 8040).

### Proyectos Activos y Perfil de Consumo (Junio 2026)

| Proyecto | Contenedores Activos | Consumo de RAM (RSS) | Consumo de CPU | Tránsito de Red | Descripción / Observaciones |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **APIs de WhatsApp** | `wppapi`, `wppapi_mb`, `wppapi_ai`, `wppapi_ai_2` | **~3.51 GiB** | ~4.20% | Bajo (~25 MB) | Pasarelas de comunicación de WhatsApp. |
| **`32` (n8n + IA)** | `32-n8n-1`, `32-ocr-1`, `32-pdf2img-1`, `32-db-1`, `32-pgvectordb-1`, `32-redis-1`, `transcription` | **~2.72 GiB** | ~1.20% | Bajo | **Core de automatización e IA**. Destaca `32-ocr-1` con 1.36 GiB de RAM asignada. |
| **`16` (Odoo 13)** | `16-web-1`, `16-db-16-1` | **~1.47 GiB** | ~0.20% | Bajo (~110 MB) | **PROYECTO CANCELADO**. Listo para apagar y liberar recursos. |
| **`39` (Metabase)** | `39-metabase-1`, `39-db-39-1` | **~0.97 GiB** | **~6.71%** | **Extremadamente Alto (64 GB+)** | Alto uso de red y base de datos activa por consultas BI constantes. |
| **`36` (Odoo)** | `36-web-1`, `36-db-36-1` | ~0.90 GiB | ~0.00% | Bajo | Instancia activa. |
| **`35` (Odoo)** | `35-web-1`, `35-db-35-1` | ~0.86 GiB | ~0.00% | Bajo | Instancia activa. |
| **`29` (Odoo)** | `29-web-1`, `29-db-29-1` | ~0.81 GiB | ~0.05% | Bajo | Instancia activa. |
| **`30`/`30a` (Odoo)**| `30-web-1`, `30-db-30-1`, `30a-web-1`, `30a-db-30-1` | ~0.76 GiB | ~0.00% | Alto (~7 GB) | Tráfico medio de red en BD 30a. |
| **`37` (Odoo)** | `37-web-1`, `37-db-37-1` | ~0.50 GiB | ~0.00% | Bajo | Instancia activa. |
| **`38` (Odoo)** | `38-web-1`, `38-db-38-1` | ~0.49 GiB | ~0.03% | Bajo | Instancia activa. |
| **`41` (Odoo)** | `41-web-1`, `41-db-41-1` | ~0.39 GiB | ~0.14% | Bajo | Instancia activa. |
| **`42` (Odoo)** | `42-web-1`, `42-db-42-1` | ~0.39 GiB | ~0.07% | Bajo | Instancia activa. |

---

## 4. Diagnóstico de Rendimiento Histórico (Enero 2026)

Del último mes con registros en la base de datos de monitoreo (`whatsapp.monitoreo_recursos`), se extrajo el siguiente comportamiento:
* **Uso promedio de CPU:** **3.50%** (Sistemas generalmente holgados).
* **Picos de CPU:** **99.94%** (Saturaciones esporádicas en procesamiento intensivo).
* **Uso promedio de RAM:** **30.44%** (~9.4 GB de 30.3 GB del host).
* **Uso de disco principal (`/`):** **43% promedio** (~101 GB de 232 GB ocupados).

---

## 5. Plan de Migración e Infraestructura Futura

Dado que el proyecto **16** ha sido cancelado, ya no es necesario seguir costeando el servidor de 32 GB. Se planea una migración a una infraestructura más pequeña y económica.

### Plan de Servidor Propuesto
* **Modelo objetivo:** **CX33** de Hetzner (4 vCPUs, 8 GB RAM, 80 GB SSD).
* **Almacenamiento Adicional:** Se requerirá agregar un **Hetzner Volume** adicional (de unos 100 GB - 150 GB) debido a que los datos actuales de los proyectos restantes suman ~100 GB, lo cual excede el disco de 80 GB del CX33 base.

### Estado del Trámite de Compra
* **Limitación del panel:** No es posible reescalar directamente el servidor actual porque el disco del CX33 (80 GB) es menor al disco actual (240 GB). Además, la cuenta posee un bloqueo/límite de recursos que impide crear el CX33 en paralelo de manera automática.
* **Acción tomada:** Se redactó y envió un ticket a soporte solicitando:
  1. Aumento del límite de recursos para poder crear una nueva instancia CX33.
  2. O bien, ayuda técnica para degradar CPU y RAM del servidor actual manteniendo el tamaño del disco rígido actual intacto.
