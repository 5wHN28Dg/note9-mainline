# Hardware

Phone: Samsung Galaxy Note 9, SM-N960F (Exynos 9810, `crownlte`).
Nothing here is verified on my Note 9 yet.

`DS` = downstream kernel `LineageOS/android_kernel_samsung_universal9810`,
branch `lineage-17.1`, commit `5a2dd7d6f3a0`; `DT` = `DS/arch/arm64/boot/dts/exynos`.
`UP` = upstream Linux at the pin in `kernel/PIN`.
`SA` = SheroAbi/galaxy-s9plus-mainline-linux docs (Galaxy S9+, not the Note 9).

| Subsystem | Upstream status | Verified on my Note 9 | Source | Notes |
|---|---|---|---|---|
| CPUs, interrupts, timer, pinctrl | in UP `exynos9810.dtsi` | no | UP | Timer frequency is fixed in DT because S-Boot doesn't program it |
| 26 MHz oscillator | board sets it, like S9 | no | `DS/drivers/clk/samsung/clk-exynos9810.c:32` | |
| Buttons (Power, Vol+, Vol−, Bixby) | our DTS (gpio-keys) | no | `DT/exynos9810-crownlte-input-common.dtsi:15-65` | Power gpa2-4, Vol− gpa0-4, Vol+ gpa0-3, Bixby gpa0-6; all active-low (flags 0xf), no internal pull (pud 0). Bixby mapped to `KEY_ASSISTANT` |
| Screen (simplefb) | our DTS | no | address/format: UP `exynos9810-starlte.dts:24-31` (S9) | 1440x2960 (`DT/exynos9810-display-lcd.dtsi:379-416`). **0xcc000000 is the S9's address, assumed for the Note 9.** S-Boot doesn't set the display "trigger" (DECON_F at 0x16030000, `DT/exynos9810.dtsi:1054-1057`), so nothing reaches the panel until something writes it (boot-path question) |
| RAM | our DTS: 3 banks below 4 GiB, ~1.9 GiB | no | bank layout: UP `exynos9810-starlte.dts:67-72` (S9); RAM from 0x80000000: `DS/include/linux/sec_debug.h:21` | **Real 6 GB layout unknown** (S-Boot inserts it; no memory node in DS). Read `/proc/iomem` from TWRP |
| Reserved memory | our DTS | no | `DT/exynos9810-rmem.dtsi:21-129`, `DT/exynos9810-rmem_crown.dtsi:27-31`, `DT/exynos9810-crownlte_common.dtsi:26-29`; 0x80000000+0x2000 and 0x90000000+0x179c000 from SA `docs/02-building.md` (**S9+ values, assumed for the Note 9**) | Also kept out: rkp/tima regions (disabled downstream). Unknown: buffers placed via the S-Boot command line (`sec_debug.base=` etc., `DS/drivers/staging/samsung/sec_debug.c:942`) |
| Watchdogs | not upstream for 9810 | no | 0x10050000 / 0x10060000 (SA docs, ntdevlabs/exynos9810-woa bootshim.S) | S-Boot leaves them running: the phone may reset after some seconds. Boot-path question |
| Clocks (CMU) | **missing** | no | | Needed for nearly everything else |
| Serial (debug UART) | missing | no | `DT/exynos9810.dtsi:2939-2950` (0x10440000) | Only reachable through the MAX77705 "JIG UART" mode (`DS/drivers/muic/max77705-muic.c:129-161`); pins on the USB-C plug unknown |
| USB | missing | no | | Milestone 2 |
| Storage (UFS) | missing | no | | Read-only first; EFS never mounted |
| PMIC | S2MPS18 (+ S2MPB02/03, S2DOS05) | no | `DT/exynos9810-crownlte_common.dtsi:499-512` | Off-limits until the power milestone |
| Charger / USB-C / fuel gauge | MAX77705 (same as S9) | no | `DT/exynos9810-crownlte_eur_open_26.dts:17` | Off-limits; upstream driver reprograms charging on probe. Disabled in our config |
| Touchscreen | missing | no | sec_ts Y771: `DS/arch/arm64/configs/exynos9810-crownlte_defconfig:2069` | Needs I2C + clocks |
| S-Pen | missing | no | Wacom W9018, I2C 0x56: `DT/exynos9810-crownlte-input-common.dtsi:161-197` | Hard blocker |
| Wi-Fi / BT | missing | no | BCM4361 over PCIe: `DS/arch/arm64/configs/exynos9810-crownlte_defconfig:1923,1936` | Needs PCIe; firmware never committed |
| Modem, audio (ABOX), cameras, suspend, real display | missing | no | | Hard blockers |
