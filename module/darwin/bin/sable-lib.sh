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
