#!/usr/bin/env bash
set -euo pipefail

### Colores (solo si la salida es una terminal que los soporta)
if [[ -t 1 ]] && command -v tput >/dev/null && tput colors >/dev/null 2>&1; then
    BOLD=$(tput bold); GREEN=$(tput setaf 2); YELLOW=$(tput setaf 3)
    RED=$(tput setaf 1); RESET=$(tput sgr0)
else
    BOLD=""; GREEN=""; YELLOW=""; RED=""; RESET=""
fi

paso()  { printf '\n%s[%s] %s%s\n' "$BOLD$YELLOW" "$1" "$2" "$RESET"; }
ok()    { printf '\n%s%s%s\n' "$BOLD$GREEN" "$1" "$RESET"; }
aviso() { printf '%s%s%s\n' "$BOLD$YELLOW" "$1" "$RESET" >&2; }
error() { printf '%sError: %s%s\n' "$BOLD$RED" "$1" "$RESET" >&2; exit 1; }

uso() {
    printf '%sUso: %s <FLATPAK_ID> <CARPETA_CONFIG_EN_DOTFILES>%s\n' \
        "$BOLD$RED" "${0##*/}" "$RESET" >&2
    printf 'Ejemplo: %s com.orcaslicer.OrcaSlicer ~/dotfiles/orca-slicer/.config/OrcaSlicer\n' \
        "${0##*/}" >&2
    exit 1
}

### Validación de argumentos
[[ $# -eq 2 ]] || uso

FLATPAK_ID=$1
# Expande "~" por si la ruta llegó entre comillas, y la convierte en absoluta
ORIGEN=$(realpath -e -- "${2/#\~/$HOME}" 2>/dev/null) \
    || error "No existe la carpeta: $2"

[[ -d $ORIGEN ]] || error "No es una carpeta: $ORIGEN"

CONFIG_NAME=$(basename -- "$ORIGEN")
SANDBOX_CONFIG="$HOME/.var/app/$FLATPAK_ID/config"
DESTINO="$SANDBOX_CONFIG/$CONFIG_NAME"

command -v flatpak >/dev/null || error "flatpak no está instalado"
flatpak info "$FLATPAK_ID" >/dev/null 2>&1 || error "La app '$FLATPAK_ID' no está instalada"

# Si la app está abierta puede reescribir la config mientras la movemos
if flatpak ps --columns=application 2>/dev/null | grep -qxF "$FLATPAK_ID"; then
    aviso "Atención: $FLATPAK_ID está en ejecución. Conviene cerrarla antes de continuar."
fi

### 1. Permisos (solo sobre la carpeta de config, no todo el repo de dotfiles)
paso 1/4 "Otorgando acceso a $ORIGEN..."
flatpak override --user --filesystem="$ORIGEN" "$FLATPAK_ID"

# Si ya está enlazado correctamente, no hay nada más que hacer
if [[ -L $DESTINO && $(readlink -- "$DESTINO") == "$ORIGEN" ]]; then
    ok "El enlace ya existe y apunta a $ORIGEN. Nada que hacer."
    exit 0
fi

### 2. Respaldo en lugar de borrado
paso 2/4 "Respaldando configuración previa del sandbox..."
if [[ -e $DESTINO || -L $DESTINO ]]; then
    BACKUP="$DESTINO.bak.$(date +%Y%m%d-%H%M%S)"
    mv -- "$DESTINO" "$BACKUP"
    printf '  Respaldo guardado en: %s\n' "$BACKUP"
else
    printf '  No había configuración previa.\n'
fi

### 3. Enlace
paso 3/4 "Generando enlace simbólico..."
mkdir -p -- "$SANDBOX_CONFIG"
ln -s -- "$ORIGEN" "$DESTINO"

ok "[4/4] ¡Completado! Verifica la integridad con tu script stow_check.sh"
