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
          profiles ? false,
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
              profile=""
              host_name=""
              ref=""

              while [ "$#" -gt 0 ]; do
                if [ "$#" -lt 2 ] || [ -z "$2" ]; then
                  println "$red" "missing value for $1"
                  exit 1
                fi
                case "$1" in
                  --profile) profile="$2" ;;
                  --hostname) host_name="$2" ;;
                  --ref) ref="$2" ;;
                  *)
                    println "$red" "unknown argument: $1"
                    exit 1
                    ;;
                esac
                shift 2
              done
              profiles="${if profiles then "1" else ""}"
              if [ -n "$profile$host_name" ] && [ -z "$profiles" ]; then
                println "$red" "--profile and --hostname are only supported on macOS"
                exit 1
              fi
              case "$profile" in
                ""|default|onboard|trial) ;;
                *)
                  println "$red" "profile must be default, onboard or trial, got $profile"
                  exit 1
                  ;;
              esac
              case "$host_name" in
                *[!A-Za-z0-9-]*)
                  println "$red" "hostname may only use letters, digits and -, got $host_name"
                  exit 1
                  ;;
              esac
              case "$ref" in
                -*|*[!A-Za-z0-9._/-]*)
                  println "$red" "ref may only use letters, digits, ., _, / and -, got $ref"
                  exit 1
                  ;;
              esac

              if [ -n "$profile$host_name" ] && [ -f "$target_dir/local.nix" ]; then
                println "$red" "$target_dir/local.nix already exists; edit it by hand instead of passing --profile or --hostname"
                exit 1
              fi

              ${nixpkgs.lib.optionalString (expectedUser != null) ''
                if [ "$user_name" != "${expectedUser}" ]; then
                  println "$red" "expected user ${expectedUser}, got $user_name"
                  exit 1
                fi
              ''}

              println "$yellow" "injecting..."

              git clone ''${ref:+--branch "$ref"} "https://github.com/sable-inc/nix-config.git" "$tmp_dir/nix-config" &>/dev/null

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

              if [ -n "$profile$host_name" ]; then
                {
                  printf '{ ... }:\n{\n'
                  if [ -n "$profile" ]; then printf '  sable.profile = "%s";\n' "$profile"; fi
                  if [ -n "$host_name" ]; then printf '  networking.hostName = "%s";\n' "$host_name"; fi
                  printf '}\n'
                } > "$target_dir/local.nix.tmp"
                mv "$target_dir/local.nix.tmp" "$target_dir/local.nix"
                println "$green" "wrote $target_dir/local.nix"
              elif [ -n "''${backup_dir:-}" ] && [ -f "$backup_dir/local.nix" ]; then
                sudo cp "$backup_dir/local.nix" "$target_dir/local.nix"
                sudo chown "$user_name" "$target_dir/local.nix"
                println "$green" "kept local.nix from $backup_dir"
              fi

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
            profiles = true;
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
