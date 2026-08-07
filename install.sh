#!/usr/bin/env bash
set -euo pipefail

# Overridable so a fork can install itself, and so this script can be exercised
# against the commit under test rather than against whatever is on main.
REPO_URL="${ZMK_BUILD_REPO_URL:-https://github.com/datapointchris/zmk-build.git}"
INSTALL_DIR="${ZMK_BUILD_INSTALL_DIR:-$HOME/.local/share/zmk-build}"
BIN_DIR="${ZMK_BUILD_BIN_DIR:-$HOME/.local/bin}"
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

# Not fatal. zmk-build builds firmware without it — only `zmk-build update`
# needs it, and that degrades to an actionable error.
info "Installing bashselfupdate..."
if install_bashselfupdate; then
  success "bashselfupdate installed"
else
  error "Could not install bashselfupdate — 'zmk-build update' will not work until it is"
  error "  Install it separately: $BASHSELFUPDATE_INSTALL_URL"
fi

if [[ ! -d "$INSTALL_DIR/.git" ]]; then
  info "Installing zmk-build..."
  if [[ -d "$INSTALL_DIR" ]]; then
    rm -rf "$INSTALL_DIR"
  fi
  if ! git clone --quiet "$REPO_URL" "$INSTALL_DIR"; then
    error "Failed to clone zmk-build repository"
    exit 1
  fi
  success "zmk-build cloned to $INSTALL_DIR"
fi

# checkout_latest rather than update: a fresh clone lands on main, which between
# releases is ahead of the newest tag, and update declines a checkout that is not
# sitting on one. It leaves the checkout on a branch and is idempotent, which is
# what makes re-running this script mean what everyone assumes it means.
if declare -F bashselfupdate_checkout_latest &>/dev/null; then
  if ! tag=$(bashselfupdate_checkout_latest "$INSTALL_DIR"); then
    error "Failed to move zmk-build to its latest release"
    exit 1
  fi
  success "zmk-build at $tag"
else
  # Reachable only when bashselfupdate could not be installed above, which is
  # also a machine where `zmk-build update` was never able to leave a detached
  # HEAD — so pull still works here.
  if ! git -C "$INSTALL_DIR" pull --quiet; then
    error "Failed to update zmk-build"
    exit 1
  fi
  success "zmk-build updated from $(git -C "$INSTALL_DIR" rev-parse --abbrev-ref HEAD)"
fi

ln -sf "$INSTALL_DIR/bin/zmk-build" "$BIN_DIR/zmk-build"
success "zmk-build installed: $BIN_DIR/zmk-build"

for dependency in docker yq; do
  if ! command -v "$dependency" &>/dev/null; then
    error "$dependency is not installed — zmk-build needs it to build firmware"
  fi
done

if command -v zmk-build &>/dev/null; then
  info "Run 'zmk-build --help' to get started"
else
  info "Add $BIN_DIR to your PATH, then run 'zmk-build --help'"
fi
