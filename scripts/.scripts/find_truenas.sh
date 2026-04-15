#!/bin/bash
IP_LOCAL="192.168.100.10"  # Tu IP de casa
IP_TAILSCALE="100.67.110.117"   # Tu IP de Tailscale

if ping -c 1 -W 1 "$IP_LOCAL" > /dev/null; then
    echo "$IP_LOCAL"
elif ping -c 1 -W 1 "$IP_TAILSCALE" > /dev/null; then
    echo "$IP_TAILSCALE"
else
    exit 1 # Falla si no encuentra ninguna
fi
