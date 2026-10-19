#!/usr/bin/env bash
# stow_check_flatpak.sh: verifica que las configs de las apps Flatpak listadas en
# ~/dotfiles/.stowable_flatpak.csv estén correctamente enlazadas al sandbox.
#
# Uso: stow_check_flatpak.sh [--fix]
#   --fix  intenta reparar las entradas con problemas usando stow_flatpak.sh
set -uo pipefail

### Colores (solo si la salida es una terminal que los soporta)
if [[ -t 1 ]] && command -v tput >/dev/null && tput colors >/dev/null 2>&1; then
    BOLD=$(tput bold); DIM=$(tput dim 2>/dev/null || true)
    GREEN=$(tput setaf 2); YELLOW=$(tput setaf 3); RED=$(tput setaf 1)
    RESET=$(tput sgr0)
else
    BOLD=""; DIM=""; GREEN=""; YELLOW=""; RED=""; RESET=""
fi

error() { printf '%sError: %s%s\n' "$BOLD$RED" "$1" "$RESET" >&2; exit 2; }

uso() {
    printf 'Uso: %s [--fix]\n' "${0##*/}" >&2
    printf '  --fix  repara las entradas con problemas usando stow_flatpak.sh\n' >&2
    exit "$1"
}

### Configuración
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
CSV="$DOTFILES_DIR/.stowable_flatpak.csv"
LINKER="$(dirname -- "$(realpath -- "$0")")/stow_flatpak.sh"

FIX=false
case "${1:-}" in
    "")        ;;
    --fix)     FIX=true ;;
    -h|--help) uso 0 ;;
    *)         uso 1 ;;
esac

[[ -f $CSV ]] || error "No existe $CSV"
command -v flatpak >/dev/null || error "flatpak no está instalado"
if $FIX && [[ ! -x $LINKER ]]; then
    error "No se encontró stow_flatpak.sh ejecutable en $LINKER"
fi

### Utilidades

# Quita espacios al inicio y al final (incluye el \r de archivos con formato Windows)
trim() {
    local s=$1
    s=${s#"${s%%[![:space:]]*}"}
    s=${s%"${s##*[![:space:]]}"}
    printf '%s' "$s"
}

# Muestra las rutas con "~" en lugar del home completo
corta() { printf '%s' "${1/#"$HOME"/\~}"; }

# Cómo mostrar el comando de enlace: por nombre si está en el PATH, si no por su ruta
if command -v stow_flatpak.sh >/dev/null; then
    LINKER_CMD="stow_flatpak.sh"
else
    LINKER_CMD=$(corta "$LINKER")
fi

# Devuelve 0 si la app $1 tiene acceso de escritura a la ruta $2,
# ya sea por un override del usuario o por los permisos propios de la app
tiene_permiso() {
    local id=$1 ruta=$2 linea entrada
    local -a entradas

    while IFS= read -r linea; do
        IFS=';' read -ra entradas <<< "${linea#filesystems=}"
        for entrada in "${entradas[@]}"; do
            # Vacías, negadas (!ruta) o de solo lectura no sirven
            [[ -z $entrada || $entrada == !* || $entrada == *:ro ]] && continue
            entrada=${entrada%:rw}
            entrada=${entrada%:create}
            case $entrada in
                host|home) return 0 ;;
                "~"*)      entrada="$HOME${entrada#\~}" ;;
            esac
            entrada=${entrada%/}
            [[ $ruta == "$entrada" || $ruta == "$entrada"/* ]] && return 0
        done
    done < <({ flatpak info --show-permissions "$id"; flatpak override --user --show "$id"; } \
               2>/dev/null | grep '^filesystems=')

    return 1
}

### Revisión de cada entrada del CSV
total=0; ok=0; arreglados=0; fallas=0
num_linea=0
comandos_enlace=()     # stow_flatpak.sh para las entradas reparables
comandos_instalar=()   # flatpak install para las apps que faltan
sin_carpeta=()         # carpetas que hay que crear a mano en dotfiles

# Se lee por el descriptor 3 para que los comandos de flatpak no consuman el CSV
while IFS=, read -r -u 3 id ruta _ || [[ -n ${id:-} ]]; do
    num_linea=$((num_linea + 1))
    id=$(trim "${id:-}")
    ruta=$(trim "${ruta:-}")

    # Saltar encabezado, líneas vacías y comentarios
    [[ $num_linea -eq 1 && $id == package_name ]] && continue
    [[ -z $id || $id == \#* ]] && continue

    total=$((total + 1))

    if [[ -z $ruta ]]; then
        printf '%s✘ %s%s\n' "$BOLD$RED" "$id" "$RESET"
        printf '    %s• sin carpeta de configuración en el CSV (línea %d)%s\n' \
            "$YELLOW" "$num_linea" "$RESET"
        fallas=$((fallas + 1))
        continue
    fi

    origen=$(realpath -m -- "$DOTFILES_DIR/${ruta#/}")
    destino="$HOME/.var/app/$id/config/$(basename -- "$origen")"
    problemas=()
    reparable=true

    if ! flatpak info "$id" >/dev/null 2>&1; then
        problemas+=("la app no está instalada")
        comandos_instalar+=("flatpak install flathub $id")
        reparable=false
    fi

    if [[ ! -d $origen ]]; then
        problemas+=("no existe la carpeta en dotfiles")
        sin_carpeta+=("$(corta "$origen")")
        reparable=false
    fi

    if [[ -L $destino ]]; then
        [[ $(readlink -- "$destino") == "$origen" ]] || problemas+=("el enlace apunta a otro lugar")
    elif [[ -e $destino ]]; then
        problemas+=("hay una carpeta real en lugar del enlace")
    elif $reparable; then
        problemas+=("falta el enlace")
    fi

    if $reparable && ! tiene_permiso "$id" "$origen"; then
        problemas+=("sin permiso de escritura")
    fi

    # Sin problemas
    if [[ ${#problemas[@]} -eq 0 ]]; then
        printf '%s✔ %s%s\n' "$GREEN" "$id" "$RESET"
        ok=$((ok + 1))
        continue
    fi

    # Intento de reparación
    if $FIX && $reparable; then
        if "$LINKER" "$id" "$origen" >/dev/null 2>&1; then
            printf '%s✔ %s %s(reparado)%s\n' "$GREEN" "$id" "$YELLOW" "$RESET"
            arreglados=$((arreglados + 1))
            continue
        fi
        problemas+=("stow_flatpak.sh falló al repararla")
    fi

    printf '%s✘ %s%s\n' "$BOLD$RED" "$id" "$RESET"
    printf "    $YELLOW• %s$RESET\n" "${problemas[@]}"
    fallas=$((fallas + 1))

    $reparable && comandos_enlace+=("$LINKER_CMD $id $(corta "$origen")")

done 3< "$CSV"

### Resumen
printf '\n%sResumen:%s %d entradas, %s%d ok%s' "$BOLD" "$RESET" "$total" "$GREEN" "$ok" "$RESET"
$FIX && printf ', %s%d reparadas%s' "$YELLOW" "$arreglados" "$RESET"
printf ', %s%d con problemas%s\n' "$RED" "$fallas" "$RESET"

### Cómo solucionarlo (siempre al final)
if [[ ${#comandos_instalar[@]} -gt 0 ]]; then
    printf '\n%sInstala las apps que faltan:%s\n' "$BOLD" "$RESET"
    printf "  $GREEN%s$RESET\n" "${comandos_instalar[@]}"
fi

if [[ ${#sin_carpeta[@]} -gt 0 ]]; then
    printf '\n%sCrea (o corrige en el CSV) estas carpetas de dotfiles:%s\n' "$BOLD" "$RESET"
    printf "  $DIM%s$RESET\n" "${sin_carpeta[@]}"
fi

if [[ ${#comandos_enlace[@]} -gt 0 ]]; then
    printf '\n%sPara configurarlas ejecuta:%s\n' "$BOLD" "$RESET"
    printf "  $GREEN%s$RESET\n" "${comandos_enlace[@]}"
    if ! $FIX; then
        printf '%sO todas juntas con: %s --fix%s\n' "$DIM" "${0##*/}" "$RESET"
    fi
fi

[[ $fallas -eq 0 ]]
