# Borrar datos de usuario corruptos
sudo systemctl stop waydroid-container
sudo rm -rf /var/lib/waydroid/data /var/lib/waydroid/overlay_rw

# Reinicializar (Recrea las carpetas limpias)
sudo waydroid init -f

export wd_script_path=~/waydroid_script

# Instalar GApps
sudo $wd_script_path/venv/bin/python $wd_script_path/main.py install gapps

# Instalar Libhoudini
#sudo $wd_script_path/venv/bin/python $wd_script_path/main.py install libhoudini

# Instalar Magisk
#sudo ~/waydroid_script/venv/bin/python ~/waydroid_script/main.py install magisk

# Iniciar contenedor
#sudo systemctl start waydroid-container
