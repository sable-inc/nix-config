{
  pkgs,
  profile ? "default",
}:
let
  shared = import ../shared/packages.nix { inherit pkgs; };
  # Large toolchains a work trialer never needs; dropping them cuts first install time.
  heavy = [
    pkgs.opam
    pkgs.qemu
    pkgs.texliveFull
    pkgs.tex-fmt
    pkgs.zig
  ];
  # Cursor is a Homebrew cask on Macs (default.nix) so its own updater works; a store copy is read-only.
  selfUpdating = [ pkgs.code-cursor ];
  base = if profile == "trial" then pkgs.lib.subtractLists heavy shared else shared;
in
pkgs.lib.subtractLists selfUpdating base
