#!/bin/bash

# 1. Ejecutar actualizaciones (opcional, puedes comentar esto si lo corres aparte)
# sudo apt update && sudo apt upgrade -y

echo "--- Iniciando chequeo de servicios y procesos ---"

# 2. Reiniciar servicios automáticamente (-r a: restart automatically)
# Usamos -v para ver qué está pasando y -q para que sea más limpio
echo "[INFO]: Reiniciando servicios del sistema que están obsoletos..."
sudo needrestart -r a

# 3. Identificar procesos de usuario o sesiones que no se pueden reiniciar solos
# El flag -p activa el modo parseable para leer la salida fácilmente
echo ""
echo "--- Reporte de procesos de usuario pendientes ---"
echo "Los siguientes procesos requieren intervención manual (ej. reiniciar la app o la sesión):"
echo "--------------------------------------------------------------------------------"

# Filtramos la salida para mostrar solo lo que NO es un servicio de sistema
sudo lsof +L1 | grep -i deleted | awk '{print "PID: "$2" | Comando: "$1" | Usuario: "$3}' | uniq

echo "--------------------------------------------------------------------------------"

# 4. Comprobar si el Kernel necesita un reinicio total
if sudo needrestart -k | grep -q "User must restart"; then
    echo "⚠️ [ALERTA]: Se ha actualizado el KERNEL. Se recomienda un REBOOT completo."
else
    echo "✅ El kernel está al día."
fi
