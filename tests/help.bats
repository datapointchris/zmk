#!/usr/bin/env bats
# `zmk <command> --help`, for every command.
#
# The flag was ignored and the command ran. In a keyboard config directory that
# means `zmk align --help` rewrites the keymap, `zmk draw --help` overwrites the
# SVG, and `zmk sync --help` does both and then builds. Nothing here runs in such
# a directory, and the guard exits before any path is resolved, so these assert
# the guard rather than the commands.
#
# Only the per-command path is covered. The full screen goes through the help_*
# helpers from formatting.sh, whose real output is the dotfiles library's to test.
#
# bin/zmk exits 1 at source time when formatting.sh is absent, which a CI runner
# always is, so setup writes a stub. It defines the help_* grammar as no-ops:
# verb_help prints with plain echo and needs none of it, and stubbing beats
# skipping because the guard then runs on the runner rather than only here.

load "$HOME/.local/lib/bats-support/load.bash"
load "$HOME/.local/lib/bats-assert/load.bash"

setup() {
  ZMK="$(cd "$BATS_TEST_DIRNAME/.." && pwd)/bin/zmk"
  export ZMK

  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME/.local/shell"
  cat >"$HOME/.local/shell/formatting.sh" <<'STUB'
help_header() { :; }
help_usage() { :; }
help_section() { :; }
help_row() { :; }
help_text() { :; }
help_end() { :; }
print_error() { echo "$*" >&2; }
print_success() { echo "$*"; }
print_info() { echo "$*"; }
STUB
}

@test "every command in the table answers --help with its own usage" {
  local name
  while IFS='|' read -r name _; do
    [[ -n "$name" ]] || continue
    run "$ZMK" "$name" --help
    [[ "$status" -eq 0 ]] || fail "zmk $name --help exited $status: $output"
    [[ "${lines[0]}" == "Usage: zmk $name"* ]] || fail "zmk $name --help said: ${lines[0]}"
  done < <(sed -n '/^ZMK_COMMANDS=(/,/^)/p' "$ZMK" | sed -n 's/^  "\(.*\)"$/\1/p')
}

@test "every command answers -h the same way" {
  local name
  while IFS='|' read -r name _; do
    [[ -n "$name" ]] || continue
    run "$ZMK" "$name" -h
    [[ "$status" -eq 0 ]] || fail "zmk $name -h exited $status: $output"
  done < <(sed -n '/^ZMK_COMMANDS=(/,/^)/p' "$ZMK" | sed -n 's/^  "\(.*\)"$/\1/p')
}

@test "a command with arguments shows them" {
  run "$ZMK" build --help
  assert_success
  assert_line --index 0 "Usage: zmk build [--pristine] [--update]"
}

@test "a command with no arguments shows none" {
  run "$ZMK" align --help
  assert_success
  assert_line --index 0 "Usage: zmk align"
}

@test "the flag is caught after another flag, not only in first position" {
  # `zmk build --pristine --help` is the shape someone types when they are
  # already mid-command, and it must not start a build.
  run "$ZMK" build --pristine --help
  assert_success
  assert_line --index 0 "Usage: zmk build [--pristine] [--update]"
}

@test "the description comes through" {
  run "$ZMK" sync --help
  assert_success
  assert_output --partial "align, then draw, then build"
}

@test "the table is the only place a command is listed" {
  # show_help loops the same array, so a command added to one is in both. This
  # fails if someone reintroduces a hardcoded help_row beside the loop.
  run grep -c '^  help_row "build"' "$ZMK"
  assert_output "0"
}
