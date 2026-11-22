#!/usr/bin/env bash
# shellcheck disable=SC2016 # the sh -c bodies are single-quoted on purpose
# check-baseline: fails if a piece of the Sable Mac baseline (ONB-11, Matthew Nov 21 2026) goes missing.
# Run by .github/workflows/check.yml on every push and PR, and by hand: scripts/check-baseline.sh
set -euo pipefail
cd "$(dirname "$0")/.."
fail=0
need() { # need <description> <command...>; a failure prints the command's output
  local d=$1 out
  shift
  if out=$("$@" 2>&1); then echo "ok    $d"
  else echo "FAIL  $d"; printf '%s\n' "$out" >&2; fail=1; fi
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
need "Claude managed settings pin pstack and codex marketplaces and turn autoUpdate off" py '
import json, re
d = json.load(open("module/darwin/config/claude-managed-settings.json"))
m = d["extraKnownMarketplaces"]
sha = re.compile(r"^[0-9a-f]{40}$")
for name, repo, ref in (
    ("cursor-plugins", "cursor/plugins", "7a583913eb1b8d1a0ee76753d1a2cf072e7b54f9"),
    ("openai-codex", "openai/codex-plugin-cc", "db52e28f4d9ded852ab3942cea316258ae4ef346"),
):
    src = m[name]["source"]
    assert src == {"source": "github", "repo": repo, "ref": ref}
    assert sha.match(src["ref"])
    assert m[name]["autoUpdate"] is False
assert d["enabledPlugins"] == {"pstack@cursor-plugins": True, "codex@openai-codex": True}'
need "agents.nix is imported and installs managed settings + /etc/codex/skills" sh -c '
grep -q "./agents.nix" module/darwin/default.nix &&
grep -q "ClaudeCode/managed-settings.json" module/darwin/agents.nix &&
grep -q "/etc/codex/skills" module/darwin/agents.nix &&
grep -Eq "pstackRev = \"[0-9a-f]{40}\"" module/darwin/agents.nix'
need "Orca is installed by activation" grep -q "TeamIdentifier=6CX3WHS9HZ" module/darwin/orca.nix
need "sable-setup: agent sign-ins, Orca repair, DS-only stack, deployments default, CLI from a package-read token" sh -c '
f=module/darwin/bin/sable-setup
grep -q "claude auth status" $f && grep -q "codex login status" $f &&
grep -q "ORCA_FLOW_VERSION=" $f && grep -q "closedAt != null" $f &&
grep -q ".onboarding // {}" $f && grep -q "ds_repos" $f &&
grep -q "project setup-clone" $f && grep -q -- "--destination" $f &&
grep -q -- "--folder-name deployments" $f && grep -q "https://github.com/sable-inc/deployments" $f &&
! grep -q "setup-existing-folder" $f && grep -q "@sable-inc/toolbelt" $f &&
grep -q "remove_sable_cli" $f && grep -q "bun remove -g @sable-inc/toolbelt" $f &&
grep -q "sable logout" $f && ! grep -q "every trial slot" $f && ! grep -q "every slot" $f &&
grep -q "bunfig.toml" $f && grep -q "install.scopes" $f &&
grep -q "bun add -g @sable-inc/toolbelt@^0.80.0 @sable-inc/e2e @sable-inc/wiki" $f &&
grep -q "sable login --device" $f && grep -q "sable-login-device.txt" $f &&
grep -q "github-trial-packages-token" $f && ! grep -q "cli-packages-token" $f &&
grep -q "worktree activate" $f && grep -q "sable-debug-session-hint" $f &&
grep -q "call-feedback-triage" $f && grep -q "isSableAdmin" $f &&
grep -q "setup continues" $f && ! grep -q "TRIAL_TYPE must be" $f &&
! grep -q "gh repo clone.*toolbelt" $f'
need "sable-doctor: notifications, managed plugins, codex skills, Orca onboarding, sign-ins, DS repo works" sh -c '
f=module/darwin/bin/sable-doctor
for l in "notifications on (Iru Sable: Notifications)" "Claude Code managed plugins: pstack + codex review" \
         "Codex admin skills: pstack in /etc/codex/skills" "Orca onboarding finished" "signed in" \
         "Claude Code trusts ~/deployments (DS)" "Codex trusts ~/deployments (DS)" \
         "== DS repo works" "skipped (non-DS)" "sable CLI installed" \
         "sable --version" "sable whoami: this slot" \
         "sable-login-device.txt" "sable CLI absent" "sable CLI config absent" \
         "no @sable-inc scope in ~/.bunfig.toml" \
         "sable-debug-session-hint" "call-feedback-triage" \
         "Orca active workspace is ~/deployments" "Claude tabs open in ~/deployments"; do grep -qF "$l" $f || exit 1; done
grep -q "all(c == clone for c in claude)" $f && ! grep -q "else ws == clone" $f && ! grep -q "not claude and ws" $f
for c in "git -C" "git fetch" "gh repo view sable-inc/deployments" "claude auth status" \
         "codex login status" "status --format json" "isAuthenticated" "repo list --json"; do
  grep -qF "$c" $f || exit 1
  grep -qF "$c" module/darwin/bin/sable-setup || exit 1
done'
need "trial policy: only ds gets Sable repos and tools; unknown and empty do not stop; deployments is added when missing" bash -c '
set -e
eval "$(sed -n "/^# BEGIN sable_trial_policy$/,/^# END sable_trial_policy$/p" module/darwin/bin/sable-setup)"
for t in eng fde design ae el marketing; do
  [ "$(sable_trial_kind "$t")" = known ] || exit 1
  sable_stack trial "$t" && exit 1
done
[ "$(sable_trial_kind "")" = empty ]
sable_stack trial "" && exit 1
[ "$(sable_trial_kind nope)" = unknown ]
sable_stack trial nope && exit 1
[ "$(sable_trial_kind ds)" = ds ]
sable_stack trial ds
sable_stack onboard ""
[ "$(ds_repos "")" = "sable-inc/deployments" ]
[ "$(ds_repos "sable-inc/runtime")" = "sable-inc/runtime sable-inc/deployments" ]
[ "$(ds_repos "sable-inc/deployments@trial/mia")" = "sable-inc/deployments@trial/mia" ]
# Non-DS, empty and unknown do none of the toolbelt workflow, org login, SableBrowse or clones.
grep -q "if sable_stack \"\$profile\" \"\$trial_type\"" module/darwin/bin/sable-setup
# The CLI install does not read the slot GitHub token.
awk "/^install_sable_cli\\(\\)/,/^}/" module/darwin/bin/sable-setup | grep -q bunfig_ready
awk "/^install_sable_cli\\(\\)/,/^}/" module/darwin/bin/sable-setup | grep -q "bun add -g @sable-inc/toolbelt@^0.80.0 @sable-inc/e2e @sable-inc/wiki"
awk "/^install_sable_cli\\(\\)/,/^}/" module/darwin/bin/sable-setup | grep -q "gh auth token" && exit 1 || true
'
need "bunfig check accepts a real token and rejects placeholders" bash -c '
set -e
eval "$(sed -n "/^bunfig_ready()/,/^}/p" module/darwin/bin/sable-setup)"
HOME=$(mktemp -d)
bunfig_ready && exit 1
printf "%s\n" "[install.scopes]" "\"@sable-inc\" = { url = \"https://npm.pkg.github.com\", token = \"<token>\" }" > "$HOME/.bunfig.toml"
bunfig_ready && exit 1
printf "%s\n" "[install.scopes]" "\"@sable-inc\" = { url = \"https://npm.pkg.github.com\", token = \"\" }" > "$HOME/.bunfig.toml"
bunfig_ready && exit 1
printf "%s\n" "[install.scopes]" "\"@sable-inc\" = { url = \"https://npm.pkg.github.com\", token = \"read-packages\" }" > "$HOME/.bunfig.toml"
bunfig_ready
'
need "Iru writes only ~/.bunfig.toml and ships no token" sh -c '
f=mdm/iru-trial-packages.sh
grep -q "github-trial-packages-token" $f && grep -q "token=\"\"" $f &&
grep -q "\[install.scopes\]" $f && grep -q "@sable-inc" $f &&
grep -q "npm.pkg.github.com" $f && grep -q "chmod 600" $f &&
grep -q "does not touch credentials.json" $f
'
need "Chrome sync is off for trial only; the shared SableBrowse profile does not set SyncDisabled" py '
import plistlib
trial = plistlib.load(open("mdm/chrome-trial-sync.mobileconfig", "rb"))
payloads = [x for x in trial["PayloadContent"] if x.get("PayloadType") == "com.google.Chrome"]
assert len(payloads) == 1 and payloads[0]["SyncDisabled"] is True
shared = open("mdm/chrome-sablebrowse.mobileconfig").read()
assert "SyncDisabled" not in shared'
need "Orca planner keeps the deployments clone, drops home and duplicates, and refuses a home clone" py '
import pathlib, subprocess, tempfile, os, textwrap
src = pathlib.Path("module/darwin/bin/sable-setup").read_text()
start, end = src.index("# BEGIN orca_project_plan"), src.index("# END orca_project_plan")
body = src[start:end]
py = body.split("<<'\''PY'\''", 1)[1].split("PY", 1)[0]
script = pathlib.Path(tempfile.mkdtemp()) / "plan.py"
script.write_text(py)
def run(home, clone, setups, repos):
    d = pathlib.Path(tempfile.mkdtemp())
    (d / "s.json").write_text(setups)
    (d / "r.json").write_text(repos)
    p = subprocess.run(["python3", "-I", str(script), home, clone, str(d / "s.json"), str(d / "r.json")], capture_output=True, text=True)
    return p.returncode, p.stdout.strip(), p.stderr.strip()
code, out, err = run("/Users/sable", "/Users/sable/deployments",
    """[{"id":"home","path":"/Users/sable"},{"id":"ok","path":"/Users/sable/deployments"},{"id":"other","path":"/Users/sable/other","repo":"sable-inc/runtime"}]""",
    "[]")
assert code == 0 and "delete home" in out.splitlines() and "add" not in out.splitlines(), (out, err)
code, out, err = run("/Users/sable", "/Users/sable/deployments",
    """[{"id":"a","path":"/Users/sable/deployments"},{"id":"b","path":"/Users/sable/deployments"}]""", "[]")
assert code == 0 and out.splitlines() == ["delete b"], (out, err)
code, out, err = run("/Users/sable", "/Users/sable", "[]", "[]")
assert code != 0, (out, err)
code, out, err = run("/Users/sable", "/Users/sable/deployments", """[{"path":"/Users/sable"}]""", "[]")
assert code != 0, (out, err)'
need "admin check is user.isSableAdmin and nothing else" bash -c '
eval "$(sed -n "/^# BEGIN sable_admin_check$/,/^# END sable_admin_check$/p" module/darwin/bin/sable-setup)"
printf "%s" "{\"user\":{\"isSableAdmin\":true,\"email\":\"secret@example.com\"}}" | sable_is_admin
printf "%s" "{\"user\":{\"isSableAdmin\":false}}" | sable_is_admin && exit 1
printf "%s" "{\"user\":{\"role\":\"admin\"}}" | sable_is_admin && exit 1
true
'
if ! command -v shellcheck >/dev/null 2>&1; then
  if command -v apt-get >/dev/null 2>&1; then
    echo "installing shellcheck (same as CI)" >&2
    sudo apt-get update -qq && sudo apt-get install -y -qq shellcheck
  fi
fi
if ! command -v shellcheck >/dev/null 2>&1; then
  echo "FAIL  shellcheck: not installed. CI installs it with apt-get; install shellcheck and rerun." >&2
  fail=1
else
  need "shellcheck: bin and mdm scripts" shellcheck -s bash module/darwin/bin/sable-doctor module/darwin/bin/sable-setup mdm/iru-bootstrap.sh mdm/iru-doctor.sh mdm/iru-update.sh mdm/iru-vanta.sh mdm/iru-trial-packages.sh scripts/check-baseline.sh
fi
if [ "$fail" = 0 ]; then echo "check-baseline: PASS"; else echo "check-baseline: FAIL"; exit 1; fi
