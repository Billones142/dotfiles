#!/bin/bash

sed -i '/HEADLESS-2/d' $HOME/.config/hypr/monitors_sunshine.conf

#notify-send --expire-time=30000 "Sunshine" "Original resolution restored" 

exit 0
