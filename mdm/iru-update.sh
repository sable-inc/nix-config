#!/bin/bash
# Iru custom script, run every check-in on Sable Trial and Sable Onboard. Rebuilds a Mac only
# when nix-config's fleet branch has moved since its last build (git push origin main:fleet),
# while sable is logged in; otherwise it exits at once. Same file for both blueprints.
set -euo pipefail
# Trial Macs: accept pending sable-inc repository invites as the slot user, on every
# check-in, before the rebuild. The slot's own gh sign-in is used. Other owners are
# not accepted. A missing binary means the first install has not finished.
accept_code=0
if grep -q 'sable.profile *= *"trial"' /etc/nix-darwin/local.nix 2>/dev/null; then
  accept=/run/current-system/sw/bin/sable-accept-invites
  if [ -x "$accept" ]; then
    install -d -o root -g wheel -m 755 /Library/Logs/sable
    touch /Library/Logs/sable/github-invites.log
    chown sable:staff /Library/Logs/sable/github-invites.log
    chmod 644 /Library/Logs/sable/github-invites.log
    sudo -H -u sable /usr/bin/env -u GH_TOKEN -u GITHUB_TOKEN /bin/zsh -ic "exec $accept" || accept_code=$?
  else
    echo "sable-accept-invites not installed yet"
  fi
fi
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
[ "$code" = 75 ] && code=0
[ "$code" != 0 ] && exit "$code"
exit "$accept_code"
