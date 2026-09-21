#!/usr/bin/env bash
# Checks on what cloud-config.sh makes of a hub's admin config and the action's
# inputs.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=s3-bucket-upload/tests/helpers.sh
. "$here/helpers.sh"
script="$here/../cloud-config.sh"
fixtures="$here/fixtures"

# Run cloud-config.sh over a fixture hub and print its step outputs, one
# `name=value` per line, so a case can assert on them.
run_config() {
  local hub_path="$1" storage_location="${2:-}" dry_run="${3:-false}"
  local aws_account="${4-123456789012}" aws_region="${5-us-east-1}"
  local output status
  output="$(mktemp)"
  GITHUB_OUTPUT="$output" HUB_PATH="$hub_path" \
    STORAGE_LOCATION="$storage_location" DRY_RUN="$dry_run" \
    ENFORCE_DEFAULT_BRANCH="true" \
    AWS_ACCOUNT="$aws_account" AWS_REGION="$aws_region" \
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
  "$(run_config "$fixtures/enabled" other-bucket)"

expect_failure "no hub config fails" \
  run_config "$fixtures/does-not-exist"

expect_failure "cloud enabled with no bucket anywhere fails" \
  run_config "$fixtures/no-location"

expect_failure "cloud enabled with no aws_account fails" \
  run_config "$fixtures/enabled" "" false ""

expect_failure "cloud enabled with no aws_region fails" \
  run_config "$fixtures/enabled" "" false 123456789012 ""

expect_equal "cloud disabled does not need the account or region" \
  "$(disabled)" \
  "$(run_config "$fixtures/disabled" "" false "" "")"

expect_failure "a flag set to something other than true or false fails" \
  run_config "$fixtures/enabled" "" yes

finish cloud-config
