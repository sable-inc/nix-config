#!/bin/bash
# Iru custom script, run every check-in on Sable Trial and Sable Onboard. Rebuilds a Mac only
# when nix-config's fleet branch has moved since its last build (git push origin main:fleet),
# while sable is logged in; otherwise it exits at once. Same file for both blueprints.
set -euo pipefail
dir="$(mktemp -d)"
trap 'rm -rf "$dir"' EXIT
curl --proto '=https' --tlsv1.2 -fsSL -o "$dir/bootstrap" \
  "https://raw.githubusercontent.com/sable-inc/nix-config/fleet/target/aarch64-darwin/bootstrap"
/bin/bash "$dir/bootstrap" --update &
child=$!
trap 'kill -TERM "$child" 2>/dev/null; wait "$child"; exit 143' TERM INT HUP
code=0
wait "$child" || code=$?
# 75: another run (the first install or an update) holds the lock; nothing to do this time.
[ "$code" = 75 ] && exit 0
exit "$code"
