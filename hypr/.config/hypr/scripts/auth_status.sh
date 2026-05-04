#!/bin/bash

# Este script procesa el estado de autenticación para hyprlock
# Recibe las variables de hyprlock como argumentos

FAIL_MSG="$1"      # $FAIL
FPRINT_MSG="$2"    # $FPRINTPROMPT
ATTEMPTS="$3"      # $ATTEMPTS

# Si hay un error de contraseña
if [ -n "$FAIL_MSG" ] && [ "$FAIL_MSG" != "null" ] && [ "$FAIL_MSG" != "" ]; then
    if [[ "$FAIL_MSG" =~ ([0-9]+)\ (seconds|segundos) ]]; then
        TIME="${BASH_REMATCH[1]}"
        echo "󰌾 Bloqueado: Reintenta en $TIME seg"
    else
        echo "󰚭 $FAIL_MSG ($ATTEMPTS)"
    fi
    exit 0
fi

# Si no hay error, pero hay intentos previos
if [ "$ATTEMPTS" -gt 0 ]; then
    if [ -n "$FPRINT_MSG" ] && [ "$FPRINT_MSG" != "null" ]; then
        echo "󰈟 $FPRINT_MSG ($ATTEMPTS)"
    else
        echo "󰌾 Reintenta... ($ATTEMPTS)"
    fi
else
    # Estado normal
    if [ -n "$FPRINT_MSG" ] && [ "$FPRINT_MSG" != "null" ]; then
        echo "󰈟 $FPRINT_MSG"
    else
        echo "󰌾 Esperando huella o contraseña..."
    fi
fi
