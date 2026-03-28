#!/bin/bash

#hyprctl keyword monitor "HEADLESS-2,${SUNSHINE_CLIENT_WIDTH}x${SUNSHINE_CLIENT_HEIGHT}@${SUNSHINE_CLIENT_FPS},auto,1,bitdepth,8"

NEW_CONFIG="monitor=HEADLESS-2,${SUNSHINE_CLIENT_WIDTH}x${SUNSHINE_CLIENT_HEIGHT}@${SUNSHINE_CLIENT_FPS},auto,1,bitdepth,8"

echo $NEW_CONFIG > $HOME/.config/hypr/monitors_sunshine.conf

#notify-send --expire-time=30000 $NEW_CONFIG

MESSAGE="Applied Sunshine resolution: ${SUNSHINE_CLIENT_WIDTH}x${SUNSHINE_CLIENT_HEIGHT}@${SUNSHINE_CLIENT_FPS}"

echo $MESSAGE
notify-send --expire-time=30000 "Applied Sunshine resolution:" "${SUNSHINE_CLIENT_WIDTH}x${SUNSHINE_CLIENT_HEIGHT}@${SUNSHINE_CLIENT_FPS}"

exit 0
