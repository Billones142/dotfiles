#!/bin/bash

# Verificar si se ha proporcionado una contraseña
if [ "$#" -lt 1 ]; then
    echo "Uso: $0 <contraseña> [tty]"
    exit 1
fi

export XDG_RUNTIME_DIR=/run/user/1000

# Obtener la contraseña del primer argumento
PASSWORD="$1"

# Verificar si se ha proporcionado un tty, sino usar tty4 como predeterminado
TTY=${2:-4}

# Cambiar a la TTY especificada
chvt "$TTY"

# Iniciar sesión como "stefano"
echo "$PASSWORD" | sudo -S -u stefano bash -c 'exec sway --unsupported-gpu'
