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
need "Claude managed settings pin the plugin marketplaces (plugin autoUpdate off keeps the SHA pins) and never disable Claude Code self-update" py '
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
assert d["enabledPlugins"] == {"pstack@cursor-plugins": True, "codex@openai-codex": True}
assert set(d) == {"extraKnownMarketplaces", "enabledPlugins"}, "managed settings may only pin plugins: no env/autoUpdatesChannel/DISABLE_*"'
need "agents.nix is imported and installs managed settings + /etc/codex/skills" sh -c '
grep -q "./agents.nix" module/darwin/default.nix &&
grep -q "ClaudeCode/managed-settings.json" module/darwin/agents.nix &&
grep -q "/etc/codex/skills" module/darwin/agents.nix &&
grep -Eq "pstackRev = \"[0-9a-f]{40}\"" module/darwin/agents.nix'
need "Claude Code and Codex are user-owned installs, not nix packages (so they can self-update)" sh -c '
! grep -Eq "claude-code.enable|codex.enable" module/shared/home-manager.nix &&
grep -q "claude.ai/install.sh" module/darwin/bin/sable-setup &&
grep -q "chatgpt.com/codex/install.sh" module/darwin/bin/sable-setup &&
grep -q "\.local/bin" module/darwin/home-manager.nix &&
! grep -rq "DISABLE_AUTOUPDATER" module'
need "sable-doctor fails a claude/codex/pnpm/bun that is a symlink into the nix store, passes a user-owned one" bash -c '
set -e
t=$(mktemp -d); trap "rm -rf $t" EXIT
sed -n "/# >>> resolve-path/,/# <<< resolve-path/p" module/darwin/bin/sable-doctor >"$t/fn.sh"
. "$t/fn.sh"
export NIX_STORE_PREFIX="$t/nix/store"
mkdir -p "$t/nix/store/abc-claude/bin" "$t/home/.local/bin" "$t/home/.local/share/real"
: >"$t/nix/store/abc-claude/bin/claude"; : >"$t/home/.local/share/real/pnpm"
ln -s "$t/nix/store/abc-claude/bin/claude" "$t/home/.local/bin/claude"          # user dir, nix target
ln -s ../share/real/pnpm "$t/home/.local/bin/pnpm"                              # relative, user target
ln -s "$t/home/.local/bin/claude" "$t/home/.local/bin/claude2"                  # chain
in_nix_store "$t/home/.local/bin/claude"
in_nix_store "$t/home/.local/bin/claude2"
! in_nix_store "$t/home/.local/bin/pnpm"
grep -q "in_nix_store \"\$p\"" module/darwin/bin/sable-doctor'
need "release installers: arch map, sha256 verified, bad checksum keeps the old install" bash -c '
set -e
t=$(mktemp -d); trap "rm -rf $t" EXIT
sed -n "/# >>> release-installers/,/# <<< release-installers/p" module/darwin/bin/sable-setup >"$t/fn.sh"
grep -q "pnpm-darwin-\$arch" "$t/fn.sh" && grep -q "bun-darwin-\$arch" "$t/fn.sh"
mkdir -p "$t/bin" "$t/srv"; printf "payload" >"$t/srv/a.zip"
good=$(sha256sum "$t/srv/a.zip" | cut -d" " -f1)
mk() { printf "{\"assets\":[{\"name\":\"a.zip\",\"browser_download_url\":\"https://x/a.zip\",\"digest\":\"sha256:%s\"}]}" "$1" >"$t/srv/meta.json"; }
printf "#!/bin/sh\nfor a; do u=\$a; done\ncase \"\$*\" in *api.github.com*) cat %s/srv/meta.json;; *) o=\"\"; while [ \$# -gt 0 ]; do [ \"\$1\" = -o ] && o=\$2; shift; done; cp %s/srv/a.zip \"\$o\";; esac\n" "$t" "$t" >"$t/bin/curl"
printf "#!/bin/sh\nsha256sum \"\$@\" | sed \"s/^\\([0-9a-f]*\\)  /\\1  /\"\n" >"$t/bin/shasum"
chmod +x "$t/bin/curl" "$t/bin/shasum"; export PATH="$t/bin:$PATH"
. "$t/fn.sh"
mk "$good"; fetch_release_asset o/r a.zip "$t/ok.zip" && cmp -s "$t/ok.zip" "$t/srv/a.zip"
mk 0000000000000000000000000000000000000000000000000000000000000000
! fetch_release_asset o/r a.zip "$t/bad.zip" 2>/dev/null
mk ""; ! fetch_release_asset o/r a.zip "$t/none.zip" 2>/dev/null
# a failed fetch must leave an existing pnpm install in place
export HOME="$t/home"; mkdir -p "$HOME/.local/share/pnpm-cli"; echo old >"$HOME/.local/share/pnpm-cli/pnpm"
mac_arch() { echo arm64; }; mk 0000000000000000000000000000000000000000000000000000000000000000
! install_pnpm 2>/dev/null
[ "$(cat "$HOME/.local/share/pnpm-cli/pnpm")" = old ]
mac_arch() { return 1; }; ! install_bun 2>/dev/null'
need "zsh loads ~/.config/sable/env only if owned by the user and not group/other writable" bash -c '
set -e
t=$(mktemp -d); trap "rm -rf $t" EXIT
mkdir -p "$t/.config/sable"; f="$t/.config/sable/env"; echo "export SABLE_T=loaded" >"$f"
run() { HOME=$t bash -c ". module/shared/config/sable-env.sh; echo \${SABLE_T:-no}" 2>/dev/null; }
chmod 600 "$f"; [ "$(run)" = loaded ]
chmod 644 "$f"; [ "$(run)" = loaded ]
chmod 664 "$f"; [ "$(run)" = no ]
chmod 646 "$f"; [ "$(run)" = no ]
chmod 600 "$f"; sudo -n chown root "$f" 2>/dev/null && { [ "$(run)" = no ]; sudo -n chown "$(id -u)" "$f"; } || true
grep -q "sable-env.sh" module/shared/home-manager.nix'
need "Cursor is a Homebrew cask, not a nix package, and the doctor checks it" sh -c '
grep -q "\"cursor\"" module/darwin/default.nix && grep -q "\"cursor\"" module/darwin/packages.nix &&
grep -q "/Applications/Cursor.app" module/darwin/bin/sable-doctor'
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
grep -q "sable-accept-invites" $f && grep -q "setup continues" $f && ! grep -q "TRIAL_TYPE must be" $f &&
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
         "Orca active workspace is ~/deployments" "Claude tabs open in ~/deployments" \
         "no pending sable-inc repository invites" \
         "gh not signed in; pending sable-inc invites were not checked"; do grep -qF "$l" $f || exit 1; done
grep -q "all(c == clone for c in claude)" $f && ! grep -q "else ws == clone" $f && ! grep -q "not claude and ws" $f || exit 1
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
grep -q "does not touch credentials.json" $f &&
grep -q "TRIAL_TYPE" $f && grep -q "not ds" $f
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
need "sable-accept-invites accepts only sable-inc invites, logs name and permission, and is idempotent" bash -c '
set -euo pipefail
command -v jq >/dev/null 2>&1 || { echo "jq is required for the stubbed gh test"; exit 1; }
tmp=$(mktemp -d)
export SABLE_FAKE_GH_JSON=$tmp/invites.json SABLE_FAKE_GH_PATCHES=$tmp/patches SABLE_INVITE_LOG=$tmp/log
: > "$SABLE_FAKE_GH_PATCHES"
cat > "$SABLE_FAKE_GH_JSON" << "JSON"
[
  {"id": 101, "permissions": "write", "token": "ghp_SHOULD_NOT_LOG", "repository": {"name": "deployments", "full_name": "sable-inc/deployments", "owner": {"login": "sable-inc"}}},
  {"id": 202, "permissions": "admin", "repository": {"name": "secret", "full_name": "other-org/secret", "owner": {"login": "other-org"}}},
  {"id": 303, "permissions": "read", "repository": {"name": "trial-inputs", "full_name": "sable-inc/trial-inputs", "owner": {"login": "sable-inc"}}},
  {"id": 404, "permissions": "write", "repository": {"name": "deployments", "full_name": "not-sable/deployments", "owner": {"login": "sable-inc"}}}
]
JSON
cat > "$tmp/gh" << "EOF"
#!/bin/bash
set -euo pipefail
if [ "$1" = auth ]; then exit 0; fi
if [ "$1" != api ]; then exit 1; fi
shift
paginate=0
method=GET
path=""
jqprog=""
while [ $# -gt 0 ]; do
  case "$1" in
    --paginate) paginate=1; shift ;;
    -X) method=$2; shift 2 ;;
    --jq) jqprog=$2; shift 2 ;;
    -H) shift 2 ;;
    *) path=$1; shift ;;
  esac
done
if [ "$method" = PATCH ]; then
  printf "%s\n" "$path" >> "$SABLE_FAKE_GH_PATCHES"
  exit 0
fi
[ "$paginate" = 1 ]
[ -n "$jqprog" ]
python3 - "$SABLE_FAKE_GH_JSON" "$SABLE_FAKE_GH_PATCHES" << "PY" | jq -r "$jqprog"
import json, sys
rows = json.load(open(sys.argv[1]))
done = set()
for line in open(sys.argv[2]):
    tail = line.strip().rsplit("/", 1)[-1]
    if tail.isdigit():
        done.add(int(tail))
left = [row for row in rows if row["id"] not in done]
json.dump(left, sys.stdout)
PY
EOF
chmod +x "$tmp/gh"
PATH="$tmp:$PATH" bash module/darwin/bin/sable-accept-invites
sort "$SABLE_FAKE_GH_PATCHES" > "$tmp/got"
printf "%s\n" "user/repository_invitations/101" "user/repository_invitations/303" > "$tmp/want"
diff -u "$tmp/want" "$tmp/got"
grep -q "$(printf "\t")sable-inc/deployments$(printf "\t")write$" "$SABLE_INVITE_LOG"
grep -q "$(printf "\t")sable-inc/trial-inputs$(printf "\t")read$" "$SABLE_INVITE_LOG"
if grep -q ghp_SHOULD_NOT_LOG "$SABLE_INVITE_LOG"; then exit 1; fi
if grep -q other-org "$SABLE_INVITE_LOG"; then exit 1; fi
if grep -q secret "$SABLE_INVITE_LOG"; then exit 1; fi
if grep -q 101 "$SABLE_INVITE_LOG"; then exit 1; fi
if grep -q 404 "$SABLE_INVITE_LOG"; then exit 1; fi
before=$(wc -l < "$SABLE_FAKE_GH_PATCHES" | tr -d " ")
PATH="$tmp:$PATH" bash module/darwin/bin/sable-accept-invites
after=$(wc -l < "$SABLE_FAKE_GH_PATCHES" | tr -d " ")
[ "$before" = "$after" ]
cat > "$tmp/gh" << "EOF"
#!/bin/bash
exit 1
EOF
chmod +x "$tmp/gh"
outlog=$tmp/signed-out.log
SABLE_INVITE_LOG=$outlog PATH="$tmp:$PATH" bash module/darwin/bin/sable-accept-invites
[ ! -e "$outlog" ]
grep -q sable-accept-invites module/darwin/profile.nix
grep -q sable-accept-invites mdm/iru-update.sh
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
  need "shellcheck: bin and mdm scripts" shellcheck -s bash module/darwin/bin/sable-doctor module/darwin/bin/sable-setup module/darwin/bin/sable-accept-invites mdm/iru-bootstrap.sh mdm/iru-doctor.sh mdm/iru-update.sh mdm/iru-vanta.sh mdm/iru-trial-packages.sh scripts/check-baseline.sh
fi
if [ "$fail" = 0 ]; then echo "check-baseline: PASS"; else echo "check-baseline: FAIL"; exit 1; fi
