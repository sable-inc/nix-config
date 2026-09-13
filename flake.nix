{
  inputs = {
    agenix = {
      inputs = {
        darwin.follows = "nix-darwin";
        home-manager.follows = "home-manager";
        nixpkgs.follows = "nixpkgs";
      };
      url = "github:ryantm/agenix";
    };
    home-manager = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:nix-community/home-manager";
    };
    nix-darwin = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:nix-darwin/nix-darwin";
    };
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    nix-vscode-extensions = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:nix-community/nix-vscode-extensions";
    };
    nixos-hardware = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:dseum/nixos-hardware/dell-xps-14-da14260";
    };
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  };
  outputs =
    inputs@{
      agenix,
      home-manager,
      nix-darwin,
      nix-homebrew,
      nixpkgs,
      ...
    }:
    let
      user = "sable";
      localModule = ./local.nix;
      linuxSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      darwinSystems = [
        "aarch64-darwin"
      ];
      mkApp =
        pkgs:
        {
          name,
          script,
          arguments ? [ ],
          runtimeInputs ? [ ],
        }:
        let
          app = pkgs.writeShellApplication {
            inherit name runtimeInputs;
            text = ''
              exec ${nixpkgs.lib.escapeShellArgs ([ script ] ++ arguments)} "$@"
            '';
          };
        in
        {
          type = "app";
          program = "${app}/bin/${name}";
          meta.description = "Run ${name}";
        };
      mkInitApp =
        pkgs:
        {
          targetDir,
          expectedUser ? null,
        }:
        let
          app = pkgs.writeShellApplication {
            name = "init";
            runtimeInputs = [
              pkgs.coreutils
              pkgs.git
            ];
            text = ''
              green="$(printf '\033[1;32m')"
              red="$(printf '\033[1;31m')"
              yellow="$(printf '\033[1;33m')"

              println() {
                printf '\033[1mnix-config: %s%s\n\033[0m' "$1" "$2"
              }

              target_dir="${targetDir}"
              tmp_dir="$(mktemp -d)"
              user_name="$(id -un)"
              trap 'rm -rf "$tmp_dir"' EXIT

              ${nixpkgs.lib.optionalString (expectedUser != null) ''
                if [ "$user_name" != "${expectedUser}" ]; then
                  println "$red" "expected user ${expectedUser}, got $user_name"
                  exit 1
                fi
              ''}

              println "$yellow" "injecting..."

              git clone "https://github.com/sable-inc/nix-config.git" "$tmp_dir/nix-config" &>/dev/null

              if [ -e "$target_dir" ] || [ -L "$target_dir" ]; then
                backup_dir="''${target_dir}.backup"
                if [ -e "$backup_dir" ] || [ -L "$backup_dir" ]; then
                  backup_dir="''${backup_dir}-$(date +%Y%m%d-%H%M%S)-$$"
                fi
                if [ -e "$backup_dir" ] || [ -L "$backup_dir" ]; then
                  println "$red" "backup path already exists: $backup_dir"
                  exit 1
                fi
                sudo mv "$target_dir" "$backup_dir"
                println "$yellow" "moved existing configuration to $backup_dir"
              fi

              sudo mv "$tmp_dir/nix-config" "$target_dir"
              sudo chown -R "$user_name" "$target_dir"
              git -C "$target_dir" config core.hooksPath .githooks

              println "$green" "injected into $target_dir"
            '';
          };
        in
        {
          type = "app";
          program = "${app}/bin/init";
          meta.description = "Install nix-config into ${targetDir}";
        };
      mkLinuxApps =
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
          };
        in
        {
          "build-switch" = mkApp pkgs {
            name = "build-switch";
            script = ./. + "/target/${system}/build-switch";
          };
          "init" = mkInitApp pkgs { targetDir = "/etc/nixos"; };
          "update" = mkApp pkgs {
            name = "update";
            script = ./target/update;
            arguments = [
              "/etc/nixos"
              "nixosConfigurations.${system}.config.system.build.toplevel"
            ];
            runtimeInputs = [
              pkgs.coreutils
              pkgs.nix
            ];
          };
        };
      mkDarwinApps =
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
          };
        in
        {
          "build-switch" = mkApp pkgs {
            name = "build-switch";
            script = ./. + "/target/${system}/build-switch";
          };
          "init" = mkInitApp pkgs {
            targetDir = "/etc/nix-darwin";
            expectedUser = user;
          };
          "update" = mkApp pkgs {
            name = "update";
            script = ./target/update;
            arguments = [
              "/etc/nix-darwin"
              "darwinConfigurations.${system}.system"
            ];
            runtimeInputs = [
              pkgs.coreutils
              pkgs.nix
            ];
          };
        };
    in
    {
      apps =
        nixpkgs.lib.genAttrs linuxSystems mkLinuxApps // nixpkgs.lib.genAttrs darwinSystems mkDarwinApps;
      darwinConfigurations = nixpkgs.lib.genAttrs darwinSystems (
        system:
        nix-darwin.lib.darwinSystem {
          specialArgs = inputs // {
            inherit user;
            targetDir = "/private/etc/nix-darwin";
          };
          modules = [
            { nixpkgs.hostPlatform = system; }
            home-manager.darwinModules.home-manager
            nix-homebrew.darwinModules.nix-homebrew
            agenix.darwinModules.default
            ./module/darwin
            (if builtins.pathExists localModule then localModule else { })
          ];
        }
      );
      nixosConfigurations = nixpkgs.lib.genAttrs linuxSystems (
        system:
        nixpkgs.lib.nixosSystem {
          specialArgs = inputs // {
            inherit user;
            targetDir = "/etc/nixos";
          };
          modules = [
            { nixpkgs.hostPlatform = system; }
            home-manager.nixosModules.home-manager
            agenix.nixosModules.default
            ./module/nixos
            (if builtins.pathExists localModule then localModule else { })
          ];
        }
      );
    };
}
