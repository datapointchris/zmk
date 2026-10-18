# zmk

Builds, draws, checks and flashes a ZMK keyboard config from inside its repo. The build runs in the
container ZMK's GitHub Actions workflow uses. It reads the same `build.yaml`, so one file
drives the local build and the CI one.

zmk holds no keymap. Each keyboard is a config repo: a ZMK user config holding `build.yaml`,
`config/` and a drawing of its layers. zmk acts on whichever config repo is the current directory.
Behaviors that several keyboards share live in a Zephyr module checked out beside them as `shared/`,
and every build mounts it. The build, the drawing and the flash are zmk's. The keymap and the targets
belong to the config repo, and the shared behaviors belong to the module.

`zmk --help` is the command reference.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/datapointchris/zmk/main/install.sh | bash
uv tool install keymap-drawer                                        # `keymap`, which draw renders with
uv tool install keymap-align                                         # keymap-align, which align runs
zmk update                                                           # later: move to the newest release
```

The installer clones zmk to `~/.local/share/zmk/` at its newest release tag and links `bin/zmk` into
`~/.local/bin/`. `ZMK_INSTALL_DIR` and `ZMK_BIN_DIR` move either one. It also clones bashselfupdate
into `~/.local/lib/`, which only `zmk update` needs. Re-running the installer moves the clone to the
newest release, as `zmk update` does. `zmk update` refuses in a development clone, which sits on no
release tag.

The installer replaces a directory at the install path that is not a git clone. Any west workspace
inside it moves to `~/.cache/zmk/` first, since a workspace is several gigabytes. It also removes a
`zmk-build` symlink and clone, this tool's former name, so a machine never carries two tools that
disagree about the verbs.

zmk also needs these on `PATH`:

- `git` clones zmk and bashselfupdate, and the installer stops without it.
- Docker, runnable without sudo, builds the firmware.
- mikefarah's `yq` reads `build.yaml` and the drawing.
- `python3` resolves the installed symlink and compares the drawing to the keymap.
- `fzf` is the flash picker.
- `udisksctl`, from udisks2, mounts the bootloader on Linux.

Help and status lines take their style from a shell formatting library at
`~/.local/shell/formatting.sh` where one is installed. Without it zmk prints the same lines
unstyled.

## Starting from scratch

```bash
cd ~/keyboards                                                  # the directory holding your config repo
git clone https://github.com/datapointchris/zmk-shared shared   # the module every build mounts, found as ../shared
cd corne                                                        # your config repo, beside shared/
zmk check                                                       # each missing file or tool, each drifted key; exit 1 on any
zmk build                                                       # first run fetches ZMK and Zephyr; one .uf2 per target lands here
zmk flash                                                       # pick halves with fzf, then double-tap reset on each
```

`build` refuses without `build.yaml`, `config/` and a `zephyr/module.yml` in `../shared`. Any
directory holding a Zephyr module passes, and `ZMK_SHARED_DIR` names one somewhere else.
[zmk-shared](https://github.com/datapointchris/zmk-shared) is the module zmk was written beside.

`check` asks for more than `build` does. It also wants the files `align` and `draw` read, so on a
stock ZMK config it names `keymap_align.toml`, `keymap_drawer.config.yaml` and the drawing's source
as missing. [zmk-config-corne42](https://github.com/datapointchris/zmk-config-corne42) is a config
repo that passes every check.

The first build initializes a west workspace in `~/.cache/zmk/corne/`: several gigabytes of ZMK and
Zephyr checkout. Every build after it is incremental.

`flash` writes nothing until the volume that appeared holds `INFO_UF2.TXT`, the file that marks a
UF2 bootloader.

## A config repo names itself once, by naming its keymap

`config/corne.keymap` makes `corne` the stem, and every derived path comes from it.
`corne_keymap.yaml` is the drawing's source and `corne_keymap.svg` is the drawing. zmk keeps no
config file of its own. The rest of a config repo has fixed names:

| File | What reads it |
| --- | --- |
| `build.yaml` | `build`, which takes each entry of its `include` list as a target, and `flash` |
| `config/<stem>.keymap` | the build; `align`, which rewrites it in place; and `check` |
| `config/west.yml` | west, which resolves ZMK and every module the build fetches through it |
| `keymap_align.toml` | keymap-align, for the keyboard's physical shape |
| `keymap_drawer.config.yaml` | keymap-drawer, when `draw` renders |
| `<stem>_keymap.yaml` | `draw` and `check`; written by hand |

`align`, `draw` and `check` refuse when `config/` holds no keymap or more than one. Two keymaps would
make every derived path ambiguous.

A target's firmware is named for its `artifact-name`, else the first word of its `shield`, else its
`board`. That name is what `zmk flash` takes. `check` warns on a target with no `artifact-name`.

## `build` — ZMK's CI build, run where the config is

```bash
zmk build              # every target in build.yaml, in parallel
zmk build --pristine   # after a cmake-args change: a clean build directory, the same workspace
zmk build --update     # run west update first, though the manifest has not changed
zmk sync               # align, then draw, then build
zmk clean              # this repo's firmware and workspace; the next build fetches it all again
```

ZMK's own answer is to push and let GitHub Actions build. That is a push and a wait for every keymap
change, and the firmware lands in a zip on GitHub. zmk runs the image that workflow runs,
`zmkfirmware/zmk-build-arm:stable`, against the same `build.yaml`. Each `.uf2` lands beside
`build.yaml`.

Targets build in parallel, one container each. A failed target prints the last twenty lines of its
log and keeps the whole log in `/tmp`. When every target succeeds the logs are removed.

Each config repo gets its own west workspace under `~/.cache/zmk/` (`$XDG_CACHE_HOME/zmk/` where
that is set), named for the repo's directory. Config repos can pin different ZMK revisions in
`config/west.yml`. One shared workspace would re-run `west update` at every switch between them. A
workspace is a rebuildable checkout, so it lives in cache rather than data.

A hash of `config/west.yml` sits beside the workspace. A changed manifest runs `west update` without
being asked, since nothing else announces the change.

The workspace is keyed on the directory's name alone. Two config repos with the same directory name
share one workspace and thrash `west update` between them. `ZMK_WORKSPACE` gives one of them its own
path.

`--pristine` is the fix for a bad CMake flag. A `-D` flag stays in the build's `CMakeCache.txt`
after it leaves `cmake-args`, so the build after any flag change needs `--pristine`. It clears the
build directory and fetches nothing. `zmk clean` removes the whole workspace, so the next build pays
the full fetch again. `zmk clean --all` removes every workspace.

## `shared/` — the working tree in a local build, the pushed branch in CI

zmk mounts the sibling `shared/` read-only into the container and passes it to ZMK as
`ZMK_EXTRA_MODULES`. A local build compiles the module's working tree, so an edit there reaches the
next build with no commit. Where `config/west.yml` also declares the module as `zmk-shared`, the
mount covers west's checkout of it at the same path, and the working tree still wins.

CI has no mount. It resolves the module through `config/west.yml`. A config repo that declares the
module at its `main` branch builds in CI against what is pushed. **Push the shared repo before the
config repo**, or the config repo's CI run compiles against a `main` that lacks the change.

## `check` — the only thing that sees a drawing fall behind its keymap

```bash
zmk align   # rewrite the keymap in place, its bindings in columns by physical position
zmk draw    # render <stem>_keymap.yaml to <stem>_keymap.svg
zmk check   # every file, tool and drawn key against the keymap; exit 1 on an error
```

The drawing's source is written by hand, with labels the keymap does not carry: `ZOOM` where the
keymap says `&tmux_zoom`. `draw` renders that file and never reads the keymap. A key changed in the
keymap does not reach the drawing, and the SVG still renders cleanly. `zmk sync` runs `align`,
`draw` and `build`, never `check`.

`check` reads each keymap layer from its `display-name` and the `bindings` after it. It pairs each
layer with the drawing's `layers` entry in the same position, and reports four kinds of drift:

- a different number of layers, or a different number of keys in one layer;
- a key whose class differs, where `&none` is drawn as `""`, `&trans` as `▽`, any other binding as
  neither, and a `{type: held}` cell matches anything;
- a key that holds a layer open, drawn with a hold legend other than that layer's name;
- a layer whose drawing marks none of the keys that open it as `{type: held}`.

The keys that hold a layer open are `&mo`, `&magic`, ZMK's stock `&lt`, and the `ltl` and `ltr`
layer-taps with their `t` and `b` variants, as zmk-shared defines them. `&tog` is left out on
purpose: a toggle is pressed and released, so it has no hold legend and its label is free
text. Labels are not compared otherwise, since the drawing chooses its own.

`check` also confirms every file in the table above, that `build.yaml` parses and has targets, that
the shared module is present, and that `docker`, `yq`, `python3`, `keymap-align` and `keymap` are
installed. A missing SVG and a target without `artifact-name` are warnings, which exit 0. Any error
exits 1.

## `flash` — whatever volume appears next, confirmed as a bootloader before the write

```bash
zmk flash                          # pick halves with fzf, then flash each in turn
zmk flash corne_left corne_right   # these, in order, with no picker
```

A UF2 bootloader appears as a removable filesystem after a double-tap of the reset button. Volume
labels differ by board: nice!nano says `NICENANO`, and other boards say something else. So `flash`
matches no label. It snapshots what is already attached, waits for whatever appears, and confirms
`INFO_UF2.TXT` before writing. `ZMK_FLASH_TIMEOUT` sets how many seconds it waits for each half.

The board reboots the instant the file lands. The closing sync fails with an I/O error and `cp` exits
non-zero. That is the flash succeeding, and `flash` treats it as one.

Linux mounts the volume through `udisks2`, which D-Bus starts on demand, so it needs no daemon and
no sudo. macOS mounts it under `/Volumes` on its own.

## Where it writes

- The config repo: each `.uf2` from `build`, `<stem>_keymap.svg` from `draw`, and the keymap itself,
  rewritten in place by `align`.
- `~/.cache/zmk/<repo>/`: the west workspace, with each target's build directory inside it.
- `/tmp/zmk-build-*.log`: a target's build log, kept only when that target fails.
- The bootloader volume, during `flash`.
- `~/.local/share/zmk/`, `~/.local/bin/zmk` and `~/.local/lib/bashselfupdate/`: the install.
  `zmk update` moves the first to the newest release.
