# New Mac runbook (follow word for word)

For whoever sets up a Sable Mac: a trial laptop, a new hire's laptop, or a trial laptop being
reset for the next person. Do the steps in order. Each step says what you should see; if you
see something else, stop and check "If something goes wrong" at the end.

The background (why it works this way) is in `docs/iru.md`. You don't need it to follow this.

## The three rules

1. **Never create an account on the Mac.** Iru creates the `sable` account itself. If the Mac
   asks you to create an account, enrollment failed: stop and see "If something goes wrong"
2. **Don't turn the Mac on (or go past the first screens) until Iru has it.** Part B tells you
   how to check
3. **Never erase a Mac without Matthew's OK** on that exact Mac (its serial number)

## What you need

- The Mac and its charger. An Ethernet cable and USB-C Ethernet adapter if you have them
  (with Ethernet, the Mac sets itself up with no clicks; without, about four clicks)
- Access to Iru (sable.iru.com) and Apple Business (business.apple.com)
- The `sable` password from 1Password (Sable's vault, the Mac setup item). Iru sets it
- Retail Macs only: an iPhone, see Part C

## Part A. Decide the name and type

| The Mac is for | Iru blueprint | Asset tag | The Mac will be called |
|:--|:--|:--|:--|
| A trial laptop | **Sable Trial** | the slot: `trial1`, `trial2`, `trial3` (or the next free number) | `sable-trial1` |
| A new hire | **Sable Onboard** | their first name, lowercase: `jane`. If a Mac already has that name: first initial + last name, `jdoe` | `sable-jane` |

Lowercase letters, digits and `-` only. No spaces, no capitals.

## Part B. Where did the Mac come from?

**Bought from Apple's business store, an Apple Store business team, or a reseller linked to
Sable's Apple Business account** (we gave them Sable's Apple Customer Number): go to Part D.
It's already in Apple Business.

**Bought anywhere else (Best Buy, Amazon, a regular Apple Store purchase, someone's old Mac):**
do Part C first.

Not sure? Go to business.apple.com > Devices, search the serial number (on the box, or on the
bottom of the Mac). Found it: Part D. Not found: Part C.

## Part C. Retail Mac: add it to Apple Business with an iPhone (once per Mac)

One-time on the iPhone:

1. Install **Apple Configurator** (by Apple) from the App Store. It needs iOS 15 or later
2. Open it, accept the terms, and sign in with a Sable Apple Business account that has the
   Administrator or Device Enrollment Manager role (Matthew's works). Approve the two-factor
   code if asked

For each Mac:

3. Plug the Mac into power and turn it on. If it shows anything other than the first setup
   screen (it was set up before), stop: it needs erasing first (Part H) and Matthew's OK
4. On the Mac, pick the **language** and stop on the next screen (**Country or Region**). Do
   not go past Country or Region. If you did, hold the power button until it turns off, turn
   it on again and start over
5. Open Apple Configurator on the iPhone and hold the iPhone near the Mac. The Mac shows
   **Assign this Mac to Your Organization** with a swirl image
6. Scan the swirl with the iPhone. (If scanning fails: tap **Pair Manually** on the iPhone,
   click **Pair Manually** on the Mac, and type the 6-digit code)
7. If the iPhone asks for a network, pick the office Wi-Fi (skip if Ethernet is plugged in).
   Sign in again if asked
8. Wait for the Mac to say **This Mac has been assigned to Sable**. It then shows **Restart**
   and **Shut Down**. **Click neither. Leave the Mac exactly like this**
   - If the iPhone shows an error ("There was a problem with this Mac", "Enrollment timed
     out", "Unable to parse message"): don't retry yet. Go to business.apple.com > Devices
     and search the serial. If it's there, it worked; carry on. Only retry if it isn't there
9. In business.apple.com > Devices, open the Mac (search the serial). Click **Edit MDM
   Server**, choose **Assign to the following MDM**, pick **Iru**, click **Continue**. (New
   Macs from Configurator land in "Devices Added by Apple Configurator 2", which is not Iru)
10. Go to Part D, then come back to the Mac and click **Restart** (step 8's screen)

## Part D. Set it up in Iru (before the Mac goes any further)

1. sable.iru.com > **Enrollment** > **Automated Device Enrollment**. Search the serial
   number. If it isn't there yet, wait 10 minutes and refresh; Iru checks Apple regularly.
   It can take up to an hour for a Mac you just assigned in Part C
2. On that row, set **Enroll to** (the blueprint) and the **Asset tag** from Part A
3. The row says **Awaiting enrollment**. That is correct: Iru is waiting for the Mac

## Part E. At the Mac

1. Plug in power. Plug in Ethernet if you have it
2. Turn it on (or click **Restart** if you came from Part C). If it's a reset Mac, it's
   already on the first screen after the erase
3. With Ethernet: do nothing, it goes through every screen by itself. Skip to step 5
4. Without Ethernet, click through only these:
   - **Language:** English, click the arrow
   - **Country or Region:** United States, **Continue**
   - **Accessibility:** **Not Now** (if shown)
   - **Wi-Fi:** pick the office network, type its password, **Continue**
5. **Remote Management** appears ("Sable can automatically configure your computer"). Click
   **Continue**. This is the screen that proves it worked. If you never see it, and instead
   see "Create a Computer Account", stop: see "If something goes wrong"
6. Every other screen (Apple Account, Location Services, Screen Time, Siri, FileVault and so
   on) is skipped by Iru. If one still appears, click **Continue**, **Not Now** or
   **Set Up Later**. Never create an account, never sign in to an Apple Account
7. The login screen shows the Mac's name (`sable-trial1` or `sable-jane`) and the user
   **sable**. If the name is still something like "MacBook Pro", that's fine for now; Iru
   renames it within the hour
8. Log in as **sable** with the password from 1Password. If a box asks for the password to
   turn on FileVault, type the same password and click **OK**
9. Leave it **logged in, plugged in, lid open**. Don't install or change anything

## Part F. Wait for the install (45 to 90 minutes)

1. In Iru, the Mac moves from Enrollment to **Devices** within a few minutes. Open it
2. **Library Items** shows "Sable ...: bootstrap" running, then **Passed**. This takes 45 to
   90 minutes on a new Mac
3. Done when the bootstrap shows **Passed** and the Mac's name is right. The Dock now shows
   Chrome, Slack, Orca, Cursor and the rest
4. FileVault may show **Error** in Iru for the first hour. Check again after the next sync
   before telling anyone

The Mac is ready. Hand it over, or put it away until the trial or start date.

## Part G. The person's first morning

**Trial laptop** (the Onboarding bot has already written the slot's list):

1. Log in as `sable`. Open **Terminal** (Spotlight: Cmd-Space, type Terminal, Return). It must
   be the app called Terminal, not Ghostty or Orca
2. Type `sable-setup` and press Return
3. Follow what it prints. Lines starting `>>` are things a person does: sign in to GitHub as
   the slot's account in the browser that opens; when asked **"Authenticate Git with your
   GitHub credentials?"** answer **No**; sign in to Sable with the slot's Google account; click
   **Add to Chrome** for SableBrowse
4. It ends with a PASS/FAIL list. All PASS: done

**New hire** (Sable's own accounts are ready: Google, Slack, GitHub in sable-inc, 1Password
invite):

1. They change the password first: System Settings > Users & Groups > `sable` > Change
   Password. Their new password also unlocks the disk at startup; they keep it to themselves
2. They sign in to each app with their @sable.ai Google account: Chrome, Slack, Zoom, Granola,
   Claude, ChatGPT, Linear, Notion, Loom, Wispr Flow, Cursor, 1Password
3. If anyone else ever signed in to GitHub on this Mac, run `gh auth logout` in Terminal first
4. In Terminal, they run `sable-setup` and follow it as above (with their own GitHub account)
5. After their first week, move the Mac in Iru to **Default Blueprint** (device page >
   Blueprint). See `docs/iru.md`, "New hires after week one"

## Part H. Reset a trial laptop for the next person

1. The Onboarding bot runs the account reset for the slot (`reset_trial.py`), and only after
   Matthew says go. Nobody may be using the Mac
2. In Iru, open the Mac > **Actions** (or the device menu) > **Erase**. Get Matthew's OK on
   this exact serial first. Keep the same blueprint and asset tag
3. The Mac restarts to the first setup screen. Go to Part E

Erasing a Mac by hand instead (when Iru can't): if it's set up, System Settings > General >
Transfer or Reset > **Erase All Content and Settings**. If it's stuck in setup, hold the power
button until **Loading startup options** appears, click **Options**, then **Continue**, and in
the menu bar choose **Recovery Assistant > Erase Mac**.

## If something goes wrong

| You see | It means | Do this |
|:--|:--|:--|
| "Create a Computer Account" during setup | Iru didn't have the Mac yet when it asked | Don't create it. Check Part D shows the serial with the right blueprint, then erase by hand (Part H, last paragraph, with Matthew's OK) and go to Part E |
| No Remote Management screen | Same | Same |
| Configurator errors on the iPhone | Usually it worked anyway | Check business.apple.com > Devices for the serial before retrying |
| Serial not in Iru after an hour | Apple Business isn't pointing it at Iru | business.apple.com > Devices > the Mac > Edit MDM Server > Iru |
| Mac in Iru says "Awaiting enrollment" | Normal before Part E | Nothing; it changes once the Mac reaches Remote Management |
| Wrong name after an hour | Iru's rename didn't apply | Iru > the device's menu > **Set device name** > `sable-<asset tag>` |
| Bootstrap shows Failed | Something in the install | Leave the Mac on and logged in; send Matthew the device page link. The log is `/var/log/sable-bootstrap.log` on the Mac |
| FileVault shows Error | Usually just early | Check again after the next sync |
| `sable-setup` says "stopped: ..." | A missing input or sign-in | Read the line; it says what's missing. Send it to the Onboarding bot or Matthew |
