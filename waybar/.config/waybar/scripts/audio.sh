#!/usr/bin/env bash
#
# Waybar custom audio module - default sink status + controls
#
# Usage:
#   audio.sh                -> print waybar JSON status (used as "exec")
#   audio.sh --toggle-mute  -> toggle mute on default sink
#   audio.sh --vol-up       -> raise default sink volume 5%
#   audio.sh --vol-down     -> lower default sink volume 5%

set -euo pipefail

SIGNAL_NUM=8   # must match "signal": 8 in the waybar module config

refresh_waybar() {
    pkill -RTMIN+"${SIGNAL_NUM}" waybar 2>/dev/null || true
}

print_status() {
    local sink vol mute icon class
    sink=$(pactl get-default-sink)
    vol=$(pactl get-sink-volume "$sink" | grep -oP '\d+(?=%)' | head -1)
    mute=$(pactl get-sink-mute "$sink" | awk '{print $2}')

    if [[ "$mute" == "yes" ]]; then
        icon=""
        class="muted"
    else
        class="unmuted"
        if   (( vol >= 66 )); then icon=""
        elif (( vol >= 33 )); then icon=""
        else                       icon=""
        fi
    fi

    jq -nc \
        --arg text "${icon}  ${vol}%" \
        --arg tooltip "Output: ${sink}
Left click: mute   Scroll: volume   Right click: choose output" \
        --arg class "$class" \
        --argjson percentage "$vol" \
        '{text: $text, tooltip: $tooltip, class: $class, percentage: $percentage}'
}

case "${1:-}" in
    --toggle-mute)
        pactl set-sink-mute @DEFAULT_SINK@ toggle
        refresh_waybar
        ;;
    --vol-up)
        pactl set-sink-mute @DEFAULT_SINK@ 0
        pactl set-sink-volume @DEFAULT_SINK@ +5%
        refresh_waybar
        ;;
    --vol-down)
        pactl set-sink-mute @DEFAULT_SINK@ 0
        pactl set-sink-volume @DEFAULT_SINK@ -5%
        refresh_waybar
        ;;
    *)
        print_status
        ;;
esac
