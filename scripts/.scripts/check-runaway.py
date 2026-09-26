#!/usr/bin/env python3
"""
Detecta procesos/servicios con consumo de CPU anómalo y "tormentas" de logs
(p. ej. un driver reseteando un dispositivo USB en bucle, que dispara miles
de eventos de udev por minuto). check-integrity.sh detecta archivos de
paquetes corruptos/faltantes; este script detecta comportamiento anómalo en
tiempo de ejecución, que es una clase de problema distinta.

Excepciones: rutas de binario (globs estilo shell: *, ?, [..]) que se ignoran
en los chequeos de CPU. Se cargan de EXCLUDE_FILE (por defecto
~/.config/check-runaway/exclude; una ruta por línea, # para comentarios) y de
-x/--exclude RUTA (repetible).

Notificaciones (--notify): cada alerta tiene una clave estable (ruta del
binario, nombre del servicio o identificador del journal). Una vez notificada,
no se repite hasta que pasen NOTIFY_COOLDOWN_RUNS ejecuciones con --notify.
El estado vive en $XDG_CACHE_HOME/check-runaway/notified.json.

Solo usa la biblioteca estándar (Python 3.8+). La sección de servicios
requiere cgroup v2.

Ubicación: ~/.scripts/check-runaway.py
"""
from __future__ import annotations

import argparse
import fcntl
import fnmatch
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from collections import Counter, defaultdict
from pathlib import Path

CGROOT = Path("/sys/fs/cgroup")
PROC = Path("/proc")
CLK_TCK = os.sysconf("SC_CLK_TCK")
DIGITS = re.compile(r"\d+")

EXIT_OK, EXIT_ALERT, EXIT_USAGE = 0, 1, 2


# ============================================================ salida

class C:
    RED = GREEN = YELLOW = BLUE = CYAN = BOLD = NC = ""


def setup_colors() -> None:
    """Colores solo si la salida es una terminal (no ensucia logs)."""
    if sys.stdout.isatty():
        C.RED, C.GREEN, C.YELLOW = "\033[0;31m", "\033[0;32m", "\033[1;33m"
        C.BLUE, C.CYAN, C.BOLD, C.NC = "\033[0;34m", "\033[0;36m", "\033[1m", "\033[0m"


def say(msg: str = "", color: str = "") -> None:
    print(f"{color}{msg}{C.NC}" if color else msg, flush=True)


def die(msg: str) -> None:
    print(msg, file=sys.stderr)
    sys.exit(EXIT_USAGE)


# ============================================================ configuración

def positive(kind):
    def conv(raw: str):
        try:
            value = kind(raw)
        except ValueError:
            raise argparse.ArgumentTypeError(f"'{raw}' no es un número válido")
        if value <= 0:
            raise argparse.ArgumentTypeError(f"'{raw}' debe ser mayor que 0")
        return value
    return conv


def env_default(name: str, default, kind):
    raw = os.environ.get(name)
    if raw is None:
        return default
    try:
        return positive(kind)(raw)
    except argparse.ArgumentTypeError as e:
        die(f"{name}: {e}")


def parse_args(argv=None) -> argparse.Namespace:
    config_home = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
    cache_home = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache")

    p = argparse.ArgumentParser(
        description="Detector de procesos/servicios con CPU anómala y tormentas de logs.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "Cada opción toma su valor por defecto de la variable de entorno indicada.\n"
            "Códigos de salida: 0 = normal, 1 = actividad anómala, 2 = error de uso."
        ),
    )
    p.add_argument("--notify", action="store_true",
                   help="enviar notificación de escritorio (con cooldown)")
    p.add_argument("-x", "--exclude", action="append", default=[], metavar="RUTA",
                   help="ignorar procesos cuyo binario coincida con RUTA (glob); repetible")
    p.add_argument("--threshold", type=positive(float),
                   default=env_default("CPU_THRESHOLD", 50.0, float),
                   help="%% de UN núcleo por proceso/servicio [CPU_THRESHOLD, 50]")
    p.add_argument("--gap", type=positive(float),
                   default=env_default("SAMPLE_GAP", 3.0, float),
                   help="segundos de la ventana de medición [SAMPLE_GAP, 3]")
    p.add_argument("--window", default=os.environ.get("JOURNAL_WINDOW", "5 min"),
                   help="ventana del chequeo de journal [JOURNAL_WINDOW, '5 min']")
    p.add_argument("--journal-threshold", type=positive(int),
                   default=env_default("JOURNAL_LINE_THRESHOLD", 3000, int),
                   help="entradas en la ventana para considerar tormenta [JOURNAL_LINE_THRESHOLD, 3000]")
    p.add_argument("--journal-top-ids", type=positive(int),
                   default=env_default("JOURNAL_TOP_IDS", 2, int),
                   help="identificadores a detallar en una tormenta [JOURNAL_TOP_IDS, 2]")
    p.add_argument("--cooldown", type=positive(int),
                   default=env_default("NOTIFY_COOLDOWN_RUNS", 6, int),
                   help="cada cuántas ejecuciones con --notify se repite una alerta [NOTIFY_COOLDOWN_RUNS, 6]")
    p.add_argument("--state-dir", type=Path,
                   default=Path(os.environ.get("STATE_DIR") or cache_home / "check-runaway"),
                   help="directorio del estado de notificaciones [STATE_DIR]")
    p.add_argument("--exclude-file", type=Path,
                   default=Path(os.environ.get("EXCLUDE_FILE")
                                or config_home / "check-runaway" / "exclude"),
                   help="archivo de excepciones [EXCLUDE_FILE]")
    return p.parse_args(argv)


# ============================================================ excepciones

def load_excludes(path: Path, cli: list[str]) -> list[str]:
    patterns = []
    try:
        for line in path.read_text().splitlines():
            line = line.strip()
            if line and not line.startswith("#"):
                patterns.append(line)
    except FileNotFoundError:
        pass
    except OSError as e:
        say(f"No se pudo leer {path}: {e}", C.YELLOW)
    return patterns + cli


class Excluder:
    def __init__(self, patterns: list[str]):
        self.patterns = patterns

    def __bool__(self) -> bool:
        return bool(self.patterns)

    def match(self, exe: str) -> bool:
        return bool(exe) and any(fnmatch.fnmatchcase(exe, p) for p in self.patterns)


# ============================================================ procesos

_exe_cache: dict[int, str] = {}


def exe_of(pid: int) -> str:
    """Ruta del binario. /proc/PID/exe es fiable pero, para procesos de otros
    usuarios, requiere root; en ese caso se cae a argv[0] (que el proceso puede
    falsear). Hilos de kernel: cadena vacía."""
    if pid in _exe_cache:
        return _exe_cache[pid]
    try:
        exe = os.readlink(PROC / str(pid) / "exe")
        if exe.endswith(" (deleted)"):          # binario reemplazado por una actualización
            exe = exe[: -len(" (deleted)")]
    except OSError:
        try:
            raw = (PROC / str(pid) / "cmdline").read_bytes()
            exe = raw.split(b"\0", 1)[0].decode(errors="replace")
        except OSError:
            exe = ""
    _exe_cache[pid] = exe
    return exe


def cmdline_of(pid: int, width: int = 100) -> str:
    try:
        raw = (PROC / str(pid) / "cmdline").read_bytes()
        cmd = raw.replace(b"\0", b" ").decode(errors="replace").strip()
        if cmd:
            return cmd[:width]
        return "[" + (PROC / str(pid) / "comm").read_text().strip() + "]"   # hilo de kernel
    except OSError:
        return "?"


def proc_snapshot() -> dict[int, tuple[int, int]]:
    """{pid: (starttime, utime+stime en ticks)}. starttime evita confundir un
    PID reciclado con el original."""
    out = {}
    with os.scandir(PROC) as it:
        for entry in it:
            if not entry.name.isdigit():
                continue
            try:
                with open(PROC / entry.name / "stat", "rb") as f:
                    data = f.read()
            except OSError:
                continue
            # El nombre (campo 2) puede tener espacios y paréntesis: se corta
            # en el último ")". Desde ahí, el índice 0 es el campo 3 (state).
            fld = data[data.rfind(b")") + 2:].split()
            try:
                out[int(entry.name)] = (int(fld[19]), int(fld[11]) + int(fld[12]))
            except (IndexError, ValueError):
                continue
    return out


# ============================================================ cgroups

def cg_snapshot() -> dict[str, int]:
    """{ruta: usage_usec} de cgroups .service/.scope con procesos propios.
    En cgroup v2 solo las hojas tienen procesos, así que no se cuentan "/" ni
    los slices, que agregan a sus hijos y duplicarían alertas."""
    out = {}
    for dirpath, _dirs, _files in os.walk(CGROOT):
        if not dirpath.endswith((".service", ".scope")):
            continue
        try:
            with open(os.path.join(dirpath, "cgroup.procs")) as f:
                if not f.read(1):
                    continue
            with open(os.path.join(dirpath, "cpu.stat")) as f:
                for line in f:
                    key, _, value = line.partition(" ")
                    if key == "usage_usec":
                        out[dirpath] = int(value)
                        break
        except (OSError, ValueError):
            continue
    return out


def cgroup_pids(path: str) -> list[int]:
    try:
        with open(os.path.join(path, "cgroup.procs")) as f:
            return [int(x) for x in f.read().split()]
    except (OSError, ValueError):
        return []


# ============================================================ journal

def decode_field(value) -> str | None:
    """journalctl emite como array de bytes los campos que no son UTF-8 válido."""
    if isinstance(value, str):
        return value
    if isinstance(value, list):
        try:
            return bytes(value).decode(errors="replace")
        except (TypeError, ValueError):
            return None
    return None


def journal_stats(window: str):
    """Una sola lectura del journal, agrupada por SYSLOG_IDENTIFIER (o _COMM si
    la entrada no lo tiene). Devuelve (total, Counter por id, mensajes por id)
    o None si journalctl no está disponible."""
    if not shutil.which("journalctl"):
        return None
    cmd = ["journalctl", "--since", f"-{window}", "--no-pager", "-q", "-o", "json",
           "--output-fields=SYSLOG_IDENTIFIER,_COMM,MESSAGE"]
    by_id: Counter = Counter()
    msgs: dict = defaultdict(Counter)
    with subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                          text=True, errors="replace") as proc:
        for line in proc.stdout:
            try:
                entry = json.loads(line)
            except ValueError:
                continue
            ident, src = decode_field(entry.get("SYSLOG_IDENTIFIER")), "t"
            if not ident:
                ident, src = decode_field(entry.get("_COMM")), "c"
            if not ident:
                ident, src = "(sin identificador)", "-"
            key = (src, ident)
            by_id[key] += 1
            msg = (decode_field(entry.get("MESSAGE")) or "").replace("\n", " ")
            msgs[key][DIGITS.sub("#", msg)[:200]] += 1
    return sum(by_id.values()), by_id, msgs


# ============================================================ notificaciones

def load_state(path: Path) -> dict:
    try:
        state = json.loads(path.read_text())
        if isinstance(state.get("run"), int) and isinstance(state.get("notified"), dict):
            return state
    except (OSError, ValueError, AttributeError):
        pass
    return {"run": 0, "notified": {}}


def save_state(path: Path, state: dict) -> None:
    fd, tmp = tempfile.mkstemp(dir=path.parent, prefix=".notified.")
    try:
        with os.fdopen(fd, "w") as f:
            json.dump(state, f, indent=2, ensure_ascii=False)
        os.replace(tmp, path)          # escritura atómica
    except BaseException:
        os.unlink(tmp)
        raise


def send_notifications(alerts: list[tuple[str, str]], args) -> int:
    """Envía las alertas que no estén en cooldown. Devuelve cuántas silenció.
    El contador avanza en toda ejecución con --notify, haya o no alertas."""
    if not shutil.which("notify-send"):
        say("notify-send no encontrado; no se envían notificaciones.", C.YELLOW)
        return 0
    try:
        args.state_dir.mkdir(parents=True, exist_ok=True)
        lock = open(args.state_dir / "lock", "w")
    except OSError as e:
        say(f"No se pudo usar {args.state_dir}: {e}", C.YELLOW)
        return 0

    with lock:
        # Evita que dos ejecuciones simultáneas pisen el estado.
        deadline = time.monotonic() + 10
        while True:
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                break
            except BlockingIOError:
                if time.monotonic() > deadline:
                    say("No se pudo tomar el lock del estado; se continúa igual.", C.YELLOW)
                    break
                time.sleep(0.2)

        path = args.state_dir / "notified.json"
        state = load_state(path)
        run = state["run"] + 1
        notified = state["notified"]
        before = dict(notified)

        to_send, silenced = [], 0
        for key, msg in alerts:
            last = notified.get(key)
            # Nueva, ya enviada en esta misma ejecución (varios PIDs del mismo
            # binario) o cooldown cumplido.
            if last is None or last == run or run - last >= args.cooldown:
                to_send.append((key, msg))
                notified[key] = run
            else:
                silenced += 1

        if to_send:
            body = "\n".join(msg for _, msg in to_send)
            res = subprocess.run(
                ["notify-send", "-u", "critical", "-a", "check-runaway",
                 "Actividad anómala detectada", body],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
            if res.returncode != 0:
                # No "gastar" el aviso si no se pudo mostrar.
                for key, _ in to_send:
                    if key in before:
                        notified[key] = before[key]
                    else:
                        notified.pop(key, None)
                say("notify-send falló (¿falta DBUS_SESSION_BUS_ADDRESS?).", C.YELLOW)

        # Solo se guardan las claves que siguen dentro del cooldown.
        state = {"run": run,
                 "notified": {k: v for k, v in notified.items() if run - v < args.cooldown}}
        try:
            save_state(path, state)
        except OSError as e:
            say(f"No se pudo guardar el estado en {path}: {e}", C.YELLOW)
    return silenced


# ============================================================ secciones

def check_cgroups(cg0, cg1, pdelta, elapsed, args, excl, alerts) -> None:
    say(f"[1/3] CPU por servicio/scope (cgroup v2)...", C.CYAN)
    if cg0 is None:
        say("  cgroup v2 no disponible, omitiendo.", C.YELLOW)
        return
    rows, found, skipped = [], [], 0
    prefix = len(str(CGROOT))
    for path, u1 in cg1.items():
        u0 = cg0.get(path)
        if u0 is None:
            continue
        pct = (u1 - u0) / 1e6 / elapsed * 100
        name = path[prefix:]
        rows.append((pct, name))
        if pct <= args.threshold:
            continue
        if excl:
            # Se resta la CPU de los procesos exceptuados en vez de descartar
            # todo el servicio.
            ticks = sum(pdelta.get(pid, 0) for pid in cgroup_pids(path)
                        if excl.match(exe_of(pid)))
            pct -= ticks / CLK_TCK / elapsed * 100
            if pct <= args.threshold:
                skipped += 1
                continue
        found.append((name, pct))

    for pct, name in sorted(rows, reverse=True)[:5]:
        say(f"  {pct:6.1f}%  {name}")
    for name, pct in found:
        say(f"  ⚠ {name} usando {pct:.1f}% CPU", C.RED)
        alerts.append((f"cg:{name}", f"{name}: {pct:.1f}% CPU"))
    if skipped:
        say(f"  ({skipped} servicio(s) por encima del umbral solo por procesos exceptuados)", C.YELLOW)


def check_processes(pdelta, elapsed, args, excl, alerts) -> None:
    say(f"[2/3] Procesos con CPU > {args.threshold:g}% durante {elapsed:.1f}s...", C.CYAN)
    found, skipped = 0, 0
    for pid, ticks in sorted(pdelta.items(), key=lambda kv: -kv[1]):
        pct = ticks / CLK_TCK / elapsed * 100
        if pct <= args.threshold:
            break                       # ordenado de mayor a menor
        exe = exe_of(pid)
        if excl.match(exe):
            skipped += 1
            continue
        cmd = cmdline_of(pid)
        say(f"  ⚠ PID {pid}  {pct:.1f}%  {C.BOLD}{exe or '?'}{C.NC}{C.RED}  {cmd}", C.RED)
        alerts.append((f"exe:{exe or cmd}", f"PID {pid} {pct:.1f}% {exe or cmd}"))
        found += 1
    if not found:
        say("  Nada por encima del umbral.", C.GREEN)
    if skipped:
        say(f"  ({skipped} proceso(s) omitidos por excepción)", C.YELLOW)


def check_journal(args, alerts) -> None:
    say(f"[3/3] Journal en los últimos {args.window}, por identificador...", C.CYAN)
    stats = journal_stats(args.window)
    if stats is None:
        say("  journalctl no encontrado, omitiendo.", C.YELLOW)
        return
    total, by_id, msgs = stats
    say(f"  Entradas totales: {total} (umbral: {args.journal_threshold})")
    for (src, ident), cnt in by_id.most_common(5):
        say(f"  {cnt:7d}  {ident}{' (_COMM)' if src == 'c' else ''}")

    if total <= args.journal_threshold:
        return
    say("  ⚠ Posible tormenta de eventos/logs detectada.", C.RED)
    for i, (key, cnt) in enumerate(by_id.most_common(args.journal_top_ids)):
        ident = key[1]
        say(f"  {ident} ({cnt} entradas), mensajes más repetidos (números como '#'):", C.YELLOW)
        top = msgs[key].most_common(3)
        for msg, n in top:
            say(f"    {n:7d} {msg}")
        if i == 0:
            first = f": {top[0][0]}" if top else ""
            alerts.append((f"journal:{ident}",
                           f"Journal: {total} entradas en {args.window}; principal: {ident} ({cnt}){first}"))


# ============================================================ main

def main(argv=None) -> int:
    args = parse_args(argv)
    setup_colors()
    excl = Excluder(load_excludes(args.exclude_file, args.exclude))
    have_cg2 = (CGROOT / "cgroup.controllers").is_file()
    alerts: list[tuple[str, str]] = []

    say("==================================================", C.BLUE)
    say("      Detector de Procesos/Servicios Anómalos     ", C.BLUE)
    say("==================================================", C.BLUE)
    if excl:
        say(f"Excepciones activas: {len(excl.patterns)}", C.YELLOW)
    say(f"Midiendo durante {args.gap:g}s...")
    say()

    # Dos fotos (cgroups y procesos juntos) para medir el consumo REAL en la
    # ventana; %cpu de ps no sirve: es el promedio de toda la vida del proceso.
    t0 = time.monotonic()
    cg0 = cg_snapshot() if have_cg2 else None
    p0 = proc_snapshot()
    time.sleep(args.gap)
    elapsed = time.monotonic() - t0     # tiempo real, no el nominal
    cg1 = cg_snapshot() if have_cg2 else {}
    p1 = proc_snapshot()

    pdelta = {pid: ticks - p0[pid][1]
              for pid, (start, ticks) in p1.items()
              if pid in p0 and p0[pid][0] == start}

    check_cgroups(cg0, cg1, pdelta, elapsed, args, excl, alerts)
    say()
    check_processes(pdelta, elapsed, args, excl, alerts)
    say()
    check_journal(args, alerts)
    say()

    silenced = send_notifications(alerts, args) if args.notify else 0

    if alerts:
        say("✖ Se detectó actividad anómala. Revisa lo señalado arriba.", C.RED)
        if silenced:
            say(f"  ({silenced} alerta(s) ya notificadas; silenciadas por cooldown)", C.YELLOW)
        return EXIT_ALERT
    say("✔ Nada fuera de lo normal.", C.GREEN)
    return EXIT_OK


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(130)
