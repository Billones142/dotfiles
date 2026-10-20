#!/bin/bash
set -e

cleanup() {
  sudo rm -f /tmp/ncdu_root.json /tmp/ncdu_home.json /tmp/ncdu_combined.json
}
sudo -v
trap cleanup EXIT

# Eliminar una sesión anterior si existe
sudo tmux kill-session -t "$SESSION" 2>/dev/null || true

SESSION="escaneos"

# Crear el primer panel ejecutando tmux como root
sudo tmux new-session -d -s "$SESSION" \
    "echo \"Escaneando /\" && ncdu -1 -x -o /tmp/ncdu_root.json /"

# Crear el segundo panel
sudo tmux split-window -v -t "$SESSION" \
    "echo \"Escaneando /home\" && ncdu -1 -x -o /tmp/ncdu_home.json /home"

# Redimensionar los paneles horizontalmente
sudo tmux select-layout -t "$SESSION" even-vertical || true

# Conectarse a la sesión como root
sudo tmux attach-session -t "$SESSION"


echo "Merging JSON trees..."
if command -v pv >/dev/null 2>&1; then
  jq -s '
    (.[1][3] | .[0] = (.[0] + {"name": "home"})) as $home_tree |
    .[0][3] |= map(if (type == "array" and .[0].name == "home") or (type == "object" and .name == "home") then empty else . end) |
    .[0][3] += [$home_tree] |
    .[0]
  ' /tmp/ncdu_root.json /tmp/ncdu_home.json | pv -s $(du -b /tmp/ncdu_root.json /tmp/ncdu_home.json | awk '{s+=$1} END {print s}') > /tmp/ncdu_combined.json
else
  jq -s '
    (.[1][3] | .[0] = (.[0] + {"name": "home"})) as $home_tree |
    .[0][3] |= map(if (type == "array" and .[0].name == "home") or (type == "object" and .name == "home") then empty else . end) |
    .[0][3] += [$home_tree] |
    .[0]
  ' /tmp/ncdu_root.json /tmp/ncdu_home.json > /tmp/ncdu_combined.json
fi

echo "Launching ncdu..."
ncdu --enable-delete --delete-command 'pkexec trash-put --' --no-confirm-delete -f /tmp/ncdu_combined.json --enable-refresh
