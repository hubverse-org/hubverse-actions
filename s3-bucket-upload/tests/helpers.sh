#!/usr/bin/env bash
# Reporting shared by the test scripts in this directory. Source it, run cases
# through the expect_* functions, and end with `finish <suite>`.

failures=0

pass() {
  echo "ok - $1"
}

fail() {
  echo "not ok - $1"
  shift
  printf '    %s\n' "$@"
  failures=$((failures + 1))
}

# Compare two multi-line values, printing each on one line when they differ so
# the difference is readable in a workflow log.
expect_equal() {
  local case_name="$1" expected="$2" actual="$3"
  if [ "$actual" = "$expected" ]; then
    pass "$case_name"
  else
    fail "$case_name" \
      "expected: $(printf '%s' "$expected" | tr '\n' '|')" \
      "actual:   $(printf '%s' "$actual" | tr '\n' '|')"
  fi
}

expect_failure() {
  local case_name="$1"
  shift
  if "$@" > /dev/null 2>&1; then
    fail "$case_name" "it succeeded, and was expected to fail"
  else
    pass "$case_name"
  fi
}

finish() {
  if [ "$failures" -gt 0 ]; then
    echo "$failures failing case(s)"
    exit 1
  fi
  echo "all $1 cases passed"
}
