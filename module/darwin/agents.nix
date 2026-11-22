# Agent baseline on every Sable Mac (Matthew, Nov 21 2026): Claude Code always has pstack and Codex
# review (codex-plugin-cc), and Codex always has pstack's skills, whoever is signed in. These are
# system files outside /Users/sable, so the trial light cleanup never touches them and every
# build-switch puts them back.
# - Claude Code reads /Library/Application Support/ClaudeCode/managed-settings.json (managed scope:
#   users can't turn the plugins off; Claude Code installs them at the next session start). The same
#   JSON is set org-wide in claude.ai (Organization settings > Claude Code > Managed settings), which
#   wins when present; this file covers a Mac before sign-in or if that page is ever emptied.
# - Codex reads admin skills from /etc/codex/skills: a link into a pinned checkout of cursor/plugins.
{ lib, ... }:
let
  pstackRepo = "https://github.com/cursor/plugins.git";
  # Bump on purpose (a PR); the activation refuses any other commit.
  pstackRev = "7a583913eb1b8d1a0ee76753d1a2cf072e7b54f9";
  pstackDir = "/Library/Application Support/Sable/cursor-plugins";
  managed = ./config/claude-managed-settings.json;
in
{
  system.activationScripts.postActivation.text = lib.mkAfter ''
    # Claude Code managed settings (pstack + codex plugins).
    /bin/mkdir -p "/Library/Application Support/ClaudeCode"
    /usr/bin/install -m 0644 -o root -g wheel ${managed} "/Library/Application Support/ClaudeCode/managed-settings.json"

    # pstack skills for Codex, from cursor/plugins at a pinned commit.
    pstack_dir="${pstackDir}"
    if [ "$(/usr/bin/git -C "$pstack_dir" rev-parse HEAD 2>/dev/null)" != "${pstackRev}" ]; then
      echo "fetching pstack ${pstackRev}..." >&2
      pstack_tmp="$(/usr/bin/mktemp -d)"
      if /usr/bin/git -C "$pstack_tmp" init -q \
        && /usr/bin/git -C "$pstack_tmp" fetch -q --depth 1 ${pstackRepo} ${pstackRev} \
        && /usr/bin/git -C "$pstack_tmp" checkout -q --detach FETCH_HEAD \
        && [ "$(/usr/bin/git -C "$pstack_tmp" rev-parse HEAD)" = "${pstackRev}" ]; then
        /bin/mkdir -p "$(dirname "$pstack_dir")"
        rm -rf "$pstack_dir.old"
        if [ -e "$pstack_dir" ] && ! mv "$pstack_dir" "$pstack_dir.old"; then
          rm -rf "$pstack_tmp"
          echo "warning: couldn't move the old pstack checkout aside, the next build-switch will try again" >&2
        elif mv "$pstack_tmp" "$pstack_dir"; then
          rm -rf "$pstack_dir.old"
          /bin/chmod -R go-w "$pstack_dir"
          /bin/chmod -R a+rX "$pstack_dir"
        else
          if [ -e "$pstack_dir.old" ]; then mv "$pstack_dir.old" "$pstack_dir"; fi
          rm -rf "$pstack_tmp"
          echo "warning: couldn't replace the pstack checkout, restored the previous one" >&2
        fi
      else
        rm -rf "$pstack_tmp"
        echo "warning: couldn't fetch pstack, the next build-switch will try again" >&2
      fi
    fi
    # Link Codex skills only when this checkout is the pinned commit. A failed update must
    # not keep serving the previous revision.
    if [ "$(/usr/bin/git -C "$pstack_dir" rev-parse HEAD 2>/dev/null)" = "${pstackRev}" ] \
      && [ -d "$pstack_dir/harness/pstack/claude-code/skills" ]; then
      /bin/mkdir -p /etc/codex
      /bin/ln -sfn "$pstack_dir/harness/pstack/claude-code/skills" /etc/codex/skills
    else
      if [ -L /etc/codex/skills ]; then /bin/rm -f /etc/codex/skills; fi
      echo "warning: pstack checkout is not ${pstackRev}, so /etc/codex/skills is not linked" >&2
    fi
  '';
}
