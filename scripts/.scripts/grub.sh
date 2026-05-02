#!/bin/bash

echo "🤖 Leyendo configuración de GRUB..."
CFG="/boot/grub/grub.cfg"

# 1. Extraer nombres de Entradas y Submenús
# CAMBIO TÁCTICO: Usamos un regex híbrido en awk.
# - '^(menuentry|submenu)' : Captura entradas principales (Nivel 0, sin indentar).
# - 'UEFI Firmware Settings' : Captura la opción UEFI explícitamente, aunque esté indentada (dentro de un if).
mapfile -t GRUB_KEYS < <(awk -F\' '/^(menuentry|submenu)|UEFI Firmware Settings/ {print $2}' "$CFG")

# 2. Mostrar opciones al usuario
echo "--------------------------------"
count=0
for entry in "${GRUB_KEYS[@]}"; do
    echo "[$count] $entry"
    ((count++))
done
echo "--------------------------------"

# 3. Leer selección
read -p "Ingrese el número de la opción deseada: " OPTION_INDEX

# Validar que sea un número y esté en rango
if [[ ! "$OPTION_INDEX" =~ ^[0-9]+$ ]] || [ "$OPTION_INDEX" -ge "${#GRUB_KEYS[@]}" ]; then
    echo "❌ Opción inválida."
    exit 1
fi

# Obtener el nombre real asociado al número
SELECTED_ENTRY="${GRUB_KEYS[$OPTION_INDEX]}"

echo "✅ Seleccionado: '$SELECTED_ENTRY'"

# 4. Aplicar y Reiniciar
# Usamos sudo porque grub-reboot requiere root
sudo grub-reboot "$SELECTED_ENTRY"
# Cambia el timeout de manera temporal a 0
sudo grub-editenv - set temp_timeout=0

read -p "¿Reiniciar ahora? [S/n]: " CONFIRM
if [[ "$CONFIRM" =~ ^[sS]$ || -z "$CONFIRM" ]]; then
    if hyprctl status; then
        #echo command returned true
        hyprshutdown --post-cmd "systemctl reboot"
    else
	systemctl reboot
fi
fi
