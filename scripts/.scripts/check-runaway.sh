#!/usr/bin/env bash

# Detecta procesos/servicios con consumo de CPU anómalo y "tormentas" de logs
# (p. ej. un driver reseteando un dispositivo USB en bucle, que dispara miles
# de eventos de udev por minuto). check-integrity.sh detecta archivos de
# paquetes corruptos/faltantes; este script detecta comportamiento anómalo
# en tiempo de ejecución, que es una clase de problema distinta.
#
# Excepciones: rutas de binario (se admiten globs de bash: *, ?, [..]) que se
# ignoran en los chequeos de CPU. Se cargan de:
#   1. el archivo $EXCLUDE_FILE (por defecto ~/.config/check-runaway/exclude),
#      una ruta por línea; se ignoran líneas vacías y las que empiezan con #
#   2. la opción -x/--exclude RUTA (repetible)
#
# Notificaciones (--notify): cada alerta tiene una clave estable (ruta del
# binario, nombre del servicio o identificador del journal). Una vez
# notificada, no se repite hasta que pasen NOTIFY_COOLDOWN_RUNS ejecuciones
# con --notify (con 6 y un timer cada 5 min: como mucho una vez cada 30 min).
# El estado vive en $XDG_CACHE_HOME/check-runaway/notified.
# La salida por terminal y el código de salida no se ven afectados.
#
# Ubicación: ~/.scripts/check-runaway.sh

set -uo pipefail

if [ -t 1 ]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
    BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; BOLD=''; NC=''
fi

CPU_THRESHOLD="${CPU_THRESHOLD:-50}"       # % de UN núcleo por proceso/servicio (entero)
SAMPLE_GAP="${SAMPLE_GAP:-3}"              # segundos de la ventana de medición (entero)
JOURNAL_WINDOW="${JOURNAL_WINDOW:-5 min}"  # ventana para el chequeo de logs
JOURNAL_LINE_THRESHOLD="${JOURNAL_LINE_THRESHOLD:-3000}"  # entradas en la ventana para considerar "tormenta"
JOURNAL_TOP_IDS="${JOURNAL_TOP_IDS:-2}"    # identificadores cuyos mensajes se detallan en una tormenta
NOTIFY_COOLDOWN_RUNS="${NOTIFY_COOLDOWN_RUNS:-6}"  # cada cuántas ejecuciones con --notify se repite una misma alerta
STATE_DIR="${STATE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/check-runaway}"
EXCLUDE_FILE="${EXCLUDE_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/check-runaway/exclude}"
CGROOT=/sys/fs/cgroup

usage() {
    cat <<EOF
Uso: $(basename "$0") [opciones]

  --notify            Enviar notificación de escritorio si hay alertas
  -x, --exclude RUTA  Ignorar procesos cuyo binario coincida con RUTA (glob).
                      Repetible. Ej: -x '/usr/lib/firefox/*'
  -h, --help          Mostrar esta ayuda

Archivo de excepciones: $EXCLUDE_FILE
Variables: CPU_THRESHOLD, SAMPLE_GAP, JOURNAL_WINDOW, JOURNAL_LINE_THRESHOLD,
           JOURNAL_TOP_IDS, NOTIFY_COOLDOWN_RUNS, STATE_DIR, EXCLUDE_FILE

Códigos de salida: 0 = normal, 1 = actividad anómala, 2 = error de uso
EOF
}

# --- Argumentos ---
notify=0
excludes=()
while [ $# -gt 0 ]; do
    case "$1" in
        --notify) notify=1 ;;
        -x|--exclude)
            [ -n "${2:-}" ] || { echo "Falta la ruta para $1" >&2; exit 2; }
            excludes+=("$2"); shift ;;
        --exclude=*) excludes+=("${1#*=}") ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Opción desconocida: $1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

for v in CPU_THRESHOLD SAMPLE_GAP JOURNAL_LINE_THRESHOLD JOURNAL_TOP_IDS NOTIFY_COOLDOWN_RUNS; do
    [[ "${!v}" =~ ^[1-9][0-9]*$ ]] || { echo "$v debe ser un entero positivo (es '${!v}')" >&2; exit 2; }
done

# --- Carga del archivo de excepciones ---
if [ -r "$EXCLUDE_FILE" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
        line="${line#"${line%%[![:space:]]*}"}"   # trim izquierdo
        line="${line%"${line##*[![:space:]]}"}"   # trim derecho
        [ -z "$line" ] || [[ "$line" == \#* ]] && continue
        excludes+=("$line")
    done < "$EXCLUDE_FILE"
fi

# Ruta del binario de un PID. /proc/PID/exe es fiable, pero para procesos de
# otros usuarios requiere root; en ese caso se cae a argv[0] (que el propio
# proceso puede falsear). Hilos de kernel: cadena vacía.
exe_of() {
    local exe
    exe=$(readlink "/proc/$1/exe" 2>/dev/null)
    exe=${exe% (deleted)}   # binario reemplazado por una actualización
    [ -n "$exe" ] || exe=$(tr '\0' '\n' < "/proc/$1/cmdline" 2>/dev/null | head -n1)
    printf '%s' "$exe"
}

is_excluded() {
    local exe=$1 pat
    [ -n "$exe" ] || return 1
    for pat in ${excludes[@]+"${excludes[@]}"}; do
        # shellcheck disable=SC2053  # sin comillas a propósito: $pat es un glob
        [[ $exe == $pat ]] && return 0
    done
    return 1
}

fmt_pct() { printf '%d.%d' $(( $1 / 10 )) $(( $1 % 10 )); }

# --- Muestreo ---
# Se toman dos fotos (cgroups y procesos a la vez) separadas por SAMPLE_GAP y
# se calcula el consumo REAL en esa ventana. (ps -o %cpu no sirve para esto:
# es el promedio de toda la vida del proceso.)

# Cgroups hoja con procesos (en cgroup v2 solo las hojas tienen procesos),
# limitado a .service y .scope: evita contar "/" y los slices, que agregan
# a sus hijos y generan alertas duplicadas.
cg_snapshot() {
    local -n out=$1
    local d first k v
    while IFS= read -r d; do
        { read -r first < "$d/cgroup.procs"; } 2>/dev/null || continue
        [ -n "$first" ] || continue
        while read -r k v; do
            [ "$k" = usage_usec ] && { out["$d"]=$v; break; }
        done 2>/dev/null < "$d/cpu.stat"
    done < <(find "$CGROOT" -mindepth 1 -type d \( -name '*.service' -o -name '*.scope' \) 2>/dev/null)
}

# Clave "pid:starttime" para no confundir un PID reciclado con el original.
proc_snapshot() {
    local -n out=$1
    local f s pid
    local -a fld
    for f in /proc/[0-9]*/stat; do
        { read -r s < "$f"; } 2>/dev/null || continue
        pid=${f#/proc/}; pid=${pid%/stat}
        read -ra fld <<<"${s##*") "}"   # campos desde "state" (el 3ro)
        out["$pid:${fld[19]}"]=$(( fld[11] + fld[12] ))   # utime + stime
    done
}

have_cg2=0
[ -f "$CGROOT/cgroup.controllers" ] && have_cg2=1
CLK_TCK=$(getconf CLK_TCK 2>/dev/null || echo 100)

declare -A cg0=() cg1=() p0=() p1=() pdelta=()
alert=0
notify_keys=()
notify_msgs=()
# add_alert CLAVE MENSAJE: la clave identifica la alerta entre ejecuciones.
add_alert() {
    alert=1
    notify_keys+=("${1//$'\t'/ }")
    notify_msgs+=("$2")
}

echo -e "${BLUE}==================================================${NC}"
echo -e "${BLUE}      Detector de Procesos/Servicios Anómalos     ${NC}"
echo -e "${BLUE}==================================================${NC}"
[ "${#excludes[@]}" -gt 0 ] && echo -e "${YELLOW}Excepciones activas: ${#excludes[@]}${NC}"
echo -e "Midiendo durante ${SAMPLE_GAP}s..."
echo ""

[ "$have_cg2" -eq 1 ] && cg_snapshot cg0
proc_snapshot p0
sleep "$SAMPLE_GAP"
[ "$have_cg2" -eq 1 ] && cg_snapshot cg1
proc_snapshot p1

for key in "${!p1[@]}"; do
    [ -n "${p0[$key]:-}" ] || continue
    pdelta[${key%%:*}]=$(( p1[$key] - p0[$key] ))
done

# CPU (en µs) que consumieron dentro de un cgroup los procesos exceptuados.
excluded_usec() {
    local pid sum=0
    [ "${#excludes[@]}" -gt 0 ] || { echo 0; return; }
    while read -r pid; do
        [ -n "${pdelta[$pid]:-}" ] || continue
        is_excluded "$(exe_of "$pid")" && sum=$(( sum + pdelta[$pid] * 1000000 / CLK_TCK ))
    done 2>/dev/null < "$1/cgroup.procs"
    echo "$sum"
}

# --- 1. CPU por servicio (cgroup), agregando todos sus procesos ---
echo -e "${CYAN}[1/3] CPU por servicio/scope (cgroup v2)...${NC}"
if [ "$have_cg2" -eq 1 ]; then
    budget=$(( SAMPLE_GAP * 1000000 ))   # µs equivalentes a 100% de un núcleo
    rows=(); alert_names=(); alert_pcts=(); skipped=0
    for d in "${!cg1[@]}"; do
        [ -n "${cg0[$d]:-}" ] || continue
        delta=$(( ${cg1[$d]} - ${cg0[$d]} ))
        name=${d#"$CGROOT"}
        rows+=("$(( delta * 1000 / budget )) $name")
        (( delta * 100 > CPU_THRESHOLD * budget )) || continue
        eff=$(( delta - $(excluded_usec "$d") ))
        if (( eff * 100 <= CPU_THRESHOLD * budget )); then
            skipped=$(( skipped + 1 )); continue
        fi
        pct=$(fmt_pct $(( eff * 1000 / budget )))
        alert_names+=("$name"); alert_pcts+=("$pct")
    done
    printf '%s\n' ${rows[@]+"${rows[@]}"} | sort -rn | head -5 | while read -r t n; do
        printf '  %6s%%  %s\n' "$(fmt_pct "$t")" "$n"
    done
    for i in ${alert_names[@]+"${!alert_names[@]}"}; do
        echo -e "  ${RED}⚠ ${alert_names[$i]} usando ${alert_pcts[$i]}% CPU${NC}"
        add_alert "cg:${alert_names[$i]}" "${alert_names[$i]}: ${alert_pcts[$i]}% CPU"
    done
    [ "$skipped" -gt 0 ] && echo -e "  ${YELLOW}($skipped servicio(s) por encima del umbral solo por procesos exceptuados)${NC}"
else
    echo -e "  ${YELLOW}cgroup v2 no disponible, omitiendo.${NC}"
fi
echo ""

# --- 2. Procesos individuales por encima del umbral en la ventana ---
echo -e "${CYAN}[2/3] Procesos con CPU > ${CPU_THRESHOLD}% durante ${SAMPLE_GAP}s...${NC}"
found=0; skipped=0
limit=$(( CPU_THRESHOLD * CLK_TCK * SAMPLE_GAP ))
for pid in "${!pdelta[@]}"; do
    d=${pdelta[$pid]}
    (( d * 100 > limit )) || continue
    exe=$(exe_of "$pid")
    if is_excluded "$exe"; then skipped=$(( skipped + 1 )); continue; fi
    pct=$(fmt_pct $(( d * 1000 / (CLK_TCK * SAMPLE_GAP) )))
    cmd=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null | cut -c1-100)
    [ -n "$cmd" ] || cmd="[$(cat "/proc/$pid/comm" 2>/dev/null)]"   # hilo de kernel
    echo -e "  ${RED}⚠ PID $pid  ${pct}%  ${BOLD}${exe:-?}${NC}${RED}  $cmd${NC}"
    found=1
    add_alert "exe:${exe:-$cmd}" "PID $pid ${pct}% ${exe:-$cmd}"
done
[ "$found" -eq 0 ] && echo -e "  ${GREEN}Nada por encima del umbral.${NC}"
[ "$skipped" -gt 0 ] && echo -e "  ${YELLOW}($skipped proceso(s) omitidos por excepción)${NC}"
echo ""

# --- 3. Tormenta de eventos en el journal, agrupada por identificador ---
# Se agrupa por SYSLOG_IDENTIFIER (el "nombre" con que loguea cada fuente:
# kernel, systemd-udevd, NetworkManager...). Si una entrada no lo tiene, se
# usa _COMM (nombre del proceso). Una sola lectura del journal sirve para
# contar el total y armar el ranking.
echo -e "${CYAN}[3/3] Journal en los últimos ${JOURNAL_WINDOW}, por identificador...${NC}"
id_counts=$(journalctl --since "-${JOURNAL_WINDOW}" --no-pager -q -o json \
        --output-fields=SYSLOG_IDENTIFIER,_COMM 2>/dev/null \
    | sed -E -e 's/.*"SYSLOG_IDENTIFIER":"([^"]*)".*/t\t\1/;t' \
             -e 's/.*"_COMM":"([^"]*)".*/c\t\1/;t' \
             -e 's/.*/-\t(sin identificador)/' \
    | sort | uniq -c | sort -rn)
total=$(awk '{s += $1} END {print s + 0}' <<<"$id_counts")
echo "  Entradas totales: $total (umbral: $JOURNAL_LINE_THRESHOLD)"

# Mensajes más repetidos de un identificador (números colapsados a '#').
journal_top_msgs() {   # $1 = t|c|-, $2 = identificador
    local -a match
    case "$1" in
        t) match=(-t "$2") ;;
        c) match=("_COMM=$2") ;;
        *) return ;;
    esac
    journalctl --since "-${JOURNAL_WINDOW}" --no-pager -q -o cat "${match[@]}" 2>/dev/null \
        | sed -E 's/[0-9]+/#/g' | sort | uniq -c | sort -rn | head -3
}

if [ "$total" -gt 0 ]; then
    while read -r cnt rest; do
        src=${rest%%$'\t'*}; id=${rest#*$'\t'}
        [ "$src" = c ] && id="$id (_COMM)"
        printf '  %7d  %s\n' "$cnt" "$id"
    done < <(head -5 <<<"$id_counts")
fi

if [ "$total" -gt "$JOURNAL_LINE_THRESHOLD" ]; then
    echo -e "  ${RED}⚠ Posible tormenta de eventos/logs detectada.${NC}"
    n=0
    while read -r cnt rest && [ "$n" -lt "$JOURNAL_TOP_IDS" ]; do
        n=$(( n + 1 ))
        src=${rest%%$'\t'*}; id=${rest#*$'\t'}
        echo -e "  ${YELLOW}${id} (${cnt} entradas), mensajes más repetidos:${NC}"
        msgs=$(journal_top_msgs "$src" "$id")
        [ -n "$msgs" ] && sed 's/^/    /' <<<"$msgs"
        if [ "$n" -eq 1 ]; then
            first=$(head -1 <<<"$msgs" | sed -E 's/^\s*[0-9]+\s*//')
            add_alert "journal:$id" "Journal: $total entradas en ${JOURNAL_WINDOW}; principal: $id ($cnt)${first:+: $first}"
        fi
    done <<<"$id_counts"
fi
echo ""

# --- Notificaciones con cooldown ---
# Formato del archivo de estado (separado por tabs):
#   run    <número de ejecución actual>
#   <ejecución en que se notificó>    <clave>
declare -A last_notified=()
run=0
load_state() {
    local a b
    [ -r "$STATE_FILE" ] || return 0
    while IFS=$'\t' read -r a b; do
        if [ "$a" = run ] && [[ "$b" =~ ^[0-9]+$ ]]; then
            run=$b
        elif [[ "$a" =~ ^[0-9]+$ ]] && [ -n "$b" ]; then
            last_notified["$b"]=$a
        fi
    done < "$STATE_FILE"
}

# Guarda solo las claves que siguen dentro del cooldown (el resto caduca).
save_state() {
    local tmp key l
    tmp=$(mktemp "$STATE_DIR/.notified.XXXXXX") || return 1
    {
        printf 'run\t%s\n' "$run"
        for key in "${!last_notified[@]}"; do
            l=${last_notified[$key]}
            (( run - l < NOTIFY_COOLDOWN_RUNS )) && printf '%s\t%s\n' "$l" "$key"
        done
    } > "$tmp" && mv -f "$tmp" "$STATE_FILE"
}

silenced=0
if [ "$notify" -eq 1 ]; then
    if ! command -v notify-send &>/dev/null; then
        echo -e "${YELLOW}notify-send no encontrado; no se envían notificaciones.${NC}"
    elif mkdir -p "$STATE_DIR" 2>/dev/null; then
        STATE_FILE="$STATE_DIR/notified"
        # Evita que dos ejecuciones simultáneas pisen el estado.
        if command -v flock &>/dev/null; then
            exec 9>"$STATE_DIR/lock"
            flock -w 10 9 || echo -e "${YELLOW}No se pudo tomar el lock del estado; se continúa igual.${NC}"
        fi
        load_state
        run=$(( run + 1 ))   # cuenta todas las ejecuciones con --notify, haya o no alertas
        body=()
        for i in ${notify_keys[@]+"${!notify_keys[@]}"}; do
            key=${notify_keys[$i]}
            l=${last_notified[$key]:-}
            # Se notifica si es nueva, si ya salió en esta misma ejecución
            # (varios PIDs del mismo binario) o si ya pasó el cooldown.
            if [ -z "$l" ] || [ "$l" -eq "$run" ] || (( run - l >= NOTIFY_COOLDOWN_RUNS )); then
                body+=("${notify_msgs[$i]}")
                last_notified["$key"]=$run
            else
                silenced=$(( silenced + 1 ))
            fi
        done
        save_state || echo -e "${YELLOW}No se pudo guardar el estado en $STATE_FILE${NC}"
        if [ "${#body[@]}" -gt 0 ]; then
            notify-send -u critical -a check-runaway "Actividad anómala detectada" \
                "$(printf '%s\n' "${body[@]}")" 2>/dev/null || true
        fi
    else
        echo -e "${YELLOW}No se pudo crear $STATE_DIR; no se envían notificaciones.${NC}"
    fi
fi

if [ "$alert" -eq 1 ]; then
    echo -e "${RED}✖ Se detectó actividad anómala. Revisa lo señalado arriba.${NC}"
    [ "$silenced" -gt 0 ] && echo -e "${YELLOW}  ($silenced alerta(s) ya notificadas; silenciadas por cooldown)${NC}"
    exit 1
else
    echo -e "${GREEN}✔ Nada fuera de lo normal.${NC}"
    exit 0
fi
