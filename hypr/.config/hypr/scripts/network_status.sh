#!/bin/bash

# Get the active interface and its type
active_iface=$(ip route | grep '^default' | awk '{print $5}' | head -n 1)

if [ -z "$active_iface" ]; then
    echo "󰤮 No Network"
    exit 0
fi

# Check if it's wifi
if [[ "$active_iface" == wlan* ]]; then
    ssid=$(iwgetid -r)
    if [ -z "$ssid" ]; then
        # Fallback if iwgetid fails
        ssid=$(nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d: -f2)
    fi
    echo "󰤨 $ssid"
else
    # Assume ethernet/wired
    echo "󰈀 Wired"
fi
