# Status

Last updated: 2026-10-06 (session 1).

## Where things stand

- Kernel pinned to **v7.3-rc6**. CI builds the arm64 kernel and the Note 9
  device tree and runs all checks.
- Device tree draft (`patches/`): screen (simplefb), buttons, RAM
  below 4 GiB, reserved firmware regions. **Not verified on my Note 9.** It
  cannot boot yet: there is no way to start it from S-Boot until the boot
  path is chosen (below).
- Phone tools: `tools/flash-boot.sh` (the one door, BOOT/RECOVERY only),
  `tools/backup-partitions.sh` and `tools/collect-info.sh` (read-only).
- Nothing has run on the phone yet.

## Owner's phone

| Fact | Value |
|---|---|
| Model | SM-N960F/DS, 6 GB RAM |
| Firmware build | **unknown** (newest Iraq/MID build per Samsung's server: N960FXXU9FVK1, not confirmed on the phone) |
| OEM LOCK | ON (relocked) |
| KG STATE / FRP LOCK | **not checked** |
| Knox | tripped |
| IMEIs | both valid (`*#06#`, owner) |
| Old EFS backup | maybe; not counted on |

## Boot path: owner must choose

S-Boot (Samsung's bootloader) won't start a mainline kernel as-is. It loads
the kernel on top of its own data (mainline's header says "offset 0"), it
doesn't start the screen's refresh (the "DECON trigger"), and it leaves two
watchdog timers running that reset the phone after a while. The upstream S9
uses uniLoader to fix that; we don't use it (its maintainers asked AI agents
not to).

- **A. Straight from S-Boot.** Patch the kernel header's offset after
  building, add the reserved memory, plus a small non-upstream kernel patch
  that pokes the display trigger. Watchdogs: unsolved without a 9810 clock
  driver, so the phone may reset after some seconds. Reported to "fail early"
  on the S9+, cause unknown.
- **B. Our own tiny shim (recommended).** About 100–200 lines of assembly in
  this repo, written only from public hardware facts (downstream kernel
  registers, watchdog addresses): stop the watchdogs, set the display
  trigger, move the kernel and device tree to a safe address, jump. The
  kernel stays unmodified and upstream-shaped.
- **C. U-Boot as a second stage.** Most upstream-friendly long-term, but
  there's no 9810 port; a big job. Not for milestone 1.

Both A and B also need a Samsung-style boot image (Android header + Samsung
"DTBH" device-tree table); that tool is next.

Also recommended: **run tests from RECOVERY, not BOOT.** Normal start-up and
charging then stay stock, so a stuck test needs only a forced restart.

## Blocked on the owner

1. Trip 1 in `docs/PROCEDURES.md` (KG/FRP check, firmware build, PIT).
2. Choose boot path A, B or C, and BOOT vs RECOVERY for tests.
3. Trips 2–3 (unlock, TWRP, backup, `collect-info.sh`). The RAM layout,
   screen address and firmware buffers in the device tree must be checked
   against `collect-info.sh` output **before the first boot test**.

## Next (agent)

- Boot image packer (Android header + DTBH) from public format facts.
- The shim, if B is chosen.
- Update the device tree from the phone's real RAM map and command line.
