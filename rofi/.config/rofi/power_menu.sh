#!/usr/bin/env bash

# Definimos las opciones
OPC_POWEROFF="󰐥 Apagar"
OPC_REBOOT="󰜉 Reiniciar"
OPC_LOGOUT="󰍃 Cerrar Sesión"
OPC_SUSPEND="󰤄 Suspender"
OPC_SWITCH="󰍉 Cambiar Usuario"

if [ -z "$1" ]; then
    # Listar opciones para Rofi
    echo -e "$OPC_POWEROFF\n$OPC_REBOOT\n$OPC_LOGOUT\n$OPC_SUSPEND\n$OPC_SWITCH"
else
    # Ejecutar acción según la selección
    case "$1" in
        "$OPC_POWEROFF")
            hyprshutdown --post-cmd "systemctl poweroff"
            ;;
        "$OPC_REBOOT")
            hyprshutdown --post-cmd "systemctl reboot"
            ;;
        "$OPC_LOGOUT")
            hyprshutdown
            ;;
        "$OPC_SUSPEND")
            # Ejemplo de uso de --post-cmd para bloquear antes de suspender
            systemctl hybrid-sleep
            ;;
        "$OPC_SWITCH")
            # Comando estándar para volver al gestor de entrada (GDM/SDDM)
            dm-tool switch-to-greeter || loginctl lock-session
            ;;
    esac
fi
