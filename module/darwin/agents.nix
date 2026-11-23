# Agent baseline on every Sable Mac (Matthew, Nov 21 2026): Claude Code always has pstack and Codex
# review (codex-plugin-cc), and Codex always has pstack's skills, whoever is signed in. These are
# system files outside /Users/sable, so the trial light cleanup never touches them and every
# build-switch puts them back.
# - Claude Code reads /Library/Application Support/ClaudeCode/managed-settings.json (managed scope:
#   users can't turn the plugins off; Claude Code installs them at the next session start). The same
#   JSON is set org-wide in claude.ai (Organization settings > Claude Code > Managed settings), which
#   wins when present; this file covers a Mac before sign-in or if that page is ever emptied.
# - Codex reads admin skills from /etc/codex/skills: a link into a checkout of
#   cursor/plugins that follows its default branch (no pin). The checkout updates at every build-switch
#   and daily through the launchd job below; both only fast-forward from github.com/cursor/plugins.
# - Claude Code's plugin marketplaces have autoUpdate on and no ref, so they track each repo's default branch.
{ lib, pkgs, ... }:
let
  pstackRepo = "https://github.com/cursor/plugins.git";
  pstackDir = "/Library/Application Support/Sable/cursor-plugins";
  managed = ./config/claude-managed-settings.json;
  # Runs from activation and from launchd (root). Never resets: an existing checkout only moves by
  # fast-forward, and only when its origin is the cursor/plugins repo.
  pstackUpdate = pkgs.writeShellScript "sable-pstack-update" ''
    set -u
    # Runs as root, so nothing inside an existing checkout is trusted until proven: git is never run there
    # before the ownership, permission and .git/config checks pass, and every git call also switches off
    # repo-local execution (hooks, fsmonitor, ssh command) and ignores system, global and environment config.
    export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null GIT_TERMINAL_PROMPT=0 HOME=/var/root
    unset GIT_DIR GIT_WORK_TREE GIT_EXEC_PATH GIT_SSH GIT_SSH_COMMAND GIT_ASKPASS GIT_EXTERNAL_DIFF GIT_PAGER GIT_CONFIG_COUNT GIT_CONFIG_PARAMETERS GIT_TEMPLATE_DIR
    git() { /usr/bin/git -c core.hooksPath=/dev/null -c core.fsmonitor=false -c core.sshCommand= -c core.pager=cat -c protocol.file.allow=never -c protocol.ext.allow=never "$@"; }
    repo="${pstackRepo}"
    dir="${pstackDir}"
    parent="$(/usr/bin/dirname "$dir")"
    owner=root
    tree_owner=root
    stop=/Library
    ref=refs/remotes/origin/sable-default
    unlink_skills() {
      if [ -L /etc/codex/skills ]; then /bin/rm -f /etc/codex/skills; fi
      echo "warning: pstack checkout is not trusted ($1), so /etc/codex/skills is not linked" >&2
    }
    # Every directory from the checkout's parent up to /Library: real directories owned by root, not group/other writable.
    parents_trusted() {
      p="$parent"
      while :; do
        [ -d "$p" ] && [ ! -L "$p" ] || return 1
        bad="$(/usr/bin/find "$p" -maxdepth 0 \( -not -user $owner -o -perm -020 -o -perm -002 \) -print 2>/dev/null)" || return 1
        [ -z "$bad" ] || return 1
        if [ "$p" = "$stop" ] || [ "$p" = / ]; then break; fi
        p="$(/usr/bin/dirname "$p")"
      done
    }
    # The checkout and everything under it is owned by root and not group/other writable, .git is a real
    # directory, and .git/config only has the keys a plain clone has (no include, hooks, fsmonitor, filter, alias...).
    tree_trusted() {
      [ -d "$dir" ] && [ ! -L "$dir" ] && [ -d "$dir/.git" ] && [ ! -L "$dir/.git" ] || return 1
      bad="$(/usr/bin/find "$dir" \( -not -user $tree_owner -o \( ! -type l -a \( -perm -020 -o -perm -002 \) \) \) -print -quit 2>/dev/null)" || return 1
      [ -z "$bad" ] || return 1
      keys="$(git config --file "$dir/.git/config" --name-only --list 2>/dev/null)" || return 1
      [ -z "$(printf '%s\n' "$keys" | /usr/bin/grep -Evi '^(core\.(repositoryformatversion|filemode|bare|logallrefupdates|ignorecase|precomposeunicode|symlinks)|remote\.origin\.(url|fetch)|branch\..+\.(remote|merge))$')" ] || return 1
    }
    # Fail closed: link Codex skills only for a trusted, clean checkout of the cursor/plugins origin whose HEAD
    # is on (reachable from) the default branch last fetched from that origin. Anything else removes the link.
    link_skills() {
      if ! tree_trusted; then unlink_skills "ownership, permissions or git config"; return; fi
      if [ "$(git -C "$dir" remote get-url origin 2>/dev/null)" != "$repo" ]; then unlink_skills "origin is not $repo"; return; fi
      if ! git -C "$dir" rev-parse -q --verify "$ref" >/dev/null; then unlink_skills "default branch never fetched"; return; fi
      if ! git -C "$dir" merge-base --is-ancestor HEAD "$ref" 2>/dev/null; then unlink_skills "HEAD is not on origin's default branch"; return; fi
      if [ -n "$(git -C "$dir" status --porcelain 2>/dev/null)" ]; then unlink_skills "local modifications"; return; fi
      if [ ! -d "$dir/harness/pstack/claude-code/skills" ]; then unlink_skills "skills directory missing"; return; fi
      /bin/mkdir -p /etc/codex
      /bin/ln -sfn "$dir/harness/pstack/claude-code/skills" /etc/codex/skills
    }
    /bin/mkdir -p "$parent"
    if ! parents_trusted; then unlink_skills "a parent directory is not a root-owned real directory"; exit 0; fi
    if [ -e "$dir" ] || [ -L "$dir" ]; then
      if ! tree_trusted; then
        unlink_skills "ownership, permissions or git config; re-cloning"
        /bin/rm -rf "$dir"
      fi
    fi
    if [ -d "$dir" ]; then
      # Checkouts made before this change have no origin remote; add it so they can follow the default branch.
      git -C "$dir" remote get-url origin >/dev/null 2>&1 || git -C "$dir" remote add origin "$repo"
      git -C "$dir" config core.fileMode false
      if [ "$(git -C "$dir" remote get-url origin 2>/dev/null)" != "$repo" ]; then
        echo "warning: pstack checkout origin is not $repo, not updating it" >&2
      else
        # Full history of the default branch (small repo): a shallow checkout is deepened first so the
        # ancestry check can't stall on a shallow boundary.
        if [ "$(git -C "$dir" rev-parse --is-shallow-repository 2>/dev/null)" = true ]; then
          git -C "$dir" fetch -q --no-tags --unshallow origin "+HEAD:$ref" 2>/dev/null \
            || git -C "$dir" fetch -q --no-tags origin "+HEAD:$ref" 2>/dev/null \
            || echo "warning: couldn't fetch pstack" >&2
        else
          git -C "$dir" fetch -q --no-tags origin "+HEAD:$ref" 2>/dev/null || echo "warning: couldn't fetch pstack" >&2
        fi
        if git -C "$dir" rev-parse -q --verify "$ref" >/dev/null && git -C "$dir" merge-base --is-ancestor HEAD "$ref" 2>/dev/null; then
          if [ -z "$(git -C "$dir" status --porcelain 2>/dev/null)" ]; then
            git -C "$dir" merge -q --ff-only "$ref" || echo "warning: couldn't fast-forward pstack, keeping the current checkout" >&2
          fi
          /bin/chmod -R go-w "$dir"; /bin/chmod -R a+rX "$dir"
        else
          echo "warning: pstack HEAD is not an ancestor of origin's default branch (or fetch failed), keeping the current checkout" >&2
        fi
      fi
    else
      # Fresh clone as root into a root-owned temp dir beside the target (same filesystem), then an atomic rename.
      tmp="$(/usr/bin/mktemp -d "$parent/.pstack.XXXXXX")"
      if git clone -q "$repo" "$tmp/c" 2>/dev/null \
        && git -C "$tmp/c" fetch -q --no-tags origin "+HEAD:$ref" 2>/dev/null \
        && git -C "$tmp/c" config core.fileMode false \
        && /bin/chmod -R go-w "$tmp/c" && /bin/chmod -R a+rX "$tmp/c" \
        && /bin/mv "$tmp/c" "$dir"; then
        :
      else
        echo "warning: couldn't fetch pstack, the next build-switch or daily job will try again" >&2
      fi
      /bin/rm -rf "$tmp"
    fi
    link_skills
  '';
in
{
  launchd.daemons.sable-pstack-update = {
    command = "${pstackUpdate}";
    serviceConfig = {
      RunAtLoad = false;
      StartCalendarInterval = [ { Hour = 4; Minute = 15; } ];
      StandardErrorPath = "/var/log/sable-pstack-update.log";
    };
  };
  system.activationScripts.postActivation.text = lib.mkAfter ''
    # Claude Code managed settings (pstack + codex plugins, both auto-updating).
    /bin/mkdir -p "/Library/Application Support/ClaudeCode"
    /usr/bin/install -m 0644 -o root -g wheel ${managed} "/Library/Application Support/ClaudeCode/managed-settings.json"

    # pstack skills for Codex: latest cursor/plugins default branch (fast-forward only).
    ${pstackUpdate} || echo "warning: pstack update failed, the daily job will retry" >&2
  '';
}
