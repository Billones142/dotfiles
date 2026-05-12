#!/bin/bash

# Este script procesa el estado de autenticación para hyprlock
# Recibe las variables de hyprlock como argumentos

FAIL_MSG="$1"      # $FAIL
FPRINT_MSG="$2"    # $FPRINTPROMPT
ATTEMPTS="$3"      # $ATTEMPTS

# Verificar si fprintd está disponible y tiene huellas para el usuario
HAS_FPRINT=false
if command -v fprintd-list > /dev/null 2>&1; then
    if fprintd-list "$USER" | grep -q "Fingerprints for user"; then
        HAS_FPRINT=true
    fi
fi

# Definir el icono base
if $HAS_FPRINT; then
    ICON="󰈟"
else
    ICON="󰌾"
fi

# Lógica de salida
if [ -n "$FAIL_MSG" ] && [ "$FAIL_MSG" != "null" ] && [ "$FAIL_MSG" != "" ]; then
    # Priorizar mensaje de error/bloqueo
    if [[ "$FAIL_MSG" =~ ([0-9]+)\ (seconds|segundos) ]]; then
        TIME="${BASH_REMATCH[1]}"
        echo "󰌾 Bloqueado: $TIME seg"
    else
        echo "󰚭 $FAIL_MSG ($ATTEMPTS)"
    fi
elif [ "$ATTEMPTS" -gt 0 ]; then
    # Si hay intentos pero no hay un mensaje de error actual (esperando reintento)
    if $HAS_FPRINT && [ -n "$FPRINT_MSG" ] && [ "$FPRINT_MSG" != "null" ]; then
        echo "$ICON $FPRINT_MSG ($ATTEMPTS)"
    else
        echo "󰚭 Reintenta... ($ATTEMPTS)"
    fi
else
    # Estado normal
    if $HAS_FPRINT && [ -n "$FPRINT_MSG" ] && [ "$FPRINT_MSG" != "null" ]; then
        echo "$ICON $FPRINT_MSG"
    else
        echo "$ICON Esperando contraseña..."
    fi
fi
