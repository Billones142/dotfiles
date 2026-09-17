#!/bin/bash
set -e

cleanup() {
  sudo rm -f /tmp/ncdu_root.json /tmp/ncdu_home.json /tmp/ncdu_combined.json
}
trap cleanup EXIT

echo "Scanning /..."
sudo ncdu -0 -x -o /tmp/ncdu_root.json /

echo "Scanning /home..."
sudo ncdu -0 -x -o /tmp/ncdu_home.json /home

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
ncdu -f /tmp/ncdu_combined.json --enable-refresh
