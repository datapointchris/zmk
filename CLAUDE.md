# zmk-build - Claude Code Instructions

Universal rules live in `~/.claude/CLAUDE.md`, shell conventions in `standards/shell.md`.
Neither is restated here.

## Dev vs installed

This repo is the source; `~/.local/share/zmk-build/` is the installed clone that `~/.local/bin/zmk-build`
points at. Never edit the installed copy — change it here, push, and run `zmk-build update`, which
moves the installed checkout to the newest tag. The installed clone sits on a tag, not on `main`.

## Building firmware is not a unit test

Every code path past `check_requirements` runs Docker and takes minutes, so the fast checks are
`shellcheck`, `shfmt -d`, and `zmk-build --help`. A real verification is a build in an actual
keyboard repo:

```sh
cd ~/code/zmk/corne42 && zmk-build
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

`ZMK_WORKSPACE` defaults to `~/.local/share/zmk/$(basename $PWD)`, so two keyboard repos with the
same directory name would share a workspace and thrash `west update` between them. That has not
happened, and is the thing to remember before renaming a config repo.
