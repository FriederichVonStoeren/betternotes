# Installing betternotes on the iPad (no Mac needed)

betternotes is not in the App Store. You install it with **SideStore**, an app that signs
other apps with your free Apple ID, directly on the iPad. The only time you need the laptop is
the very first install of SideStore itself. For that we use **iloader** on Fedora.

Button names in iloader and SideStore change between versions. If something here does not
match what you see, the official guide wins: <https://docs.sidestore.io>.

## What a free Apple ID allows

- An installed app works for **7 days**, then it must be refreshed (one tap in SideStore).
- At most **3** sideloaded apps at a time. SideStore is one of them.
- At most **10 new app IDs per 7 days**.
- Your notes are not deleted when the app expires. They come back after a refresh. Do not
  delete the app from the home screen while it is expired, that would delete its data.

## Your Apple ID

iloader and SideStore need your Apple ID and password to ask Apple for a signing certificate.
They talk to Apple directly; nothing goes to this project. If you prefer, create a second
Apple ID just for sideloading at <https://account.apple.com>. Never write the Apple ID or
password into this repository or into a chat.

## Part 1: on the Fedora laptop (once)

1. Open a terminal and install the USB helper and iloader:

   ```bash
   sudo dnf install usbmuxd
   sudo dnf install https://github.com/nab138/iloader/releases/latest/download/iloader-linux-x86_64.rpm
   ```

2. Connect the iPad with a USB-C cable and unlock it.
3. The iPad asks "Trust This Computer?". Tap **Trust** and enter the iPad passcode.
4. Start **iloader** from the application menu.
5. Sign in with your Apple ID. Apple sends a 6-digit code to one of your devices; type it in.
6. Choose **Install SideStore** and wait until it says it is done.
   iloader also places the "pairing file" that SideStore needs. You do not have to do that by hand.

## Part 2: on the iPad (once)

1. **Trust yourself as developer**: Settings > General > VPN & Device Management >
   tap your Apple ID under "Developer App" > **Trust**.
2. **Developer Mode**: Settings > Privacy & Security > Developer Mode > switch on >
   **Restart**. After the restart confirm with **Turn On**.
   (This entry only appears after a sideloaded app has been installed.)
3. Install **LocalDevVPN** from the App Store and switch it on inside that app.
   It is not a real VPN: it lets SideStore talk to the iPad itself. No data leaves the device.
4. Open **SideStore** and sign in with the same Apple ID (Settings tab).

## Part 3: install betternotes

1. On the iPad, open Safari and go to
   <https://github.com/FriederichVonStoeren/betternotes/releases>.
2. Under the newest release, open **Assets** and tap **betternotes.ipa**. Tap **Download**.
3. Open SideStore > **My Apps** > tap **+** (top left) > pick `betternotes.ipa` from Downloads.
4. Wait for the install. LocalDevVPN must be on.
5. Open betternotes from the home screen.

Later, updates will come through a SideStore "source" so that step 1 to 3 become one tap.
That is not set up yet.

## Every week: refresh

Open SideStore with LocalDevVPN switched on > My Apps > **Refresh All**. Do this before the
7 days are over. SideStore shows the remaining days next to each app.

## If something fails

| What you see | Try |
|---|---|
| iloader does not see the iPad | Unlock the iPad, tap Trust again, try another cable; `sudo systemctl restart usbmuxd` |
| "Unable to Verify App" / app does not open | Part 2 step 1 (trust) and step 2 (Developer Mode) |
| SideStore install or refresh hangs | Is LocalDevVPN on? Is the iPad on Wi-Fi? |
| Pairing file error after an iPadOS update | Connect to the laptop again, open iloader, let it place the pairing file again |
| "Maximum number of apps" | You have 3 sideloaded apps; remove one in SideStore |

iloader logs: `~/.local/share/me.nabdev.iloader/logs/`. Before pasting a log anywhere, check
that it does not contain your Apple ID.

## What to report back after the install test

- [ ] iloader installed and saw the iPad
- [ ] SideStore installed and opens
- [ ] betternotes.ipa installed through SideStore
- [ ] betternotes opens and shows "The install worked." / "Installation hat funktioniert."
- [ ] Which step, if any, did not match this guide (so the guide can be fixed)
