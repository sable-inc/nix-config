{
  user,
  targetDir,
  ...
}:
{
  home-manager = {
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
        home.packages = import ./packages.nix { inherit pkgs; };
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
