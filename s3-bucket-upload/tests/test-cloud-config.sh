#!/usr/bin/env bash
# Checks on what cloud-config.sh makes of a hub's admin config and the action's
# inputs, which are the two sources of the same two answers.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=s3-bucket-upload/tests/helpers.sh
. "$here/helpers.sh"
script="$here/../cloud-config.sh"
fixtures="$here/fixtures"

# Run cloud-config.sh over a fixture hub and print its step outputs, one
# `name=value` per line, so a case can assert on them.
run_config() {
  local hub_path="$1" cloud_enabled="${2:-}" storage_location="${3:-}" dry_run="${4:-false}"
  local output status
  output="$(mktemp)"
  GITHUB_OUTPUT="$output" HUB_PATH="$hub_path" \
    CLOUD_ENABLED="$cloud_enabled" STORAGE_LOCATION="$storage_location" \
    DRY_RUN="$dry_run" ENFORCE_DEFAULT_BRANCH="true" \
    bash "$script" > /dev/null 2>&1
  status=$?
  cat "$output"
  rm -f "$output"
  return $status
}

enabled_at() {
  printf 'cloud_enabled=true\nstorage_location=%s' "$1"
}

disabled() {
  printf 'cloud_enabled=false\nstorage_location='
}

expect_equal "cloud enabled gives the bucket from the config" \
  "$(enabled_at test-bucket)" \
  "$(run_config "$fixtures/enabled")"

expect_equal "cloud disabled syncs nothing" \
  "$(disabled)" \
  "$(run_config "$fixtures/disabled")"

expect_equal "no cloud group syncs nothing" \
  "$(disabled)" \
  "$(run_config "$fixtures/no-cloud")"

expect_equal "the storage_location input overrides the config's bucket" \
  "$(enabled_at other-bucket)" \
  "$(run_config "$fixtures/enabled" "" other-bucket)"

expect_equal "cloud_enabled false overrides a config that enables it" \
  "$(disabled)" \
  "$(run_config "$fixtures/enabled" false)"

expect_equal "cloud_enabled true overrides a config that disables it" \
  "$(enabled_at test-bucket)" \
  "$(run_config "$fixtures/disabled" true)"

expect_equal "the inputs alone are enough without a hub config" \
  "$(enabled_at other-bucket)" \
  "$(run_config "$fixtures/does-not-exist" true other-bucket)"

expect_equal "no hub config and cloud_enabled false syncs nothing" \
  "$(disabled)" \
  "$(run_config "$fixtures/does-not-exist" false)"

expect_failure "no hub config and no cloud_enabled input fails" \
  run_config "$fixtures/does-not-exist"

expect_failure "no hub config and no storage_location input fails" \
  run_config "$fixtures/does-not-exist" true

expect_failure "cloud enabled with no bucket anywhere fails" \
  run_config "$fixtures/no-location"

expect_failure "a flag set to something other than true or false fails" \
  run_config "$fixtures/enabled" "" "" yes

expect_failure "a cloud_enabled input that is neither true nor false fails" \
  run_config "$fixtures/enabled" yes

finish cloud-config
