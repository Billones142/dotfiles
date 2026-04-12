#!/bin/bash

# --- CONFIGURACIÓN ---
tmp_dir="/tmp/cliphist_thumbs"
menu_file="/tmp/rofi_clip_menu_list"
mkdir -p "$tmp_dir"

# Configuración Visual (Mantenemos la que ya te gustaba)
rofi_config="configuration { show-icons: true; } 
             window { width: 50%; }
             listview { lines: 6; }
             element { orientation: horizontal; children: [ element-icon, element-text ]; spacing: 15px; } 
             element-icon { size: 3.5em; } 
             element-text { vertical-align: 0.5; }
             textbox { vertical-align: 0.5; }"

# Función auxiliar para detectar iconos de sistema según mimetype
get_icon_for_file() {
    local mime="$1"
    case "$mime" in
        video/*) echo "video-x-generic" ;;
        audio/*) echo "audio-x-generic" ;;
        text/*) echo "text-x-generic" ;;
        application/pdf) echo "application-pdf" ;;
        inode/directory) echo "folder" ;;
        *) echo "text-x-generic" ;; # Icono por defecto
    esac
}

# --- BUCLE PRINCIPAL ---
while true; do
    # 1. Generar lista
    cliphist list | while read -r line; do
        id=$(echo "$line" | cut -f1)
        
        # === CASO A: IMAGEN BINARIA (Captura de pantalla o copiar imagen directa) ===
        if [[ "$line" =~ "binary data" ]]; then
            img_path="$tmp_dir/${id}_bin.png"
            if [ ! -f "$img_path" ]; then
                cliphist decode "$id" | magick - -resize 256x256! "$img_path" 2>/dev/null
            fi
            meta_info=$(echo "$line" | grep -oE "[0-9]+x[0-9]+" || echo "Binario")
            echo -en "$id\t📷 Imagen Copiada [$meta_info]\0icon\x1f$img_path\n"
        
        else
            # === CASO B: TEXTO O RUTA DE ARCHIVO ===
            # Limpiamos el texto para analizarlo
            text_raw=$(echo "$line" | cut -f2-)
            # Quitamos el prefijo file:// si existe para verificar ruta
            possible_path=$(echo "$text_raw" | sed 's/^file:\/\///') 
            # Trim de espacios
            possible_path=$(echo "$possible_path" | xargs)

            # ¿Es un archivo real que existe en el disco?
            if [[ "$possible_path" == /* ]] && [ -e "$possible_path" ]; then
                
                # Obtenemos el tipo MIME del archivo
                mime_type=$(file --mime-type -b "$possible_path")
                
                if [[ "$mime_type" == image/* ]]; then
                    # --- ES UN ARCHIVO DE IMAGEN ---
                    # Generamos thumbnail del archivo real
                    thumb_path="$tmp_dir/${id}_file.png"
                    if [ ! -f "$thumb_path" ]; then
                        magick "$possible_path" -resize 256x256! "$thumb_path" 2>/dev/null
                    fi
                    
                    # Mostramos el nombre del archivo y el icono generado
                    filename=$(basename "$possible_path")
                    echo -en "$id\t🖼️ Archivo: $filename\0icon\x1f$thumb_path\n"
                
                else
                    # --- ES OTRO TIPO DE ARCHIVO (PDF, Video, etc) ---
                    # Usamos un icono genérico del sistema basado en el mime
                    sys_icon=$(get_icon_for_file "$mime_type")
                    filename=$(basename "$possible_path")
                    echo -en "$id\t📄 Archivo: $filename\0icon\x1f$sys_icon\n"
                fi
            else
                # === CASO C: TEXTO NORMAL ===
                # Texto plano, url, código, etc.
                clean_text=$(echo "$text_raw" | sed 's/\t/ /g')
                echo -en "$id\t$clean_text\0icon\x1ftext-x-generic\n"
            fi
        fi
    done > "$menu_file"

    # 2. Mostrar Rofi
    selection=$(cat "$menu_file" | rofi -dmenu \
        -theme-str "$rofi_config" \
        -p "Portapapeles" \
        -display-columns 2 \
        -kb-custom-1 "Alt+Delete" \
        -kb-custom-2 "Alt+Shift+Delete" \
        -mesg "<b>Enter:</b> Pegar | <b>Alt+Supr:</b> Borrar Uno | <b>Alt+Shift+Supr:</b> Borrar Todo")
    
    exit_code=$?

    # 3. Acciones (Igual que antes)
    case $exit_code in
        0) 
            if [ -z "$selection" ]; then rm "$menu_file"; exit 0; fi
            id=$(echo "$selection" | cut -f1)
            # Decodificamos. Si era un archivo, cliphist devuelve el path texto, lo cual es correcto para pegar
            cliphist decode "$id" | wl-copy
            rm "$menu_file"
            exit 0
            ;;
        10) 
            if [ -n "$selection" ]; then
                id=$(echo "$selection" | cut -f1)
                cliphist list | grep "^$id" | cliphist delete
                # Borramos posibles thumbnails (binario o file)
                rm "$tmp_dir/${id}_bin.png" 2>/dev/null
                rm "$tmp_dir/${id}_file.png" 2>/dev/null
            fi
            ;;
        11)
            confirm=$(echo -e "No\nSí, borrar todo" | rofi -dmenu -p "⚠️ ¿ESTÁS SEGURO?" -lines 2)
            if [ "$confirm" == "Sí, borrar todo" ]; then
                cliphist wipe
                rm "$tmp_dir"/*.png 2>/dev/null
                rm "$menu_file"
                exit 0
            fi
            ;;
        *) rm "$menu_file"; exit 0 ;;
    esac
done
