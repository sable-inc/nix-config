#!/bin/bash
# Iru custom script, Sable Trial blueprint, run once per device. Iru retries it at each
# check-in until it exits 0; the bootstrap resumes where the last run stopped.
set -euo pipefail
ref="main"
dir="$(mktemp -d)"
trap 'rm -rf "$dir"' EXIT
curl --proto '=https' --tlsv1.2 -fsSL -o "$dir/bootstrap" \
  "https://raw.githubusercontent.com/sable-inc/nix-config/$ref/target/aarch64-darwin/bootstrap"
# Run as a child so the EXIT trap still cleans up, and pass a stop from Iru on to it.
/bin/bash "$dir/bootstrap" --profile trial --ref "$ref" &
child=$!
trap 'kill -TERM "$child" 2>/dev/null; wait "$child"; exit 143' TERM INT HUP
wait "$child"
