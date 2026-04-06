#!/bin/bash
#sudo sddm-helper --start /usr/share/wayland-sessions/uwsm-hyprland.desktop --user $USER
# este va a estar en /usr/local/bin/remote-login.sh

# 1. Backup de seguridad
sudo cp /etc/sddm.conf /etc/sddm.conf.bak

# Detectar el usuario real incluso bajo sudo
REAL_USER=${SUDO_USER:-$(logname)}

# 2. Modificar las líneas existentes en el archivo principal
# Buscamos 'User=' y lo reemplazamos por 'User=tu_usuario', etc.
sudo sed -i "s/^User=.*/User=$REAL_USER/" /etc/sddm.conf
sudo sed -i "s/^Session=.*/Session=hyprland-uwsm.desktop/" /etc/sddm.conf

echo "Reiniciando SDDM para logueo remoto..."
sudo systemctl restart sddm

# 3. Esperar a que Sunshine/Hyprland levanten
echo "Esperando 5 segundos..."
sleep 5

echo "Reiniciando sunshine..."
systemctl --user restart sunshine.service

# 4. Restaurar el archivo original (deja las líneas vacías otra vez)
sudo mv /etc/sddm.conf.bak /etc/sddm.conf
echo "Configuración original restaurada. La sesión debería estar activa."
loginctl list-sessions --output=cat
