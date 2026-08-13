#!/usr/bin/env bash
#
# Waybar custom audio module - right-click submenu
# Lets you set-default and adjust volume for 3 specific sinks.
#
# Find your exact sink names with:  pactl list sinks short
# then edit the SINKS array below (Display Name -> exact sink name).

set -euo pipefail

declare -A SINKS=(
    ["Speakers"]="alsa_output.pci-0000_00_1f.3.analog-stereo"
    ["Headphones"]="alsa_output.usb-Generic_USB_Audio-00.analog-stereo"
    ["HDMI"]="alsa_output.pci-0000_01_00.1.hdmi-stereo"
)

MENU_CMD="rofi -dmenu -i"   # swap for: wofi --dmenu   |   fuzzel --dmenu
SIGNAL_NUM=8

refresh_waybar() {
    pkill -RTMIN+"${SIGNAL_NUM}" waybar 2>/dev/null || true
}

# Step 1: pick which of the 3 sinks
choice=$(printf '%s\n' "${!SINKS[@]}" | $MENU_CMD -p "Audio Output")
[[ -z "${choice:-}" ]] && exit 0
sink="${SINKS[$choice]}"

# Step 2: pick an action for that sink
action=$(printf '%s\n' \
    "Set as default" \
    "Volume 25%" \
    "Volume 50%" \
    "Volume 75%" \
    "Volume 100%" \
    "Volume +5%" \
    "Volume -5%" \
    "Toggle mute" \
    | $MENU_CMD -p "$choice")
[[ -z "${action:-}" ]] && exit 0

case "$action" in
    "Set as default")
        pactl set-default-sink "$sink"
        # optional: move currently-playing streams over to the new default
        pactl list short sink-inputs | awk '{print $1}' | while read -r id; do
            pactl move-sink-input "$id" "$sink"
        done
        ;;
    "Volume 25%")  pactl set-sink-volume "$sink" 25% ;;
    "Volume 50%")  pactl set-sink-volume "$sink" 50% ;;
    "Volume 75%")  pactl set-sink-volume "$sink" 75% ;;
    "Volume 100%") pactl set-sink-volume "$sink" 100% ;;
    "Volume +5%")  pactl set-sink-volume "$sink" +5% ;;
    "Volume -5%")  pactl set-sink-volume "$sink" -5% ;;
    "Toggle mute") pactl set-sink-mute "$sink" toggle ;;
esac

refresh_waybar
