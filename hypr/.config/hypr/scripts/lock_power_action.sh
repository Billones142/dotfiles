#!/bin/bash

# Countdown + cancel wrapper for the hyprlock power buttons (poweroff/reboot/logout).
# First click starts a 30s countdown; clicking the same button again cancels it;
# clicking a different power button cancels the pending one and starts a new countdown.
#
# Usage: lock_power_action.sh <poweroff|reboot|logout>
#        lock_power_action.sh --fire <poweroff|reboot|logout>   (internal, runs after the countdown)

STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/hyprlock_power"
STATE_FILE="$STATE_DIR/pending"
PID_FILE="$STATE_DIR/pgid"
DELAY=30

run_action() {
    case "$1" in
        poweroff) hyprshutdown --post-cmd "systemctl poweroff" ;;
        reboot)   hyprshutdown --post-cmd "systemctl reboot" ;;
        logout)   hyprshutdown ;;
    esac
}

if [ "$1" = "--fire" ]; then
    run_action "$2"
    exit 0
fi

action="$1"
case "$action" in
    poweroff|reboot|logout) ;;
    *) exit 1 ;;
esac

mkdir -p "$STATE_DIR"

if [ -f "$STATE_FILE" ]; then
    pending_action=$(awk '{print $1}' "$STATE_FILE")
    [ -f "$PID_FILE" ] && kill -- "-$(cat "$PID_FILE")" 2>/dev/null
    rm -f "$STATE_FILE" "$PID_FILE"
    [ "$pending_action" = "$action" ] && exit 0
fi

echo "$action $(($(date +%s) + DELAY))" > "$STATE_FILE"

setsid bash -c "sleep $DELAY; rm -f '$STATE_FILE' '$PID_FILE'; '$0' --fire '$action'" >/dev/null 2>&1 &
echo $! > "$PID_FILE"
