#!/bin/bash
# Uso: ./video_peek.sh [ID_WORKSPACE]

TARGET_WS=$1

# 1. Crear un monitor virtual temporal específicamente para el preview
# Esto nos asegura que no usamos HEADLESS-2 (el de Sunshine/espejo)
VIRTUAL_MONITOR=$(hyprctl output create headless | grep -o "HEADLESS-[0-9]\+")

# Si falla la creación o no devuelve nombre, intentamos detectar el último HEADLESS creado
if [ -z "$VIRTUAL_MONITOR" ]; then
    VIRTUAL_MONITOR=$(hyprctl monitors -j | jq -r ".[] | select(.name | contains(\"HEADLESS\")) | .name" | sort -V | tail -n 1)
fi

# 2. Obtener el monitor actual (el real) para devolver el workspace luego
CURRENT_MONITOR=$(hyprctl monitors -j | jq -r ".[] | select(.name != \"$VIRTUAL_MONITOR\" and .name != \"HEADLESS-2\" and .focused == true) | .name")
[ -z "$CURRENT_MONITOR" ] && CURRENT_MONITOR=$(hyprctl monitors -j | jq -r ".[] | select(.name != \"$VIRTUAL_MONITOR\" and .name != \"HEADLESS-2\") | .name" | head -n 1)

# 3. Obtener el workspace actual para no perder el foco
CURRENT_WS=$(hyprctl activeworkspace -j | jq -r ".id")

# 4. Mover el workspace objetivo al monitor temporal
hyprctl dispatch moveworkspacetomonitor "$TARGET_WS" "$VIRTUAL_MONITOR"

# 5. Lanzar wl-mirror apuntando al monitor temporal
wl-mirror --title "hypr_video_peek" "$VIRTUAL_MONITOR" &

# 6. Mantener el foco donde estaba el usuario
hyprctl dispatch workspace "$CURRENT_WS"

# 7. Limpieza al cerrar
(
    while pgrep -f "wl-mirror --title hypr_video_peek" > /dev/null; do sleep 1; done
    # Devolver workspace
    hyprctl dispatch moveworkspacetomonitor "$TARGET_WS" "$CURRENT_MONITOR"
    # Eliminar el monitor virtual temporal para no ensuciar la config
    hyprctl output remove "$VIRTUAL_MONITOR"
) &
