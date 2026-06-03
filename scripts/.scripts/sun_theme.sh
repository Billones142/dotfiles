#!/bin/bash
# Configura tu ubicación (puedes buscarla en Google Maps)
LAT="-27.47"
LON="-58.83"

# El comando sunwait esperará hasta que ocurra el evento
# sunset: atardecer, sunrise: amanecer
sunwait poll sunset $LAT $LON
# Si sunwait termina, es que oscureció:
kwriteconfig6 --file kdeglobals --group General --key ColorScheme "BreezeDark"

sunwait poll sunrise $LAT $LON
# Si sunwait termina, es que amaneció:
kwriteconfig6 --file kdeglobals --group General --key ColorScheme "Breeze"
