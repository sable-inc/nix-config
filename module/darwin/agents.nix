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
    link_skills() {
      if [ -d "$dir/harness/pstack/claude-code/skills" ]; then
        /bin/mkdir -p /etc/codex
        /bin/ln -sfn "$dir/harness/pstack/claude-code/skills" /etc/codex/skills
      else
        if [ -L /etc/codex/skills ]; then /bin/rm -f /etc/codex/skills; fi
        echo "warning: no pstack checkout, so /etc/codex/skills is not linked" >&2
      fi
    }
    if [ -d "$dir/.git" ]; then
      # Checkouts made before this change have no origin remote; add it so they can follow the default branch.
      $git -C "$dir" remote get-url origin >/dev/null 2>&1 || $git -C "$dir" remote add origin "$repo"
      if [ "$($git -C "$dir" remote get-url origin 2>/dev/null)" != "$repo" ]; then
        echo "warning: pstack checkout origin is not $repo, leaving it as is" >&2
      elif $git -C "$dir" fetch -q --depth 200 origin HEAD 2>/dev/null \
        && $git -C "$dir" merge-base --is-ancestor HEAD FETCH_HEAD 2>/dev/null; then
        $git -C "$dir" merge -q --ff-only FETCH_HEAD || echo "warning: couldn't fast-forward pstack, keeping the current checkout" >&2
        /bin/chmod -R go-w "$dir"; /bin/chmod -R a+rX "$dir"
      else
        echo "warning: pstack update is not a fast-forward from $repo (or fetch failed), keeping the current checkout" >&2
      fi
    else
      tmp="$(/usr/bin/mktemp -d)"
      if $git clone -q --depth 200 "$repo" "$tmp/c" 2>/dev/null; then
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
