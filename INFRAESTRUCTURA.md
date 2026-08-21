# Estado de la Infraestructura de Contenedores

Este documento detalla el estado, credenciales y distribución de la infraestructura de contenedores al día de hoy (**20 de agosto de 2026**). Su propósito es servir de contexto para futuras sesiones de desarrollo y administración.

---

## 1. Servidores Activos

La infraestructura se distribuye en 5 servidores Linux (acceso `root`):

| Servidor | IP Pública(s) | IP Local | Rol |
| :--- | :--- | :--- | :--- |
| **Bastion** | `95.217.165.80`, `65.109.240.180`, `5.75.214.38` | `10.0.0.3` | Nginx (proxy reverso a los nodos Docker) |
| **Docker - New - 01** | `46.224.72.175` | `10.0.0.4` | Contenedores Docker |
| **Docker - New - 02** | `77.42.26.60` | `10.0.0.5` | Contenedores Docker |
| **Docker - New - 03** | `37.27.190.155` | `10.0.0.2` | Contenedores Docker |
| **Docker - Alma - 16GB** | `2.29.11.73` | `10.0.0.6` | Contenedores Docker (AlmaLinux 9, 8vCPU/16GB/160GB) |

> **Nota:** El servidor original (`37.27.218.117`, Hetzner Helsinki) ya no forma parte de la infraestructura.

### Distribución de proyectos por servidor

| Servidor | Rol | Proyectos |
| :--- | :--- | :--- |
| **Bastion** (`10.0.0.3`) | Nginx — proxy reverso de todos los dominios | Ningún contenedor; solo nginx con vhosts de `sites-available/` |
| **Docker - New - 01** (`46.224.72.175` / `10.0.0.4`) | Contenedores | Por confirmar (migración a Alma completada) |
| **Docker - New - 02** (`77.42.26.60` / `10.0.0.5`) | Contenedores | Vacío — desmantelable |
| **Docker - New - 03** (`37.27.190.155` / `10.0.0.2`) | Contenedores | Vacío — desmantelable |
| **Docker - Alma - 16GB** (`2.29.11.73` / `10.0.0.6`) | Contenedores | **✅ CONSOLIDADO:** `29`, `30`, `32` (n8n + IA), `35`, `36`, `37`, `41`, `42`, `43`, `pgadmin4` |

---

## 2. Bases de Datos y Credenciales

### Servidor de Base de Datos Principal (Puerto 9032)
* **Tipo:** PostgreSQL 12 (Servicio `db` en proyecto `32`)
* **Acceso:** `37.27.218.117:9032` *(verificar si migró a nuevo servidor)*
* **Usuario:** `n8n`
* **Contraseña:** `Urantia73`
* **Base de Datos Destacada:** `n8n`
  * *Contenido clave:*
    * `metricas_personalizadas`: Logs de uso de IA (`gpt-4o-mini`), archivos procesados, etc. (~95,000 registros).
    * `execution_entity`: Historial de ejecuciones de n8n, duraciones y estados de error/éxito (~10,000 registros).
    * `workflow_statistics`: Conteo consolidado de éxitos/errores por flujo de n8n.

### Servidor de Base de Datos Vectorial / WhatsApp (Puerto 9033)
* **Tipo:** PostgreSQL 14 + pgvector (Servicio `pgvectordb` en proyecto `32`)
* **Acceso:** `37.27.218.117:9033` *(verificar si migró a nuevo servidor)*
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
* **`16` (Odoo 13):** CANCELADO.
* **`33` (Wetty):** Terminal en navegador (Puerto 8033).
* **`34` (VSCode Web):** IDE online (Puerto 8034).
* **`40` (Openclaw-gateway):** Gateway para openclaw (Puerto 8040).

### Proyectos Activos (Junio 2026)

| Proyecto | Descripción | Observaciones |
| :--- | :--- | :--- |
| **APIs de WhatsApp** | Pasarelas de comunicación de WhatsApp | `wppapi`, `wppapi_mb`, `wppapi_ai`, `wppapi_ai_2` |
| **`32` (n8n + IA)** | Core de automatización e IA | Incluye n8n, OCR, pdf2img, pgvector, redis, transcription |
| **`39` (Metabase)** | BI / consultas | Alto tránsito de red |
| **`35`–`38`, `42` (Odoo)** | Instancias Odoo | Puertos `80NN`/`90NN` |
| **`41` (Prospectum)** | Odoo 18 — `prospectum.ai-mindnovation.com` | Puerto `8041`/`9041`, longpoll `8079` |

---

## 4. Pendientes conocidos

- **Prospectum (41):** Configuración probada en `77.42.26.60` (Docker - New - 02). El vhost en el repo (`sites-available/prospectum.ai-mindnovation.com.conf`) apunta a `10.0.0.5:8041`, que es correcto. Falta verificar si ese vhost ya está desplegado en el Bastion (`65.109.240.180`).
- **Distribución de proyectos:** Confirmar qué proyectos están en cada servidor Docker y actualizar la tabla de la sección 1.
- **BDs del proyecto 32:** Verificar en qué servidor quedaron tras la migración.
