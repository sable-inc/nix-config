# Trial Macs in Iru (v2)

Iru runs the install that `docs/claude-setup-v1.md` does by hand. A person still creates the
`sable` account at Setup Assistant. Iru then installs the Command Line Tools, Nix and this
repo with the trial profile, and reports `sable-doctor` daily. Sign-ins (GitHub, Google,
Claude) stay by hand.

Automated Device Enrollment is connected (Apple Business, Oct 29, 2026): a Mac that is in
Apple Business enrolls into Iru during Setup Assistant. A Mac not already in Apple Business
can be added with Apple Configurator for iPhone (see the end of this doc) or enrolled by hand.

## One-time setup in the Iru console

Create a blueprint named **Sable Trial** and add:

| library item | setting | file |
|:--|:--|:--|
| Device Name | name and hostname `sable-` + Asset tag | |
| Custom Profile | upload | `mdm/chrome-sablebrowse.mobileconfig` |
| Custom Script | run once per device; paste the file | `mdm/iru-bootstrap.sh` |
| Custom Script | run daily; paste the file | `mdm/iru-doctor.sh` |

`iru-bootstrap.sh` downloads `target/aarch64-darwin/bootstrap` from `main`. Until the profile
and bootstrap changes merge, set `ref` in the pasted script to the branch under test.

Or by API: an Iru token with these write permissions lets a script create the same items.
Grant only what is listed, and add the matching read permissions:

- Blueprints: create, update, assign library item
- Library: create and update custom scripts and custom profiles
- Devices: update (asset tag, blueprint), set name, erase

In Iru's Automated Device Enrollment settings, set the blueprint for trial Macs to
**Sable Trial** (today the default is "Default Blueprint"). Iru's enrollment settings can
also create the `sable` account and skip Setup Assistant panes; untested here.

Profile-based Device Enrollment also supervises Macs on macOS 11 or later; Apple Business
is not required for supervision. For a hand-enrolled Mac, verify that Iru applies the Device
Name item. If it does not, set the local hostname to `sable-<slot>` in System Settings >
General > Sharing before retrying the bootstrap, which requires the `sable-` prefix.

## Each Mac (new or erased)

In Apple Business:

1. In Iru, set the asset tag to the slot (`trial1`) and the blueprint to **Sable Trial**; the
   Mac becomes `sable-trial1`
2. Setup Assistant: the Mac enrolls into Iru on its own. Create the admin account with short
   name `sable` (the password is in the vault) and log in. The bootstrap waits for `sable` to
   be logged in before its last step

Not in Apple Business:

1. Setup Assistant: create `sable` as above and log in. Set the name to `sable-<slot>` in
   System Settings > General > Sharing
2. Enroll by hand at the Iru enrollment portal with the Sable Trial code (Iru > Enrollment >
   Manual Enrollment; the code is not kept in this repo). Then set the asset tag in Iru

Then, either way:

3. Wait until the bootstrap script passes on the device page (about 20 minutes on a fresh Mac)
4. Put `~/trial-inputs.env` and the approved `~/trial-prompt-template.md` on the Mac as
   described in `docs/claude-setup-v1.md`, then continue at step 7 (GitHub sign-in)

The bootstrap log is also on the Mac at `/var/log/sable-bootstrap.log`.

The bootstrap temporarily grants `sable` passwordless sudo. Normal exits and handled signals
remove the grant. If cleanup cannot run (SIGKILL or reboot), the grant stops authorizing new
sudo commands two hours after creation. Commands already running are not stopped. Rerun the
bootstrap if later steps need sudo after the grant expires.

## Non-technical trials

No Nix and no Vercel. Create a second blueprint, **Sable Trial (non-technical)**, with the
Device Name item, the Chrome profile, and Iru Auto Apps instead of the bootstrap: Google
Chrome, Slack, Zoom, Claude, Cursor, ChatGPT, Notion, Granola and Wispr Flow. Skip
`docs/claude-setup-v1.md`; the trialer signs in with Google.

## Reset

Revoke the trialer's access first (the bots), then erase the Mac from Iru. It returns to
Setup Assistant; start again at step 1.

## Adding a Mac to Apple Business

Macs from Apple or a linked reseller appear in Apple Business on their own and go to Iru
(the default for Macs). For a Mac bought elsewhere: erase it, then at Setup Assistant add it
with Apple Configurator on an iPhone. For 30 days after that, the person at the Mac can still
remove it from management.
