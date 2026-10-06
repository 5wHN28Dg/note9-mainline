> **Warning: AI-written, not reviewed by a human.** Everything here was written
> by an AI coding agent. No person has reviewed the code. Do not flash anything
> from this repo onto your phone unless you understand what it does.

# note9-mainline

An attempt to run a current mainline Linux kernel on the Samsung Galaxy Note 9
(Exynos, SM-N960F, codename `crownlte`, Exynos 9810). It is a sibling board of
the Galaxy S9 (`starlte`), which upstream Linux already supports in a basic way.

This is early work. Nothing here has been tested on a phone yet. See
[docs/STATUS.md](docs/STATUS.md).

## Layout

| Path | What |
|---|---|
| `kernel/PIN` | The upstream Linux tag we build on |
| `patches/` | Our kernel changes, as a patch series in upstream shape |
| `kernel/crownlte.config` | Kernel options added on top of arm64 `defconfig` |
| `kernel/init.c` | A tiny test program that prints button presses |
| `scripts/` | Fetch, patch, build and check (used locally and by CI) |
| `tools/flash-boot.sh` | The only script that writes to a phone (BOOT/RECOVERY only) |
| `docs/` | Status, roadmap, hardware table, phone procedures |

## Build

Needs an aarch64 cross compiler, plus `flex`, `bison`, `bc`, `libssl-dev`, and
a Python venv with `dtschema` and `yamllint` for the checks.

```sh
scripts/prepare-tree.sh ~/note9-work/ci-linux      # pinned kernel + patches
CROSS_COMPILE=aarch64-linux-gnu- scripts/build.sh ~/note9-work/ci-linux ~/note9-work/out
scripts/check.sh ~/note9-work/ci-linux ~/note9-work/out
```

## License

Kernel patches and `kernel/init.c` are GPL-2.0 (like the files they touch,
see each file's SPDX header). Everything else in this repo is GPL-3.0, see
[LICENSE](LICENSE).
