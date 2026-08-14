# zmk

Builds, draws, checks and flashes a ZMK keyboard config. Reads `build.yaml` from the current
directory in the standard ZMK GitHub Actions format, so the same file drives a local build and a
CI one.

```sh
cd ~/code/zmk/corne42
zmk check                 # what is missing or has drifted
zmk sync                  # align, then draw, then build every target
zmk flash                 # pick halves with fzf, then write each
```

`zmk --help` is the command reference.

## Why it exists

The upstream answer is to push and let GitHub Actions build, which costs several minutes per
keymap tweak and produces no local artifact to flash. This builds in the same
`zmkfirmware/zmk-build-arm` container CI uses, incrementally, and drops the `.uf2` beside the
config it came from.

## Every path derives from the keymap

A config repo names itself once, by naming its keymap. `config/corne.keymap` gives
`corne_keymap.yaml` and `corne_keymap.svg`; nothing else has to be configured and there is no
per-repo config file. `zmk check` enforces that there is exactly one `config/*.keymap`, since two
would make every derived path ambiguous.

## `check` exists for one failure that is otherwise silent

The drawer YAML is hand-written. `keymap parse` cannot read these keymaps — the conditional-layers
node holds layer defines rather than integers, and there is no flag to hand the parser the shared
include path, so it dies on `invalid literal for int() with base 10`.

That means a layer added to the keymap never reaches the drawing, and the SVG still renders
cleanly one layer short. `zmk check` compares the layer count on both sides and names the
difference. It also verifies the required files, the `build.yaml` targets, the shared module and
the four tools.

## Per-repo workspaces

Each keyboard repo gets its own west workspace under `~/.cache/zmk/<repo>/`, because different
boards pin different ZMK revisions and a shared workspace makes switching between them a full
re-download. A workspace is a rebuildable checkout, which is why it is cache rather than data.

The workspace is keyed on the config directory's basename, and the manifest hash is recorded next
to it — switching repos or editing `config/west.yml` triggers a `west update` without being asked,
which is the case that otherwise fails with a confusing CMake error rather than a
missing-dependency one.

`zmk clean` removes this repo's workspace and its firmware; `zmk clean --all` removes every
workspace.

## The shared behaviors module

`zmk` bind-mounts a sibling `shared/` directory into the container as a Zephyr module and passes it
as `ZMK_EXTRA_MODULES`, which ZMK prepends ahead of the west-fetched copy. So a shared edit takes
effect on the next local build with no commit. Override the location with `ZMK_SHARED_DIR`.

CI has no bind-mount and resolves the module through `config/west.yml`, which declares it from
GitHub at `main`. **Push the shared repo before the board repo**, or the board's CI run compiles
against a `main` that does not have the change yet.

## Flashing

A UF2 bootloader appears as a removable filesystem after a double-tap of the reset button. Rather
than matching a volume label — nice!nano says `NICENANO`, other boards say something else — `zmk
flash` snapshots what is already attached, waits for whatever is new, and confirms `INFO_UF2.TXT`
before writing.

The board reboots the instant the file lands, so the closing sync fails with an I/O error and `cp`
exits non-zero. That is the flash succeeding, and it is treated as such.

Linux needs `udisks2`, which is D-Bus activated, so no daemon and no sudo. macOS mounts under
`/Volumes` on its own.

## Requirements

Docker, `yq`, `keymap-align` and `keymap` (keymap-drawer), plus a `build.yaml` and a `config/`
directory in the working directory. `fzf` for the flash picker.

## Installing

```sh
curl -fsSL https://raw.githubusercontent.com/datapointchris/zmk/main/install.sh | bash
```

Clones to `~/.local/share/zmk/` and symlinks `bin/zmk` into `~/.local/bin/`. `zmk update` moves the
checkout to the latest release.

The tool was called `zmk-build` until v2, and the installer removes that symlink and clone if it
finds them. It also moves any west workspace it finds at `~/.local/share/zmk/` into the cache
first, because that path is now where the tool itself installs.

Help output is rendered with the shell formatting library from
[dotfiles](https://github.com/datapointchris/dotfiles), sourced from `~/.local/shell/` when it is
present.
