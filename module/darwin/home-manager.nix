{
  config,
  lib,
  user,
  targetDir,
  ...
}:
{
  home-manager = {
    backupFileExtension = "before-nix-config";
    overwriteBackup = true;
    extraSpecialArgs = {
      inherit targetDir;
    };
    useGlobalPkgs = true;
    users.${user} =
      {
        pkgs,
        ...
      }:
      {
        imports = [
          ../shared/home-manager.nix
        ];
        home.packages = import ./packages.nix {
          inherit pkgs;
          profile = config.sable.profile;
        };
        # Claude Code and Codex are user-owned native installs in ~/.local/bin (sable-setup),
        # not nix store binaries, so Orca and `claude update` / `codex update` can replace them.
        # Listed first so nothing else on PATH shadows a user's newer copy.
        home.sessionPath = lib.mkBefore [ "$HOME/.local/bin" ];
        nix.gc = {
          automatic = true;
          dates = "weekly";
          options = "--delete-older-than=7d";
        };
        programs.ghostty.package = null;
        programs.man.generateCaches = false;
      };
  };
}
