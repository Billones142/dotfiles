#!/bin/bash

# Lista de paquetes de telemetría y publicidad (msa, analytics, daemon, etc.)
PACKAGES=(
    "com.miui.msa.global"        # El motor de anuncios principal (msa)
    "com.miui.analytics"         # Recolección de datos y métricas
    "com.miui.daemon"            # El recolector de estadísticas en segundo plano
    "com.xiaomi.joyose"          # Tracking de juegos y límites de rendimiento
    "com.miui.hybrid.accessory"  # Quick Apps (rastreo de uso de apps rápidas)
    "com.miui.videoplayer"       # Mi Video (recolecta historial de visualización)
    "com.miui.player"            # Mi Music (recolecta historial de audio)
    "com.miui.notes"             # Notas de Xiaomi (si usas Google Keep o similar)
    "com.miui.yellowpage"        # Páginas Amarillas (rastreo de llamadas/spam)
    "com.xiaomi.scanner"         # Escáner de Xiaomi (telemetría de fotos/QR)
    "com.android.providers.downloads.ui" # Interfaz de descargas con anuncios
)

echo "--- Iniciando limpieza de HyperOS en Poco X7 Pro ---"

for package in "${PACKAGES[@]}"; do
    echo "Intentando eliminar: $package"
    # --user 0 desinstala para el usuario actual
    adb shell pm uninstall --user 0 "$package" || echo "Saltando: $package no encontrado o ya eliminado."
done

echo "--- Proceso completado. Reinicia tu dispositivo para aplicar cambios. ---"
