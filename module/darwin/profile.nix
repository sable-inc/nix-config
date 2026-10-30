# Machine profile: "default" (today's behavior, unchanged), "onboard" (new hire),
# or "trial" (work-trial laptop: lighter install, no heavy toolchains).
# Pick one in the ignored local.nix:  { sable.profile = "trial"; }
# or with:  nix run github:sable-inc/nix-config#init -- --profile trial --hostname sable-trial1
{
  config,
  lib,
  pkgs,
  user,
  ...
}:
let
  profile = config.sable.profile;
  sableDoctor = pkgs.writeShellScriptBin "sable-doctor" (builtins.readFile ./bin/sable-doctor);
in
{
  options.sable.profile = lib.mkOption {
    type = lib.types.enum [
      "default"
      "onboard"
      "trial"
    ];
    default = "default";
    description = "Which Sable machine profile this Mac uses.";
  };

  config = lib.mkMerge [
    (lib.mkIf (profile != "default") {
      environment.systemPackages = [ sableDoctor ];
      homebrew.casks = [ "notion" ];
      home-manager.users.${user} = {
        # Nix's node lives in the read-only store, so npm and bun globals go under $HOME.
        home.sessionVariables.NPM_CONFIG_PREFIX = "$HOME/.npm-global";
        home.sessionPath = [
          "$HOME/.npm-global/bin"
          "$HOME/.bun/bin"
        ];
        # @sable-inc packages and `sable update` read the GitHub token from NPM_TOKEN.
        programs.zsh.initContent = ''
          export NPM_TOKEN="$(gh auth token 2>/dev/null)"
        '';
      };
    })
    (lib.mkIf (profile == "onboard") {
      homebrew.casks = [ "linear" ];
    })
    (lib.mkIf (profile == "trial") {
      # Trial laptops are wiped after every trial: no Devin seat, no Spotify in the dock.
      system.defaults.dock.persistent-apps = lib.mkForce [
        "/Applications/Google Chrome.app"
        "/System/Applications/Utilities/Terminal.app/"
        "/Applications/Ghostty.app"
        "${config.users.users.${user}.home}/Applications/Home Manager Apps/Cursor.app"
        "/Applications/Claude.app"
        "/Applications/Nix Apps/Slack.app"
        "/Applications/zoom.us.app"
        "/System/Applications/System Settings.app"
      ];
    })
  ];
}
