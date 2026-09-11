#!/usr/bin/env bash

# Rutas de archivos (usando rutas absolutas para Rofi)
CONFIG_FILE="$HOME/.config/hypr/monitors_presentation.lua"
MAIN_OUTPUT="desc:AU Optronics 0x4A90"
HDMI_OUTPUT="HDMI-A-1"

# Opciones para el menú
OPC_OFF="󰶐 Deshabilitar HDMI"
OPC_MIRROR="󰶟 Modo Espejo"
OPC_EXTEND="󰶞 Extender Pantalla"

if [ -z "$1" ]; then
    # Listar opciones
    echo -e "$OPC_OFF\n$OPC_MIRROR\n$OPC_EXTEND"
else
    case "$1" in
        "$OPC_OFF")
            # Borra todo el contenido del archivo
            : > "$CONFIG_FILE"
            notify-send "Monitor" "Configuración de monitores limpiada"
            ;;
        "$OPC_MIRROR")
            # Escribe la configuración de espejo
            cat <<EOF > "$CONFIG_FILE"
hl.monitor({
    output = "$HDMI_OUTPUT",
    mirror = "$MAIN_OUTPUT",
    position = "auto",
    scale = 1,
    bitdepth = 8,
    vrr = 1,
})
EOF
            notify-send "Monitor" "Modo Espejo activado"
            ;;
        "$OPC_EXTEND")
            # Escribe la configuración extendida (HDMI a la derecha por defecto)
            cat <<EOF > "$CONFIG_FILE"
hl.monitor({
    output = "$HDMI_OUTPUT",
    mode = "preferred",
    position = "auto",
    scale = 1,
    bitdepth = 8,
    vrr = 1,
})
EOF
            notify-send "Monitor" "Pantalla extendida activada"
            ;;
    esac
fi
