# CLAUDE.md — note9-mainline

Standing rules for every session in this repo. The owner does not read or
review code; they read only the end-of-session report. The checks below are
the only review this code gets.

## Goal

Port the Exynos Samsung Galaxy Note 9 (SM-N960F, codename `crownlte`,
Exynos 9810) to a current mainline Linux kernel, as a sibling board of the
upstream Galaxy S9 (`starlte`). Ubuntu Touch on top is a someday goal (one
line in the roadmap, nothing more for now).

Be honest about scope. Upstream `exynos9810.dtsi` has only CPUs, the
interrupt controller, pinctrl, chipid, PMU and timer. There is no clock
controller, serial, I2C, USB, storage (UFS) or PCIe. So touch, USB, Wi-Fi
and storage all need driver work that doesn't exist upstream. Expected hard
blockers: the Shannon modem (calls/SMS/data), the ABOX audio DSP, a real
display driver (simplefb only), suspend, cameras and the S-Pen.

- Milestone 1: the kernel boots, its log shows on screen, and the buttons
  respond.
- Milestone 2: a USB shell.

The one door to the phone is `tools/flash-boot.sh`. Kernel pin: `kernel/PIN`.

Owner's phone: SM-N960F/DS, 6 GB RAM, Knox already tripped. Per-phone facts
and what is still unknown live in `docs/STATUS.md`.

## uniLoader: respect its maintainers

The upstream S9 boot path recommends uniLoader, a small shim between
Samsung's S-Boot and Linux. On 2026-10-03, uniLoader added an `AGENTS.md`
asking AI agents not to read, generate or modify any of its code, and to stop
and tell the user if they object. **Follow that.** Don't open its source,
patch it, change its build config, or file issues/PRs there. Instead,
research and propose a path that doesn't depend on it: booting directly from
S-Boot with a workaround, or an independent minimal shim written from
hardware facts (downstream kernel, cover letter, SheroAbi's docs) without
ever looking at uniLoader's code. The owner chooses between the options. If
neither looks workable, say so.

## Phone safety (absolute)

Only the owner may authorize changes to this section, explicitly, in a
message. Any such change must be mentioned in the session report.

- **One door to the phone.** All writes to the phone go through one script in
  the repo, which the owner runs themself. It may only
  write the BOOT or RECOVERY partition. Before writing, it checks that the
  image exists and fits, and prints its checksum. Claude never runs heimdall,
  odin4, Thor, `adb push`, `dd`, or anything that writes to the phone or any
  block device. Read-only `adb` commands only when the owner says the phone is
  connected.
- **Before anything is flashed:** if Knox isn't already tripped, the owner
  confirms they accept that it trips permanently (Samsung Pay and Secure
  Folder are gone for good). The download-mode screen shows
  `KG STATE: Normal` (not Prenormal or Checking); otherwise flashing fails
  with misleading errors. Personal data is backed up, because unlocking can
  wipe the phone.
- **The one exception to "back up before any flash":** a stock phone has no
  root, so the backup needs TWRP. The procedure flashes official TWRP
  (twrp.me) to RECOVERY only and boots straight into it. In TWRP, choose
  **Keep Read Only**. Never Format Data, Wipe, or "swipe to allow
  modifications". Then pull every partition except system, vendor, odm,
  userdata, cache and hidden, plus the partition table (PIT). Keep sha256
  checksums. Store them in `~/note9-backups` with a second copy on another
  drive. An old EFS backup, if found, is kept as an extra copy, but a fresh
  one is still taken (EFS can change, and an old copy may predate the current
  firmware). If `*#06#` doesn't show a valid IMEI, stop and tell the owner
  before anything else, because the EFS may already be damaged from past ROM
  swaps. TWRP then stays as the tool for flashing test images and restoring
  stock boot.
- **After every test:** restore the stock boot image. As long as mainline
  sits in BOOT, every restart, and plugging in a charger while the phone is
  off, boots mainline. That means no proper charging and a frozen screen that
  can burn into the AMOLED. Tests are short, and the owner stays with the
  phone.
- **Rescue:** the owner may flash full official stock firmware for their model
  from Samsung's servers with HOME_CSC, never CSC (CSC wipes data). Never
  repartition, flash a PIT or erase NAND. Don't take Samsung OTA updates
  mid-project (the bootloader can't be downgraded).
- **Mainline must not be able to write internal storage** until the owner
  explicitly says so. Storage support starts read-only, and EFS-type
  partitions (which hold the IMEI) are never mounted.
- **Power hardware is off-limits until the owner starts that milestone:** no
  charger, fuel gauge, PMIC regulator voltages, CPU frequency above
  bootloader defaults, or thermal changes. Upstream's MAX77705 driver (the S9
  family's charger and USB-C chip; check whether the Note 9 uses it)
  reprograms charging as soon as its node is added. When that milestone
  comes: no battery values from S9 sources, and every value gets a unit
  check. Charging tests are attended, with a USB power meter.
- Whenever the owner must do something physical, give: the exact steps; what
  they should see; exactly what to send back; whether it's destructive; and
  how to undo it. Batch these requests — the owner is the slowest part of the
  loop. Download mode allows one flash per entry.

## Code and checks

- **Every hardware value cites its source** (file and line in the downstream
  kernel or a doc). If there's no source, mark it unknown; don't fill it in
  from memory.
- **Don't fork or vendor the Linux tree.** Upstream is pinned to the newest
  tagged release or -rc, recorded in `kernel/PIN`. Changes live as a patch
  series under `patches/`
  (`git format-patch --zero-commit --no-signature --base=<pin>`), made from a
  working tree outside the repo (`~/note9-work/linux`). Moving to a newer
  kernel is its own change.
- **CI on every push and PR** (GitHub Actions, every action pinned to a
  commit SHA):
  - build the arm64 Image plus the crownlte DTB;
  - run `checkpatch.pl --strict --no-signoff` on the patches;
  - run `make CHECK_DTBS=y exynos/exynos9810-crownlte.dtb`, failing on any
    warning about files we touch (`dtbs_check` alone never fails: it ends in
    `|| true`);
  - run `dt_binding_check` whenever anything under
    `Documentation/devicetree/bindings/` changes;
  - fail if any patch contains a `Signed-off-by:` line.
  The new board compatible goes into `samsung-boards.yaml` in the same series.
- **Never weaken a check quietly.** Any ignored warning, loosened flag or
  skipped check is named in the report with the reason.
- **Review, since the owner won't:** every PR that touches kernel patches,
  device trees, or the phone script gets a fresh subagent review before
  merge. Give the reviewer the *applied* diff (not just the .patch files)
  plus the downstream source paths for each hardware value, and record its
  findings and what was done about each one in the PR. Docs-only PRs skip
  review. Merge when CI is green and review is resolved. Untested boards are
  marked "not verified on my Note 9" in `docs/HARDWARE.md`.
- **Upstream and attribution:** never add `Signed-off-by:` in the owner's
  name. Follow `Documentation/process/coding-assistants.rst` of the pinned
  tree for the `Assisted-by:` tag; if that file is missing, use
  `Assisted-by:` with the model name. Never email any mailing list. Sending
  upstream is the owner's decision later, so keep the series in upstream
  shape: kernel style, YAML bindings, and license headers matching
  neighboring files. No Rust.

## Repo, privacy and this PC

- Public GitHub repo `5wHN28Dg/note9-mainline` (creation authorized). Use
  `gh` only for this repo: no gists, no other repos, no visibility changes,
  no force-pushing main.
- The README opens with a plain banner: AI-written, not reviewed by a human,
  don't flash it on your phone without understanding it.
- Never commit backups, `*.img`/`*.bin` files, raw logs, IMEIs, serial
  numbers or MAC addresses. Owner's logs go in `~/note9-logs` (outside the
  repo); docs and PRs quote only cleaned-up excerpts.
- No `sudo` and no system package changes. List what the owner should
  install; use a Python venv for things like dtschema.

## Docs and reports

- Keep docs short: `README.md`, `docs/STATUS.md` (where things stand, what's
  next, what's blocked on the owner), `docs/ROADMAP.md`, and
  `docs/HARDWARE.md`. HARDWARE.md has one row per subsystem, with columns for
  upstream status, verified on my Note 9 (yes/no), source, and notes.
- Reports are short and in plain language, with no jargon the owner would
  have to look up. Always separate what was tested on the phone from what is
  assumed. End with exactly what the owner should do next and where to put
  any files.
- When a subsystem is blocked, record why and move on to other work. Don't
  stop just because something is hard, but don't write speculative code
  either.
