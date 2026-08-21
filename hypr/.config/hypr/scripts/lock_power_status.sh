#!/bin/bash

# Prints the live countdown text for a pending power action, or nothing if none is pending.
# Read by hyprlock.conf as a cmd[update:1000] label.

STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/hyprlock_power/pending"

[ -f "$STATE_FILE" ] || exit 0

read -r action end < "$STATE_FILE"
remaining=$((end - $(date +%s)))
[ "$remaining" -gt 0 ] || exit 0

case "$action" in
    poweroff) icon="󰐥"; text="Apagando" ;;
    reboot)   icon="󰜉"; text="Reiniciando" ;;
    logout)   icon="󰍃"; text="Cerrando sesión" ;;
    *) exit 0 ;;
esac

echo "$icon $text en ${remaining}s — click de nuevo para cancelar"
