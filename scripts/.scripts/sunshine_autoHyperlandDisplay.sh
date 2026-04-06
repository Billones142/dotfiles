#!/bin/bash

# 1. Obtener el nombre del primer monitor físico detectado (si existe)
PHYSICAL_MONITOR=$(hyprctl monitors | grep "Monitor" | grep -v "HEADLESS" | awk '{print $2}' | head -n 1)
PHYSICAL_COUNT=$(hyprctl monitors | grep "Monitor" | grep -v "HEADLESS" | wc -l)

# 2. Verificar si ya existe algún monitor HEADLESS activo y obtener el último
EXISTING_HEADLESS=$(hyprctl monitors | grep "HEADLESS" | awk '{print $2}' | tail -n 1)

# 3. Lógica de decisión
if [ "$PHYSICAL_COUNT" -eq 0 ]; then
    if [ -z "$EXISTING_HEADLESS" ]; then
        echo "No hay monitores físicos. Creando nuevo monitor virtual..."
        
        # Capturamos la creación. Hyprland suele imprimir el nombre en el log o stdout.
        # Si no lo hace directamente, lo extraemos comparando la lista antes y después.
        hyprctl output create headless
        
        # Esperamos un instante para que el socket de hyprland procese el nuevo monitor
        sleep 0.2
        
        # El nuevo monitor siempre será el último en la lista de 'hyprctl monitors'
        MONITOR=$(hyprctl monitors | grep "HEADLESS" | awk '{print $2}' | tail -n 1)
        echo "Nuevo monitor creado: $MONITOR"
    else
        MONITOR="$EXISTING_HEADLESS"
        echo "Usando monitor HEADLESS ya existente: $MONITOR"
    fi
else
    # Si hay monitores físicos, priorizamos el físico y limpiamos los virtuales
    MONITOR="$PHYSICAL_MONITOR"
    echo "Monitor físico detectado: $MONITOR"
    
    if [ ! -z "$EXISTING_HEADLESS" ]; then
        echo "Limpiando monitores virtuales residuales..."
        hyprctl monitors | grep "HEADLESS" | awk '{print $2}' | while read -r name; do
            hyprctl output remove "$name"
        done
    fi
fi

# 4. Exportar la variable
export MONITOR
echo "-----------------------------------"
echo "VARIABLE EXPORTADA: MONITOR=$MONITOR"
echo "-----------------------------------"
