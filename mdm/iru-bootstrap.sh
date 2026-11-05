#!/bin/bash
# Iru custom script, run once per device. Iru retries it at each check-in until it exits 0;
# the bootstrap resumes where the last run stopped. Paste it into each blueprint's own
# bootstrap item with profile set for that blueprint: trial for Sable Trial, onboard for
# Sable Onboard.
set -euo pipefail
profile="trial"
ref="main"
dir="$(mktemp -d)"
trap 'rm -rf "$dir"' EXIT
curl --proto '=https' --tlsv1.2 -fsSL -o "$dir/bootstrap" \
  "https://raw.githubusercontent.com/sable-inc/nix-config/$ref/target/aarch64-darwin/bootstrap"
# Run as a child so the EXIT trap still cleans up, and pass a stop from Iru on to it.
/bin/bash "$dir/bootstrap" --profile "$profile" --ref "$ref" &
child=$!
trap 'kill -TERM "$child" 2>/dev/null; wait "$child"; exit 143' TERM INT HUP
wait "$child"
