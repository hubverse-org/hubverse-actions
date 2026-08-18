#!/usr/bin/env bash
# Checks on the default-branch guard.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=s3-bucket-upload/tests/helpers.sh
. "$here/helpers.sh"
script="$here/../check-branch.sh"

# Run the guard for one ref and check both what it decided and what it said, so
# that a guard which passes for the wrong reason is still caught.
expect() {
  local case_name="$1" expected="$2" pattern="$3" ref="$4" default_branch="$5"
  local output decided
  if output="$(REF="$ref" DEFAULT_BRANCH="$default_branch" bash "$script" 2>&1)"; then
    decided=pass
  else
    decided=fail
  fi

  if [ "$decided" != "$expected" ]; then
    fail "$case_name" "expected the guard to $expected, it $decided" "output: $output"
    return
  fi
  if ! printf '%s' "$output" | grep -q "$pattern"; then
    fail "$case_name" "expected output matching: $pattern" "actual: $output"
    return
  fi
  pass "$case_name"
}

expect "the default branch syncs" pass "the default branch" refs/heads/main main
expect "another branch is refused" fail "refs/heads/a-branch" refs/heads/a-branch main
expect "a pull request ref is refused" fail "::error::" refs/pull/1/merge main
expect "a default branch other than main is honoured" pass "the default branch" refs/heads/trunk trunk
expect "an event with no default branch warns rather than refusing" pass "::warning::" refs/heads/anything ""

finish check-branch
