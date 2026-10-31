{
  config,
  user,
  targetDir,
  ...
}:
{
  home-manager = {
    backupFileExtension = "before-nix-config";
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
