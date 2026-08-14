#!/bin/bash

# Este script copia las configuraciones de inputplumber a los directorios del sistema.
# Requiere privilegios de administrador.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🔧 Instalando perfiles de InputPlumber..."
sudo mkdir -p /etc/inputplumber/profiles
sudo cp "$SCRIPT_DIR/profiles/ds4_mode.yaml" /etc/inputplumber/profiles/ds4_mode.yaml
sudo cp "$SCRIPT_DIR/profiles/ds5_mode.yaml" /etc/inputplumber/profiles/ds5_mode.yaml
sudo cp "$SCRIPT_DIR/profiles/xbox_mode.yaml" /etc/inputplumber/profiles/xbox_mode.yaml

echo "🔧 Configurando perfil DS4Passthrough como perfil predeterminado..."
sudo cp "$SCRIPT_DIR/profiles/ds4_mode.yaml" /usr/share/inputplumber/profiles/default.yaml
sudo cp "$SCRIPT_DIR/profiles/ds4_mode.yaml" /etc/inputplumber/profiles/default.yaml


echo "🔧 Instalando configuración del dispositivo (DualShock 4)..."
sudo mkdir -p /etc/inputplumber/devices.d
sudo cp "$SCRIPT_DIR/devices.d/60-ps4_gamepad.yaml" /etc/inputplumber/devices.d/60-ps4_gamepad.yaml

echo "🔧 Instalando mapa de capacidades del panel táctil..."
sudo mkdir -p /etc/inputplumber/capability_maps
sudo cp "$SCRIPT_DIR/capability_maps/ds4_touchpad.yaml" /etc/inputplumber/capability_maps/ds4_touchpad.yaml

echo "🔧 Instalando pacman hook para que persista tras actualizaciones..."
sudo mkdir -p /etc/pacman.d/hooks
sudo cp "$SCRIPT_DIR/hooks/inputplumber-profile.hook" /etc/pacman.d/hooks/inputplumber-profile.hook

echo "🔧 Instalando regla de udev para ocultar mando físico..."
sudo cp "$SCRIPT_DIR/udev/99-hide-physical-ds4.rules" /etc/udev/rules.d/99-hide-physical-ds4.rules
sudo udevadm control --reload-rules
sudo udevadm trigger

echo "🔄 Reiniciando el servicio de InputPlumber..."
sudo systemctl restart inputplumber

echo "✅ Instalación completada correctamente."


