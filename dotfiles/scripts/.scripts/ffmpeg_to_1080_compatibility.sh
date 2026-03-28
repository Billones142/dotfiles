#!/bin/bash

# --- CONFIGURACIÓN ---
INPUT_FILE="$1"
CUSTOM_OUTPUT="$2"

# 1. Validación de argumentos y archivo
if [ -z "$INPUT_FILE" ]; then
    echo "❌ Error: Falta el archivo de entrada."
    echo "Uso: $(basename "$0") <archivo_de_video> [salida_opcional]"
    return 1
fi

if [ ! -f "$INPUT_FILE" ]; then
    echo "❌ Error: El archivo '$INPUT_FILE' no existe o no se encuentra."
    return 1
fi

# 2. Lógica de Nombres y Extensiones
# Extraer nombre base y extensión original
filename=$(basename -- "$INPUT_FILE")
extension="${filename##*.}"
filename="${filename%.*}"

# Definir nombre de salida
if [ -n "$CUSTOM_OUTPUT" ]; then
    OUTPUT_NAME="$CUSTOM_OUTPUT"
else
    # Mantiene la extensión original (sea mp4, avi, mkv, etc)
    OUTPUT_NAME="${INPUT_FILE%.*}_1080p.${extension}"
fi

# 3. Preparar el entorno (Trap para restaurar terminal si hay error/Ctrl+C)
# Esto asegura que nunca te quedes atrapado en el buffer alternativo
trap 'tput rmcup; echo "⚠️ Proceso interrumpido o finalizado."' EXIT

# Guardar estado y cambiar al buffer alternativo
tput smcup

echo "🚀 Iniciando conversión optimizada con RTX 3090..."
echo "📂 Entrada: $INPUT_FILE"
echo "💾 Salida:  $OUTPUT_NAME"
echo "---------------------------------------------------"

# 4. Ejecución de FFmpeg
# Nota: Si el contenedor de salida (ej. MP4) no soporta los subtítulos del input,
# ffmpeg podría fallar al usar "-c:s copy". 
# Si eso pasa, cambia la extensión de salida a .mkv manualmente.

ffmpeg -hwaccel cuda -hwaccel_output_format cuda -i "$INPUT_FILE" \
    -map 0:v:0 \
    -map 0:a \
    -map 0:s? \
    -vf scale_cuda=1920:-2 \
    -c:v hevc_nvenc -preset p7 -cq 26 -rc vbr \
    -c:a copy \
    -c:s copy \
    "$OUTPUT_NAME"

# El trap al final (EXIT) se encargará de hacer el tput rmcup automáticamente
# pero podemos imprimir el mensaje final antes de salir.
