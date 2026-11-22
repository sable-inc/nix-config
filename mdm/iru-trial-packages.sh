#!/bin/bash
# Iru library script, Sable Trial only, pushed by Onboarding.
# GitHub classic token with only the read:packages scope. On the Onboarding box the secret
# is named github-trial-packages-token. Paste it into token= in the Iru item. The Mac never
# reads the box, and this file in git stays empty. Never commit the token.
# Writes ~/.bunfig.toml for the sable user (mode 600) only when TRIAL_TYPE=ds.
# Engineering and every other trial type get no token. bun prefers bunfig over ~/.npmrc.
# Does not write a second copy of the token, and does not touch credentials.json.
# Never copy ~/.config/sable/credentials.json from another machine.
set -euo pipefail
token=""

die() { echo "FAIL: $*"; exit 1; }

[ -n "$token" ] || die "token is empty: paste github-trial-packages-token into this Iru item (read:packages only)"

home=$(dscl . -read /Users/sable NFSHomeDirectory | awk '{print $2}')
[ -n "$home" ] || die "no home directory for user sable"
inputs="$home/trial-inputs.env"
if [ ! -s "$inputs" ]; then
  die "no $inputs yet. sable-setup fetches the list first; this script writes the token on a later check-in, then run sable-setup again"
fi
trial_type=$(sed -n 's/^TRIAL_TYPE="\{0,1\}\([^"]*\)"\{0,1\}.*/\1/p' "$inputs" | head -1)
if [ "$trial_type" != ds ]; then
  echo "TRIAL_TYPE=${trial_type:-empty} is not ds; not writing ~/.bunfig.toml"
  unset token
  exit 0
fi
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
