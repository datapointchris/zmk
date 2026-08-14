#!/usr/bin/env bash
set -euo pipefail

# Overridable so a fork can install itself, and so this script can be exercised
# against the commit under test rather than against whatever is on main.
REPO_URL="${ZMK_REPO_URL:-https://github.com/datapointchris/zmk.git}"
INSTALL_DIR="${ZMK_INSTALL_DIR:-$HOME/.local/share/zmk}"
BIN_DIR="${ZMK_BIN_DIR:-$HOME/.local/bin}"
WORKSPACE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/zmk"
BASHSELFUPDATE_REPO_URL="${BASHSELFUPDATE_REPO_URL:-https://github.com/datapointchris/bashselfupdate.git}"
BASHSELFUPDATE_INSTALL_URL="https://github.com/datapointchris/bashselfupdate"

info() { echo "[info] $*"; }
success() { echo "[ok] $*"; }
error() { echo "[error] $*" >&2; }

if ! command -v git &>/dev/null; then
  error "git is required but not installed"
  exit 1
fi

mkdir -p "$BIN_DIR"

# This path held multi-gigabyte west workspaces before the tool was renamed from
# zmk-build, and the clone below removes whatever non-repo it finds here. Each
# workspace is a rebuildable checkout, so it belongs in cache anyway; both paths
# are under $HOME, which makes the move a rename rather than a re-download.
migrate_legacy_workspaces() {
  [[ -d "$INSTALL_DIR" ]] || return 0
  [[ ! -d "$INSTALL_DIR/.git" ]] || return 0

  local workspace moved=0
  for workspace in "$INSTALL_DIR"/*/; do
    [[ -f "$workspace/.west/config" ]] || continue
    mkdir -p "$WORKSPACE_DIR"
    mv "$workspace" "$WORKSPACE_DIR/"
    moved=$((moved + 1))
  done

  if [[ "$moved" -gt 0 ]]; then
    success "Moved $moved build workspace(s) to $WORKSPACE_DIR"
  fi
}

# Cloned with git rather than piped from its install script over curl, because
# that is the one transport this installer already requires and the two are not
# equally available: a locked-down network can allow github.com over git while
# blocking raw.githubusercontent.com.
install_bashselfupdate() {
  local dir="${XDG_LIB_HOME:-$HOME/.local/lib}/bashselfupdate"

  if [[ ! -d "$dir/.git" ]]; then
    rm -rf "$dir"
    mkdir -p "$(dirname "$dir")"
    git clone --quiet "$BASHSELFUPDATE_REPO_URL" "$dir" || return 1
  fi

  source "$dir/lib/version.sh"
  source "$dir/lib/source.sh"
  source "$dir/lib/update.sh"

  bashselfupdate_checkout_latest "$dir" >/dev/null
}

# Not fatal. zmk builds firmware without it — only `zmk update` needs it, and
# that degrades to an actionable error.
info "Installing bashselfupdate..."
if install_bashselfupdate; then
  success "bashselfupdate installed"
else
  error "Could not install bashselfupdate — 'zmk update' will not work until it is"
  error "  Install it separately: $BASHSELFUPDATE_INSTALL_URL"
fi

migrate_legacy_workspaces

if [[ ! -d "$INSTALL_DIR/.git" ]]; then
  info "Installing zmk..."
  if [[ -d "$INSTALL_DIR" ]]; then
    rm -rf "$INSTALL_DIR"
  fi
  if ! git clone --quiet "$REPO_URL" "$INSTALL_DIR"; then
    error "Failed to clone zmk repository"
    exit 1
  fi
  success "zmk cloned to $INSTALL_DIR"
fi

# checkout_latest rather than update: a fresh clone lands on main, which between
# releases is ahead of the newest tag, and update declines a checkout that is not
# sitting on one. It leaves the checkout on a branch and is idempotent, which is
# what makes re-running this script mean what everyone assumes it means.
if declare -F bashselfupdate_checkout_latest &>/dev/null; then
  if ! tag=$(bashselfupdate_checkout_latest "$INSTALL_DIR"); then
    error "Failed to move zmk to its latest release"
    exit 1
  fi
  success "zmk at $tag"
else
  # Reachable only when bashselfupdate could not be installed above, which is
  # also a machine where `zmk update` was never able to leave a detached HEAD —
  # so pull still works here.
  if ! git -C "$INSTALL_DIR" pull --quiet; then
    error "Failed to update zmk"
    exit 1
  fi
  success "zmk updated from $(git -C "$INSTALL_DIR" rev-parse --abbrev-ref HEAD)"
fi

ln -sf "$INSTALL_DIR/bin/zmk" "$BIN_DIR/zmk"
success "zmk installed: $BIN_DIR/zmk"

# The tool was called zmk-build until v2. Left in place, its symlink still
# resolves and its clone still answers `zmk-build update`, so a machine would
# carry two tools that disagree about what the verbs are.
if [[ -L "$BIN_DIR/zmk-build" ]]; then
  rm -f "$BIN_DIR/zmk-build"
  success "Removed the zmk-build symlink it replaced"
fi
if [[ -d "$HOME/.local/share/zmk-build/.git" ]]; then
  rm -rf "$HOME/.local/share/zmk-build"
  success "Removed the zmk-build clone it replaced"
fi

for dependency in docker yq; do
  if ! command -v "$dependency" &>/dev/null; then
    error "$dependency is not installed — zmk needs it to build firmware"
  fi
done

if command -v zmk &>/dev/null; then
  info "Run 'zmk --help' to get started"
else
  info "Add $BIN_DIR to your PATH, then run 'zmk --help'"
fi
