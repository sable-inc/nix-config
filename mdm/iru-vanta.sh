#!/bin/bash
# Iru custom script, run once per device (Iru retries it at each check-in until it exits 0).
# Installs Vanta Device Monitor and registers it to <asset tag>@sable.ai: Iru names the Mac
# sable-<asset tag>, and asset tags are the part of the person's (or trial slot's) email
# before @. Same file for every blueprint.
#
# Paste the company Vanta key into vanta_key in the Iru item only. Never commit it.
# Vanta > Computers > Unmonitored > View setup instructions > Option 3 shows it as VANTA_KEY.
set -euo pipefail
vanta_key=""
region="us"
domain="sable.ai"
# From Vanta's own installer (github.com/VantaInc/vanta-agent-scripts, install-macos.sh).
# The agent updates itself after this first install.
pkg_url="https://agent-downloads.vanta.com/targets/versions/2.21.0/vanta-universal.pkg"
pkg_sha256="7d8367ea3e4deadd41acaa8197b158c13d4edc2f40174359805a8ddad433c5a9"
developer_id="Vanta Inc (632L25QNV4)"
cert_sha256="48893790A4B4FB1684589E3AC91CC25EDD5284F9E7BA07025CBDF2814FE74984"
cli="/usr/local/vanta/vanta-cli"
conf="/etc/vanta.conf"

die() { echo "FAIL: $*"; exit 1; }

[ -n "$vanta_key" ] || die "vanta_key is empty: paste the company Vanta key into this Iru item"

monitor_status() { local code=0; "$cli" status >/dev/null 2>&1 || code=$?; echo "$code"; }

if [ -x "$cli" ] && [ "$(monitor_status)" = 0 ]; then
  echo "Vanta Device Monitor is already running"
  exit 0
fi

name=""
for key in LocalHostName HostName ComputerName; do
  candidate="$(scutil --get "$key" 2>/dev/null || true)"
  candidate="${candidate%%.*}"
  case "$candidate" in sable-?*) name="$candidate"; break ;; esac
done
if [ -z "$name" ]; then
  # Older Macs on Default Blueprint keep their own names; their owner can't be inferred.
  echo "skipped: the Mac isn't named sable-<asset tag>, so its owner is unknown; install Vanta Device Monitor by hand"
  exit 0
fi
email="${name#sable-}@$domain"

if [ ! -x "$cli" ]; then
  dir="$(mktemp -d)"
  trap 'rm -rf "$dir"' EXIT
  pkg="$dir/vanta.pkg"
  curl --proto '=https' --tlsv1.2 -fsSL -o "$pkg" "$pkg_url"
  [ "$(shasum -a 256 "$pkg" | cut -d' ' -f1)" = "$pkg_sha256" ] || die "the Vanta package checksum doesn't match"
  signature="$(pkgutil --check-signature "$pkg")"
  grep -qF "$developer_id" <<<"$signature" || die "the Vanta package isn't signed by $developer_id"
  tr -d ' \n' <<<"$signature" | grep -qF "SHA256Fingerprint:$cert_sha256" || die "the Vanta signing certificate doesn't match"

  # The installer reads this file to register the Mac, the same way Vanta's own script does.
  umask 077
  printf '{"ACTIVATION_REQUESTED_NONCE":%s000,"AGENT_KEY":"%s","OWNER_EMAIL":"%s","NEEDS_OWNER":true,"REGION":"%s"}\n' \
    "$(date +%s)" "$vanta_key" "$email" "$region" > "$conf"
  chown root:wheel "$conf"
  chmod 600 "$conf"
  installer -pkg "$pkg" -target / >/dev/null
fi

# Status 2 means running but not registered: let the installer's own registration finish
# first, then register directly. Anything else non-zero gets one start. A failure exits
# non-zero so Iru retries at the next check-in.
code="$(monitor_status)"
case "$code" in 0|2) ;; *) "$cli" start >/dev/null 2>&1 || true ;; esac
if [ "$(monitor_status)" = 2 ]; then
  "$cli" check-registration --attempts=6 >/dev/null 2>&1 ||
    "$cli" register --secret="$vanta_key" --email="$email" >/dev/null
fi
code="$(monitor_status)"
[ "$code" = 0 ] || die "Vanta Device Monitor isn't running and registered (vanta-cli status exited $code); run: sudo $cli doctor"
echo "Vanta Device Monitor is running, registered to $email"
