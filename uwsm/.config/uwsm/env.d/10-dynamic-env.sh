#!/usr/bin/env bash

MACHINE_ID=$(cat /etc/machine-id)

# Configuraciones específicas por máquina
case "$MACHINE_ID" in
    "6503f1a4984e4725abb0e8938c245cbd") # gamer
        echo "## Configuración para Desktop"
	echo "UWSM_PERFIL=gamer" # para poder debugear si es necesario

        # Si usas una ID de GPU fija para MangoHud en la de escritorio
        echo "MANGOHUD_CONFIG=pci_dev=0000:01:00.0" 
	echo "DXVK_FILTER_DEVICE_NAME='NVIDIA GeForce RTX 3090'"
        ;;
    "2ce56e0901cd4d70b3e88ac4dd5920ee") # Dell Latitude 7430
        echo "## Configuración para Laptop"
	echo "UWSM_PERFIL=laptop-dell"

        echo "MANGOHUD_CONFIG=pci_dev=0000:02:00.0" 
        echo "MOZ_ENABLE_WAYLAND=1"
        echo "QT_SCALE_FACTOR=1"
        # Forzar que Brave use Wayland nativo para evitar lags de scroll
        echo "ELECTRON_OZONE_PLATFORM_HINT=auto"
	echo "DXVK_FILTER_DEVICE_NAME='Intel(R) Iris(R) Xe Graphics (ADL GT2)'"
        ;;
esac
