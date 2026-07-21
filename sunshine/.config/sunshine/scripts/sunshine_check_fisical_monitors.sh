#!/bin/bash

# 1. Asegurar instancia única usando un Lockfile
LOCKFILE="/tmp/monitor_notifier.lock"

# Si el lockfile existe y el PID dentro sigue activo, salir
if [ -f "$LOCKFILE" ]; then
    PID=$(cat "$LOCKFILE")
    if ps -p "$PID" > /dev/null; then
        echo "El script ya está corriendo con PID $PID"
        exit 1
    fi
fi

# Guardar el PID actual en el lockfile
echo $$ > "$LOCKFILE"

# Función de limpieza al salir
cleanup() {
    rm -f "$LOCKFILE"
    exit 0
}
trap cleanup SIGINT SIGTERM EXIT

# Ruta al socket de eventos de Hyprland
HYPR_SOCKET="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"

# Función para procesar los eventos
process_event() {
    # El evento monitoradded viene en formato: monitoradded>>NAME
    if [[ $1 == monitoradded* ]]; then
        monitor_name=$(echo "$1" | cut -d'>' -f3)
        
        # Si el nombre NO contiene HEADLESS
        if [[ ! "$monitor_name" =~ "HEADLESS" ]]; then
            notify-send "Monitor Físico Detectado" "Se ha conectado: $monitor_name" --expire-time=0 --icon=display
            # Aquí podrías añadir lógica extra para Sunshine si lo deseas
        fi
    fi

    if [[ $1 == monitorremoved* ]]; then
        monitor_name=$(echo "$1" | cut -d'>' -f3)
        
        # Si el nombre NO contiene HEADLESS
        if [[ ! "$monitor_name" =~ "HEADLESS" ]]; then
            notify-send "Monitor Físico Desconectado" "Se ha desconectado: $monitor_name" --expire-time=0 --icon=display
            # Aquí podrías añadir lógica extra para Sunshine si lo deseas
        fi
    fi
}

# Escuchar el socket de forma continua
socat -U - "UNIX-CONNECT:$HYPR_SOCKET" | while read -r line; do
    process_event "$line"
done
