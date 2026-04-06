#!/bin/bash

# Guardar el ID de la instancia
export HYPRLAND_INSTANCE_SIGNATURE=$(hyprctl instances | awk '/instance/ {print $2}' | tr -d ':')

echo "La instancia actual es: $HYPRLAND_INSTANCE_SIGNATURE"
