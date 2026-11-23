#!/bin/bash
# Iru Custom Script "ONB computer-use check (read-only)", run daily (docs/iru.md).
# Read-only: shows whether mdm/computer-use-pppc.mobileconfig reached this Mac (installed profile and
# TCC MDM overrides), the user's Screen Recording / Accessibility state in TCC, and whether each of the
# seven profile ids still satisfies its designated requirement. Changes nothing. Never prints a secret.
# skip_serials: serials this run must not touch (space separated). Set when the item is pasted.
skip_serials=""
set -u
serial=$(/usr/sbin/ioreg -rd1 -c IOPlatformExpertDevice | /usr/bin/awk -F'"' '/IOPlatformSerialNumber/{print $4}')
for s in $skip_serials; do
  if [ "$serial" = "$s" ]; then echo "skipped $serial (in skip_serials); nothing read"; exit 0; fi
done
echo "== computer-use check $(/usr/sbin/scutil --get ComputerName 2>/dev/null) $serial $(/bin/date -u +%FT%TZ) macOS $(/usr/bin/sw_vers -productVersion)"
echo "== profile"
/usr/bin/profiles show -type configuration 2>/dev/null | /usr/bin/grep -E 'attribute: name: Sable: Computer use' | /usr/bin/sed 's/^ *//' || true
/usr/bin/profiles show -type configuration 2>/dev/null | /usr/bin/grep -q 'Sable: Computer use' && echo "profile installed" || echo "profile NOT installed"
apps=(
  "com.stablyai.orca|/Applications/Orca.app|6CX3WHS9HZ"
  "com.stablyai.orca.computer-use|/Applications/Orca.app/Contents/Resources/Orca Computer Use.app|6CX3WHS9HZ"
  "com.anthropic.claudefordesktop|/Applications/Claude.app|Q6L2SF6YDW"
  "com.openai.codex|/Applications/ChatGPT.app|2DC432GLL2"
  "com.openai.chat|/Applications/ChatGPT.app|2DC432GLL2"
  "com.openai.sky.CUAService|/Applications/ChatGPT.app/Contents/Resources/cua_node/lib/node_modules/@oai/sky/Codex Computer Use.app|2DC432GLL2"
  "com.openai.sky.CUAService.cli|/Applications/ChatGPT.app/Contents/Resources/cua_node/lib/node_modules/@oai/sky/Codex Computer Use.app/Contents/SharedSupport/SkyComputerUseClient.app|2DC432GLL2"
)
echo "== MDM overrides (what the profile granted)"
mo="/Library/Application Support/com.apple.TCC/MDMOverrides.plist"
if [ -r "$mo" ]; then
  for e in "${apps[@]}"; do
    id=${e%%|*}
    key=${id//./\\.}  # plutil keypaths split on dots, so escape the dots in the bundle id
    /usr/bin/plutil -extract "$key" xml1 -o - "$mo" >/dev/null 2>&1 || { echo "  $id: none"; continue; }
    svcs=$(/usr/bin/plutil -extract "$key" xml1 -o - "$mo" | /usr/bin/grep -oE 'kTCCService[A-Za-z]+' | /usr/bin/sort -u | /usr/bin/tr '\n' ' ')
    echo "  $id: $svcs"
  done
else
  echo "  $mo not readable or absent"
fi
echo "== TCC (auth_value 2 = allowed, 0 = denied)"
q() { /usr/bin/sqlite3 -readonly "$1" "select service, client, auth_value, auth_reason from access where client like 'com.stablyai.orca%' or client like 'com.anthropic.claudefordesktop' or client like 'com.openai.%' order by client, service;" 2>&1 | /usr/bin/sed 's/^/  /'; }
echo " system db:"; q "/Library/Application Support/com.apple.TCC/TCC.db"
echo " user sable db:"; q "/Users/sable/Library/Application Support/com.apple.TCC/TCC.db"
echo "== installed apps vs profile code requirement"
for e in "${apps[@]}"; do
  IFS='|' read -r id path team <<<"$e"
  paths=("$path")
  case "$id" in
    com.openai.sky.CUAService)
      paths+=("/Users/sable/.codex/computer-use/Codex Computer Use.app") ;;
    com.openai.sky.CUAService.cli)
      paths+=("/Users/sable/.codex/computer-use/Codex Computer Use.app/Contents/SharedSupport/SkyComputerUseClient.app") ;;
  esac
  seen=""
  for path in "${paths[@]}"; do
    [ -d "$path" ] || continue
    seen=1
    have=$(/usr/bin/defaults read "$path/Contents/Info.plist" CFBundleIdentifier 2>/dev/null)
    [ "$have" = "$id" ] || { echo "  $id: $path is ${have:-unreadable}, not this id"; continue; }
    ver=$(/usr/bin/defaults read "$path/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null)
    req="identifier \"$id\" and anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] /* exists */ and certificate leaf[field.1.2.840.113635.100.6.1.13] /* exists */ and certificate leaf[subject.OU] = \"$team\""
    if /usr/bin/codesign -v -R="$req" "$path" 2>/dev/null; then m="matches"; else m="DOES NOT MATCH"; fi
    echo "  $id $ver: $m ($path); designated: $(/usr/bin/codesign -dr - "$path" 2>&1 | /usr/bin/sed -n 's/^designated => //p')"
  done
  [ -n "$seen" ] || echo "  $id: not installed at ${paths[*]}"
done
echo "== end"
exit 0
