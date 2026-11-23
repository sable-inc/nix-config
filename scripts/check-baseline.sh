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
need "Claude managed settings: plugin marketplaces follow the default branch (autoUpdate on, no ref pin) and never disable Claude Code self-update" py '
import json
d = json.load(open("module/darwin/config/claude-managed-settings.json"))
m = d["extraKnownMarketplaces"]
for name, repo in (("cursor-plugins", "cursor/plugins"), ("openai-codex", "openai/codex-plugin-cc")):
    assert m[name]["source"] == {"source": "github", "repo": repo}, "no ref/sha pin allowed"
    assert m[name]["autoUpdate"] is True
assert d["enabledPlugins"] == {"pstack@cursor-plugins": True, "codex@openai-codex": True}
assert set(d) == {"extraKnownMarketplaces", "enabledPlugins"}, "managed settings may only set plugins: no env/autoUpdatesChannel/DISABLE_*"'
need "pstack checkout follows cursor/plugins (no pinned rev), fast-forward only, updated daily by launchd and at activation" sh -c '
f=module/darwin/agents.nix
! grep -Eq "pstackRev|[0-9a-f]{40}" $f &&
grep -q "launchd.daemons.sable-pstack-update" $f &&
tr -d "\n " <$f | grep -q "StartCalendarInterval=\[{Hour=4;Minute=15;}\]" &&
grep -q -- "--unshallow" $f &&
! grep -q -- "--depth" $f &&
grep -q "merge -q --ff-only" $f &&
grep -q "is-ancestor" $f &&
! grep -Eq "reset --hard|checkout -q --detach" $f'
need "self-updating apps: casks for Cursor/Claude/ChatGPT/Devin, Orca installs from latest release, no greedy or version pin" sh -c '
grep -q "\"cursor\"" module/darwin/default.nix &&
grep -q "\"claude\"" module/darwin/default.nix &&
grep -q "\"chatgpt\"" module/darwin/default.nix &&
grep -q "devin-desktop" module/darwin/default.nix &&
grep -q "releases/latest/download" module/darwin/orca.nix &&
! grep -Eq "greedy|HOMEBREW_NO_AUTO_UPDATE" module/darwin/default.nix'
need "weekly flake-update workflow opens a PR (never pushes to fleet) and runs check-baseline" sh -c '
f=$(ls .github/workflows/flake-update.yml docs/flake-update.workflow.yml 2>/dev/null | head -1)
grep -q "cron:" $f && grep -q "nix flake update" $f && grep -q "scripts/check-baseline.sh" $f &&
grep -q "create-pull-request\|gh pr create" $f && ! grep -q ":fleet\|origin fleet" $f'
need "pstack update (root script): no repo-local execution, ownership/permission/config trust checks re-clone, fail-closed linking" bash -c '
set -e
umask 022
# host system/global git config must not leak into any assertion in this block
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
unset GIT_CONFIG_COUNT GIT_CONFIG_PARAMETERS GIT_DIR GIT_WORK_TREE
t=$(mktemp -d); trap "rm -rf $t" EXIT
f=module/darwin/agents.nix
me=$(id -un); other=$(awk -F: -v me="$me" "\$1!=me && \$1!=\"\"{print \$1; exit}" /etc/passwd)
# The real script text from agents.nix, run as this user in a sandbox. Substitutions (the only differences from a
# real run): /etc/codex, the repo URL, the checkout path, HOME and the /Library stop point move into $t; "root" becomes
# the current user (the test cannot chown to root); and protocol.file.allow=always so a local repo can stand in for
# GitHub. mk <owner> builds a variant: a different <owner> simulates a checkout owned by a non-root user.
mk() { sed -n "/writeShellScript \"sable-pstack-update\"/,/^  '"'"''"'"';/p" $f | sed "1d;\$d" \
  | sed "s#\${pstackRepo}#$t/origin#; s#\${pstackDir}#$t/Sable/co#; s#/etc/codex#$t/etc#g; s#HOME=/var/root#HOME=$t#; s#^    stop=/Library#    stop=$t#; s#^    owner=root#    owner=$me#; s#^    tree_owner=root#    tree_owner=$1#; s#protocol.file.allow=never#protocol.file.allow=always#" >$t/upd-$1.sh; }
mk "$me"; mk "$other"
grep -q "sable-pstack-update" $f && grep -q "tree_owner=$me" $t/upd-$me.sh && grep -q "unlink_skills()" $t/upd-$me.sh
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
mkdir $t/etc
O="git -C $t/origin"
git init -q $t/origin; mkdir -p $t/origin/harness/pstack/claude-code/skills; : >$t/origin/harness/pstack/claude-code/skills/a
$O add -A; $O commit -qm one
upd() { bash $t/upd-${1:-$me}.sh 2>$t/err || { cat $t/err; return 1; }; }
linked() { [ -L $t/etc/skills ]; }
head_is() { [ "$(git -C $t/Sable/co rev-parse HEAD)" = "$($O rev-parse HEAD)" ]; }
bump() { : >$t/origin/harness/pstack/claude-code/skills/$1; $O add -A; $O commit -qm "$1"; }
upd; linked && head_is || { echo "fresh clone was not made and linked"; exit 1; }
# 1. planted post-merge hook must not run on update; still updates and links
printf "#!/bin/sh\ntouch $t/hook-ran\n" >$t/Sable/co/.git/hooks/post-merge; chmod +x $t/Sable/co/.git/hooks/post-merge
bump b; upd; [ ! -e $t/hook-ran ] || { echo "post-merge hook ran"; exit 1; }
head_is && linked || { echo "did not update/link with a planted hook"; exit 1; }
# 2. planted core.fsmonitor / core.hooksPath in .git/config must not run; untrusted config means re-clone
git -C $t/Sable/co config core.fsmonitor "touch $t/fsmon-ran"; git -C $t/Sable/co config core.hooksPath $t/Sable/co/.git/hooks
bump c; upd; [ ! -e $t/fsmon-ran ] && [ ! -e $t/hook-ran ] || { echo "repo-local command ran"; exit 1; }
[ -z "$(git config --file $t/Sable/co/.git/config --get core.fsmonitor || true)" ] && head_is && linked || { echo "poisoned config was not re-cloned"; exit 1; }
# 3. a file not owned by root (simulated: run the variant whose trusted owner is another user) triggers re-clone, and fails closed
echo junk >$t/Sable/co/junk; rm -f $t/etc/skills
if [ -n "$other" ]; then upd "$other"; [ ! -e $t/Sable/co/junk ] || { echo "foreign-owned checkout was kept"; exit 1; }; ! linked || { echo "foreign-owned checkout was linked"; exit 1; }; fi
upd; linked || { echo "not relinked after re-clone"; exit 1; }
# 4. a group/other-writable file triggers re-clone
echo junk >$t/Sable/co/junk; chmod go+w $t/Sable/co/harness/pstack/claude-code/skills/a; upd
[ ! -e $t/Sable/co/junk ] && linked || { echo "writable file did not trigger re-clone"; exit 1; }
# 5. a group-writable parent directory: nothing runs in the checkout and the link is removed
echo junk >$t/Sable/co/junk; chmod 775 $t/Sable; upd; chmod 755 $t/Sable
[ -e $t/Sable/co/junk ] && ! linked || { echo "untrusted parent was not refused"; exit 1; }
rm $t/Sable/co/junk; upd; linked || { echo "not relinked"; exit 1; }
# 6. fail-closed linking: dirty tree, wrong origin, local commit off the default branch
echo x >$t/Sable/co/dirty; upd; ! linked || { echo "dirty checkout linked"; exit 1; }
rm $t/Sable/co/dirty
git -C $t/Sable/co remote set-url origin https://example.com/evil.git; upd; ! linked || { echo "wrong origin linked"; exit 1; }
git -C $t/Sable/co remote set-url origin $t/origin
git -C $t/Sable/co commit -q --allow-empty -m local; upd; ! linked || { echo "local commit linked"; exit 1; }
git -C $t/Sable/co reset -q --hard HEAD~1; upd; linked || { echo "not relinked after recovery"; exit 1; }
# the script must never run git before the trust check, and never pass a pin
grep -q "git() { /usr/bin/git -c core.hooksPath=/dev/null -c core.fsmonitor=false" $f
! grep -Eq "pstackRev|reset --hard|--depth" $f'
need "Claude Code and Codex are user-owned installs, not nix packages (so they can self-update)" sh -c '
! grep -Eq "claude-code.enable|codex.enable" module/shared/home-manager.nix &&
grep -q "claude.ai/install.sh" module/darwin/bin/sable-setup &&
grep -q "chatgpt.com/codex/install.sh" module/darwin/bin/sable-setup &&
grep -q "\.local/bin" module/darwin/home-manager.nix &&
! grep -rq "DISABLE_AUTOUPDATER" module'
need "sable-doctor and sable-setup (shared sable-lib.sh) treat a nix-store symlink as not user-owned, and setup reinstalls it" bash -c '
set -e
must() { "$@" || { echo "assertion failed: $*" >&2; exit 1; }; }
mustnot() { if "$@"; then echo "assertion should have failed: $*" >&2; exit 1; fi; }
t=$(mktemp -d); trap "rm -rf $t" EXIT
. module/darwin/bin/sable-lib.sh
export NIX_STORE_PREFIX="$t/nix/store"
mkdir -p "$t/nix/store/abc-claude/bin" "$t/home/.local/bin" "$t/home/.local/share/real"
: >"$t/nix/store/abc-claude/bin/claude"; : >"$t/home/.local/share/real/pnpm"
ln -s "$t/nix/store/abc-claude/bin/claude" "$t/home/.local/bin/claude"          # user dir, nix target
ln -s ../share/real/pnpm "$t/home/.local/bin/pnpm"                              # relative, user target
ln -s "$t/home/.local/bin/claude" "$t/home/.local/bin/claude2"                  # chain
must in_nix_store "$t/home/.local/bin/claude"
must in_nix_store "$t/home/.local/bin/claude2"
mustnot in_nix_store "$t/home/.local/bin/pnpm"
# setup decides with own_install: reject the nix-store symlink and the chain, accept the user-owned binary
export HOME="$t/home"; export PATH="$t/home/.local/bin:$PATH"
chmod +x "$t/nix/store/abc-claude/bin/claude" "$t/home/.local/share/real/pnpm"
mustnot own_install claude
mustnot own_install claude2
must own_install pnpm
mustnot own_install nonexistent-cmd
must grep -q "own_install \"\$1\"" module/darwin/bin/sable-setup
must grep -q "! own_install pnpm" module/darwin/bin/sable-setup
must grep -q "! own_install bun" module/darwin/bin/sable-setup
must grep -q "sableLib + builtins.readFile ./bin/sable-doctor" module/darwin/profile.nix
must grep -q "sableLib + builtins.readFile ./bin/sable-setup" module/darwin/profile.nix'
need "sable-setup --unattended: no prompts, one line per missing sign-in, exit 0 unless an install failed; auto when stdin is not a TTY" bash -c '
set -e
must() { "$@" || { echo "assertion failed: $*" >&2; exit 1; }; }
mustnot() { if "$@"; then echo "assertion should have failed: $*" >&2; exit 1; fi; }
t=$(mktemp -d); trap "rm -rf $t" EXIT
f=module/darwin/bin/sable-setup
must grep -q "unattended-args" $f
must grep -q "unattended-report" $f
sed -n "/# >>> unattended-report/,/# <<< unattended-report/p" $f >"$t/report.sh"
# Interactive logins are banned inside the report block; the read-only status probes (claude auth status,
# codex login status, gh auth status, sable whoami, devin) are allowed.
mustnot grep -Eq "(^|[^a-z_])read -r|wait_enter|gh auth login|claude auth login|claude +/login|codex login($| +[^s ]| +s[^t])|devin auth login|sable login|vercel login|gcloud auth login|(^|[^a-z_])open( |$)" "$t/report.sh"
must grep -q "codex login status" "$t/report.sh"
must grep -q "claude auth status" "$t/report.sh"
must grep -q "gh auth status" "$t/report.sh"
sed -n "/# >>> unattended-args/,/# <<< unattended-args/p" $f >"$t/args.sh"
mkdir -p "$t/bin"; for c in gh claude codex agent sable; do printf "#!/bin/sh\nexit 1\n" >"$t/bin/$c"; chmod +x "$t/bin/$c"; done
printf "#!/bin/sh\nexit 1\n" >"$t/bin/jq"; chmod +x "$t/bin/jq"
run() { # run <install_failed> : report block under stubs, nothing signed in
  PATH="$t/bin:/usr/bin:/bin" bash -c "say() { :; }; have() { command -v \"\$1\" >/dev/null 2>&1; }; unattended=1; install_failed=$1; . $t/report.sh" </dev/null
}
out=$(run 0)
for w in gh claude codex cursor sable; do
  if ! printf "%s\n" "$out" | grep -q "^needs sign-in: $w"; then echo "missing line for $w" >&2; exit 1; fi
done
n=$(printf "%s\n" "$out" | grep -c "^needs sign-in" || true)
if [ "$n" != 5 ]; then echo "expected 5 sign-in lines, got $n" >&2; exit 1; fi
rc=0; run 1 >/dev/null 2>&1 || rc=$?
if [ "$rc" != 1 ]; then echo "an install failure must exit 1, got $rc" >&2; exit 1; fi
# argument parsing: --unattended sets it, stdin not a TTY sets it, unknown flags stop
must env PATH="/usr/bin:/bin" bash -c "die() { exit 9; }; . $t/args.sh; [ \$unattended = 1 ]" --unattended </dev/null
must env PATH="/usr/bin:/bin" bash -c "die() { exit 9; }; set -- ; . $t/args.sh; [ \$unattended = 1 ]" </dev/null
rc=0; PATH="/usr/bin:/bin" bash -c "die() { exit 9; }; set -- --bogus; . $t/args.sh" </dev/null || rc=$?
if [ "$rc" != 9 ]; then echo "unknown flag must stop, got $rc" >&2; exit 1; fi'
need "Devin Desktop: new hires only (onboard profile; absent on default and trial), no CLI installer, doctor fails a trial Mac that has it, nothing in mdm or trial docs" bash -c '
set -e
must() { "$@" || { echo "assertion failed: $*" >&2; exit 1; }; }
mustnot() { if "$@"; then echo "assertion should have failed: $*" >&2; exit 1; fi; }
t=$(mktemp -d); trap "rm -rf $t" EXIT
# the cask is installed on non-trial profiles and subtracted on trial
must grep -q "lib.optional (config.sable.profile == \"onboard\") \"devin-desktop\"" module/darwin/default.nix
# the cask is not in the shared list and not subtracted for trial: it is added for onboard only
mustnot grep -q "^      \"devin-desktop\"" module/darwin/default.nix
mustnot grep -q "subtractLists.*devin" module/darwin/default.nix
# Devin appears only in default.nix (cask), the doctor and the docs: not in profile.nix trial paths, mdm/ or the trial docs
mustnot grep -qi devin module/darwin/profile.nix
mustnot grep -rqi devin mdm docs/claude-setup-v1.md docs/iru.md
mustnot grep -qi devin module/darwin/bin/sable-setup
# no CLI install and no login step anywhere
mustnot grep -rqiE "cli\.devin\.ai|devin auth login|devin_install|devin update" module mdm
# doctor behavior: onboard needs the app, trial fails if it is there, other profiles are not checked
sed -n "/# >>> devin-desktop/,/# <<< devin-desktop/p" module/darwin/bin/sable-doctor >"$t/devin.sh"
run() { # run <profile> <apps dir>
  bash -c "ok() { echo \"PASS \$1\"; }; bad() { echo \"FAIL \$1\"; }; profile=$1; DEVIN_APPS_DIR=$2; . $t/devin.sh"
}
mkdir -p "$t/none" "$t/with/Devin.app"
if ! run onboard "$t/with" | grep -q "^PASS Devin Desktop installed"; then echo "onboard with app should pass" >&2; exit 1; fi
if ! run onboard "$t/none" | grep -q "^FAIL Devin Desktop"; then echo "onboard without app should fail" >&2; exit 1; fi
if ! run trial "$t/with" | grep -q "^FAIL Devin Desktop is not on trial Macs"; then echo "trial with app should fail" >&2; exit 1; fi
if ! run trial "$t/none" | grep -q "^PASS no Devin Desktop"; then echo "trial without app should pass" >&2; exit 1; fi
n=$(run default "$t/with" | wc -l); if [ "$n" != 0 ]; then echo "default profile must print nothing" >&2; exit 1; fi'
need "release installers: arch map, sha256 verified, bad checksum keeps the old install" bash -c '
set -e
must() { "$@" || { echo "assertion failed: $*" >&2; exit 1; }; }
mustnot() { if "$@"; then echo "assertion should have failed: $*" >&2; exit 1; fi; }
t=$(mktemp -d); trap "rm -rf $t" EXIT
sed -n "/# >>> release-installers/,/# <<< release-installers/p" module/darwin/bin/sable-setup >"$t/fn.sh"
must grep -q "pnpm-darwin-\$arch" "$t/fn.sh"
must grep -q "bun-darwin-\$arch" "$t/fn.sh"
mkdir -p "$t/bin" "$t/srv"; printf "payload" >"$t/srv/a.zip"
good=$(sha256sum "$t/srv/a.zip" | cut -d" " -f1)
mk() { printf "{\"assets\":[{\"name\":\"a.zip\",\"browser_download_url\":\"https://x/a.zip\",\"digest\":\"sha256:%s\"}]}" "$1" >"$t/srv/meta.json"; }
printf "#!/bin/sh\ncase \"\$*\" in *api.github.com*) cat %s/srv/meta.json;; *) o=\"\"; while [ \$# -gt 0 ]; do [ \"\$1\" = -o ] && o=\$2; shift; done; cp %s/srv/a.zip \"\$o\";; esac\n" "$t" "$t" >"$t/bin/curl"
printf "#!/bin/sh\nshift 2\nsha256sum \"\$@\"\n" >"$t/bin/shasum"
chmod +x "$t/bin/curl" "$t/bin/shasum"; export PATH="$t/bin:$PATH"
. "$t/fn.sh"
mk "$good"
must fetch_release_asset o/r a.zip "$t/ok.zip"
must cmp -s "$t/ok.zip" "$t/srv/a.zip"
mk 0000000000000000000000000000000000000000000000000000000000000000
mustnot fetch_release_asset o/r a.zip "$t/bad.zip"
mk ""
mustnot fetch_release_asset o/r a.zip "$t/none.zip"
# a failed fetch must leave an existing pnpm install in place
export HOME="$t/home"; mkdir -p "$HOME/.local/share/pnpm-cli"; echo old >"$HOME/.local/share/pnpm-cli/pnpm"
mac_arch() { echo arm64; }
mk 0000000000000000000000000000000000000000000000000000000000000000
mustnot install_pnpm
if [ "$(cat "$HOME/.local/share/pnpm-cli/pnpm")" != old ]; then echo "old pnpm was lost" >&2; exit 1; fi
mac_arch() { return 1; }
mustnot install_bun'
need "zsh loads ~/.config/sable/env only if owned by the user and not group/other writable" bash -c '
set -e
t=$(mktemp -d); trap "rm -rf $t" EXIT
mkdir -p "$t/.config/sable"; f="$t/.config/sable/env"; echo "export SABLE_T=loaded" >"$f"
run() { HOME=$t bash -c ". module/shared/config/sable-env.sh; echo \${SABLE_T:-no}" 2>/dev/null; }
expect() { # expect <mode> <loaded|no>
  chmod "$1" "$f"
  got=$(run)
  if [ "$got" != "$2" ]; then echo "mode $1: expected $2, got $got" >&2; exit 1; fi
}
expect 600 loaded
expect 644 loaded
expect 664 no
expect 646 no
chmod 600 "$f"
if sudo -n chown root "$f" 2>/dev/null; then
  got=$(run); sudo -n chown "$(id -u)" "$f"
  if [ "$got" != no ]; then echo "a root-owned file must not load" >&2; exit 1; fi
fi
if ! grep -q "sable-env.sh" module/shared/home-manager.nix; then echo "home-manager does not load sable-env.sh" >&2; exit 1; fi'
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
need "package token: scope at every bunfig path bun reads, NPM_TOKEN is the package token on trial (not the slot gh token), drop keeps other settings" bash -c '
set -eu
. module/darwin/bin/sable-lib.sh
HOME=$(mktemp -d); export HOME; XDG_CONFIG_HOME=$HOME/xdg; export XDG_CONFIG_HOME
mkdir -p "$HOME/bin"; printf "#!/bin/sh\n[ \"\$1 \$2\" = \"auth token\" ] && echo slot-gh-token\n" > "$HOME/bin/gh"; chmod +x "$HOME/bin/gh"; PATH=$HOME/bin:$PATH
# no scope yet: trial falls back to gh, sync reports no token
[ "$(sable_npm_token trial)" = slot-gh-token ]
sync_bunfig_scope && exit 1
printf "%s\n" "[install]" "exact = true" "" "[install.scopes]" "\"@sable-inc\" = { url = \"https://npm.pkg.github.com\", token = \"<token>\" }" "\"@other\" = \"https://example.invalid\"" > "$HOME/.bunfig.toml"
sable_pkg_token >/dev/null && exit 1   # a placeholder is not a token
printf "%s\n" "[install]" "exact = true" "" "[install.scopes]" "\"@sable-inc\" = { url = \"https://npm.pkg.github.com\", token = \"pkg-read\" }" "\"@other\" = \"https://example.invalid\"" > "$HOME/.bunfig.toml"
sync_bunfig_scope
for f in "$HOME/.bunfig.toml" "$HOME/.config/.bunfig.toml" "$XDG_CONFIG_HOME/.bunfig.toml"; do
  [ "$(sable_bunfig_py get "$f")" = pkg-read ] || { echo "no scope in $f"; exit 1; }
  [ "$(stat -c %a "$f" 2>/dev/null || stat -f %Lp "$f")" = 600 ] || { echo "$f not 600"; exit 1; }
  [ "$(grep -c "@sable-inc" "$f")" = 1 ] || { echo "duplicate scope in $f"; exit 1; }
done
grep -q "exact = true" "$HOME/.bunfig.toml" && grep -q "@other" "$HOME/.bunfig.toml"
# only the XDG copy is left (what a terminal with XDG_CONFIG_HOME reads): still found
rm "$HOME/.bunfig.toml" "$HOME/.config/.bunfig.toml"; [ "$(sable_pkg_token)" = pkg-read ]
sync_bunfig_scope; [ "$(sable_bunfig_py get "$HOME/.bunfig.toml")" = pkg-read ]
[ "$(sable_npm_token trial)" = pkg-read ]
[ "$(sable_npm_token onboard)" = slot-gh-token ]
# a symlinked bunfig is refused, not followed
rm "$HOME/.config/.bunfig.toml"; ln -s "$HOME/elsewhere" "$HOME/.config/.bunfig.toml"
sync_bunfig_scope && exit 1; [ ! -e "$HOME/elsewhere" ]; rm "$HOME/.config/.bunfig.toml"
# drop removes the scope everywhere and keeps other Bun settings
printf "%s\n" "[install]" "exact = true" "" "[install.scopes]" "\"@sable-inc\" = { url = \"https://npm.pkg.github.com\", token = \"pkg-read\" }" > "$HOME/.bunfig.toml"
drop_bunfig_scope
grep -q "@sable-inc" "$HOME/.bunfig.toml" && exit 1; grep -q "exact = true" "$HOME/.bunfig.toml"
[ ! -e "$XDG_CONFIG_HOME/.bunfig.toml" ]
sable_pkg_token >/dev/null && exit 1
[ "$(sable_npm_token trial)" = slot-gh-token ]
# callers: sable-setup and the trial shell take NPM_TOKEN from sable_npm_token, never straight from gh
f=module/darwin/bin/sable-setup
! grep -q "NPM_TOKEN=\"\$(gh auth token" $f
[ "$(grep -c "NPM_TOKEN=\"\$(sable_npm_token \"\$profile\")\"" $f)" = 2 ]
awk "/^install_sable_cli\\(\\)/,/^}/" $f | grep -q sync_bunfig_scope
awk "/^remove_sable_cli\\(\\)/,/^}/" $f | grep -q drop_bunfig_scope
grep -q "sable-npm-token 2>/dev/null" module/darwin/profile.nix
! grep -q "export NPM_TOKEN=\"\$(gh auth token" module/darwin/profile.nix
grep -q "\.config/\.bunfig\.toml" mdm/iru-trial-packages.sh
'
need "Iru bunfig writer: runs as sable, merges only the scope (other Bun settings kept), 600, refuses symlinks (no root redirect)" bash -c '
set -eu
f=mdm/iru-trial-packages.sh
grep -q "sudo -u sable -H /usr/bin/python3 -I -c \"\$merge_py\"" $f
! grep -qE "cat >\"?\\\$bunfig" $f
prog=$(sed -n "/^merge_py=/,/^os.replace/p" $f | sed -e "1s/^merge_py=.//" -e "\$ s/.\$//")
h=$(mktemp -d)
printf "%s\n" "[install]" "exact = true" "" "[install.scopes]" "\"@sable-inc\" = { url = \"x\", token = \"old\" }" "\"@other\" = \"y\"" > "$h/.bunfig.toml"
printf "pkg-read" | python3 -I -c "$prog" "$h" .bunfig.toml
printf "pkg-read" | python3 -I -c "$prog" "$h" .config/.bunfig.toml
grep -q "exact = true" "$h/.bunfig.toml"; grep -q "@other" "$h/.bunfig.toml"
for x in .bunfig.toml .config/.bunfig.toml; do
  [ "$(grep -c "@sable-inc" "$h/$x")" = 1 ]; grep -q "token = \"pkg-read\"" "$h/$x"
  [ "$(stat -c %a "$h/$x" 2>/dev/null || stat -f %Lp "$h/$x")" = 600 ]
done
mkdir "$h/away"; rm -rf "$h/.config"; ln -s "$h/away" "$h/.config"
printf "pkg-read" | python3 -I -c "$prog" "$h" .config/.bunfig.toml 2>/dev/null && exit 1
[ -z "$(ls -A "$h/away")" ]
rm "$h/.config"; mkdir "$h/.config"; ln -s "$h/away/t" "$h/.config/.bunfig.toml"
printf "pkg-read" | python3 -I -c "$prog" "$h" .config/.bunfig.toml 2>/dev/null && exit 1
[ ! -e "$h/away/t" ]
'
need "Iru writes only the bunfig scope (both paths) and ships no token" sh -c '
f=mdm/iru-trial-packages.sh
grep -q "github-trial-packages-token" $f && grep -q "token=\"\"" $f &&
grep -q "\[install.scopes\]" $f && grep -q "@sable-inc" $f &&
grep -q "npm.pkg.github.com" $f && grep -q "0o600" $f &&
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
if ! command -v nix-instantiate >/dev/null 2>&1 && command -v apt-get >/dev/null 2>&1; then
  echo "installing nix-bin for nix-instantiate --parse (same as CI)" >&2
  sudo_cmd=sudo
  if [ "$(id -u)" = 0 ]; then sudo_cmd=; fi
  if ! $sudo_cmd apt-get update -qq || ! $sudo_cmd apt-get install -y -qq nix-bin; then
    echo "warning: could not install nix-bin" >&2
  fi
fi
if ! command -v nix-instantiate >/dev/null 2>&1; then
  echo "FAIL  nix parse: nix-instantiate not installed. CI installs nix-bin with apt-get; install nix and rerun." >&2
  fail=1
else
  need "every .nix file parses (nix-instantiate --parse), and the checker rejects a broken file and a duplicate scalar attribute" bash -c '
set -e
t=$(mktemp -d); trap "rm -rf $t" EXIT
# A private chroot store under $t: parsing then needs no nix daemon, no /nix/var and no root (apt nix-bin has no daemon).
parse_all() { local f; for f in "$@"; do NIX_REMOTE= nix-instantiate --store "$t/store" --parse "$f" >/dev/null 2>"$t/err" || { echo "does not parse: $f" >&2; cat "$t/err" >&2; return 1; }; done; }
files=$(git ls-files "*.nix")
if [ -z "$files" ]; then echo "no .nix files found" >&2; exit 1; fi
# shellcheck disable=SC2086
if ! parse_all $files; then exit 1; fi
# self-test: the checker must fail on a syntax error and on a duplicated non-attrset attribute
printf "{ a = ; }\n" >"$t/syntax.nix"
printf "{ a = 1; a = 2; }\n" >"$t/dup.nix"
if parse_all "$t/syntax.nix" 2>/dev/null; then echo "checker accepted a syntax error" >&2; exit 1; fi
if parse_all "$t/dup.nix" 2>/dev/null; then echo "checker accepted a duplicated attribute" >&2; exit 1; fi'
fi
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
  need "shellcheck: bin and mdm scripts" shellcheck -s bash module/darwin/bin/sable-lib.sh module/darwin/bin/sable-doctor module/darwin/bin/sable-setup module/darwin/bin/sable-accept-invites mdm/iru-bootstrap.sh mdm/iru-doctor.sh mdm/iru-update.sh mdm/iru-vanta.sh mdm/iru-trial-packages.sh scripts/check-baseline.sh
fi
if [ "$fail" = 0 ]; then echo "check-baseline: PASS"; else echo "check-baseline: FAIL"; exit 1; fi
