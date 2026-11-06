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
  sableSetup = pkgs.writeShellScriptBin "sable-setup" (builtins.readFile ./bin/sable-setup);
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
      environment.systemPackages = [
        sableDoctor
        sableSetup
      ];
      homebrew.casks = [
        "notion"
        "1password"
        "granola"
        "linear"
      ];
      # Shown on the login and lock screen, so identical-looking Macs can be told apart.
      system.defaults.loginwindow.LoginwindowText =
        lib.mkIf (config.networking.hostName != "darwin") config.networking.hostName;
      # New hires and trial candidates get the same work apps in the dock, except Loom (new
      # hires) and Figma and Canva (trials).
      system.defaults.dock.persistent-apps = lib.mkForce ([
        "/Applications/Google Chrome.app"
        "/Applications/Nix Apps/Slack.app"
        "/Applications/Orca.app"
        "${config.users.users.${user}.home}/Applications/Home Manager Apps/Cursor.app"
        "/Applications/ChatGPT.app"
        "/Applications/Claude.app"
        "/System/Applications/Utilities/Terminal.app/"
        "/Applications/Wispr Flow.app"
        "/Applications/zoom.us.app"
        "/Applications/Granola.app"
        "/Applications/Notion.app"
        "/Applications/Linear.app"
      ]
      ++ lib.optional (profile == "onboard") "/Applications/Loom.app"
      ++ lib.optionals (profile == "trial") [
        "/Applications/Figma.app"
        "/Applications/Canva.app"
      ]
      ++ [
        "/Applications/1Password.app"
        "/System/Applications/Notes.app"
        "/Applications/Nix Apps/Spotify.app"
        "/System/Applications/System Settings.app"
      ]);
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
      homebrew.casks = [ "loom" ];
    })
    (lib.mkIf (profile == "trial") {
      homebrew.casks = [
        "figma"
        "canva"
      ];
      # sable-setup stores trial API keys in the login Keychain; new shells export them.
      home-manager.users.${user}.programs.zsh.initContent = ''
        for key in ANTHROPIC_API_KEY OPENAI_API_KEY; do
          value="$(security find-generic-password -a sable -s "$key" -w 2>/dev/null)" && export "$key=$value"
        done
        unset key value
      '';
    })
  ];
}
