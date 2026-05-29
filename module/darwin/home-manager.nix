{
  self,
  config,
  pkgs,
  lib,
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
        config,
        pkgs,
        lib,
        ...
      }:
      {
        imports = [
          ../shared/home-manager.nix
        ];
        home.packages = pkgs.callPackage ./packages.nix { inherit pkgs; };
        programs.ghostty.package = null;
        targets.darwin.linkApps.enable = false;
      };
  };
}
