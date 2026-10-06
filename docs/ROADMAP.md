# Roadmap

Each step needs the one before. "Upstream" means current mainline Linux.

1. **Boot, log on screen, buttons work.** Device tree with memory,
   simplefb and buttons. Needs: a working boot path from S-Boot (owner
   chooses, see STATUS.md), a backup, and short attended tests.
2. **USB shell.** Needs a clock controller (CMU) driver for Exynos 9810, the
   USB PHY and DWC3 glue, and USB gadget. None of this is upstream for 9810.
   Large driver work.
3. **Storage, read-only.** UFS on 9810 needs clocks, the UFS PHY and Exynos
   UFS glue for this SoC. Starts read-only; EFS-type partitions are never
   mounted.
4. **Touchscreen.** Needs I2C/USI (and clocks) plus the touch controller
   driver.
5. **Power: battery, charging.** Off-limits until the owner starts it.
   Needs PMIC and charger/fuel-gauge drivers, owner-attended tests with a USB
   power meter, no S9 battery values.
6. **Wi-Fi.** Needs PCIe for 9810 and the Broadcom chip's firmware (from the
   owner's own phone, never committed).
7. **Expected hard blockers, no plan yet:** modem (calls/SMS/data), audio
   DSP (ABOX), real display driver, suspend, cameras, S-Pen.

Someday: Ubuntu Touch on top.
