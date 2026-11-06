# Sable machine profiles

| profile | who | what changes vs `default` |
|:--|:--|:--|
| `default` | existing machines | nothing (builds the same system as `main`); Orca (orca.dev) is installed on every profile |
| `onboard` | new hire Mac | + Notion, 1Password, Granola, Linear casks; + `sable-doctor`; work-app dock (Claude, ChatGPT, Zoom, Granola, Notes, Linear, Notion, Wispr Flow, 1Password, Orca); npm/bun globals under `$HOME`; `NPM_TOKEN` from `gh auth token` |
| `trial` | trial laptops | everything `onboard` adds except Linear; − Devin, opam, qemu, texliveFull, zig; the new-hire dock without Spotify or Linear |

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

`sable-doctor [--trial-type ds|eng|ae] [--trial-dir <path>]` prints PASS/FAIL per piece (apps,
CLIs, gh auth and `read:packages`, npm registry, sable CLI and Trials org, SableBrowse and its
Chrome extension; for `ds` the deployments trial branch and `TRIAL_PROMPT.md`; for `eng` the
candidate's repo, API keys in the Keychain, Vercel and gcloud sign-in). An `ae` trial checks
only the machine, apps and CLIs. On a trial Mac the type defaults to `TRIAL_TYPE` in
`~/trial-inputs.env`. Exit code is the number of FAILs. It never prints a secret.

`@sable-inc` packages come from GitHub Packages. The profile exports
`NPM_TOKEN="$(gh auth token)"`, and `~/.npmrc` refers to it:

```sh
gh auth refresh -s read:packages
npm config set @sable-inc:registry https://npm.pkg.github.com
npm config set '//npm.pkg.github.com/:_authToken' '${NPM_TOKEN}'
```

v1 trial setup: see `docs/claude-setup-v1.md`.
