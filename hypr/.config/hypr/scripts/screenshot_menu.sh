# Opciones con iconos para que se vea bonito
opcion1="🖼️  Región / Seleccionar"
opcion2="🪟  Ventana Activa"
opcion3="🖥️   Monitor Completo"

# Abrimos el menú wofi
seleccion=$(echo -e "$opcion1\n$opcion2\n$opcion3" | wofi --dmenu --prompt "Tipo de Captura" --width 300 --height 200)

case $seleccion in
    "$opcion1")
        # El modo region congela la pantalla y te deja dibujar
        hyprshot -m region
        ;;
    "$opcion2")
        # Captura la ventana bajo el cursor o activa
        hyprshot -m window
        ;;
    "$opcion3")
        # Captura todo lo que se ve en el monitor
        hyprshot -m output
        ;;
esac
