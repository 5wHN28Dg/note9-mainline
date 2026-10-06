# Phone procedures

Only the owner does these. Each trip says what is destructive and how to undo it.
Key combos (Note 9):

- **Download mode:** phone off, USB cable plugged into the PC, hold
  **Bixby + Volume Down + Power**, then press **Volume Up** at the warning.
- **Recovery:** from off or a forced restart, hold **Bixby + Volume Up + Power**.
- **Forced restart:** hold **Volume Down + Power** (about 7–10 s).
- Download mode allows **one flash per entry**.

## 0. Install on the PC (no phone needed)

- **Heimdall, Grimler's fork** (newer bootloaders need it; Ubuntu's
  `heimdall-flash` 1.4.2 may not work): https://git.sr.ht/~grimler/Heimdall.
  Build it with `cmake` plus `libusb-1.0-0-dev` (see its README), and put the
  binary on your PATH. Without root you need its udev rule. Check:
  `heimdall version`.
- `lz4` (to unpack stock firmware), `gpg` (to check TWRP), `adb` (already
  installed).

## Trip 1: look, don't touch (not destructive)

1. `*#06#` in the dialer: both IMEIs still valid? (You said yes. If not:
   **stop and tell me**.)
2. Settings > About phone > Software information: write down **Build number**
   and **Baseband version**.
3. If a Google account is on the phone, **remove it** (Settings > Accounts).
   Otherwise the wipe in trip 2 leaves the phone FRP-locked to that account.
4. Download mode (combo above). Read the screen: `OEM LOCK`, `KG STATE`,
   `FRP LOCK`, and anything containing `RMM`.
5. Still in download mode, save the partition table (reads only):
   `heimdall download-pit --output ~/note9-backups/note9.pit --no-reboot`
   (make the folder first: `mkdir -p ~/note9-backups`). Then
   `heimdall print-pit --file ~/note9-backups/note9.pit > ~/note9-logs/pit.txt`.
6. Leave download mode: forced restart (Volume Down + Power).

**You should see:** `KG STATE: Normal`. If it says `Prenormal` or `Checking`:
**stop**. Keep the phone on Wi-Fi with a SIM for some days, then look again.
Flashing fails until it is `Normal`.

**Send back:** the build number, baseband version, and the OEM LOCK /
KG STATE / FRP LOCK lines (typed out, or a photo with the serial covered).
Leave `pit.txt` in `~/note9-logs`.

## Trip 2: unlock the bootloader (DESTRUCTIVE: wipes the phone)

Only if trip 1 showed `KG STATE: Normal`.

1. Settings > Developer options > **OEM unlocking** on. (Developer options:
   tap Build number 7 times.) If the switch is missing, stop and tell me.
2. Download mode. On the warning screen, **long-press Volume Up** and confirm.
   The phone wipes and restarts.
3. Finish setup quickly **with internet** (Wi-Fi), skip the Google account.
   Enable Developer options again; OEM unlocking should be on and greyed out.
4. Download mode again: check `OEM LOCK: OFF` and `KG STATE: Normal`. Then
   forced restart.

**Undo:** none needed. Never re-lock the bootloader while anything unofficial
is on the phone (that can brick it). Re-locking is only safe on full stock.
**Send back:** the OEM LOCK and KG STATE lines after step 4.

## Trip 3: TWRP into RECOVERY, then back up (destructive only to RECOVERY)

1. In a browser, download `twrp-3.7.0_9-0-crownlte.img` and its `.asc` from
   https://twrp.me/samsung/samsunggalaxynote9.html into `~/note9-work/twrp/`.
   Check it:
   ```sh
   cd ~/note9-work/twrp
   sha256sum twrp-3.7.0_9-0-crownlte.img
   # must be 7ea8960e5c8df86f07c6d6b3f5b4ab6fa1c533cafd46cd4e2578d32867f154af
   gpg --import twrp-public.asc     # TeamWin key 9570 7D42 307C 9D41 D09B F709 1D85 97D7 891A 43DF
   gpg --verify twrp-3.7.0_9-0-crownlte.img.asc twrp-3.7.0_9-0-crownlte.img
   ```
2. Download mode, then from the repo folder:
   ```sh
   tools/flash-boot.sh recovery ~/note9-work/twrp/twrp-3.7.0_9-0-crownlte.img \
     --expect-sha256 7ea8960e5c8df86f07c6d6b3f5b4ab6fa1c533cafd46cd4e2578d32867f154af
   ```
   Type `RECOVERY` when asked.
3. **Go straight to TWRP:** hold Volume Down + Power; the moment the screen
   goes black, switch to **Bixby + Volume Up + Power**. If Android boots
   instead, stock may put its own recovery back: just repeat steps 2–3.
4. In TWRP: if it asks for a password, tap **Cancel** (this TWRP can't
   decrypt data; we don't need it). At the system-modification prompt choose
   **Keep Read Only**. **Never** Format Data, Wipe, or "swipe to allow
   modifications".
5. On the PC, from the repo folder:
   ```sh
   adb devices                       # should list the phone as "recovery"
   tools/backup-partitions.sh ~/note9-backups/note9.pit
   tools/collect-info.sh
   ```
   The backup takes a while (it reads everything except system, vendor, odm,
   userdata, cache and hidden, and checks each one twice).
6. Copy the new `~/note9-backups/<date>` folder to a second drive and run
   `sha256sum -c SHA256SUMS` inside the copy. If you find the old EFS backup,
   copy it in as `~/note9-backups/old-efs/` too (keep it, don't use it).
7. Reboot to Android from TWRP (Reboot > System). Check `*#06#` again.

**Undo:** to put stock recovery back, flash `recovery.img` from the stock
firmware (step "Rescue" below) with `tools/flash-boot.sh recovery`.
**Send back:** "done", plus the folder names. I read `~/note9-logs` myself.

## After every mainline test: restore stock boot

If mainline was flashed to BOOT: forced restart, then at once hold
**Bixby + Volume Down + Power** for download mode, then:

```sh
B=~/note9-backups/<date>
tools/flash-boot.sh boot $B/BOOT.img --reboot \
  --expect-sha256 $(awk '$2 == "BOOT.img" {print $1}' $B/SHA256SUMS)
```

The phone should start Android normally. Until this is done, don't charge it
while off and don't leave it alone (frozen screen can burn into the AMOLED).

## Rescue

Flash full official stock firmware for SM-N960F (Iraq: CSC `MID`, inside the
`OXM` package) from Samsung's servers, with **HOME_CSC, never CSC** (CSC wipes
data). Never repartition, never flash a PIT, never erase NAND. Don't take OTA
updates during the project. Single images (boot.img, recovery.img) come from
the AP tar: `tar xf AP_*.tar.md5 boot.img.lz4 && lz4 -d boot.img.lz4`.
