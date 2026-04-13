# Arquitectura de Conectividad - Contenedor Odoo 36

## Diagrama de Flujo

```
[Usuarios Externos - Internet]
    ↓ (HTTPS)
[Nginx Bastion - sicone.ai-mindnovation.com:443]
    ↓ (Proxy Reverse)
[Contenedor Docker Odoo - 10.0.0.2:8036]
    ↓ (Para salida a internet externo)
[Internet - APIs externas, servicios externos]
```

---

## Estado Actual: ✅ Contenedor sí tiene acceso a Internet

Se realizó prueba directa dentro del contenedor:

```bash
docker exec 36-web-1 curl -v https://www.google.com
```

**Resultado:** ✅ Exitosa
- DNS resolvió correctamente
- Conexión SSL/TLS establecida (TLSv1.3)
- Certificados válidos
- Datos descargados sin problema

---

## Arquitectura de Conectividad

### Entrada (Usuarios → Odoo)
- **Bastion Host (Nginx)** actúa como reverse proxy
- Recibe peticiones HTTPS en `sicone.ai-mindnovation.com`
- Las redirige internamente al contenedor en `10.0.0.2:8036`
- Maneja certificados SSL y seguridad TLS

**Headers importantes que Nginx pasa:**
```
X-Forwarded-For      → IP real del cliente
X-Forwarded-Proto    → https (protocolo original)
X-Forwarded-Host     → sicone.ai-mindnovation.com
Host                 → Host original
```

### Salida (Odoo → Internet)
- **Red bridge de Docker** permite comunicación hacia exterior
- El contenedor accede a internet a través del host
- No requiere proxy explícito (el host tiene salida directa/natural)
- Ejemplo: N8N en el mismo host consume APIs externas sin problemas

---

## Capacidades Demostradas

El contenedor puede:
1. ✅ Resolver DNS externos (`www.google.com` → IPs IPv4/IPv6)
2. ✅ Establecer conexiones HTTPS con TLS 1.3
3. ✅ Validar certificados SSL correctamente
4. ✅ Descargar datos de internet sin timeout

---

## ¿Qué integración específica necesitan?

Para confirmar que la configuración es suficiente, necesitamos saber:

**Por favor compartir:**
- 📋 **Tipo de API** a consumir (ej: REST, SOAP, GraphQL)
- 🔗 **URL del servicio** (si es pública o interna)
- 📝 **Ejemplo de la consulta** que necesita hacer Odoo
- 🔐 **Autenticación** requerida (API Key, OAuth, certificados, etc.)
- 🏦 **Específicamente:** El ejemplo del banco de la república que mencionaste

Con esto podemos:
1. Validar que es posible desde aquí
2. Crear un script de prueba en Odoo
3. Documentar las variables de entorno o configuración necesaria

---

## Conclusión

**El contenedor ya tiene internet.** La solicitud de habilitar explícitamente la salida probablemente es para:
- Documentación de requerimientos
- Asegurar que esta capacidad está garantizada en la infraestructura
- Dejar constancia de que se requiere conectividad externa para las inversiones temporales mencionadas

Esperamos que compartan la integración específica que necesitan para hacer la prueba completa de extremo a extremo.
