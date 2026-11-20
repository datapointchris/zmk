#!/usr/bin/env bats
# `zmk --help`, and `zmk <command> --help` for every command.
#
# Every command answers the flag with its own usage instead of running. The
# comment on that guard in `main` names what each command would do otherwise.
# Nothing here runs in a keyboard config directory, and the guard exits before
# any path is resolved, so these assert the guard rather than the commands.
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
  local name args description example flag
  while IFS='|' read -r name args description example _; do
    # A command reached by tab-completion is read without the root help, so its
    # own screen carries a command to copy.
    [[ "$example" == "zmk $name"* ]] || fail "zmk $name has no example of its own: '$example'"
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
