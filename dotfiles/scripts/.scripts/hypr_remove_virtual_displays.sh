#!/bin/bash

# 1. Obtener los nombres de todos los monitores que comienzan con HEADLESS-
# 2. Filtrar solo la palabra que contiene el nombre (ej. HEADLESS-4)
# 3. Iterar y eliminarlos uno por uno
hyprctl monitors | grep -o 'HEADLESS-[0-9]\+' | while read -r monitor; do
    echo "Eliminando monitor virtual: $monitor"
    hyprctl output remove "$monitor"
done

echo "Limpieza completada."
