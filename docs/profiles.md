# Sable machine profiles

| profile | who | what changes vs `default` |
|:--|:--|:--|
| `default` | existing machines | nothing (builds the same system as `main`); Orca (orca.dev) is installed on every profile |
| `onboard` | new hire Mac (first week; then Default Blueprint in Iru, see `docs/iru.md`) | Homebrew apps the hire installs are kept (trial Macs remove them); + Notion, 1Password, Granola, Linear, Loom casks; + `sable-setup`, `sable-doctor`; the Mac's name on the login and lock screen; work-app dock (Chrome, Slack, Orca, Cursor, ChatGPT, Claude, Terminal, Wispr Flow, Zoom, Granola, Notion, Linear, Loom, 1Password, Notes, Spotify, System Settings); npm/bun globals under `$HOME`; `NPM_TOKEN` from `gh auth token` |
| `trial` | trial laptops | the same as `onboard`, except Figma and Canva instead of Loom (casks and dock); − Devin, opam, qemu, texliveFull, zig; API keys from the Keychain |

`tex-fmt` remains available to Neovim through the shared editor configuration.

Choose at install (on a fresh Mac, in **Terminal.app**):

```sh
nix --extra-experimental-features 'nix-command flakes' run --refresh \
  github:sable-inc/nix-config#init -- --profile trial --hostname sable-trial1
```

`--ref <branch or tag>` installs that ref instead of `main`. Ref names may contain letters,
digits, `.`, `_`, `/` and `-`, and cannot start with `-`. The profile and hostname flags write
`local.nix`:

```nix
{ ... }:
{
  sable.profile = "trial";
  networking.hostName = "sable-trial1";
}
```

Then build and switch:

```sh
cd /etc/nix-darwin && nix --extra-experimental-features 'nix-command flakes' run path:.#build-switch
```

Name trial laptops after their trial account (`trial1@` is
`sable-trial1`) so two laptops never share a hostname.

Run the Nix installer and `build-switch` from Terminal.app. On macOS 27, terminals without the
right privacy permission (Orca's terminal, for example) can't write `/etc/fstab`, and the Nix
installer fails with "Operation not permitted".

`sable-setup` finishes a trial or new-hire Mac after the install: GitHub sign-in, Sable's
packages, the sable CLI (Trials org on trial Macs, Sable otherwise), SableBrowse, and on trial
Macs the access listed in the slot's `trial-inputs.env`, which it downloads from the private
`sable-inc/trial-inputs` repo (repos, trial agent, Vercel, gcloud; API keys only if asked for).
It stops at each step a person must do and is safe to rerun.

`sable-doctor [--trial-dir <path>]` prints PASS/FAIL per piece (apps, CLIs, gh auth and
`read:packages`, npm registry, sable CLI and Trials org, SableBrowse and its Chrome extension,
and on trial Macs each piece of access in `~/trial-inputs.env`). A trial with no GitHub user
in the file checks only the machine, apps and CLIs. Exit code is the number of FAILs. It never prints a secret.

`@sable-inc` packages come from GitHub Packages. The profile exports
`NPM_TOKEN="$(gh auth token)"`, and `~/.npmrc` refers to it:

```sh
gh auth refresh -s read:packages
npm config set @sable-inc:registry https://npm.pkg.github.com
npm config set '//npm.pkg.github.com/:_authToken' '${NPM_TOKEN}'
```

v1 trial setup: see `docs/claude-setup-v1.md`.
