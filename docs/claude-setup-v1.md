# v1 trial laptop setup

For the office person setting up a Sable trial laptop. Covers:

- **A. New trial laptop:** a brand-new Mac joins the trial pool
- **B. Cleanup:** an existing trial laptop gets the next candidate after the light cleanup at
  midnight PT on the last day (`docs/new-mac-runbook.md`, Part H), then the `sable-setup`
  check. A full erase is the exception and needs Matthew's OK on that exact serial (Part H
  step 5)
- **C. New-hire Mac:** Iru does steps 2-6 on the **Sable Onboard** blueprint
  (`docs/iru.md`, "ADE preflight (required before anyone continues Setup Assistant)").
  Do that before anyone continues Setup Assistant. Without Iru, follow hand steps 1-6
  with `--profile onboard` and the
  person's own hostname (`--hostname sable-<name>`). Then the hire signs in to their apps and
  runs `sable-setup` (section C below). Don't store the FileVault key by hand; Iru escrows it

No secrets go in this file, in Slack, or in the repo. Passwords come from that slot's own 1Password vault `Trial – <slot>` (for example `Trial – trial1`). The guest does not see a shared Trial vault, and no vault id is stored here. Time each
step in the two-Mac checklist.

## Inputs from the bots

Every trial Mac gets the same install and apps. What differs is the access the bots grant for
the candidate's role, and `sable-setup` sets up exactly that access and nothing more:

| Role | The bots grant | `trial-inputs.env` lines |
|---|---|---|
| DS | sable-inc/deployments (trial branch), the trial agent, Trials org | `TRIAL_GITHUB_USER`, `REPOS="sable-inc/deployments@trial/<first>-<last>"`, `AGENT_PATH`, `AGENT_ID`, `TRIAL_TYPE="ds"` |
| Eng, FDE | their own new repo `sable-inc/<name>`, Vercel, GCP, Trials org | `TRIAL_GITHUB_USER`, `REPOS="sable-inc/<name>"`, `VERCEL="yes"`, `GCP="yes"` |
| Design | repos to be decided (deployments for now), Trials org | `TRIAL_GITHUB_USER`, `REPOS` |
| Security | read-only GCP on the project under review, Trust Center, repos to be decided, Trials org | `TRIAL_GITHUB_USER`, `REPOS`, `GCP="yes"` |
| EL, AE, Marketing | Trials org on the web (no repos or CLI) | none |

The slot's GitHub account gets only the repos in `REPOS`. Remove the previous trial's repo and
GCP access at reset.

The Onboarding bot writes one file per trial, `<slot>/trial-inputs.env` (for example
`trial3/trial-inputs.env`), in the private repo `sable-inc/trial-inputs`, with no secrets in it.
Nobody copies it: `sable-setup` signs in to GitHub as the slot's account and downloads the file
for this Mac's slot (from its name, `sable-trial3`). Every slot's GitHub account needs read
access to that repo. Nobody accepts GitHub invites by hand: `sable-accept-invites` lists
`/user/repository_invitations` and accepts every pending invite whose repository owner is
`sable-inc`, and no other owner. It runs at setup and at each Iru check-in (`mdm/iru-update.sh`),
as the slot user with that slot's own `gh` sign-in. It logs only the repo name and permission
to `/Library/Logs/sable/github-invites.log`. `sable-doctor` fails if a `sable-inc` invite is
still pending, and warns if `gh` is not signed in. This includes EL, AE and Marketing trials;
`sable-setup` signs those out of GitHub again after it has the list. Leave out any line the role doesn't need:

```sh
# A DS trial
TRIAL_NAME="Jane Doe"
TRIAL_EMAIL="trial1@sable.ai"          # the slot's Google account
TRIAL_SLOT="trial1"                    # this Mac is sable-trial1
TRIAL_GITHUB_USER="<GITHUB_USER>"      # the slot's GitHub account; empty = no technical setup
REPOS="sable-inc/deployments@trial/jane-doe"   # space-separated, @branch optional
AGENT_PATH="trials/partner-qualifier-jane"     # inside ~/deployments
AGENT_ID="agt_..."                     # the trial agent, never a live one
TRIAL_TYPE="ds"                        # ds | eng | fde | design | ae | el | marketing | empty
```

`TRIAL_TYPE` is one of `ds`, `eng`, `fde`, `design`, `ae`, `el`, `marketing`, or empty (an idle
slot). Only `ds` gets Sable repos and the DS tools: the Trials org login, SableBrowse, and the
repos in `REPOS`. If that list omits `sable-inc/deployments`, `sable-setup` adds it. It then
checks that git, gh, Claude Code, Codex, Cursor and Orca can use `~/deployments`
(`sable-doctor`, "DS repo works"), that Orca's active workspace (and any Claude tab cwd) is
that folder, and that `~/.claude/CLAUDE.md` tells Claude to use `/call-feedback-triage` for a
"Debug session" card. The deployments repo itself is not edited. Every other type, including
empty, gets none of the Sable repos, no Trials org login, no SableBrowse, no toolbelt
workflow, and no sable CLI; a `REPOS` line is ignored, with a warning. An unknown value
warns and setup continues. If the CLI is already on a non-DS slot, setup signs it out
and uninstalls it.

Only a DS trial gets the sable CLI. Non-DS slots cannot read the packages, so setup does
not clone them and, if the CLI is already there, signs it out and uninstalls it. The DS
install is `bun add -g @sable-inc/toolbelt@^0.80.0 @sable-inc/e2e @sable-inc/wiki`. bun
must be at least 1.4.4; setup installs or upgrades it when it is older. bun reads the
registry from `~/.bunfig.toml` (mode `600`), which it prefers over `~/.npmrc`:

```toml
[install.scopes]
"@sable-inc" = { url = "https://npm.pkg.github.com", token = "<token>" }
```

The token is a GitHub classic token with only `read:packages`. On the Onboarding box it is
named `github-trial-packages-token`. Iru writes `~/.bunfig.toml` from `mdm/iru-trial-packages.sh`;
the Mac never reads the box, and the token is never committed. The slot's `gh auth token` is not used.

Each DS Mac signs in once as that slot's own trial account (`trial@sable.ai` on
`sable-trial`, `trial1@sable.ai` on `sable-trial1`), not as a separate admin account.
Those accounts already have the platform admin flag. It is Google OAuth. Setup runs
`sable login --device` when `sable whoami` is missing or is a different email, and writes
the device URL and code (no tokens) to `/Library/Logs/sable/sable-login-device.txt` so
Onboarding can finish it in a browser as that slot's account. Credentials stay in
`~/.config/sable/credentials.json` (mode `0600`, auto-refresh). The reset keeps that file.
Never copy it from another machine.

On a DS trial, `sable-doctor` requires `sable --version` and `sable whoami` to report that
slot's trial email, and fails if the email is anyone else's. On every other trial type it
fails if the `sable` binary, `~/.config/sable`, or an `@sable-inc` scope in `~/.bunfig.toml`
is still present. There is no claude.ai Slack connector and no `#bug-reports` access. Call
notes come from the checkout's `.sable/reviews` and `sable bundle`.

An Eng or FDE trial replaces the `REPOS`, `AGENT_PATH`, `AGENT_ID` and `TRIAL_TYPE` lines with:

```sh
REPOS="sable-inc/jane-doe"             # ignored unless TRIAL_TYPE is ds
VERCEL="yes"
GCP="yes"                              # gcloud signed in as TRIAL_EMAIL
TRIAL_TYPE="eng"                       # fde for an FDE trial
```

Trials get no API keys by default: Claude Code runs on the slot's Claude seat, and the slot
accounts are in Sable's Anthropic and OpenAI organizations, so a candidate who needs a key makes
one there. Adding `API_KEYS="yes"` makes `sable-setup` ask for both keys and store them in the
login Keychain, never in a file or shell history; new shells export them as
`ANTHROPIC_API_KEY` and `OPENAI_API_KEY`.

With `AGENT_PATH`, `sable-setup` also downloads the approved trial prompt template
(`<slot>/trial-prompt-template.md`, or `trial-prompt-template.md` at the top of the repo) and
writes `~/TRIAL_PROMPT.md` from it, replacing `{{AGENT_PATH}}` and `{{AGENT_ID}}`.

If any value still looks like `<...>`, `agt_...`, `agt_XXXX` or `TODO`, `sable-setup` stops.
That is what broke the Oct 25 trial. Keep these per-trial files in `sable-inc/trial-inputs`,
never in this public repository, and delete the slot's folder at reset. If the repo can't be
reached, files copied by hand to `~/trial-inputs.env` (and `~/trial-prompt-template.md` for an
agent) still work.

## B only: reset first

The Onboarding bot's midnight routine runs the account reset for the slot, with no per-trial
go from Matthew.

1. At midnight PT on the trial's last day, the Mac gets the light cleanup in
   `docs/new-mac-runbook.md`, Part H
2. Then run the `sable-setup` check
3. Erasing is the exception and needs Matthew's OK on this exact serial. That is Part H
   step 5

## A. By hand, in Terminal.app (not Ghostty, Orca or another terminal)

On macOS 27, the Nix installer needs to write `/etc/fstab`, which only works from a terminal
with that privacy permission. Terminal.app has it; Ghostty and Orca don't by default.

1. macOS Setup Assistant: admin account with short name exactly `sable`. Join Wi-Fi. Install
   macOS updates
2. Open **Terminal.app**. `uname -m && id -un` must print `arm64` and `sable`
3. `xcode-select --install`, wait for it to finish
4. Install Nix, then quit Terminal and open a new window:
   ```sh
   sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install) --daemon
   ```
5. Install nix-config with the trial profile, for every trial type (replace `trial1` with the slot):
   ```sh
   nix --extra-experimental-features 'nix-command flakes' run --refresh \
     github:sable-inc/nix-config#init -- --profile trial --hostname sable-trial1
   ```
   **Fresh or erased Macs only.** The next step deletes any app nix-config doesn't list.
6. Build and switch (asks for the admin password; wait for "switched"):
   ```sh
   cd /etc/nix-darwin && nix --extra-experimental-features 'nix-command flakes' run path:.#build-switch
   ```
7. In Terminal.app, run `sable-setup`, for every role. It signs in to GitHub as the slot's
   account and downloads this slot's list from `sable-inc/trial-inputs`. Then:
   - **DS:** it installs `@sable-inc/toolbelt@^0.80.0`, `@sable-inc/e2e` and `@sable-inc/wiki`
     with bun, using the `@sable-inc` scope in `~/.bunfig.toml`, and runs `sable login --device`
     once as this slot's trial account when `sable whoami` is not that email. It does not clone
     toolbelt. Then Trials org login, SableBrowse, the repos (adding `sable-inc/deployments`
     when `REPOS` omits it), Orca's clone-from-URL into `~/deployments`, the Debug session
     hint, and checks that git, gh, Claude Code, Codex, Cursor and Orca work there.
   - **EL, AE, Marketing, and an idle slot:** no Sable repos and no sable CLI. If the CLI
     is installed, setup signs it out and removes it. An idle slot signs GitHub out and
     says to sign in to Chrome, Slack and the other apps with the slot's Google account.
   - **Every other trial type:** no Sable repos, no Trials org login, no SableBrowse, no
     toolbelt workflow, and no sable CLI. It still signs in to Claude Code and Codex when those sign-ins are
     missing, and sets up any API keys, Vercel or GCP listed in the file. An unknown
     `TRIAL_TYPE` warns and continues. It ends with `sable-doctor`. Safe to rerun: it skips
     what's already done. Then sign in to the apps as above.

If something fails and the fix isn't obvious, run `claude` in Terminal.app and paste the
output.

## C. New-hire Mac, day one

When Iru enrolls the Mac, the ADE preflight has to pass before anyone continues Setup
Assistant (`docs/iru.md`, "ADE preflight (required before anyone continues Setup Assistant)").
After Iru's install (or hand steps 1-6 with `--profile onboard`):

1. The hire changes the `sable` password to their own: System Settings > Users & Groups.
   The Mac starts with the setup password from Sable's vault, which others know. The new
   password is also the one that unlocks the disk at startup; the hire keeps it to themselves
2. The hire signs in to each app with their @sable.ai Google account: Chrome, Slack, Zoom,
   Granola, Claude, ChatGPT, Linear, Notion, Loom, Wispr Flow, Cursor, and 1Password (needs
   their 1Password invite)
3. Once their GitHub account is in sable-inc, they run `sable-setup` in Terminal.app. It does
   the same as on a trial Mac, with the main Sable org instead of Trials and no inputs file.
   If anyone else signed in to GitHub on this Mac (for testing), run `gh auth logout` first:
   `sable-setup` keeps an existing sign-in. When `gh auth login` asks "Authenticate Git with
   your GitHub credentials?", answer No; `sable-setup` sets that up itself
4. After their first week, move the Mac to Default Blueprint in Iru (`docs/iru.md`, "New hires
   after week one"), so automatic updates never reset their own setup

## After

Paste the `sable-doctor` output and `~/setup-log.md` into the two-Mac checklist. Every step
that needed a human is a gap for v2 (Iru) or the final version (Doppler) to remove.

## Open items (owner in brackets)

- Whether trial slot accounts become sable-inc members again, which would let them read every
  internal repo; today they are outside collaborators (Leon, Marcos)
- Trials org invite for each trial email (eng)
- Dedicated trial repos instead of branches on `deployments` (Leon, Ita)
