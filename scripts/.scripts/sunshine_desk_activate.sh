#!/bin/bash

# aplicar a .conf
#NEW_CONFIG="monitor=HEADLESS-2,${SUNSHINE_CLIENT_WIDTH}x${SUNSHINE_CLIENT_HEIGHT}@${SUNSHINE_CLIENT_FPS},auto,1,bitdepth,8"

# aplicar a .lua
NEW_CONFIG='monitorv2{output="virtual-fallback-display",mode=${SUNSHINE_CLIENT_WIDTH}x${SUNSHINE_CLIENT_HEIGHT}@${SUNSHINE_CLIENT_FPS}bitdepth=8}'

echo $NEW_CONFIG > $HOME/.config/hypr/monitors_sunshine.lua

#notify-send --expire-time=30000 $NEW_CONFIG

MESSAGE="Applied Sunshine resolution: ${SUNSHINE_CLIENT_WIDTH}x${SUNSHINE_CLIENT_HEIGHT}@${SUNSHINE_CLIENT_FPS}"

echo $MESSAGE
notify-send --expire-time=30000 "Applied Sunshine resolution:" "${SUNSHINE_CLIENT_WIDTH}x${SUNSHINE_CLIENT_HEIGHT}@${SUNSHINE_CLIENT_FPS}"

exit 0
