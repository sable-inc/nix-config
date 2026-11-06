# v1 trial laptop setup

For the office person setting up a Sable trial laptop. Covers:

- **A. New trial laptop:** a brand-new Mac joins the trial pool
- **B. Reset:** an existing trial laptop gets the next candidate. Erase it first (below), then
  follow A
- **C. New-hire Mac:** Iru does steps 2-6 on the **Sable Onboard** blueprint
  (`docs/iru.md`). Without Iru, follow hand steps 1-6 with `--profile onboard` and the
  person's own hostname (`--hostname sable-<name>`). Then run `claude` in Terminal.app and
  paste the new-hire prompt (below the trial prompt). It does not use the trial input files.
  The trial prompt is for trial laptops only. Don't store the FileVault key by hand; Iru
  escrows it

No secrets go in this file, in Slack, or in the repo. Passwords come from the vault. Time each
step in the two-Mac checklist.

## Inputs from the bots

Pick the trial type first. It decides which inputs the bots fill in and what the trial prompt
sets up. Every Mac gets the same install; only the setup after it differs.

| `TRIAL_TYPE` | Who | Setup after the install |
|---|---|---|
| `ds` | deployment strategist | sable-inc/deployments on the trial branch, the trial agent built and linted, `~/TRIAL_PROMPT.md`, sable CLI in the Trials org, SableBrowse |
| `eng` | engineer | the candidate's own repo `sable-inc/<name>` (no deployments access), Anthropic and OpenAI keys in the Keychain, Vercel and Google Cloud sign-in, sable CLI in the Trials org |
| `ae` | account exec, non-technical | apps only: Chrome, Slack and permissions. No GitHub, no repo |

The Onboarding bot produces one file per trial, `trial-inputs.env`, with no secrets in it.
Copy it to `~/trial-inputs.env` on the laptop. Fill in only the lines for the trial's type:

```sh
TRIAL_TYPE="ds"                        # ds | eng | ae
TRIAL_NAME="Jane Doe"
TRIAL_EMAIL="trial1@sable.ai"          # the slot's Google account
TRIAL_SLOT="trial1"                    # hostname becomes sable-trial1
# ds and eng
TRIAL_GITHUB_USER="<GITHUB_USER>"      # the slot's GitHub account
# ds only
TRIAL_BRANCH="trial/jane-doe"
AGENT_PATH="trials/partner-qualifier-jane"
AGENT_ID="agt_..."                     # the trial agent, never a live one
# eng only
TRIAL_REPO="sable-inc/jane-doe"        # new, empty repo the candidate commits to on main
```

For `ds`, also ask the Onboarding bot for the approved trial prompt template and save it as
`~/trial-prompt-template.md`. Do not start the Claude step until the inputs for the type are
present. Keep these per-trial files on the laptop, not in this public repository.

If any value for the chosen type still looks like `<...>`, `agt_...`, `agt_XXXX` or `TODO`,
stop and ask the Onboarding bot. That is what broke the Oct 25 trial.

GitHub access follows the type. The slot's GitHub account gets sable-inc/deployments for
`ds`, only the candidate's own repo for `eng`, and nothing for `ae`. Remove the previous
trial's repo access at reset.

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
7. Open a new Terminal window. Sign in to GitHub as the slot's GitHub account, in the browser.
   When asked "Authenticate Git with your GitHub credentials?", answer **No**.
   Don't use `gh auth setup-git`: nix-config owns `~/.config/git/config`, so it fails with
   "permission denied". The last two lines do the same in `~/.gitconfig` (the `'!'` quoting
   stops zsh from expanding `!$`):
   ```sh
   gh auth login --web --git-protocol https --scopes read:packages
   git config --file ~/.gitconfig --replace-all credential.https://github.com.helper ""
   git config --file ~/.gitconfig --add credential.https://github.com.helper '!'"$(command -v gh) auth git-credential"
   ```
8. In that same Terminal.app window, type `claude` and press Return. Sign in with the slot's
   Google account, then paste the prompt below. Use the `claude` command in Terminal, not the
   Claude desktop app or claude.ai: those run in the cloud and can't touch this Mac

## The prompt (paste into `claude` in Terminal.app as is; it reads `~/trial-inputs.env`)

For `ds` and `eng`, do the GitHub sign-in (step 7 above) first. For `ae`, skip it.

```
You are finishing the setup of a Sable work-trial Mac. Nix and nix-config are already
installed. Log each step with start and end times in ~/setup-log.md. Never print, echo,
log or commit a token, password or API key. You cannot type passwords, keys or complete
browser sign-ins: when a step needs one, tell me exactly what to do and wait.

0. Read ~/trial-inputs.env. TRIAL_TYPE must be ds, eng or ae; otherwise stop. Required for
   every type: TRIAL_NAME, TRIAL_EMAIL, TRIAL_SLOT. Also required for ds: TRIAL_GITHUB_USER,
   TRIAL_BRANCH, AGENT_PATH, AGENT_ID and a non-empty ~/trial-prompt-template.md. For eng:
   TRIAL_GITHUB_USER, TRIAL_REPO (sable-inc/<name>). If a required value is empty or contains
   "<", "XXXX", "TODO" or the agent-id placeholder "agt_...", stop and tell me what is missing.
   Ignore fields the type does not use. Each step below says which types it applies to.
1. All: check `id -un` is sable and `scutil --get LocalHostName` is sable-$TRIAL_SLOT.
   ds, eng: `gh auth status` shows $TRIAL_GITHUB_USER with the read:packages scope, and
   `echo ${NPM_TOKEN:+set}` prints "set". If NPM_TOKEN is empty, open a new login shell.
2. ds, eng: npm registry for @sable-inc (the token stays in the environment, not in the file):
   npm config set @sable-inc:registry https://npm.pkg.github.com
   npm config set '//npm.pkg.github.com/:_authToken' '${NPM_TOKEN}'
3. ds, eng: sable CLI: `bun add -g @sable-inc/toolbelt`, then `sable --version` and
   `sable update`. `sable login --no-browser`: give me the URL it prints and tell me to open
   it and sign in as $TRIAL_EMAIL. Then `sable switch` to the Trials org and confirm
   `sable whoami` shows it. If the org is missing, stop: an engineer must invite $TRIAL_EMAIL.
4. ds: SableBrowse: `npm install -g @sable-inc/sablebrowse && sablebrowse setup`.
5. ds: repo: `gh repo clone sable-inc/deployments ~/deployments`, then
   `git -C ~/deployments checkout $TRIAL_BRANCH`. Confirm ~/deployments/$AGENT_PATH exists
   and its deployment.yaml uses $AGENT_ID. Then `sable build` and `sable lint` in that folder.
   Write ~/TRIAL_PROMPT.md from ~/trial-prompt-template.md, filling in the real $AGENT_PATH
   and $AGENT_ID. No placeholders may remain.
6. eng: repo: `gh repo clone $TRIAL_REPO ~/$(basename $TRIAL_REPO)`. It may be empty; the
   candidate commits to main. Don't clone sable-inc/deployments.
7. eng: API keys. Tell me to run these two lines one at a time and type each key at the
   hidden prompt (the key is stored in the login Keychain, never in a file or the shell):
     security add-generic-password -U -a sable -s ANTHROPIC_API_KEY -w
     security add-generic-password -U -a sable -s OPENAI_API_KEY -w
   Then confirm both exist with `security find-generic-password -s <name> >/dev/null` (never
   with -w). New shells export them as ANTHROPIC_API_KEY and OPENAI_API_KEY.
8. eng: `npm install -g vercel`. Tell me to run `vercel login` and `gcloud auth login`, each
   signing in as $TRIAL_EMAIL in the browser. Wait for me. Confirm `vercel whoami` and that
   `gcloud auth list` shows $TRIAL_EMAIL.
9. eng: tell me to open Cursor and sign in as $TRIAL_EMAIL. Claude Code is this session.
10. All: tell me to open Chrome and sign in as $TRIAL_EMAIL, then open Slack and sign in as
    $TRIAL_EMAIL. ds only: also click "Add to Chrome" on
    https://chromewebstore.google.com/detail/ildldnmbjlkbomodicckikcenamaabfj. Wait for me.
11. All: tell me to open System Settings > Privacy & Security and allow Microphone, Camera and
    Screen & System Audio Recording for Chrome, Zoom and Wispr Flow. Wait for me.
12. All: run `sable-doctor --trial-type $TRIAL_TYPE`, adding
    `--trial-dir ~/deployments/$AGENT_PATH` for ds. Fix every FAIL you can and rerun. End
    with the final sable-doctor output and ~/setup-log.md.
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
   `! gh auth login --web --git-protocol https --scopes read:packages`.
   Tell me to answer No to "Authenticate Git with your GitHub credentials?" and sign in as
   GITHUB_USER in the browser. Then set the credential helper yourself (not gh auth setup-git):
   git config --file ~/.gitconfig --replace-all credential.https://github.com.helper ""
   git config --file ~/.gitconfig --add credential.https://github.com.helper '!'"$(command -v gh) auth git-credential"
   Check `gh auth status` shows GITHUB_USER with read:packages. Your shell started before
   this sign-in, so it has no NPM_TOKEN: begin every command in steps 3-5 with
   `export NPM_TOKEN="$(gh auth token)";` and never print it.
3. npm registry for @sable-inc (the token stays in the environment, not in the file):
   npm config set @sable-inc:registry https://npm.pkg.github.com
   npm config set '//npm.pkg.github.com/:_authToken' '${NPM_TOKEN}'
4. sable CLI: `bun add -g @sable-inc/toolbelt`, then `sable --version` and `sable update`.
   `sable login --no-browser`: give me the URL it prints and tell me to open it and sign
   in as EMAIL. Then `sable switch` to the main Sable org (not Trials) and confirm
   `sable whoami`. If the org is missing, note it in the log and go on.
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
