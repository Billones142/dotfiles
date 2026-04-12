#!/bin/bash
# Esperar un momento a que Hyprland arranque bien
sleep 2

# Matar todo lo que se mueva
killall -e xdg-desktop-portal-hyprland
killall -e xdg-desktop-portal-wlr
killall -e xdg-desktop-portal-gnome
killall -e xdg-desktop-portal-kde
killall -e xdg-desktop-portal

# IMPORTANTE: Asegurar que las variables existen antes de importarlas
# (A veces fallan si dbus no está listo)
export XDG_CURRENT_DESKTOP=Hyprland
export XDG_SESSION_TYPE=wayland
export XDG_SESSION_DESKTOP=Hyprland

# Importar al entorno de systemd (Vital para que los servicios sepan dónde dibujar)
systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XDG_SESSION_DESKTOP
dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XDG_SESSION_DESKTOP

# Esperar a que la importación termine
sleep 1

# Iniciar el backend de Hyprland primero (con debug para ver si revive)
/usr/lib/xdg-desktop-portal-hyprland &

# Esperar a que el backend se registre
sleep 2

# Iniciar el portal maestro
/usr/lib/xdg-desktop-portal &
