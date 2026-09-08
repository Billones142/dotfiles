#!/bin/bash
#
# Notifica en el escritorio cuando se conecta o desconecta un monitor fisico,
# escuchando el socket de eventos de Hyprland. Los outputs virtuales/headless
# se ignoran porque los crea el propio flujo de Sunshine.
#
# Instancia unica via flock: el kernel libera el lock cuando el proceso muere,
# asi que un huerfano no deja un lock obsoleto. El esquema anterior guardaba un
# PID en el archivo y lo validaba con `ps -p`, pero si el archivo quedaba vacio
# la comprobacion no fallaba y cada arranque acumulaba otra copia.

set -u

LOCKFILE="/tmp/monitor_notifier.lock"
PIDFILE="/tmp/monitor_notifier.pid"
FIFO=""
SOCAT_PID=""

exec 9>"$LOCKFILE" || { echo "No se pudo abrir $LOCKFILE" >&2; exit 1; }
if ! flock -n 9; then
    echo "El notificador de monitores ya esta corriendo" >&2
    exit 0
fi

command -v socat >/dev/null 2>&1 || { echo "Falta socat" >&2; exit 1; }

if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    echo "HYPRLAND_INSTANCE_SIGNATURE no definida: no hay sesion Hyprland" >&2
    exit 1
fi

HYPR_SOCKET="${XDG_RUNTIME_DIR}/hypr/${HYPRLAND_INSTANCE_SIGNATURE}/.socket2.sock"
[ -S "$HYPR_SOCKET" ] || { echo "Socket de eventos no encontrado: $HYPR_SOCKET" >&2; exit 1; }

# socat corre en segundo plano y vuelca a un FIFO, en vez de por una tuberia.
# Asi el bucle de lectura se queda en el shell principal (no en un subshell) y
# su PID queda accesible para poder matarlo en la limpieza.
cleanup() {
    [ -n "$SOCAT_PID" ] && kill "$SOCAT_PID" 2>/dev/null
    [ -n "$FIFO" ] && rm -f "$FIFO"
    rm -f "$PIDFILE"
}
trap cleanup EXIT
trap 'exit 0' INT TERM

FIFO=$(mktemp -u "/tmp/monitor_notifier.XXXXXXXX.fifo")
mkfifo "$FIFO" || { echo "No se pudo crear el FIFO $FIFO" >&2; exit 1; }

echo $$ > "$PIDFILE"

# Descarta los outputs que no corresponden a hardware real.
es_monitor_fisico() {
    case "$1" in
        *HEADLESS*|virtual-fallback-display) return 1 ;;
        *) return 0 ;;
    esac
}

# Los eventos llegan como: monitoradded>>NOMBRE
process_event() {
    local event="$1" nombre titulo

    case "$event" in
        monitoradded*)   titulo="Monitor Fisico Detectado" ;;
        monitorremoved*) titulo="Monitor Fisico Desconectado" ;;
        *) return ;;
    esac

    nombre="${event#*>>}"
    [ -n "$nombre" ] || return
    es_monitor_fisico "$nombre" || return

    notify-send "$titulo" "$nombre" --expire-time=0 --icon=display
}

socat -U - "UNIX-CONNECT:$HYPR_SOCKET" > "$FIFO" &
SOCAT_PID=$!

while read -r line; do
    process_event "$line"
done < "$FIFO"
