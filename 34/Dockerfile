FROM ubuntu:22.04

# Dependencias básicas
RUN apt-get update && apt-get install -y \
    wget curl git sudo gnupg python3 python3-pip ca-certificates apt-transport-https \
    && rm -rf /var/lib/apt/lists/*

# Repositorio de VS Code oficial (Microsoft)
RUN wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg \
    && install -o root -g root -m 644 microsoft.gpg /usr/share/keyrings/ \
    && sh -c 'echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list' \
    && apt-get update && apt-get install -y code \
    && rm -rf /var/lib/apt/lists/* microsoft.gpg

# Crear usuario no root
RUN useradd -m -s /bin/bash coder && echo "coder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
USER coder
WORKDIR /home/coder/project

# Asegurar permisos correctos
RUN mkdir -p /home/coder/.vscode && chown -R coder:coder /home/coder

# Puerto web
EXPOSE 8034

# Comando de inicio
ENTRYPOINT ["bash", "-c", "code serve-web --host 0.0.0.0 --port 8034 --without-connection-token --accept-server-license-terms"]