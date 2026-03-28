#!/bin/bash

# ==========================================
# 📱 ANDROID WEBCAM (Auto-Reconnect Smart)
# ==========================================

# Configuración
VIDEO_DEV="/dev/video10"
RESOLUTION="1920x1080"
APP_NAME="Android Webcam"

# Función para enviar notificaciones
notify() {
    # $1 = Título, $2 = Mensaje, $3 = Urgencia, $4 = Tiempo (ms)
    TIME=${4:-5000} # Por defecto 5 segundos si no se especifica
    notify-send "$1" "$2" -a "$APP_NAME" -i camera-web -u "$3" -t "$TIME"
}

# 1. Verificar módulo v4l2loopback
if [ ! -e "$VIDEO_DEV" ]; then
    echo "🔧 Cargando módulo de kernel..."
    sudo modprobe v4l2loopback video_nr=10 card_label="ScrcpyCam" exclusive_caps=1
    if [ ! -e "$VIDEO_DEV" ]; then
        echo "❌ Error: No se pudo crear la cámara virtual."
        exit 1
    fi
fi

# 2. Selección de Dispositivo
echo "🔍 Buscando dispositivos Android..."
devices=$(adb devices | awk '$2=="device" {print $1}')
count=$(echo "$devices" | wc -w)

if [ -z "$devices" ]; then
    echo "❌ No se detectaron dispositivos."
    notify "$APP_NAME" "Conecta tu teléfono y activa depuración USB." "critical"
    exit 1
elif [ "$count" -eq 1 ]; then
    SERIAL=$devices
    echo "✅ Dispositivo detectado: $SERIAL"
else
    echo "📱 Selecciona el dispositivo:"
    IFS=$'\n' read -rd '' -a device_array <<< "$devices"
    select d in "${device_array[@]}"; do
        if [ -n "$d" ]; then
            SERIAL=$d
            break
        fi
    done
fi

# 3. Selección de Cámara
echo "----------------------------------------"
scrcpy --serial "$SERIAL" --list-cameras
echo "----------------------------------------"
read -p "👉 ID de cámara (0=Trasera, 1=Frontal): " CAM_ID

if ! [[ "$CAM_ID" =~ ^[0-9]+$ ]]; then
    echo "❌ ID inválido."
    exit 1
fi

# 4. Bucle Inteligente
echo "----------------------------------------"
echo "🚀 Iniciando transmisión..."
notify "$APP_NAME" "🟢 Iniciando cámara..." "normal"

while true; do
    # Ejecutamos scrcpy
    scrcpy --serial "$SERIAL" \
           --video-source=camera \
           --camera-id="$CAM_ID" \
           --camera-size="$RESOLUTION" \
           --v4l2-sink="$VIDEO_DEV" \
           --no-audio \
           --no-window

    # --- ZONA DE DESCONEXIÓN ---
    echo "⚠️  Conexión perdida."
    
    # Notificación de error (Dura 15 segundos)
    notify "$APP_NAME" "🔴 Conexión perdida. Esperando dispositivo..." "critical" 15000
    
    # PAUSA INTELIGENTE: El script se congela aquí hasta que enchufes el USB
    echo "⏳ Esperando a que el dispositivo $SERIAL vuelva a estar online..."
    adb -s "$SERIAL" wait-for-device
    
    # Si pasa de aquí, es que ya enchufaste el cable
    echo "✅ Dispositivo reconectado."
    notify "$APP_NAME" "🟢 Conexión restablecida. Reiniciando cámara..." "normal" 3000
    
    # Pequeña pausa de seguridad para que el sistema monte el USB bien
    sleep 1
done
