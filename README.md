# nix-config

## macOS Installation

This configuration supports Apple Silicon Macs and expects the macOS account short name to be `sable`. Run the following commands from that administrator account. Confirm both values before making system changes:

```sh
uname -m
id -un
```

They must print `arm64` and `sable`, respectively.

### 1. Install Apple's Command Line Tools

Check whether the tools are already available:

```sh
xcode-select -p
```

If that command reports an error, start the installer:

```sh
xcode-select --install
```

Wait for the installation to finish, then rerun `xcode-select -p`. Do not continue until it prints a developer directory. Homebrew requires either these tools or Xcode.

### 2. Install Nix

Install the upstream, multi-user Nix distribution as the `sable` user, not with `sudo`:

```sh
curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install | sh
```

The installer will request administrator access when needed. When it finishes, close Terminal completely, open a new Terminal, and verify that Nix is available:

```sh
nix --version
```

### 3. Install This Configuration

The extra feature flag makes the first invocation work without editing `/etc/nix/nix.conf`; nix-darwin enables these features permanently during the first switch.

```sh
nix --extra-experimental-features 'nix-command flakes' run --refresh github:sable-inc/nix-config#init
cd /etc/nix-darwin
```

The initializer clones this repository into `/etc/nix-darwin` (the same location as `/private/etc/nix-darwin`), makes `sable` its owner, and enables the repository's pre-commit hook. If a configuration already exists, it is moved to `/etc/nix-darwin.backup`; an existing backup is preserved by using a timestamped name.

Before switching an existing Mac, declare every Homebrew package that must be retained in `local.nix`. Activation uses Homebrew's `zap` cleanup and removes formulae and casks that are not declared by this configuration or `local.nix`.

Build and activate the configuration:

```sh
nix --extra-experimental-features 'nix-command flakes' run path:.#build-switch
```

Enter your administrator password when prompted. After the command reports `switched`, open a new Terminal and verify the installation:

```sh
darwin-rebuild --list-generations
brew --version
```

## NixOS Installation

With Nix available, run:

```sh
nix --extra-experimental-features 'nix-command flakes' run --refresh github:sable-inc/nix-config#init
cd /etc/nixos
nix --extra-experimental-features 'nix-command flakes' run path:.#build-switch
```

To preview and apply updates, run:

```sh
nix run path:.#update
```

This shows package version changes without building the updated system, then asks before updating `flake.lock`. Press Enter to update it. Build-time dependencies may be included.

To update specific inputs, pass them after `--`:

```sh
nix run path:.#update -- nixpkgs home-manager
```

## Local Module

This config automatically loads a local module for changes specific to each machine. In the root directory of the checkout, create an ignored file named `local.nix`.

On macOS, it can contain local Homebrew or system settings:

```nix
{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.terraform ];
  homebrew.brews = [ "livekit" ];
}
```

On NixOS, keep machine identity and hardware-dependent settings there, including `system.stateVersion`, hardware-profile imports, firmware allowances, and machine-specific boot mount points:

```nix
{ ... }:
{
  system.stateVersion = "26.05";
}
```

Set `system.stateVersion` to the NixOS release used for that machine's first installation and do not update it during normal upgrades. `hardware-configuration.nix` remains generated hardware discovery; do not put hand-written machine policy in it.

## Work Trial Applications

The macOS base installs Zoom, Wispr Flow, Claude Desktop, and Codex desktop through Homebrew. Codex desktop is now included in the ChatGPT app, so the base uses the `chatgpt` cask rather than the discontinued `codex-app` cask. See the [official Codex desktop migration announcement](https://learn.chatgpt.com/docs/changelog#codex-joins-the-chatgpt-desktop-app-26707).

Claude Code and Codex CLI are already enabled through Home Manager on both macOS and NixOS. The desktop apps do not replace these terminal tools.

| Application | macOS (Apple Silicon) | NixOS (x86_64) | NixOS (aarch64) |
| --- | --- | --- | --- |
| Zoom | Homebrew `zoom` | Nix `zoom-us`, with GNOME portal support | Not installed; the pinned package does not support this platform |
| Wispr Flow | Homebrew `wispr-flow` | Not installed | Not installed |
| Claude Desktop | Homebrew `claude` | Not installed | Not installed |
| Codex desktop | Homebrew `chatgpt` | Not installed | Not installed |
| Claude Code | Home Manager | Home Manager | Home Manager |
| Codex CLI | Home Manager | Home Manager | Home Manager |

After `build-switch` on macOS, verify the desktop packages and terminal tools:

```sh
brew list --cask chatgpt claude wispr-flow zoom
claude --version
codex --version
```

On x86_64 NixOS, also verify Zoom with `command -v zoom`.

Installation does not sign users into the apps. Complete sign-in and grant microphone, camera, accessibility, and screen-sharing permissions as needed during onboarding.

## Agent Configuration

Nix installs Claude Code, Codex, OpenCode, and Pi but does not manage their instructions, skills, settings, plugins, or other configuration. Configure them normally in `~/.claude`, `~/.codex`, `~/.config/opencode`, and `~/.pi/agent`; rebuilds leave those directories under local, imperative control.

## Secrets

Secrets are managed with [agenix](https://github.com/ryantm/agenix): encrypted `*.age` files in `secrets/` are decrypted to `/run/agenix/<name>` on `build-switch`. Declare each in `local.nix` under `age.secrets` and reference it as `config.age.secrets.<name>.path`.

Add or rotate one with `age-secret <name>` (hidden prompt, no trailing newline), then rebuild:

```sh
age-secret modal-token-id
```

Agent configuration can reference the resulting `/run/agenix/<name>` files while remaining locally editable.

## Acknowledgements

Thanks to [dustinlyons/nixos-config](https://github.com/dustinlyons/nixos-config) for the starter that began this project!
