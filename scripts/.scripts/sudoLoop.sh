#!/bin/bash
sudo -v
# Ejecutar hasta que se cierre la terminal o se revoquen permisos de sudo
(
    while sudo -n true 2>/dev/null; do
        sleep 60
    done
) &
