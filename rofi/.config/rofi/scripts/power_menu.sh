#!/usr/bin/env bash

# Definimos las opciones
OPC_POWEROFF="󰐥 Apagar"
OPC_REBOOT="󰜉 Reiniciar"
OPC_SOFTREBOOT="󰜉 Reinicio rapido"
OPC_LOGOUT="󰍃 Cerrar Sesión"
OPC_SUSPEND="󰤄 Suspender"
OPC_SWITCH="󰍉 Cambiar Usuario"

hyprshutdown_command () {
  setsid hyprshutdown  --top-label "$1" --post-cmd "$2" > /dev/null 2>&1 &
}

if [ -z "$1" ]; then
    # Listar opciones para Rofi
    echo -e "$OPC_POWEROFF\n$OPC_REBOOT\n$OPC_SOFTREBOOT\n$OPC_LOGOUT\n$OPC_SUSPEND\n$OPC_SWITCH"
else
    #pkill rofi
    # Ejecutar acción según la selección
    case "$1" in
        "$OPC_POWEROFF")
	    (hyprshutdown_command "Shutting down..." "systemctl poweroff")
            ;;
        "$OPC_REBOOT")
	    (hyprshutdown_command "Rebooting..." "systemctl reboot")
            ;;
        "$OPC_SODTREBOOT")
	    (hyprshutdown_command "Rebooting..." "systemctl soft-reboot")
            ;;
        "$OPC_LOGOUT")
	    (hyprshutdown_command "Loging out..." "")
            ;;
        "$OPC_SUSPEND")
            # Ejemplo de uso de --post-cmd para bloquear antes de suspender
            systemctl hybrid-sleep &
            #systemctl suspend-then-hibernate &
            ;;
        "$OPC_SWITCH")
            loginctl lock-session ; busctl call org.freedesktop.DisplayManager /org/freedesktop/DisplayManager/Seat0 org.freedesktop.DisplayManager.Seat SwitchToGreeter
            ;;
    esac
    exit 0
fi
