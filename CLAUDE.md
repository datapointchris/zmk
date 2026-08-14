# zmk - Claude Code Instructions

Universal rules live in `~/.claude/CLAUDE.md`, shell conventions in `standards/shell.md`.
Neither is restated here.

## Dev vs installed

This repo is the source; `~/.local/share/zmk/` is the installed clone that `~/.local/bin/zmk`
points at. Never edit the installed copy — change it here, push, and run `zmk update`, which moves
the installed checkout to the newest tag. The installed clone sits on a tag, not on `main`.

## Building firmware is not a unit test

Every code path past `check_requirements` runs Docker and takes minutes, so the fast checks are
`shellcheck`, `shfmt -d`, `zmk --help` and `zmk check` in a real config repo. A real verification
is a build:

```sh
cd ~/code/zmk/corne42 && zmk build
```

`~/code/zmk/shared` is the Zephyr module bind-mounted into the container, and `~/code/zmk/corne42`,
`glove80` and `piantor` are the configs that consume it.

## Two flag traps, both learned the hard way

**`ZMK_EXTRA_MODULES`, never `ZEPHYR_EXTRA_MODULES`.** ZMK sets the latter itself to register its
own board definitions, and passing it as a CLI `-D` clobbers that list. It surfaces as
`No board named 'nice_nano' found`, which points nowhere near the cause.

**A bad `-D` persists in `CMakeCache.txt`.** After changing any CMake flag, the next build needs
`--pristine` to clear it, or the fixed script still fails the same way. `--pristine` only wipes the
build directory; it does not re-download the west workspace.

## The workspace cache is keyed on a basename

`ZMK_WORKSPACE` defaults to `~/.cache/zmk/$(basename $PWD)`, so two keyboard repos with the same
directory name would share a workspace and thrash `west update` between them. That has not
happened, and is the thing to remember before renaming a config repo.

It lived at `~/.local/share/zmk/` until v2, which is now where the tool's own clone installs. Both
the tool and the installer move a workspace they find at the old path rather than letting the clone
remove several gigabytes of west checkout.

## `draw` renders, it does not parse

`keymap parse` cannot read these keymaps. The conditional-layers node holds layer defines rather
than integers and there is no flag to give the parser the shared include path, so it fails with
`invalid literal for int() with base 10: 'WM'`. The drawer YAML is therefore hand-written and
`draw` only renders it to SVG.

That is what `check` is for. A layer added to a keymap does not reach the drawing, and the SVG
renders cleanly one layer short with nothing reporting it. The layer-count comparison is the check
that earns the verb; the rest is file and tool presence.

If a future keymap-drawer gains an include-path flag, `draw` should parse and `check`'s drift
comparison becomes redundant.

## Flashing is the one verb with no test

It needs real hardware in bootloader mode, so nothing in CI exercises `cmd_flash`. The parts worth
re-reading before changing it: detection is a set difference against what was already attached
rather than a label match, because labels differ per board; `INFO_UF2.TXT` is what confirms the new
volume is a bootloader; and `cp` is expected to fail, since the board reboots mid-write.
