#!/bin/bash

# ==============================================================================
# SINCRONIZADOR BLUETOOTH V4 (WINDOWS -> LINUX)
# ==============================================================================
# Uso: sudo ./sync_bt_keys_v4.sh <Ruta_Montaje_Windows> <MAC_DISPOSITIVO>
# ==============================================================================

if [[ $EUID -ne 0 ]]; then
   echo "❌ ERROR: Requiere sudo." 
   exit 1
fi

if [[ -z "$1" || -z "$2" ]]; then
    echo "❌ Uso: sudo $0 <Ruta_Windows> <MAC_DISPOSITIVO>"
    exit 1
fi

WIN_MOUNT="$1"
TARGET_MAC="$2"
TARGET_MAC_WIN=$(echo "$TARGET_MAC" | tr -d ':' | tr '[:upper:]' '[:lower:]')
TARGET_MAC_LINUX=$(echo "$TARGET_MAC" | tr '[:lower:]' '[:upper:]')

if ! command -v chntpw &> /dev/null; then
    echo "❌ Instala chntpw primero."
    exit 1
fi

# Copia de seguridad del registro
SYSTEM_FILE=$(find "$WIN_MOUNT" -ipath "*/Windows/System32/config/SYSTEM" | head -n 1)
if [[ -z "$SYSTEM_FILE" ]]; then echo "❌ No se encontró SYSTEM."; exit 1; fi

TMP_HIVE="/tmp/SYSTEM_HIVE_COPY"
cp "$SYSTEM_FILE" "$TMP_HIVE" || exit 1

echo "⛏️  Analizando registro..."
REG_PATH="ControlSet001\\Services\\BTHPORT\\Parameters\\Keys"

# Obtener lista de adaptadores filtrando basura
ADAPTERS_RAW=$(printf "cd $REG_PATH\nls\nq\n" | chntpw -e "$TMP_HIVE" 2>/dev/null)
# Filtramos solo lo que parece una MAC (12 caracteres hex entre <>)
ADAPTERS=$(echo "$ADAPTERS_RAW" | grep -o '<[0-9a-f]\{12\}>' | tr -d '<>')

FOUND_KEY=""

for ADAPTER in $ADAPTERS; do
    echo "   -> Probando adaptador: $ADAPTER"
    
    HEX_OUTPUT=$(printf "cd $REG_PATH\\$ADAPTER\nhex $TARGET_MAC_WIN\nq\n" | chntpw -e "$TMP_HIVE" 2>/dev/null)
    
    if echo "$HEX_OUTPUT" | grep -q ":00000"; then
        # CORRECCIÓN V4: Usar awk para tomar EXACTAMENTE los 16 pares de bytes hexadecimales
        # Ignora la columna 1 (:00000) y toma desde la 2 hasta la 17.
        FOUND_KEY=$(echo "$HEX_OUTPUT" | grep ":00000" | awk '{print $2$3$4$5$6$7$8$9$10$11$12$13$14$15$16$17}' | tr '[:lower:]' '[:upper:]')
        
        # Validación extra: La clave debe tener exactamente 32 caracteres
        if [[ ${#FOUND_KEY} -eq 32 ]]; then
            echo "   ✅ ¡Clave válida encontrada!"
            break 
        else
            echo "   ⚠️  Clave detectada pero longitud incorrecta (${#FOUND_KEY} chars), ignorando."
            FOUND_KEY=""
        fi
    fi
done

rm "$TMP_HIVE"

if [[ -z "$FOUND_KEY" ]]; then
    echo "❌ Clave no encontrada en Windows."
    exit 1
fi

# Búsqueda en Linux
LINUX_CONFIG_FILE=$(find /var/lib/bluetooth -name "$TARGET_MAC_LINUX" -type d -exec find {} -name "info" \; | head -n 1)

if [[ -z "$LINUX_CONFIG_FILE" ]]; then
    echo "❌ No hay config en Linux. Empareja el dispositivo primero."
    exit 1
fi

CURRENT_KEY=$(grep "Key=" "$LINUX_CONFIG_FILE" | head -n 1 | cut -d '=' -f 2 | tr -d ' ' | tr -d '\r')

echo ""
echo "========================================="
echo " 🐧 Clave Linux:   $CURRENT_KEY"
echo " 🪟 Clave Windows: $FOUND_KEY"
echo "========================================="

if [[ "$CURRENT_KEY" == "$FOUND_KEY" ]]; then
    echo "✅ Las claves ya coinciden."
    exit 0
fi

read -p "❓ ¿Actualizar? (S/n): " CONFIRM
CONFIRM=${CONFIRM:-S}

if [[ "$CONFIRM" =~ ^[sS]$ ]]; then
    cp "$LINUX_CONFIG_FILE" "${LINUX_CONFIG_FILE}.bak"
    # Reemplazo seguro
    sed -i "s/Key=[A-F0-9]\{32\}/Key=$FOUND_KEY/" "$LINUX_CONFIG_FILE"
    systemctl restart bluetooth
    echo "✅ ¡Listo!"
else
    echo "🚫 Cancelado."
fi
