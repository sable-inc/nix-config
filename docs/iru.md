# Trial and new-hire Macs in Iru (v2)

Iru runs the install that `docs/claude-setup-v1.md` does by hand, for trial Macs and for
new-hire Macs. With Ethernet, Setup Assistant shows no screens; on Wi-Fi it asks only for
language, country and Wi-Fi. Iru creates the `sable` admin account, then installs the Command Line Tools, Nix and this repo with the trial
or onboard profile, and reports `sable-doctor` daily. Sign-ins (GitHub, Google, Claude) need
the person's password and phone, so they stay with that person, guided by the Claude prompt.

| blueprint | for | bootstrap profile |
|:--|:--|:--|
| **Sable Onboard** | new hires | `onboard` |
| **Sable Trial** | trial laptops | `trial` |
| **Default Blueprint** | every other Mac, including those enrolled before Nov 2026 | none (security settings only) |

Automated Device Enrollment is connected (Apple Business, Oct 29, 2026): a Mac that is in
Apple Business enrolls into Iru during Setup Assistant. A Mac not already in Apple Business
can be added with Apple Configurator for iPhone (see the end of this doc) or enrolled by hand.

## One-time setup in the Iru console

Sable Onboard and Sable Trial each get these items (done Nov 5, 2026):

| library item | setting | file |
|:--|:--|:--|
| Device Name | name and hostname `sable-` + Asset tag | |
| Custom Profile | upload; installs the SableBrowse and 1Password Chrome extensions | `mdm/chrome-sablebrowse.mobileconfig` |
| Custom Script | run once per device; paste the file with `profile` set for the blueprint | `mdm/iru-bootstrap.sh` |
| Custom Script | run daily; paste the file | `mdm/iru-doctor.sh` |
| Automated Device Enrollment | Mac: "Skip all screens", auto-advance (needs Ethernet), primary account "Skip", provision local admin `sable` (password in the vault), made the MDM-enabled user | |

The bootstrap is one library item per blueprint, because `profile` differs. The other items
are shared. To make another blueprint like these, duplicate Sable Trial in Iru, then swap its
bootstrap item for one with the right `profile`.

`iru-bootstrap.sh` downloads `target/aarch64-darwin/bootstrap` from `main`. To test a branch,
set `ref` in the pasted script to it, and set it back to `main` afterwards.

All three blueprints carry Sable's security settings (disk encryption, screen lock, OS
updates); add the same to any new blueprint, such as **Sable Trial (non-technical)**. The
details are kept privately. Iru escrows FileVault keys, so don't store them by hand.

Or by API: an Iru token with these write permissions lets a script create the same items.
Grant only what is listed, and add the matching read permissions:

- Blueprints: create, update, assign library item
- Library: create and update custom scripts and custom profiles
- Devices: update (asset tag, blueprint), set name, erase

New Macs in Apple Business default to Default Blueprint. Set each new Mac's blueprint in
Iru (Enrollment, the "Enroll to" column, or the device page) before it is turned on.

The enrollment item creates `sable` itself, so nobody makes an account. Someone still logs
in as `sable` once so the bootstrap can finish. First tested on trial3 (Nov 6, 2026):
enrollment, rename, FileVault and the bootstrap all passed.

Profile-based Device Enrollment also supervises Macs on macOS 11 or later; Apple Business
is not required for supervision. For a hand-enrolled Mac, verify that Iru applies the Device
Name item. If it does not, set the local hostname to `sable-<slot>` in System Settings >
General > Sharing before retrying the bootstrap, which requires the `sable-` prefix.

## Each Mac (new or erased)

In Apple Business:

1. In Iru, set the asset tag and the blueprint before the Mac is turned on. Trial: the slot
   (`trial1`) and **Sable Trial**, so the Mac becomes `sable-trial1`. New hire: their first
   name (`jane`) and **Sable Onboard**, so the Mac becomes `sable-jane`. If a Mac already has
   that name, use the first initial and last name (`jdoe`).
   Use lowercase letters, digits and `-` only. The name shows on the Mac's login and lock
   screen
2. Erase it (from Iru if it's enrolled, otherwise System Settings > General > Transfer or
   Reset > Erase All Content and Settings) and turn it on. With Ethernet, Setup Assistant
   needs nothing; on Wi-Fi, pick the language, country and network. The Mac enrolls into Iru
   and Iru creates `sable`. Log in as `sable` (the password is in the vault) and leave it
   logged in and plugged in. The bootstrap waits for that login before its last step

Not in Apple Business:

1. Setup Assistant: create `sable` as above and log in. Set the name to `sable-<slot>` in
   System Settings > General > Sharing
2. Enroll by hand at the Iru enrollment portal with the blueprint's code (Iru > Enrollment >
   Manual Enrollment; the code is not kept in this repo). Then set the asset tag in Iru

Then, either way:

3. Wait until the bootstrap script passes on the device page (45 to 90 minutes on a fresh Mac; the first run downloads and builds everything)
4. Trial: once the Onboarding bot has written the slot's list to `sable-inc/trial-inputs`, run
   `sable-setup` in Terminal.app and follow step 7 of `docs/claude-setup-v1.md`.
   New hire: on their first day, they sign in to their apps and run `sable-setup`
   (`docs/claude-setup-v1.md`, section C)

The bootstrap log is also on the Mac at `/var/log/sable-bootstrap.log`.

The bootstrap temporarily grants `sable` passwordless sudo. Normal exits and handled signals
remove the grant. If cleanup cannot run (SIGKILL or reboot), the grant stops authorizing new
sudo commands two hours after creation. Commands already running are not stopped. Rerun the
bootstrap if later steps need sudo after the grant expires.

## Non-technical trials

EL, AE and Marketing trials use a normal Sable Trial Mac with no GitHub or other access in
`trial-inputs.env`. `sable-setup` signs in to GitHub only to read the list, then signs out;
they only sign in to the apps. A lighter blueprint without Nix (Iru Auto
Apps instead of the bootstrap) is possible but not built.

## Reset

In this order, and finish each step before the next:

1. Revoke the trialer's access (the bots), and delete the slot's folder in
   `sable-inc/trial-inputs`. This rotates the slot's passwords and signs out
   every session, including on the Mac. Never run it while someone is setting up or signing
   in at a trial Mac (ask whoever is at the Mac): they would have to sign in to everything again
2. Check the slot's account is on Sable's Claude team with a seat that includes Claude Code.
   Without one, `claude` asks for Pro or Max at sign-in
3. Erase the Mac from Iru. It returns to Setup Assistant; start again at step 1

## Adding a Mac to Apple Business

Macs from Apple or a linked reseller appear in Apple Business on their own and go to Iru
(the default for Macs). For a Mac bought elsewhere: erase it, then at Setup Assistant add it
with Apple Configurator on an iPhone. For 30 days after that, the person at the Mac can still
remove it from management.

Apple Business does not send Configurator-added Macs to Iru. It assigns them to "Devices Added
by Apple Configurator 2", and they skip Remote Management at Setup Assistant. In Apple Business,
open each one and change its device management service to Iru, and check that the Mac shows
in Iru's Automated Device Enrollment list. Do this before continuing Setup Assistant. If the
Mac gets past Setup Assistant without the Remote Management screen, erase it and start again.
