#!/bin/bash

echo "🚀 Iniciando configuración del servidor de despliegue..."

# 🔹 Obtener key del repositorio Jenkins
sudo wget -O /usr/share/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key

# 🔹 Añadir repo
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc]" \
  https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null



# 🔹 Actualizar repositorios e instalar dependencias esenciales
sudo apt update && sudo apt install -y \
    python3 python3-pip python3-venv git sqlite3 curl nginx ansible fontconfig openjdk-17-jre jenkins


KEY_JENKINS_INSTALL=$(sudo cat /var/lib/jenkins/secrets/initialAdminPassword )



# 🔹 Definir la carpeta de instalación
INSTALL_DIR="/opt/deploy_system"
GIT_REPO="https://github.com/josealm22/deploy_system.git"

# 🔹 Clonar el repositorio si no existe
if [ ! -d "$INSTALL_DIR" ]; then
    echo "📥 Clonando el repositorio..."
    git clone $GIT_REPO $INSTALL_DIR
else
    echo "🔄 Actualizando código desde Git..."
    cd $INSTALL_DIR
    git pull origin master
fi

# Cambiar el usuario de carpeta proyecto 

sudo chown -R $USER:$USER /opt/deploy_system



# 🔹 Crear entorno virtual de Python
echo "🐍 Creando entorno virtual..."
python3 -m venv $INSTALL_DIR/venv
source $INSTALL_DIR/venv/bin/activate
pip install -r $INSTALL_DIR/requirements.txt

# 🔹 Inicializar base de datos
echo "📦 Configurando base de datos..."
python3 $INSTALL_DIR/app/database.py

# 🔹 Crear servicio systemd para la API Flask
echo "⚙️ Creando servicio systemd para la API..."
cat <<EOF > /etc/systemd/system/deploy_api.service
[Unit]
Description=API de despliegue Flask
After=network.target

[Service]
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/venv/bin/python3 $INSTALL_DIR/app/app.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# 🔹 Habilitar y reiniciar la API
systemctl daemon-reload
systemctl enable deploy_api
systemctl restart deploy_api

# 🔹 Configurar Nginx para servir `client.ps1`
echo "🌍 Configurando Nginx..."
cat <<EOF > /etc/nginx/sites-available/deploy_system
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }

    location /client.ps1 {
        root /var/www/html;
        autoindex on;
    }
}
EOF

ln -sf /etc/nginx/sites-available/deploy_system /etc/nginx/sites-enabled/
systemctl restart nginx

# 🔹 Generar el script PowerShell con la IP del servidor
SERVER_IP=$(hostname -I | awk '{print $1}')
echo "📝 Generando script PowerShell con IP: $SERVER_IP..."
cat <<EOF > /var/www/html/client.ps1
\$server = "http://$SERVER_IP:5000"
\$hostname = \$env:COMPUTERNAME
\$ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { \$_.InterfaceAlias -notlike "Loopback*" }).IPAddress

# Registrar el equipo en el servidor
\$body = @{ hostname = \$hostname; ip = \$ip } | ConvertTo-Json -Compress
Invoke-RestMethod -Uri "\$server/register_device" -Method Post -Body \$body -ContentType "application/json"

while (\$true) {
    try {
        \$task_url = "\$server/get_task?hostname=\$hostname"
        \$task_response = Invoke-RestMethod -Uri \$task_url -Method Get
        \$task = \$task_response.task

        if (\$task -ne "") {
            Invoke-Expression \$task
        }
    } catch {
        Write-Host "Error al conectar con el servidor: \$_"
    }

    Start-Sleep -Seconds 300
}
EOF

echo "✅ Instalación completada. Accede a la API en: http://$SERVER_IP/"
echo "📥 Descarga el script PowerShell en: http://$SERVER_IP/client.ps1"
echo "    Clave de instalacion Jenkins: $KEY_JENKINS_INSTALL"
