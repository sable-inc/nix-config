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
        programs.man.generateCaches = false; # No man package on Darwin in 26.05; caches are a no-op
        targets.darwin.linkApps.enable = false;
        launchd.agents.nix-user-gc = {
          enable = true;
          config = {
            ProgramArguments = [
              "/run/current-system/sw/bin/nix-collect-garbage"
              "--delete-older-than"
              "7d"
            ];
            StartCalendarInterval = [
              {
                Hour = 3;
                Minute = 0;
              }
            ];
            StandardOutPath = "${config.home.homeDirectory}/Library/Logs/nix-user-gc.log";
            StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/nix-user-gc.log";
          };
        };
      };
  };
}
