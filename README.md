# zmk-build

Docker-based ZMK firmware builder. Reads `build.yaml` from the current directory in the standard
ZMK GitHub Actions format, so the same file drives a local build and a CI one.

```sh
cd ~/code/zmk/corne42
zmk-build                 # incremental build of every target in build.yaml
zmk-build --pristine      # full rebuild, clearing the CMake cache
```

`zmk-build --help` is the flag reference.

## Why it exists

The upstream answer is to push and let GitHub Actions build, which costs several minutes per
keymap tweak and produces no local artifact to flash. This builds in the same
`zmkfirmware/zmk-build-arm` container CI uses, incrementally, and drops the `.uf2` beside the
config it came from.

## Per-repo workspaces

Each keyboard repo gets its own west workspace under `~/.local/share/zmk/<repo>/`, because
different boards pin different ZMK revisions and a shared workspace makes switching between them a
full re-download. The workspace is keyed on the config directory's basename, and the manifest hash
is recorded next to it — switching repos or editing `config/west.yml` triggers a `west update`
without being asked, which is the case that otherwise fails with a confusing CMake error rather
than a missing-dependency one.

`--clean` removes the current repo's workspace; `--clean-all` removes every one.

## The shared behaviors module

`zmk-build` bind-mounts a sibling `shared/` directory into the container as a Zephyr module, so
edits to shared behaviors take effect on the next build with no push/pull cycle. Override the
location with `ZMK_SHARED_DIR`. The module is deliberately *not* in `west.yml` — pulling it from
GitHub would reintroduce the round trip the local mount exists to remove.

## Requirements

Docker and `yq`, plus a `build.yaml` and a `config/` directory in the working directory.

## Installing

```sh
curl -fsSL https://raw.githubusercontent.com/datapointchris/zmk-build/main/install.sh | bash
```

Clones to `~/.local/share/zmk-build/` and symlinks `bin/zmk-build` into `~/.local/bin/`.
`zmk-build update` moves the checkout to the latest release.

Help output is rendered with the shell formatting library from
[dotfiles](https://github.com/datapointchris/dotfiles), sourced from `~/.local/shell/` when it is
present.
