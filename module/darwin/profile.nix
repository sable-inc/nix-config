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
      homebrew.casks = [ "notion" "1password" "granola" ];
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
      # New hires get the work apps in the dock, not only the default set.
      system.defaults.dock.persistent-apps = lib.mkForce [
        "/Applications/Google Chrome.app"
        "/Applications/Nix Apps/Spotify.app"
        "/Applications/Nix Apps/Slack.app"
        "/Applications/zoom.us.app"
        "/Applications/Granola.app"
        "/System/Applications/Notes.app"
        "/Applications/Claude.app"
        "/Applications/ChatGPT.app"
        "/Applications/Linear.app"
        "/Applications/Notion.app"
        "/Applications/Wispr Flow.app"
        "/Applications/1Password.app"
        "/Applications/Orca.app"
        "/System/Applications/Utilities/Terminal.app/"
        "${config.users.users.${user}.home}/Applications/Home Manager Apps/Cursor.app"
        "/System/Applications/System Settings.app"
      ];
    })
    (lib.mkIf (profile == "trial") {
      # Eng trials store their API keys in the login Keychain (docs/claude-setup-v1.md).
      home-manager.users.${user}.programs.zsh.initContent = ''
        for key in ANTHROPIC_API_KEY OPENAI_API_KEY; do
          value="$(security find-generic-password -a sable -s "$key" -w 2>/dev/null)" && export "$key=$value"
        done
        unset key value
      '';
      # Trial laptops are wiped after every trial: the new-hire dock without Spotify or Linear.
      system.defaults.dock.persistent-apps = lib.mkForce [
        "/Applications/Google Chrome.app"
        "/Applications/Nix Apps/Slack.app"
        "/Applications/zoom.us.app"
        "/Applications/Granola.app"
        "/System/Applications/Notes.app"
        "/Applications/Claude.app"
        "/Applications/ChatGPT.app"
        "/Applications/Notion.app"
        "/Applications/Wispr Flow.app"
        "/Applications/1Password.app"
        "/Applications/Orca.app"
        "/System/Applications/Utilities/Terminal.app/"
        "${config.users.users.${user}.home}/Applications/Home Manager Apps/Cursor.app"
        "/System/Applications/System Settings.app"
      ];
    })
  ];
}
