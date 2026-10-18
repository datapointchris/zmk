#!/usr/bin/env bats
# `zmk --help`, and `zmk <command> --help` for every command.
#
# The flag was ignored and the command ran. In a keyboard config directory that
# means `zmk align --help` rewrites the keymap, `zmk draw --help` overwrites the
# SVG, and `zmk sync --help` does both and then builds. Nothing here runs in such
# a directory, and the guard exits before any path is resolved, so these assert
# the guard rather than the commands.
#
# HOME is empty, so no formatting library is found and every screen prints
# through zmk's own plain fallbacks, as it does on a machine without one.

load "$HOME/.local/lib/bats-support/load.bash"
load "$HOME/.local/lib/bats-assert/load.bash"

setup() {
  ZMK="$(cd "$BATS_TEST_DIRNAME/.." && pwd)/bin/zmk"
  export ZMK
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"
}

commands() {
  sed -n '/^ZMK_COMMANDS=(/,/^)/p' "$ZMK" | sed -n 's/^  "\(.*\)"$/\1/p'
}

@test "every command answers --help and -h with its own usage and description" {
  local name args description flag
  while IFS='|' read -r name args description; do
    for flag in --help -h; do
      run "$ZMK" "$name" "$flag"
      [[ "$status" -eq 0 ]] || fail "zmk $name $flag exited $status: $output"
      [[ "${lines[0]}" == "Usage: zmk $name${args:+ $args}" ]] || fail "zmk $name $flag said: ${lines[0]}"
      [[ "$output" == *"$description"* ]] || fail "zmk $name $flag left out: $description"
    done
  done < <(commands)
}

@test "the flag is caught after another flag, not only in first position" {
  # `zmk build --pristine --help` is the shape someone types when they are
  # already mid-command, and it must not start a build.
  run "$ZMK" build --pristine --help
  assert_success
  assert_line --index 0 "Usage: zmk build [--pristine] [--update]"
}
