#!/bin/bash

# 1. Avisar al usuario (opcional, requiere libnotify)
notify-send "Apagando..." "Cerrando aplicaciones suavemente"

# 2. Enviar señal SIGTERM a todo lo que sea tuyo (excepto el script mismo)
# Esto le dice a Brave, Discord, Steam: "Por favor, guarda y cierra".
pkill -TERM -u $USER

# 3. Esperar un momento de seguridad para que escriban en disco (Buffer flush)
# Brave suele tardar entre 1 y 2 segundos en liberar el bloqueo de SQLite.
sleep 3

# 4. Ahora sí, decirle al sistema que corte la energía
systemctl poweroff
