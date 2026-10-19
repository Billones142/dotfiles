#!/usr/bin/env python3
"""
Automatización completa: VM de Windows (KVM/libvirt) a ISO booteable.

Uso:
    sudo ./crear_iso_windows.py NOMBRE_VM [opciones]
    ./crear_iso_windows.py NOMBRE_VM --iso ./Win11_Spanish_x64.iso --salida ./Custom.iso

El disco se obtiene de la definición de la VM en libvirt: se toma el último
disco (device='disk') declarado. Si la VM usa snapshots externos, ese disco es
la capa más reciente y qemu-nbd lee toda la cadena de backing automáticamente.
"""

import argparse
import os
import shutil
import subprocess
import sys
import tempfile
import threading
import time
import xml.etree.ElementTree as ET
from pathlib import Path

# ------------------------------------------------------------------------------
# Valores por defecto (se pueden sobrescribir por línea de comandos)
# ------------------------------------------------------------------------------
ISO_ORIGINAL = "./Win11_Spanish_x64.iso"
DIRECTORIO_EXTRACCION = "./win_iso_extract"
ISO_SALIDA = "./Windows_Personalizado.iso"
ETIQUETA_VOLUMEN = "WIN_CUSTOM"
LIBVIRT_URI = "qemu:///system"

DEPENDENCIAS = ["7z", "mkisofs", "qemu-nbd", "wimcapture", "wimjoin", "virsh",
                "blkid", "mount", "umount", "modprobe", "udevadm"]

# Entorno en inglés para que la salida de virsh/blkid no dependa del idioma
ENV_C = {**os.environ, "LC_ALL": "C", "LANG": "C"}


# ------------------------------------------------------------------------------
# Utilidades
# ------------------------------------------------------------------------------
def info(msg):
    print(f"[*] {msg}", flush=True)


def aviso(msg):
    print(f"[!] {msg}", flush=True)


def error(msg):
    print(f"[Error] {msg}", file=sys.stderr, flush=True)
    sys.exit(1)


def es_root():
    return os.geteuid() == 0


def run(cmd, root=False, capturar=False, check=True):
    """Ejecuta un comando; si root=True y no somos root, antepone sudo."""
    if root and not es_root():
        cmd = ["sudo"] + cmd
    resultado = subprocess.run(
        cmd, env=ENV_C, check=False, text=True,
        stdout=subprocess.PIPE if capturar else None,
        stderr=subprocess.PIPE if capturar else None,
    )
    if check and resultado.returncode != 0:
        detalle = (resultado.stderr or "").strip() if capturar else ""
        error(f"Falló: {' '.join(cmd)}" + (f"\n{detalle}" if detalle else ""))
    return resultado


def mantener_sudo():
    """Pide la contraseña una vez y renueva sudo en segundo plano.

    La captura puede tardar más que el timestamp_timeout de sudo; sin esto,
    los pasos con sudo posteriores (chown, desconectar NBD) piden contraseña
    de nuevo y fallan si nadie la escribe a tiempo.
    """
    if es_root():
        return
    if subprocess.run(["sudo", "-v"], check=False).returncode != 0:
        error("No se pudo obtener permisos de sudo.")

    def renovar():
        while True:
            time.sleep(60)
            subprocess.run(["sudo", "-n", "-v"], check=False, stdout=subprocess.DEVNULL,
                           stderr=subprocess.DEVNULL)

    threading.Thread(target=renovar, daemon=True).start()


def verificar_dependencias():
    info("Verificando dependencias...")
    faltan = [c for c in DEPENDENCIAS if shutil.which(c) is None]
    if faltan:
        error("Faltan instalar: " + ", ".join(faltan))


# ------------------------------------------------------------------------------
# Libvirt: estado de la VM y último disco
# ------------------------------------------------------------------------------
def verificar_vm_apagada(vm, uri):
    r = run(["virsh", "-c", uri, "domstate", vm], root=True, capturar=True, check=False)
    if r.returncode != 0:
        error(f"No se encontró la VM '{vm}' en {uri}.\n{r.stderr.strip()}")
    estado = r.stdout.strip()
    if estado != "shut off":
        error(f"La VM '{vm}' está en estado '{estado}'. Apagala antes de continuar "
              "(capturar un disco en uso corrompe la imagen).")


def obtener_ultimo_disco(vm, uri):
    """Devuelve (ruta, formato) del último disco de la VM según su XML."""
    r = run(["virsh", "-c", uri, "dumpxml", vm], root=True, capturar=True)
    raiz = ET.fromstring(r.stdout)

    discos = []
    for disco in raiz.findall("./devices/disk"):
        if disco.get("device") != "disk":
            continue  # se ignoran cdrom y floppy
        source = disco.find("source")
        if source is None:
            continue
        ruta = source.get("file") or source.get("dev")
        if not ruta:
            continue
        driver = disco.find("driver")
        formato = driver.get("type") if driver is not None else "qcow2"
        destino = disco.find("target")
        dev_destino = destino.get("dev") if destino is not None else "?"
        discos.append((ruta, formato or "qcow2", dev_destino))

    if not discos:
        error(f"La VM '{vm}' no tiene discos con archivo o dispositivo de origen.")

    info(f"Discos encontrados en '{vm}':")
    for ruta, fmt, dev in discos:
        print(f"      {dev}: {ruta} ({fmt})")

    ruta, formato, dev = discos[-1]
    info(f"Usando el último disco: {dev} : {ruta}")
    return ruta, formato


# ------------------------------------------------------------------------------
# NBD
# ------------------------------------------------------------------------------
def buscar_nbd_libre():
    run(["modprobe", "nbd", "max_part=16"], root=True)
    for i in range(16):
        tam = Path(f"/sys/block/nbd{i}/size")
        if tam.exists() and tam.read_text().strip() == "0":
            return f"/dev/nbd{i}"
    error("No hay dispositivos /dev/nbdX libres.")


def conectar_nbd(disco, formato):
    nbd = buscar_nbd_libre()
    info(f"Conectando {disco} en {nbd} (solo lectura)...")
    run(["qemu-nbd", "--read-only", "-f", formato, "-c", nbd, disco], root=True)

    # Esperar a que el kernel exponga las particiones
    if shutil.which("partprobe"):
        run(["partprobe", nbd], root=True, check=False)
    run(["udevadm", "settle"], root=True, check=False)
    for _ in range(20):
        if list(Path("/dev").glob(f"{Path(nbd).name}p*")):
            break
        time.sleep(0.5)
    return nbd


def desconectar_nbd(nbd):
    run(["qemu-nbd", "-d", nbd], root=True, capturar=True, check=False)


# ------------------------------------------------------------------------------
# Detección de la partición de Windows
# ------------------------------------------------------------------------------
def detectar_particion_windows(nbd, particion_forzada=None):
    if particion_forzada:
        part = f"{nbd}p{particion_forzada}"
        if not Path(part).exists():
            error(f"La partición {part} no existe.")
        return part

    nombre = Path(nbd).name
    particiones = sorted(Path("/dev").glob(f"{nombre}p*"),
                         key=lambda p: int(p.name.split("p")[-1]))

    for part in particiones:
        r = run(["blkid", "-o", "value", "-s", "TYPE", str(part)],
                root=True, capturar=True, check=False)
        if r.stdout.strip() != "ntfs":
            continue

        punto = tempfile.mkdtemp(prefix="win_detect_")
        try:
            m = run(["mount", "-o", "ro", str(part), punto],
                    root=True, capturar=True, check=False)
            if m.returncode != 0:
                aviso(f"No se pudo montar {part}: {m.stderr.strip()}")
                continue
            try:
                if Path(punto, "Windows", "System32").is_dir():
                    info(f"Partición de Windows detectada: {part}")
                    return str(part)
            finally:
                run(["umount", punto], root=True, check=False)
        finally:
            os.rmdir(punto)

    error("No se encontró una partición NTFS con Windows\\System32. "
          "Si Windows quedó hibernado o con Inicio rápido activo, apagalo "
          "completamente (shutdown /s /f /t 0) o indicá la partición con --particion.")


# ------------------------------------------------------------------------------
# ISO
# ------------------------------------------------------------------------------
def extraer_iso(iso, destino):
    destino.mkdir(parents=True, exist_ok=True)
    if any(destino.iterdir()):
        aviso("Limpiando directorio de extracción anterior...")
        shutil.rmtree(destino)
        destino.mkdir(parents=True)

    info("Extrayendo la ISO base de Windows...")
    # 7z en vez de bsdtar: las ISOs de Microsoft guardan los archivos en UDF y
    # libarchive solo lee la capa ISO9660 (casi vacía), sin dar error.
    run(["7z", "x", "-y", "-bso0", f"-o{destino}", str(iso)])
    if not (destino / "sources").is_dir():
        error(f"La extracción no generó {destino / 'sources'}; ¿es una ISO de Windows?")

    # La ISO es de solo lectura y se conservan esos permisos; los habilitamos
    for raiz, dirs, archivos in os.walk(destino):
        for n in dirs + archivos:
            p = os.path.join(raiz, n)
            os.chmod(p, os.stat(p).st_mode | 0o200)

    info("Eliminando WIM/ESD base...")
    for nombre in ("install.wim", "install.esd"):
        (destino / "sources" / nombre).unlink(missing_ok=True)


def capturar_wim(particion, wim_salida, nombre, descripcion):
    info("Capturando la imagen del sistema (esto tomará bastante tiempo y CPU)...")
    # Se pasa el dispositivo de bloque, no un directorio montado: wimlib usa
    # el modo NTFS-3G y conserva ACLs, atributos y flujos alternativos.
    run(["wimcapture", particion, str(wim_salida), nombre, descripcion,
         "--compress=lzx"], root=True)

    # Dueño final: quien lanzó el script (aunque haya sido con sudo)
    usuario = os.environ.get("SUDO_USER") or (None if es_root() else os.environ.get("USER"))
    if usuario:
        info("Arreglando permisos del nuevo install.wim...")
        run(["chown", f"{usuario}:", str(wim_salida)], root=True, check=False)


def unir_swm_si_hace_falta(sources):
    """Une install*.swm de ejecuciones anteriores en un único install.wim.

    Con el WIM partido, Windows Setup copia los .swm al disco destino antes
    de aplicarlos ($WINDOWS.~BT) y puede quedarse sin espacio (0x80070070).
    """
    wim = sources / "install.wim"
    partes = sorted(sources.glob("install*.swm"))
    if wim.exists():
        return
    if not partes:
        error(f"No existe {wim}.")

    info("Uniendo install*.swm en un único install.wim...")
    run(["wimjoin", str(wim)] + [str(x) for x in partes])
    for parte in partes:
        parte.unlink()


def empaquetar_iso(directorio, iso_salida, etiqueta):
    for req in ("boot/etfsboot.com", "efi/microsoft/boot/efisys.bin"):
        if not (directorio / req).exists():
            error(f"No se encontró {req} en la ISO extraída.")

    unir_swm_si_hace_falta(directorio / "sources")

    if iso_salida.exists():
        # Si una VM bootea la ISO, libvirt la deja como libvirt-qemu:0644 y no
        # se puede sobrescribir; borrarla solo requiere permiso sobre el directorio.
        aviso(f"Reemplazando ISO anterior: {iso_salida}")
        try:
            iso_salida.unlink()
        except OSError as e:
            error(f"No se pudo borrar la ISO anterior: {e}")

    info("Empaquetando la ISO booteable final...")
    # mkisofs de cdrtools (no el de xorriso): con -udf admite el install.wim
    # de más de 4 GiB en una sola pieza, igual que las ISOs de Microsoft.
    run([
        "mkisofs", "-quiet", "-iso-level", "3", "-udf", "-J", "-joliet-long",
        "-V", etiqueta,
        "-b", "boot/etfsboot.com", "-no-emul-boot", "-boot-load-size", "8",
        "-c", "boot.catalog",
        "-eltorito-alt-boot", "-eltorito-platform", "efi",
        "-b", "efi/microsoft/boot/efisys.bin", "-no-emul-boot",
        "-o", str(iso_salida), str(directorio),
    ])


# ------------------------------------------------------------------------------
# Principal
# ------------------------------------------------------------------------------
def main():
    p = argparse.ArgumentParser(description="Crea una ISO booteable de Windows a partir de una VM de libvirt.")
    p.add_argument("vm", help="Nombre de la VM en libvirt (virsh list --all)")
    p.add_argument("--iso", default=ISO_ORIGINAL, help=f"ISO original (por defecto: {ISO_ORIGINAL})")
    p.add_argument("--salida", default=ISO_SALIDA, help=f"ISO de salida (por defecto: {ISO_SALIDA})")
    p.add_argument("--extraccion", default=DIRECTORIO_EXTRACCION, help="Directorio de trabajo")
    p.add_argument("--etiqueta", default=ETIQUETA_VOLUMEN, help="Etiqueta del volumen")
    p.add_argument("--particion", type=int, help="Número de partición de Windows (si no, se detecta sola)")
    p.add_argument("--uri", default=LIBVIRT_URI, help=f"URI de libvirt (por defecto: {LIBVIRT_URI})")
    p.add_argument("--nombre-imagen", default="Windows Custom")
    p.add_argument("--descripcion", default="Windows personalizado")
    p.add_argument("--solo-empaquetar", action="store_true",
                   help="Saltear extracción y captura; empaquetar el directorio de trabajo existente")
    args = p.parse_args()

    iso = Path(args.iso).resolve()
    extraccion = Path(args.extraccion).resolve()
    salida = Path(args.salida).resolve()
    # ISO9660 solo admite mayúsculas, dígitos y '_' en la etiqueta
    etiqueta = args.etiqueta.upper()

    verificar_dependencias()
    if args.solo_empaquetar:
        empaquetar_iso(extraccion, salida, etiqueta)
        exito(salida)
        return

    mantener_sudo()
    if not iso.is_file():
        error(f"No existe la ISO original: {iso}")
    if not os.access(iso, os.R_OK):
        # libvirt (dynamic_ownership) suele dejar la ISO como libvirt-qemu:0600
        error(f"Sin permiso de lectura sobre {iso}. Si la usó una VM, devolvela con:\n"
              f"    sudo chown {os.environ.get('SUDO_USER') or os.environ.get('USER')}: {iso}")

    verificar_vm_apagada(args.vm, args.uri)
    disco, formato = obtener_ultimo_disco(args.vm, args.uri)
    if not Path(disco).exists():
        error(f"El disco {disco} no existe.")

    extraer_iso(iso, extraccion)

    nbd = None
    try:
        nbd = conectar_nbd(disco, formato)
        particion = detectar_particion_windows(nbd, args.particion)
        capturar_wim(particion, extraccion / "sources" / "install.wim",
                     args.nombre_imagen, args.descripcion)
    finally:
        # Se ejecuta siempre, incluso con errores o Ctrl+C
        if nbd:
            info("Desconectando disco virtual...")
            desconectar_nbd(nbd)

    empaquetar_iso(extraccion, salida, etiqueta)
    exito(salida)


def exito(salida):
    print("=" * 59)
    print(f"[ÉXITO] La ISO ha sido creada en: {salida}")
    print("=" * 59)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n[!] Cancelado por el usuario.")
        sys.exit(130)
