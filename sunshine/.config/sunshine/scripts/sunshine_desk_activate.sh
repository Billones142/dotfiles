#!/bin/bash

SUNSHINE_CLIENT_WIDTH="${SUNSHINE_CLIENT_WIDTH:-1920}"
SUNSHINE_CLIENT_HEIGHT="${SUNSHINE_CLIENT_HEIGHT:-1080}"
SUNSHINE_CLIENT_FPS="${SUNSHINE_CLIENT_FPS:-60}"

# aplicar a .lua
NEW_CONFIG="hl.monitor({output='virtual-fallback-display',mode='${SUNSHINE_CLIENT_WIDTH}x${SUNSHINE_CLIENT_HEIGHT}@${SUNSHINE_CLIENT_FPS}',bitdepth=8})"

echo $NEW_CONFIG > $HOME/.config/hypr/monitors_sunshine.lua

#notify-send --expire-time=30000 $NEW_CONFIG

MESSAGE="Applied Sunshine resolution: ${SUNSHINE_CLIENT_WIDTH}x${SUNSHINE_CLIENT_HEIGHT}@${SUNSHINE_CLIENT_FPS}"

echo $MESSAGE
notify-send --expire-time=30000 "Sunshine" "$MESSAGE"

exit 0
