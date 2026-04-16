#!/bin/bash

IP_LOCAL="192.168.100.10"
MAC_CONOCIDA="a8:a1:59:8b:f8:08"
FINGERPRINT="SHA256:RGA+yRpGga5ythJ4kfFJbsq6kh2eX1SkG6QMHqvJwsE"

# 1. Verificación de Capa 2 (MAC Address)
# Buscamos en la tabla ARP la MAC asociada a la IP local
if ip neighbor show "$IP_LOCAL" | grep -qi "$MAC_CONOCIDA"; then
    
    # 2. Verificación de Capa 7 (SSH Fingerprint)
    # Si la MAC coincide, confirmamos la identidad criptográfica
    if ssh-keyscan -t ed25519 "$IP_LOCAL" 2>/dev/null | ssh-keygen -lf - | grep -q "$FINGERPRINT"; then
        echo "truenas_local"
        exit 0
    fi
fi

# Fallback: Si la MAC no coincide o el SSH falla, usamos Tailscale
echo "truenas_tailscale"
exit 1
