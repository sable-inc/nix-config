# v1 trial laptop setup

For the office person setting up a Sable trial laptop. Covers:

- **A. New trial laptop:** a brand-new Mac joins the trial pool
- **B. Reset:** an existing trial laptop gets the next candidate. Erase it first (below), then
  follow A
- **C. New-hire Mac:** follow hand steps 1-6 with `--profile onboard` and the person's own
  hostname (`--hostname sable-<name>`). Then run `claude` in Terminal.app and paste the
  new-hire prompt (below the trial prompt). It does not use the trial input files. The trial
  prompt is for trial laptops only
  The Mac goes on the Default Blueprint in Iru; don't store the FileVault key by hand, Iru
  escrows it

No secrets go in this file, in Slack, or in the repo. Passwords come from the vault. Time each
step in the two-Mac checklist.

## Inputs from the bots

The Onboarding bot produces one file per trial, `trial-inputs.env`, with no secrets in it.
Copy it to `~/trial-inputs.env` on the laptop:

```sh
TRIAL_NAME="Jane Doe"
TRIAL_EMAIL="trial1@sable.ai"          # the slot's Google account
TRIAL_SLOT="trial1"                    # hostname becomes sable-trial1
TRIAL_ROLE="eng"                       # eng | ds | fde | el
TRIAL_GITHUB_USER="<GITHUB_USER>"      # the slot's GitHub account
TRIAL_BRANCH="trials/jane-doe"
AGENT_PATH="trials/partner-qualifier-jane"
AGENT_ID="agt_..."                     # the trial agent, never a live one
```

Ask the Onboarding bot for the approved trial prompt template and save it as
`~/trial-prompt-template.md`. Do not start the Claude step until both input files are present.
Keep these per-trial files on the laptop, not in this public repository.

If any value still looks like `<...>`, `agt_...`, `agt_XXXX` or `TODO`, stop and ask the Onboarding bot.
That is what broke the Oct 25 trial.

## B only: reset first

1. The bots have run the account reset (`reset_trial.py <slot>`) and Matthew has approved it
2. On the Mac: System Settings > General > Transfer or Reset > **Erase All Content and
   Settings**. (Later: Iru remote erase)
3. Continue with A

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
5. Install nix-config with the trial profile (replace `trial1` with the slot):
   ```sh
   nix --extra-experimental-features 'nix-command flakes' run --refresh \
     github:sable-inc/nix-config#init -- --profile trial --hostname sable-trial1
   ```
   **Fresh or erased Macs only.** The next step deletes any app nix-config doesn't list.
6. Build and switch (asks for the admin password; wait for "switched"):
   ```sh
   cd /etc/nix-darwin && nix --extra-experimental-features 'nix-command flakes' run path:.#build-switch
   ```
7. Open a new Terminal window. Sign in to GitHub as the slot's GitHub account, in the browser.
   Don't use `gh auth setup-git`: nix-config owns `~/.config/git/config`, so it fails with
   "permission denied". The last two lines do the same in `~/.gitconfig` (the `'!'` quoting
   stops zsh from expanding `!$`):
   ```sh
   gh auth login --web --git-protocol https --scopes read:packages
   git config --file ~/.gitconfig credential.https://github.com.helper ""
   git config --file ~/.gitconfig --add credential.https://github.com.helper '!'"$(command -v gh) auth git-credential"
   ```
8. In that same Terminal.app window, type `claude` and press Return. Sign in with the slot's
   Google account, then paste the prompt below. Use the `claude` command in Terminal, not the
   Claude desktop app or claude.ai: those run in the cloud and can't touch this Mac

## The prompt (paste into `claude` in Terminal.app as is; it reads `~/trial-inputs.env`)

```
You are finishing the setup of a Sable work-trial Mac. Nix and nix-config are already
installed. Log each step with start and end times in ~/setup-log.md. Never print, echo,
log or commit a token or password. You cannot type passwords or complete browser sign-ins:
when a step needs one, tell me exactly what to do and wait.

0. Read ~/trial-inputs.env and ~/trial-prompt-template.md. If either file is missing or empty,
   or any input value is empty or contains "<", "XXXX", "TODO" or the agent-id placeholder "agt_...",
   stop and tell me what is missing or wrong.
1. Check: `id -un` is sable, `scutil --get LocalHostName` is sable-$TRIAL_SLOT,
   `gh auth status` shows $TRIAL_GITHUB_USER with the read:packages scope, and
   `echo ${NPM_TOKEN:+set}` prints "set". If NPM_TOKEN is empty, open a new login shell.
2. npm registry for @sable-inc (the token stays in the environment, not in the file):
   npm config set @sable-inc:registry https://npm.pkg.github.com
   npm config set '//npm.pkg.github.com/:_authToken' '${NPM_TOKEN}'
3. sable CLI: `bun add -g @sable-inc/toolbelt`, then `sable --version` and `sable update`.
4. `sable login`: tell me to finish the sign-in in the browser as $TRIAL_EMAIL. Then
   `sable switch` to the Trials org and confirm `sable whoami` shows it. If the org is
   missing, stop: an engineer must invite $TRIAL_EMAIL to Trials.
5. SableBrowse: `npm install -g @sable-inc/sablebrowse && sablebrowse setup`.
6. Repo: `gh repo clone sable-inc/deployments ~/deployments`, then
   `git -C ~/deployments checkout $TRIAL_BRANCH`. Confirm ~/deployments/$AGENT_PATH exists
   and its deployment.yaml uses $AGENT_ID. Then `sable build` and `sable lint` in that folder.
7. Write ~/TRIAL_PROMPT.md from ~/trial-prompt-template.md, filling in the real $AGENT_PATH and
   $AGENT_ID. No placeholders may remain.
8. Tell me to: open Chrome, sign in as $TRIAL_EMAIL, and click "Add to Chrome" on
   https://chromewebstore.google.com/detail/ildldnmbjlkbomodicckikcenamaabfj. Wait for me.
9. Tell me to open System Settings > Privacy & Security and allow Microphone, Camera and
   Screen & System Audio Recording for Chrome, Zoom and Wispr Flow. Wait for me.
10. Run `sable-doctor --trial-dir ~/deployments/$AGENT_PATH`. Fix every FAIL you can and
    rerun. End with the final sable-doctor output and ~/setup-log.md.
```

## The new-hire prompt (section C; paste into `claude` in Terminal.app as is)

Have the hire's Google password ready, and their phone if Google asks for a second step.
Their GitHub account is optional: without it, Claude skips the GitHub steps and lists them
for the hire's first day.

```
You are finishing the setup of a new Sable employee's Mac. Nix and nix-config (onboard
profile) are already installed. Log each step with start and end times in ~/setup-log.md.
Never print, echo, log or commit a token or password. You cannot type passwords or complete
browser sign-ins: when a step needs one, tell me exactly what to do and wait.

0. Ask me for the hire's @sable.ai email and their GitHub username (or "not yet"). Use
   those below as EMAIL and GITHUB_USER.
1. Check: `id -un` is sable, `scutil --get LocalHostName` starts with sable-, and
   /etc/nix-darwin/local.nix sets the profile to "onboard". If any check fails, stop.
2. GitHub (skip to step 6 if GITHUB_USER is "not yet"): tell me to type
   `! gh auth login --web --git-protocol https --scopes read:packages` and sign in as
   GITHUB_USER in the browser. Then set the credential helper yourself (not gh auth setup-git):
   git config --file ~/.gitconfig credential.https://github.com.helper ""
   git config --file ~/.gitconfig --add credential.https://github.com.helper '!'"$(command -v gh) auth git-credential"
   Check `gh auth status` shows GITHUB_USER with read:packages. Your shell started before
   this sign-in, so it has no NPM_TOKEN: begin every command in steps 3-5 with
   `export NPM_TOKEN="$(gh auth token)";` and never print it.
3. npm registry for @sable-inc (the token stays in the environment, not in the file):
   npm config set @sable-inc:registry https://npm.pkg.github.com
   npm config set '//npm.pkg.github.com/:_authToken' '${NPM_TOKEN}'
4. sable CLI: `bun add -g @sable-inc/toolbelt`, then `sable --version` and `sable update`.
   `sable login`: tell me to finish the sign-in in the browser as EMAIL. Then `sable switch`
   to the main Sable org (not Trials) and confirm `sable whoami`. If the org is missing,
   note it in the log and go on.
5. SableBrowse: `npm install -g @sable-inc/sablebrowse && sablebrowse setup`.
6. Chrome: tell me to open Chrome, sign in as EMAIL, and click "Add to Chrome" on
   https://chromewebstore.google.com/detail/ildldnmbjlkbomodicckikcenamaabfj. Wait for me.
7. Apps: one at a time, tell me to open each app and sign in as EMAIL (Google sign-in), and
   wait for me after each: Slack, Zoom, Granola, Claude, ChatGPT, Linear, Notion, Wispr Flow, Cursor,
   1Password (needs the hire's 1Password invite).
   If one has no invite yet, note it in the log and go on.
8. Tell me to open System Settings > Privacy & Security and allow Microphone, Camera and
   Screen & System Audio Recording for Chrome, Zoom and Wispr Flow. Wait for me.
9. Run `sable-doctor` (after step 2, as `export NPM_TOKEN="$(gh auth token)"; sable-doctor`).
   Fix every FAIL you can and rerun. If you skipped the GitHub steps,
   the GitHub, NPM_TOKEN, npm, sable and SableBrowse FAILs are expected: don't try to fix
   them. End with the final sable-doctor output, ~/setup-log.md, and a short list of what
   the hire still has to do on day one (steps 2-5 if they were skipped).
```

## After

Paste the `sable-doctor` output and `~/setup-log.md` into the two-Mac checklist. Every step
that needed a human is a gap for v2 (Iru) or the final version (Doppler) to remove.

## Open items (owner in brackets)

- `<GITHUB_USER>` per trial slot, and whether trial users stay org members, which lets them
  read every internal repo (Leon, Marcos)
- Trials org invite for each trial email (eng)
- Dedicated trial repos instead of branches on `deployments` (Leon, Ita)
