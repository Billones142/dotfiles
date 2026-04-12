#!/bin/bash

# Archivo de log para ver qué pasa (Míralo con: cat /tmp/rofi_debug.txt)
LOG="/tmp/rofi_debug.txt"
echo "--- Inicio Script ---" > "$LOG"

APPS_DIRS="/usr/share/applications $HOME/.local/share/applications /var/lib/flatpak/exports/share/applications $HOME/Desktop"

# Ejecutamos Rofi
# -kb-custom-1 "Alt+c": Definimos la tecla. 
# NOTA: En algunas versiones es sensible a mayúsculas, probamos ambas por seguridad.
selection=$(rofi -show drun \
    -run-command "uwsm app -- {cmd}" \
    -kb-custom-1 "Alt+c" \
    -mesg "<b>Enter:</b> Abrir | <b>Alt+C:</b> Copiar ruta" \
    )
exit 0

# Capturamos el código de salida INMEDIATAMENTE
exit_code=$?
echo "Selección: '$selection' | Código de salida: $exit_code" >> "$LOG"

if [ -z "$selection" ]; then
    echo "Cancelado por el usuario" >> "$LOG"
    exit 0
fi

# CÓDIGO 0: ENTER (Abrir App)
if [ $exit_code -eq 0 ]; then
    echo "Abriendo app..." >> "$LOG"
    
    # SOLUCIÓN:
    # 1. Usamos 'sh -c' para poder usar redirecciones.
    # 2. '{cmd} > /dev/null 2>&1' -> Manda todo el texto (logs/errores) al vacío.
    # 3. '&' -> Manda el proceso al fondo inmediatamente.
    # 4. 'disown' -> (Opcional pero recomendado) Desvincula el proceso del shell actual.

    # ESTO ESTA MAL, esto hace que vuelva a aparecer rofi pero usando el resultado del stdout del programa que se lanzo antes
    rofi -show drun \
         -run-command "/bin/sh -c '{cmd} > /dev/null 2>&1 & disown'" \
         -drun-match-fields name \
         -filter "^$selection$" \
         -auto-select \
         -now
         
    exit 0
fi

# CÓDIGO 10: ALT+C (Copiar Ruta)
if [ $exit_code -eq 10 ]; then
    echo "Buscando ruta para: $selection" >> "$LOG"
    
    # 1. Intento por nombre exacto en el archivo .desktop (Name=...)
    desktop_file=$(grep -rn "Name=$selection" $APPS_DIRS 2>/dev/null | head -n 1 | cut -d: -f1)
    
    # 2. Si falla, intento por nombre de archivo (ej: busca 'brave' en brave-browser.desktop)
    if [ -z "$desktop_file" ]; then
        echo "Busqueda exacta falló, intentando búsqueda difusa..." >> "$LOG"
        clean_name=$(echo "$selection" | awk '{print tolower($1)}') # Primera palabra, minúscula
        desktop_file=$(find $APPS_DIRS -name "*$clean_name*.desktop" 2>/dev/null | head -n 1)
    fi

    if [ -n "$desktop_file" ]; then
        echo "Encontrado: $desktop_file" >> "$LOG"
        echo -n "$desktop_file" | wl-copy
        notify-send "✅ Ruta copiada" "$desktop_file" -i edit-copy
    else
        echo "NO ENCONTRADO" >> "$LOG"
        notify-send "❌ Error" "No se encontró el .desktop para '$selection'" -u critical
    fi
fi
