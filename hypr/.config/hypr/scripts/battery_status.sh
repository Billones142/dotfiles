#!/bin/bash

# Find the first battery device
BAT=$(ls /sys/class/power_supply/ | grep BAT | head -n 1)

if [ -n "$BAT" ]; then
    percentage=$(cat /sys/class/power_supply/$BAT/capacity)
    status=$(cat /sys/class/power_supply/$BAT/status)
    
    # Determine icon based on status and percentage
    if [ "$status" = "Charging" ]; then
        icon="󰂄"
    else
        if [ "$percentage" -ge 90 ]; then icon="󰁹";
        elif [ "$percentage" -ge 80 ]; then icon="󰂁";
        elif [ "$percentage" -ge 70 ]; then icon="󰂀";
        elif [ "$percentage" -ge 60 ]; then icon="󰁿";
        elif [ "$percentage" -ge 50 ]; then icon="󰁾";
        elif [ "$percentage" -ge 40 ]; then icon="󰁽";
        elif [ "$percentage" -ge 30 ]; then icon="󰁼";
        elif [ "$percentage" -ge 20 ]; then icon="󰁻";
        elif [ "$percentage" -ge 10 ]; then icon="󰁺";
        else icon="󰂃"; fi
    fi
    
    echo "$icon $percentage%"
fi
