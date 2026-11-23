# sable-lib.sh: shared by sable-setup and sable-doctor. profile.nix prepends this file to both scripts
# (one implementation, no sourcing at run time). Function definitions only.

# Follow every symlink (macOS-safe: no readlink -f) and say where the file really lives.
resolve_path() {
  local p=$1 n=0 t d
  while [ -L "$p" ] && [ "$n" -lt 40 ]; do
    t=$(readlink "$p"); d=$(dirname "$p")
    case "$t" in /*) p=$t ;; *) p="$d/$t" ;; esac
    n=$((n+1))
  done
  d=$(cd -P "$(dirname "$p")" 2>/dev/null && pwd -P) || { echo "$p"; return; }
  echo "$d/$(basename "$p")"
}
in_nix_store() { case "$(resolve_path "$1")" in "${NIX_STORE_PREFIX:-/nix/store}"/*) return 0 ;; *) return 1 ;; esac; }
# own_install <command>: the command is on PATH under ~/.local or ~/.bun AND does not resolve into the
# nix store (a symlink there into the store is not the user's own install and can't update itself).
own_install() {
  local p
  p=$(command -v "$1" 2>/dev/null || true)
  [ -n "$p" ] || return 1
  if in_nix_store "$p"; then return 1; fi
  case "$p" in "$HOME"/.local/*|"$HOME"/.bun/*) return 0 ;; *) return 1 ;; esac
}

# ---- @sable-inc package token (Nov 23 2026: trial1 `sable update` got 403 on @sable-inc/apps) ----
# Bun reads ONE global bunfig: $XDG_CONFIG_HOME/.bunfig.toml when XDG_CONFIG_HOME is set, else ~/.bunfig.toml.
# Iru writes the read:packages scope to ~/.bunfig.toml; a shell with XDG_CONFIG_HOME set never saw it, fell back to
# ~/.npmrc (${NPM_TOKEN} = the slot's repo-only gh token) and got 403. So the scope goes to every path bun may read,
# and on trial Macs NPM_TOKEN is the package token, never the slot's gh token. Nothing here prints a token except
# sable_pkg_token / sable_npm_token, whose stdout is only ever captured by $(...).
bunfig_paths() { # every global bunfig path bun may read, one per line; ~/.bunfig.toml (Iru's copy) first
  printf '%s\n' "$HOME/.bunfig.toml" "$HOME/.config/.bunfig.toml"
  if [ -n "${XDG_CONFIG_HOME:-}" ] && [ "${XDG_CONFIG_HOME%/}" != "$HOME/.config" ]; then
    printf '%s\n' "${XDG_CONFIG_HOME%/}/.bunfig.toml"
  fi
}
# sable_bunfig_py <mode> <file>: get|put|drop the "@sable-inc" scope line. get prints the token (exit 1 if none or a
# placeholder); put reads the token on stdin and writes or replaces the scope line, keeping every other setting,
# mode 600, atomically; drop removes the scope line (and the file if nothing else is left). Symlinks are refused.
sable_bunfig_py() {
  # The program goes in with -c, not on stdin: put reads the token on stdin.
  local prog
  prog=$(cat <<'PY'
import os, re, sys
mode, path = sys.argv[1], sys.argv[2]
SCOPE = re.compile(r"""^\s*["']?@sable-inc["']?\s*=""")
TOK = re.compile(r'token\s*=\s*"([^"]*)"')
BAD = ("", "<token>", "TODO", "CHANGEME")
if os.path.islink(path):
    raise SystemExit(2)
text = open(path).read() if os.path.exists(path) else ""
lines = text.splitlines()
if mode == "get":
    for ln in lines:
        m = TOK.search(ln) if SCOPE.match(ln) and "npm.pkg.github.com" in ln else None
        if m and m.group(1) not in BAD:
            sys.stdout.write(m.group(1)); raise SystemExit(0)
    raise SystemExit(1)
kept = [ln for ln in lines if not SCOPE.match(ln)]
if mode == "put":
    tok = sys.stdin.read().strip()
    if tok in BAD or '"' in tok or "\n" in tok:
        raise SystemExit(1)
    line = '"@sable-inc" = { url = "https://npm.pkg.github.com", token = "%s" }' % tok
    if "[install.scopes]" in [k.strip() for k in kept]:
        i = [k.strip() for k in kept].index("[install.scopes]")
        kept.insert(i + 1, line)
    else:
        kept += ([""] if kept else []) + ["[install.scopes]", line]
elif mode == "drop":
    if not os.path.exists(path):
        raise SystemExit(0)
    meaningful = [k.strip() for k in kept if k.strip() and not k.strip().startswith("#") and k.strip() != "[install.scopes]"]
    if not meaningful:
        os.remove(path); raise SystemExit(0)
else:
    raise SystemExit(64)
d = os.path.dirname(path)
os.makedirs(d, mode=0o700, exist_ok=True)
tmp = path + ".sable-tmp"
fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_NOFOLLOW, 0o600)
with os.fdopen(fd, "w") as fh:
    fh.write("\n".join(kept) + "\n")
os.chmod(tmp, 0o600)
os.replace(tmp, path)
PY
)
  python3 -I -c "$prog" "$@"
}
sable_pkg_token() { # print the @sable-inc scope token from the first bunfig path that has a real one; else exit 1
  local f
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    sable_bunfig_py get "$f" && return 0
  done < <(bunfig_paths)
  return 1
}
sync_bunfig_scope() { # copy the scope token to every bunfig path bun may read. Exit 1 if there is no token yet.
  local tok f rc=0
  tok=$(sable_pkg_token) || return 1
  while IFS= read -r f; do
    printf '%s' "$tok" | sable_bunfig_py put "$f" || rc=1
  done < <(bunfig_paths)
  unset tok
  return "$rc"
}
drop_bunfig_scope() { # remove only the @sable-inc scope from every bunfig path; other Bun settings stay
  local f
  while IFS= read -r f; do sable_bunfig_py drop "$f" || true; done < <(bunfig_paths)
}
sable_npm_token() { # sable_npm_token <profile>: the token NPM_TOKEN should hold. Trial: the package scope token when
  # this slot has one (DS), else gh. Never the slot's repo-only gh token while a package token exists.
  if [ "${1:-}" = trial ] && sable_pkg_token; then return 0; fi
  gh auth token 2>/dev/null
}
