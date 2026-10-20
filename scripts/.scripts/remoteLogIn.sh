#!/usr/bin/env bash
# /usr/local/bin/remote-login.sh
# Uso: ejecutarlo como tu usuario (NO con sudo), por ejemplo desde SSH:
#   remote-login.sh            # si ya hay una sesión gráfica, avisa y no hace nada
#   remote-login.sh --force    # reinicia SDDM igual (cierra la sesión existente)
set -euo pipefail

# ---------- Parámetros ----------
FORCE=0
for arg in "$@"; do
  case "$arg" in
    -f|--force) FORCE=1 ;;
    -h|--help)
      echo "Uso: $(basename "$0") [-f|--force]"
      echo "  -f, --force   Inicia la sesión aunque ya haya una sesión gráfica abierta"
      exit 0 ;;
    *)
      echo "Parámetro desconocido: $arg (usá --help)" >&2
      exit 1 ;;
  esac
done

# ---------- Configuración ----------
SESSION_FILE="hyprland-uwsm.desktop"   # verificá el nombre en /usr/share/wayland-sessions/
SDDM_CONF="/etc/sddm.conf"
TIMEOUT=30                             # segundos máximos esperando la sesión
# Solo si usás KWallet con backend GPG (ver notas). Vacío = no se usa.
KWALLET_GPG_KEYGRIP=""
GPG_PRESET="/usr/lib/gnupg/gpg-preset-passphrase"

# ---------- Usuario y entorno ----------
if [[ $EUID -eq 0 ]]; then
  echo "Ejecutalo como tu usuario, no como root." >&2
  exit 1
fi
REAL_USER=$(id -un)
REAL_UID=$(id -u)
RUNTIME_DIR="/run/user/$REAL_UID"
export XDG_RUNTIME_DIR="$RUNTIME_DIR"
export DBUS_SESSION_BUS_ADDRESS="unix:path=$RUNTIME_DIR/bus"

# ---------- Detectar sesiones gráficas ya abiertas ----------
# Lista sesiones wayland/x11 de clase "user" (excluye el greeter de SDDM y las de SSH/TTY)
# Devuelve solo los IDs, uno por línea
graphical_session_ids() {
  local id type class
  for id in $(loginctl list-sessions --no-legend | awk '{print $1}'); do
    type=$(loginctl show-session "$id" -p Type --value 2>/dev/null) || continue
    class=$(loginctl show-session "$id" -p Class --value 2>/dev/null) || continue
    [[ ( $type == wayland || $type == x11 ) && $class == user ]] || continue
    echo "$id"
  done
}

OLD_IDS=$(graphical_session_ids)
if [[ -n "$OLD_IDS" ]]; then
  echo "Ya hay una sesión gráfica abierta:"
  for id in $OLD_IDS; do
    printf '  sesión %s: usuario=%s tipo=%s estado=%s\n' "$id" \
      "$(loginctl show-session "$id" -p Name --value)" \
      "$(loginctl show-session "$id" -p Type --value)" \
      "$(loginctl show-session "$id" -p State --value)"
  done
  if (( FORCE == 0 )); then
    echo "No se hizo nada. Usá --force para reiniciar SDDM igual (se cierra esa sesión)."
    exit 2
  fi
  echo "--force activo: se va a reiniciar SDDM y esa sesión se cerrará."
fi

# ---------- Pedir la contraseña una sola vez ----------
read -rsp "Contraseña de $REAL_USER: " PASS
echo
# La validamos contra sudo (y de paso queda cacheada para el resto del script)
sudo -k
if ! printf '%s\n' "$PASS" | sudo -S -p '' -v 2>/dev/null; then
  echo "Contraseña incorrecta." >&2
  exit 1
fi

# ---------- Limpieza garantizada (aunque falle algo o hagas Ctrl+C) ----------
cleanup() {
  if [[ -f "$SDDM_CONF.bak" ]]; then
    sudo mv "$SDDM_CONF.bak" "$SDDM_CONF"
    echo "Configuración original de SDDM restaurada."
  fi
  unset PASS
}
trap cleanup EXIT

# ---------- 1. Autologin temporal ----------
sudo cp -a "$SDDM_CONF" "$SDDM_CONF.bak"
sudo sed -i "s/^User=.*/User=$REAL_USER/" "$SDDM_CONF"
sudo sed -i "s/^Session=.*/Session=$SESSION_FILE/" "$SDDM_CONF"

echo "Reiniciando SDDM para logueo remoto..."
sudo systemctl restart sddm

# ---------- 2. Esperar a que la sesión gráfica esté arriba (en vez de sleep fijo) ----------
# Se espera una sesión con ID NUEVO: con --force, la vieja puede seguir
# figurando como activa unos instantes después del restart.
new_session_up() {
  local id
  for id in $(graphical_session_ids); do
    grep -qx "$id" <<<"$OLD_IDS" && continue
    return 0
  done
  return 1
}

echo "Esperando la sesión gráfica..."
READY=0
for ((i = 0; i < TIMEOUT; i++)); do
  if new_session_up && [[ -S "$RUNTIME_DIR/bus" ]] &&
     systemctl --user is-active --quiet graphical-session.target; then
    READY=1
    break
  fi
  sleep 1
done
if (( READY == 0 )); then
  echo "La sesión no levantó en ${TIMEOUT}s." >&2
  exit 1
fi

# Ya logueó: restauramos sddm.conf ahora mismo
sudo mv "$SDDM_CONF.bak" "$SDDM_CONF"
echo "Configuración original de SDDM restaurada."

# ---------- 3. Desbloquear wallets ----------
# gnome-keyring (lo usan la mayoría de apps vía org.freedesktop.secrets)
if command -v gnome-keyring-daemon >/dev/null; then
  # Esperar a que el daemon esté escuchando
  for ((i = 0; i < 10; i++)); do
    [[ -S "$RUNTIME_DIR/keyring/control" ]] && break
    sleep 1
  done
  printf '%s' "$PASS" | gnome-keyring-daemon --unlock >/dev/null 2>&1 || true

  locked=$(busctl --user get-property org.freedesktop.secrets \
    /org/freedesktop/secrets/collection/login \
    org.freedesktop.Secret.Collection Locked 2>/dev/null || echo "?")
  case "$locked" in
    "b false") echo "gnome-keyring: desbloqueado." ;;
    "b true")  echo "gnome-keyring: sigue bloqueado (¿la contraseña del keyring es distinta a la de login?)." >&2 ;;
    *)         echo "gnome-keyring: no se pudo verificar el estado." >&2 ;;
  esac
fi

# KWallet con backend GPG: se precarga la passphrase en gpg-agent,
# así cuando una app abra la wallet no aparece ningún diálogo.
if [[ -n "$KWALLET_GPG_KEYGRIP" && -x "$GPG_PRESET" ]]; then
  gpg-connect-agent /bye >/dev/null 2>&1 || true
  if printf '%s' "$PASS" | "$GPG_PRESET" --preset "$KWALLET_GPG_KEYGRIP"; then
    echo "KWallet (GPG): passphrase cargada en gpg-agent."
  else
    echo "KWallet (GPG): no se pudo precargar la passphrase." >&2
  fi
fi

unset PASS

# ---------- 4. Sunshine ----------
echo "Reiniciando Sunshine..."
systemctl --user restart app-dev.lizardbyte.app.Sunshine.service ; systemctl --user restart sunshine.service

loginctl list-sessions --output=cat
