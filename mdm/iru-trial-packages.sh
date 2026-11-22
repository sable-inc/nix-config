#!/bin/bash
# Iru library script, Sable Trial only, pushed by Onboarding.
# GitHub classic token with only the read:packages scope. On the Onboarding box the secret
# is named github-trial-packages-token. Paste it into token= in the Iru item. The Mac never
# reads the box, and this file in git stays empty. Never commit the token.
# Writes only ~/.bunfig.toml for the sable user (mode 600). bun prefers that over ~/.npmrc.
# Does not write a second copy of the token, and does not touch credentials.json.
# Never copy ~/.config/sable/credentials.json from another machine.
set -euo pipefail
token=""

die() { echo "FAIL: $*"; exit 1; }

[ -n "$token" ] || die "token is empty: paste github-trial-packages-token into this Iru item (read:packages only)"

home=$(dscl . -read /Users/sable NFSHomeDirectory | awk '{print $2}')
[ -n "$home" ] || die "no home directory for user sable"
bunfig="$home/.bunfig.toml"
umask 077
cat >"$bunfig" <<EOF
[install.scopes]
"@sable-inc" = { url = "https://npm.pkg.github.com", token = "${token}" }
EOF
chown sable:staff "$bunfig"
chmod 600 "$bunfig"
unset token
echo "wrote $bunfig (mode 600). The token was not printed."
