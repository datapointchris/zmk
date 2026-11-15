#!/usr/bin/env bats
# The update notice and `zmk update` read one checkout and one remote.
#
# The notice names a release and `update` installs one. If the two read
# different checkouts or remotes, the notice can advertise a release that
# `update` never installs. A stub library records the arguments each receives.

load "$HOME/.local/lib/bats-support/load.bash"
load "$HOME/.local/lib/bats-assert/load.bash"

setup() {
  ZMK="$(cd "$BATS_TEST_DIRNAME/.." && pwd)/bin/zmk"
  export HOME="$BATS_TEST_TMPDIR/home"
  export XDG_LIB_HOME="$BATS_TEST_TMPDIR/lib"
  export CALLS="$BATS_TEST_TMPDIR/calls"
  mkdir -p "$HOME" "$XDG_LIB_HOME/bashselfupdate"
  cat >"$XDG_LIB_HOME/bashselfupdate/load.bash" <<'EOF'
bashselfupdate_notify() { printf 'notify %s\n' "${*:2}" >>"$CALLS"; }
bashselfupdate_current_version() { echo v1.0.0; }
bashselfupdate_update() { printf 'update %s\n' "$*" >>"$CALLS"; }
bashselfupdate_describe() { echo v1.0.0; }
EOF
}

@test "the notice and update pass the library the same checkout and remote" {
  run "$ZMK" --help
  assert_success
  run "$ZMK" update
  assert_success

  local notified updated
  notified=$(sed -n 's/^notify //p' "$CALLS")
  updated=$(sed -n 's/^update //p' "$CALLS")
  [[ -n "$notified" ]] || fail "no command printed the update notice"
  [[ -n "$updated" ]] || fail "zmk update never called the library"
  [[ "$notified" == "$updated" ]] || fail "notice read '$notified', update read '$updated'"
}
