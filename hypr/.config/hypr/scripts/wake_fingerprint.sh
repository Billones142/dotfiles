#!/bin/bash

# Broadcom BCM58200 ControlVault 3
ID_VENDOR="0a5c"
ID_PRODUCT="5843"

# Buscar el dispositivo en /sys
for dev in /sys/bus/usb/devices/*; do
    if [ -f "$dev/idVendor" ] && [ -f "$dev/idProduct" ]; then
        v=$(cat "$dev/idVendor")
        p=$(cat "$dev/idProduct")
        if [ "$v" == "$ID_VENDOR" ] && [ "$p" == "$ID_PRODUCT" ]; then
            DEV_PATH="$dev"
            break
        fi
    fi
done

if [ -n "$DEV_PATH" ]; then
    # Forzar encendido para despertar al sensor
    echo "on" | sudo tee "$DEV_PATH/power/control" > /dev/null
    # Un pequeño delay para que fprintd lo reconozca
    sleep 0.2
    # Devolverlo a auto para que el kernel gestione el ahorro si es necesario
    echo "auto" | sudo tee "$DEV_PATH/power/control" > /dev/null
fi
