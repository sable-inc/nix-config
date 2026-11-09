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

name=""
for key in LocalHostName HostName ComputerName; do
  candidate="$(scutil --get "$key" 2>/dev/null || true)"
  candidate="${candidate%%.*}"
  case "$candidate" in sable-?*) name="$candidate"; break ;; esac
done
[ -n "$name" ] || die "the Mac isn't named sable-<asset tag> yet, so its owner is unknown; set the asset tag in Iru (this retries at the next check-in)"
email="${name#sable-}@$domain"

if [ -x "$cli" ]; then
  status=0
  "$cli" status >/dev/null 2>&1 || status=$?
  case "$status" in
    0) echo "Vanta Device Monitor is already running"; exit 0 ;;
    2) "$cli" register --secret="$vanta_key" --email="$email" >/dev/null
       echo "registered the installed Vanta Device Monitor to $email"; exit 0 ;;
    *) die "Vanta Device Monitor is installed but not running (vanta-cli status exited $status); run: sudo $cli doctor" ;;
  esac
fi

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

status=0
"$cli" status >/dev/null 2>&1 || status=$?
case "$status" in
  0|2) echo "installed Vanta Device Monitor for $email" ;;
  *) die "Vanta Device Monitor installed but isn't running (vanta-cli status exited $status); run: sudo $cli doctor" ;;
esac
