#!/bin/bash
# Iru custom script, on demand from Self Service on Sable Trial and Sable Onboard. Moves the
# Mac to nix-config's main and rebuilds only when it changed since the last build, while
# sable is logged in. Skips Macs whose first install hasn't finished. Same file for both
# blueprints.
set -euo pipefail
dir="$(mktemp -d)"
trap 'rm -rf "$dir"' EXIT
curl --proto '=https' --tlsv1.2 -fsSL -o "$dir/bootstrap" \
  "https://raw.githubusercontent.com/sable-inc/nix-config/main/target/aarch64-darwin/bootstrap"
/bin/bash "$dir/bootstrap" --update &
child=$!
trap 'kill -TERM "$child" 2>/dev/null; wait "$child"; exit 143' TERM INT HUP
wait "$child"
