# VS Code Server en AWS

## Configuración de Seguridad

### 1. Variables de Entorno
Edita `.env` y configura una contraseña segura:
```bash
VSCODE_PASSWORD=tu-password-muy-segura
```

### 2. Despliegue
```bash
docker-compose up -d
```

### 3. Acceso
Accede via: `http://IP-PUBLICA-AWS:8034`

### 4. Seguridad AWS
- Security Group: Permitir solo tu IP en puerto 8034
- Instance: Controla encendido/apagado manual
- Key pair: Solo tú tienes acceso SSH

### 5. Detener
```bash
docker-compose down
```

## Extensiones Copilot
Una vez dentro de VS Code web, instala:
- GitHub Copilot
- GitHub Copilot Chat
