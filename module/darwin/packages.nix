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
in
if profile == "trial" then pkgs.lib.subtractLists heavy shared else shared
