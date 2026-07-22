get_last_mod_recursive() {
    local target_dir="${1:-.}"
    local latest_file
    
    # Obtenemos únicamente la ruta del archivo más reciente
    latest_file=$(find "$target_dir" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)
    
    if [ -n "$latest_file" ]; then
        # Imprimimos la fecha con stat -c y la ruta por separado
        echo -n "Fecha: $(stat -c "%y" "$latest_file") | Archivo: "
        echo "$latest_file"
    else
        echo "No se encontraron archivos en el directorio."
    fi
}

get_last_mod_recursive $1
