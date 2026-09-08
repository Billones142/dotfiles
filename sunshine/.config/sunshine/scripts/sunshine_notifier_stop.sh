#!/bin/bash
#
# Detiene el notificador de monitores usando el PID que dejo en su pidfile.
#
# No se usa `pkill -f sunshine_check_fisical_monitors.sh`: ese patron tambien
# coincide con la linea de comando del propio shell que ejecuta este `undo`,
# de modo que el comando se mataba a si mismo antes de terminar y el proceso
# objetivo sobrevivia como huerfano.

set -u

PIDFILE="/tmp/monitor_notifier.pid"

if [ ! -f "$PIDFILE" ]; then
    exit 0
fi

PID=$(cat "$PIDFILE" 2>/dev/null)
rm -f "$PIDFILE"

# Sin PID valido no hay nada seguro que matar.
case "$PID" in
    ''|*[!0-9]*) exit 0 ;;
esac

kill "$PID" 2>/dev/null || exit 0

# Espera a que termine; si sigue vivo tras 3 segundos, se fuerza.
for _ in 1 2 3 4 5 6; do
    kill -0 "$PID" 2>/dev/null || exit 0
    sleep 0.5
done

kill -9 "$PID" 2>/dev/null
exit 0
