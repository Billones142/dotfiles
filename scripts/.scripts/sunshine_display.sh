#!/bin/bash

# --- CONFIGURACIÓN DE DEPURACIÓN ---
# Usamos /tmp para garantizar que SIEMPRE se pueda escribir, sin depender de $HOME
LOG_FILE="/tmp/sunshine_script.log"

# Modo debug (set -x) desactivado por defecto en daemon para no llenar el disco
# Lo activamos dinámicamente si no es modo daemon
if [ "$1" != "daemon" ]; then
    set -x
    exec 1>>"$LOG_FILE" 2>&1
fi

# --- CONFIGURACIÓN SWAY ---
REAL_MONITOR="DP-3" 
RES="1920x1080@60Hz"

# --- FIX DE ENTORNO (PATH) ---
export PATH="/usr/local/bin:/usr/bin:/bin:$PATH"

# --- FIX DE SWAYSOCK (Auto-detect) ---
ensure_socket() {
    if [ -z "$SWAYSOCK" ] || [ ! -S "$SWAYSOCK" ]; then
        USER_ID=$(id -u)
        # Buscar sockets vivos
        FOUND_SOCK=$(find /run/user/"$USER_ID"/ -name "sway-ipc.*.sock" -print -quit 2>/dev/null)
        if [ -n "$FOUND_SOCK" ]; then
            export SWAYSOCK="$FOUND_SOCK"
        fi
    fi
}

ensure_socket

# --- FUNCIONES ---
get_headless_monitors() {
    swaymsg -t get_outputs | jq -r '.[] | select(.name | startswith("HEADLESS-")) | .name'
}

# --- LÓGICA PRINCIPAL ---
case "$1" in
    daemon)
        # MODO CENTINELA: Se ejecuta en background desde Sway
        # Vigila si nos quedamos sin monitores y actúa.
        echo "$(date): 🛡️ Centinela iniciado." >> "$LOG_FILE"
        
        while true; do
            ensure_socket
            
            # Obtener estado actual
            OUTPUTS_JSON=$(swaymsg -t get_outputs 2>/dev/null)
            if [ $? -ne 0 ]; then
                sleep 5
                continue
            fi
            
            NUM_OUTPUTS=$(echo "$OUTPUTS_JSON" | jq 'length')
            HAS_REAL=$(echo "$OUTPUTS_JSON" | jq -r ".[] | select(.name == \"$REAL_MONITOR\") | .active")
            HEADLESS_LIST=$(echo "$OUTPUTS_JSON" | jq -r '.[] | select(.name | startswith("HEADLESS-")) | .name')

            # CASO 1: EMERGENCIA (0 Monitores) -> Crear Virtual YA
            if [ "$NUM_OUTPUTS" -eq 0 ]; then
                echo "$(date): 🚨 0 Monitores detectados. Creando virtual de rescate..." >> "$LOG_FILE"
                swaymsg create_output
                # Configurar el nuevo (cualquiera que sea su nombre)
                NEW_HEADLESS=$(swaymsg -t get_outputs | jq -r '.[] | select(.name | startswith("HEADLESS-")) | .name' | tail -n 1)
                if [ -n "$NEW_HEADLESS" ]; then
                    swaymsg output "$NEW_HEADLESS" resolution "$RES" position 1920 0
                    swaymsg workspace 1 output "$NEW_HEADLESS"
                fi
                
            # CASO 2: LIMPIEZA (Monitor Real volvió + Virtual existe) -> Borrar Virtual
            elif [ "$HAS_REAL" == "true" ] && [ -n "$HEADLESS_LIST" ]; then
                echo "$(date): ✅ Monitor real volvió. Eliminando virtuales..." >> "$LOG_FILE"
                for h in $HEADLESS_LIST; do
                    swaymsg output "$h" unplug
                done
                swaymsg output "$REAL_MONITOR" position 0 0
                swaymsg workspace 1 output "$REAL_MONITOR"
            fi

            sleep 5
        done
        ;;

    start)
        # Mantenemos 'start' para compatibilidad manual, pero ahora 
        # el trabajo pesado lo hace el daemon.
        # Si el daemon está corriendo, 'start' solo verifica y sale.
        echo ">>> START (Manual Trigger) <<<"
        ensure_socket
        
        # Misma lógica: Si no hay monitores, crear uno (por si el daemon no corrió)
        NUM_OUTPUTS=$(swaymsg -t get_outputs | jq 'length')
        
        if [ "$NUM_OUTPUTS" -eq 0 ]; then
             echo "Forzando creación manual..."
             swaymsg create_output
             sleep 1
             # Configurar
             NEW=$(get_headless_monitors | tail -n 1)
             swaymsg output "$NEW" resolution "$RES"
        fi
        
        echo "✅ Listo para Sunshine."
        exit 0
        ;;
        
    stop)
        # El modo stop manual ya no es crítico si usamos el daemon,
        # pero lo mantenemos para forzar limpieza.
        echo ">>> STOP (Manual Trigger) <<<"
        ensure_socket
        
        # Intentar despertar monitor real
        swaymsg output "$REAL_MONITOR" enable
        exit 0
        ;;
esac
