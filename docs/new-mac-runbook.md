# New Mac runbook (follow word for word)

For whoever sets up a Sable Mac: a trial laptop, a new hire's laptop, or a trial laptop being
reset for the next person. Do the steps in order. Each step says what you should see; if you
see something else, stop and check "If something goes wrong" at the end.

The background (why it works this way) is in `docs/iru.md`. You don't need it to follow this.

## The three rules

1. **Never create an account on the Mac.** Iru creates the `sable` account itself. If the Mac
   asks you to create an account, enrollment failed: stop and see "If something goes wrong".
   (The only exception is Part I, used only when Matthew says so)
2. **Don't go past the Country or Region screen until Iru lists the Mac** (Part D). Turning it
   on is fine; Part C even needs it on. Going further before Iru has it is what breaks setup
3. **Never erase a Mac without Matthew's OK** on that exact Mac (its serial number)

## What you need

- The Mac and its charger. An Ethernet cable and USB-C Ethernet adapter if you have them
  (with Ethernet, the Mac sets itself up with no clicks; without, about four clicks)
- Access to Iru (sable.iru.com) and Apple Business (business.apple.com)
- The `sable` password: the 1Password item **Trial-pw** (ask Matthew for access). Iru
  creates the `sable` account with it. Never write it in a doc, Slack or a ticket
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

These steps follow Apple's guide ("Add devices using Apple Configurator" in the Apple Business
User Guide).

One-time on the iPhone:

1. Install **Apple Configurator** (by Apple) from the App Store. The iPhone needs iOS 16 or
   later
2. Open it, accept the terms, and sign in with a Sable Apple Business account that is allowed
   to add devices (Matthew's is). Approve the two-factor code if asked

For each Mac:

3. Plug the Mac into power (so it doesn't sleep) and plug in Ethernet if you have it. Turn it
   on. If it shows a login screen or desktop instead of the setup screens, it was set up
   before: stop, it needs erasing first (Part H) with Matthew's OK
4. On the Mac, choose the **language**, then stop on **Select Your Country or Region**. Do not
   go past it. If you did: hold the power button until it turns off, turn it on and start
   again
5. Open Apple Configurator on the iPhone and hold it near the Mac. The Mac shows an image to
   scan. Scan it with the iPhone. (If scanning fails: click **Pair Manually** on the Mac and
   type the six-digit code the iPhone shows)
6. If asked about a network, keep the default (the iPhone shares its Wi-Fi), or skip it if
   Ethernet is plugged in
7. Wait until the iPhone says the Mac was added. Then **shut down the Mac** (click **Shut
   Down** on the Mac, or hold the power button until it turns off)
   - If the iPhone shows an error ("There was a problem with this Mac", "Enrollment timed
     out", "Unable to parse message"): don't retry yet. Check step 8 first. It usually worked
8. On business.apple.com go to **Devices > Inventory** and search the serial number (on the
   box, or under the Mac). It should be there. Open it and check which device management
   service it's assigned to. If it isn't **Iru**: **Assign Device Management** > **Iru** >
   **Continue** > **Confirm**. (If the serial isn't there at all, repeat steps 3 to 7)
9. Go to Part D. Don't turn the Mac on again until Part D is done

## Part D. Set it up in Iru (before the Mac goes past Country or Region)

1. sable.iru.com > **Enrollment** (left menu) > tab **Automated Device Enrollment** > choose
   **All**, and search the serial number
2. Not there? Click **Fetch devices**, wait a minute and search again. A Mac you just added in
   Part C can take a while; keep fetching every few minutes. Until it's listed, don't take
   the Mac past Country or Region (this is what went wrong on Nov 6)
3. Click the Mac's name (blue, first column). Its device page opens. At the top right, next
   to the name, click **Edit device details**:
   - **Edit Blueprint** > pick the blueprint from Part A > save
   - **Edit device details** again > **Edit asset tag** > type the asset tag from Part A > save
4. Back in **Enrollment** > **Automated Device Enrollment** > **All**, the Mac's row now shows
   your blueprint under **Enroll to** and your tag under **Asset tag**. Check the
   **ADE Library Item** column says "Sable: Setup Assistant (sable account, skip all screens)"
5. **Enrollment status** says **Awaiting enrollment**. That is correct: Iru is waiting for the
   Mac. It changes to **Enrolled** during Part E

## Part E. At the Mac

1. Plug in power. Plug in Ethernet if you have it
2. Turn it on. (A Mac from Part C: if it went past Country or Region before Part D was done,
   erase it first, Part H.) A reset Mac is already on the first screen after the erase
3. With Ethernet: do nothing, it goes through every screen by itself. Skip to step 5
4. Without Ethernet, click through only these:
   - **Language:** English, click the arrow
   - **Select Your Country or Region:** United States, **Continue**
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
8. Log in as **sable** with the password from 1Password item **Trial-pw**. If a box asks for the password to
   turn on FileVault, type the same password and click **OK**
9. Leave it **logged in, plugged in, lid open**. Don't install or change anything

## Part F. Wait for the install (45 to 90 minutes)

1. In Iru, the Mac shows up in **Devices** within a few minutes. Click its name
2. On the **Status** tab, under **Custom Scripts**, find "Sable Trial: bootstrap (nix-config)"
   or "Sable Onboard: bootstrap (nix-config)". It turns to **Pass** after 45 to 90 minutes on
   a new Mac
3. Done when the bootstrap shows **Pass** and the Mac's name is right. The Dock now shows
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
5. After their first week, move the Mac in Iru to **Default Blueprint** (Devices > the Mac's
   name > **Edit device details** > **Edit Blueprint**). See `docs/iru.md`, "New hires after week one"

## Part H. Reset a trial laptop for the next person

1. The Onboarding bot runs the account reset for the slot (`reset_trial.py`), and only after
   Matthew says go. Nobody may be using the Mac
2. In Iru, open the Mac (Devices > its name) > the **actions** menu at the top right, next to
   the name > **Erase**. Get Matthew's OK on this exact serial first. The blueprint and asset
   tag stay the same
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
| Serial not in Iru after an hour | Apple Business isn't pointing it at Iru | business.apple.com > Devices > Inventory > the Mac > **Assign Device Management** > Iru, then Iru > **Fetch devices** |
| Mac in Iru says "Awaiting enrollment" | Normal before Part E | Nothing; it changes once the Mac reaches Remote Management |
| Wrong name after an hour | Iru's rename didn't apply | Iru > the device > **actions** menu > **Set device name** > `sable-<asset tag>` |
| Bootstrap shows Failed | Something in the install | Leave the Mac on and logged in; send Matthew the device page link. The log is `/var/log/sable-bootstrap.log` on the Mac |
| FileVault shows Error | Usually just early | Check again after the next sync |
| `sable-setup` says "stopped: ..." | A missing input or sign-in | Read the line; it says what's missing. Send it to the Onboarding bot or Matthew |

## Part I. Only if Apple Business can't take the Mac at all

Use this only when Matthew says so (for example a Mac that Configurator can't add). It's the
one case where you create the account yourself:

1. Setup Assistant: create an admin account with the short name exactly `sable` and the
   password from 1Password item **Trial-pw**, then log in
2. System Settings > General > Sharing > set the name to `sable-<asset tag>`
3. Enroll at Iru: Enrollment > tab **Manual Enrollment**, use the blueprint's enrollment
   code there, and follow the link on the Mac. Then in Iru: Devices > the Mac's name > **Edit device details** > **Edit asset tag** >
   type the asset tag from Part A > save
4. Continue at Part F
