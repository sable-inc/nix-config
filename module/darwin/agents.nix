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
    git=/usr/bin/git
    repo="${pstackRepo}"
    dir="${pstackDir}"
    ref=refs/remotes/origin/sable-default
    unlink_skills() {
      if [ -L /etc/codex/skills ]; then /bin/rm -f /etc/codex/skills; fi
      echo "warning: pstack checkout is not trusted ($1), so /etc/codex/skills is not linked" >&2
    }
    # Fail closed: link Codex skills only for a clean checkout of the cursor/plugins origin whose HEAD is
    # on (reachable from) the default branch last fetched from that origin. Anything else removes the link.
    link_skills() {
      if [ ! -d "$dir/.git" ]; then unlink_skills "no checkout"; return; fi
      if [ "$($git -C "$dir" remote get-url origin 2>/dev/null)" != "$repo" ]; then unlink_skills "origin is not $repo"; return; fi
      if ! $git -C "$dir" rev-parse -q --verify "$ref" >/dev/null; then unlink_skills "default branch never fetched"; return; fi
      if ! $git -C "$dir" merge-base --is-ancestor HEAD "$ref" 2>/dev/null; then unlink_skills "HEAD is not on origin's default branch"; return; fi
      if [ -n "$($git -C "$dir" status --porcelain 2>/dev/null)" ]; then unlink_skills "local modifications"; return; fi
      if [ ! -d "$dir/harness/pstack/claude-code/skills" ]; then unlink_skills "skills directory missing"; return; fi
      /bin/mkdir -p /etc/codex
      /bin/ln -sfn "$dir/harness/pstack/claude-code/skills" /etc/codex/skills
    }
    if [ -d "$dir/.git" ]; then
      # Checkouts made before this change have no origin remote; add it so they can follow the default branch.
      $git -C "$dir" remote get-url origin >/dev/null 2>&1 || $git -C "$dir" remote add origin "$repo"
      $git -C "$dir" config core.fileMode false
      if [ "$($git -C "$dir" remote get-url origin 2>/dev/null)" != "$repo" ]; then
        echo "warning: pstack checkout origin is not $repo, not updating it" >&2
      else
        # Full history of the default branch (small repo): a shallow checkout is deepened first so the
        # ancestry check can't stall on a shallow boundary.
        if [ "$($git -C "$dir" rev-parse --is-shallow-repository 2>/dev/null)" = true ]; then
          $git -C "$dir" fetch -q --no-tags --unshallow origin "+HEAD:$ref" 2>/dev/null \
            || $git -C "$dir" fetch -q --no-tags origin "+HEAD:$ref" 2>/dev/null \
            || echo "warning: couldn't fetch pstack" >&2
        else
          $git -C "$dir" fetch -q --no-tags origin "+HEAD:$ref" 2>/dev/null || echo "warning: couldn't fetch pstack" >&2
        fi
        if $git -C "$dir" rev-parse -q --verify "$ref" >/dev/null && $git -C "$dir" merge-base --is-ancestor HEAD "$ref" 2>/dev/null; then
          if [ -z "$($git -C "$dir" status --porcelain 2>/dev/null)" ]; then
            $git -C "$dir" merge -q --ff-only "$ref" || echo "warning: couldn't fast-forward pstack, keeping the current checkout" >&2
          fi
          /bin/chmod -R go-w "$dir"; /bin/chmod -R a+rX "$dir"
        else
          echo "warning: pstack HEAD is not an ancestor of origin's default branch (or fetch failed), keeping the current checkout" >&2
        fi
      fi
    else
      tmp="$(/usr/bin/mktemp -d)"
      if $git clone -q "$repo" "$tmp/c" 2>/dev/null \
        && $git -C "$tmp/c" fetch -q --no-tags origin "+HEAD:$ref" 2>/dev/null; then
        $git -C "$tmp/c" config core.fileMode false
        /bin/mkdir -p "$(dirname "$dir")"
        /bin/rm -rf "$dir"
        /bin/mv "$tmp/c" "$dir" && /bin/chmod -R go-w "$dir" && /bin/chmod -R a+rX "$dir"
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
