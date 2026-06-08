#!/bin/bash

sed -i '/virtual-fallback-display/d' $HOME/.config/hypr/monitors_sunshine.lua

#notify-send --expire-time=30000 "Sunshine" "Original resolution restored" 

exit 0
