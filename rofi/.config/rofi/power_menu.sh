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
    #pkill rofi
    # Ejecutar acción según la selección
    case "$1" in
        "$OPC_POWEROFF")
	    (setsid hyprshutdown  --top-label "Shutting down..." --post-cmd "systemctl poweroff" > /dev/null 2>&1 &)
            ;;
        "$OPC_REBOOT")
	    (setsid hyprshutdown --top-label "Rebooting..." --post-cmd "systemctl reboot" > /dev/null 2>&1 &)
            ;;
        "$OPC_LOGOUT")
	    (setsid hyprshutdown  --top-label "Loging out..." > /dev/null 2>&1 &)
            ;;
        "$OPC_SUSPEND")
            # Ejemplo de uso de --post-cmd para bloquear antes de suspender
            #systemctl hybrid-sleep &
            systemctl suspend-then-hibernate &
            ;;
        "$OPC_SWITCH")
            # Comando estándar para volver al gestor de entrada (GDM/SDDM)
            dm-tool switch-to-greeter || loginctl lock-session &
            ;;
    esac
    exit 0
fi
