#!/bin/bash

# Check if kdeconnect-cli is available
if ! command -v kdeconnect-cli &> /dev/null; then
    exit 0
fi

# Get reachable devices
devices=$(kdeconnect-cli -a --name-only 2>/dev/null)

if [ -n "$devices" ]; then
    # Format devices into a single line or multiple if needed, here we'll join them
    echo "󰄜 $(echo "$devices" | tr '\n' ' ' | sed 's/ $//')"
fi
