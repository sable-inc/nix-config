#!/usr/bin/env bash
# shellcheck disable=SC2016 # the sh -c bodies are single-quoted on purpose
# check-baseline: fails if a piece of the Sable Mac baseline (ONB-11, Matthew Nov 21 2026) goes missing.
# Run by .github/workflows/check.yml on every push and PR, and by hand: scripts/check-baseline.sh
set -euo pipefail
cd "$(dirname "$0")/.."
fail=0
need() { # need <description> <command...>
  local d=$1; shift
  if "$@" >/dev/null 2>&1; then echo "ok    $d"; else echo "FAIL  $d"; fail=1; fi
}
py() { python3 -I -c "$@"; }

need "notifications profile parses, one notificationsettings payload, Slack + Orca enabled" py '
import plistlib
d = plistlib.load(open("mdm/notifications.mobileconfig", "rb"))
p = [x for x in d["PayloadContent"] if x["PayloadType"] == "com.apple.notificationsettings"]
assert len(p) == 1
e = {s["BundleIdentifier"]: s for s in p[0]["NotificationSettings"]}
for b in ("com.tinyspeck.slackmacgap", "com.stablyai.orca"):
    assert e[b]["NotificationsEnabled"] is True and e[b]["AlertType"] in (1, 2)'
need "Claude managed settings enable pstack and codex from their marketplaces" py '
import json
d = json.load(open("module/darwin/config/claude-managed-settings.json"))
m = d["extraKnownMarketplaces"]
assert m["cursor-plugins"]["source"] == {"source": "github", "repo": "cursor/plugins"}
assert m["openai-codex"]["source"] == {"source": "github", "repo": "openai/codex-plugin-cc"}
assert d["enabledPlugins"] == {"pstack@cursor-plugins": True, "codex@openai-codex": True}'
need "agents.nix is imported and installs managed settings + /etc/codex/skills" sh -c '
grep -q "./agents.nix" module/darwin/default.nix &&
grep -q "ClaudeCode/managed-settings.json" module/darwin/agents.nix &&
grep -q "/etc/codex/skills" module/darwin/agents.nix &&
grep -Eq "pstackRev = \"[0-9a-f]{40}\"" module/darwin/agents.nix'
need "Orca is installed by activation" grep -q "TeamIdentifier=6CX3WHS9HZ" module/darwin/orca.nix
need "sable-setup: agent sign-ins, Orca seed, DS-only repos, Sable CLI" sh -c '
f=module/darwin/bin/sable-setup
grep -q "claude auth status" $f && grep -q "codex login status" $f &&
grep -q "ORCA_FLOW_VERSION=" $f && grep -q "TRIAL_TYPE=ds needs sable-inc/deployments" $f &&
grep -q "repo add --path" $f && grep -q "@sable-inc/toolbelt" $f'
need "sable-doctor: notifications, managed plugins, codex skills, Orca onboarding, sign-ins, DS repos" sh -c '
f=module/darwin/bin/sable-doctor
for l in "notifications on (Iru Sable: Notifications)" "Claude Code managed plugins: pstack + codex review" \
         "Codex admin skills: pstack in /etc/codex/skills" "Orca onboarding finished" "signed in" \
         "Claude Code trusts ~/deployments (DS)" "Codex trusts ~/deployments (DS)" "Orca has ~/deployments (DS)" \
         "sable CLI installed"; do grep -qF "$l" $f || exit 1; done'
need "shellcheck: bin and mdm scripts" shellcheck -s bash module/darwin/bin/sable-doctor module/darwin/bin/sable-setup mdm/iru-bootstrap.sh mdm/iru-doctor.sh mdm/iru-update.sh mdm/iru-vanta.sh scripts/check-baseline.sh
if [ "$fail" = 0 ]; then echo "check-baseline: PASS"; else echo "check-baseline: FAIL"; exit 1; fi
