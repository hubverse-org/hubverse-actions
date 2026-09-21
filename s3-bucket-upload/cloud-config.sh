#!/usr/bin/env bash
# Determine whether cloud storage is enabled and which bucket to sync to. Both
# come from the hub's admin config. The `storage_location` input, when set,
# takes precedence over the config's bucket.
set -euo pipefail

check_flag() {
  local input="$1" value="$2"
  if [ "$value" != "true" ] && [ "$value" != "false" ]; then
    echo "::error::s3-bucket-upload: \`$input\` takes true or false; got \"$value\"."
    exit 1
  fi
}

# A flag arrives as a string, and every string other than "true" is treated as
# false. Without this check `dry_run: yes` would sync for real and
# `enforce_default_branch: yes` would drop the guard, in both cases silently.
check_flag dry_run "$DRY_RUN"
check_flag enforce_default_branch "$ENFORCE_DEFAULT_BRANCH"

write_output() {
  {
    echo "cloud_enabled=$1"
    echo "storage_location=$2"
  } >> "$GITHUB_OUTPUT"
}

admin_config="$HUB_PATH/hub-config/admin.json"
if [ ! -f "$admin_config" ]; then
  echo "::error::s3-bucket-upload: no hub config at $admin_config. Point \`hub_path\` at the hub root."
  exit 1
fi

# A hub that does not use cloud storage either omits the cloud group from its
# admin config or sets cloud.enabled to false. Both are ordinary, so a missing
# group means disabled, not a broken config.
cloud_enabled=$(jq -r '.cloud.enabled // false' "$admin_config")
if [ "$cloud_enabled" != "true" ]; then
  echo "Cloud storage is not enabled. Nothing to sync."
  write_output false ""
  exit 0
fi

config_location=$(jq -r '.cloud.host.storage_location // ""' "$admin_config")
storage_location="${STORAGE_LOCATION:-$config_location}"
if [ -z "$storage_location" ]; then
  echo "::error::s3-bucket-upload: cloud storage is enabled but no bucket is configured. Set cloud.host.storage_location in $admin_config, or pass the \`storage_location\` input."
  exit 1
fi

# The runner does not enforce `required` on a composite action's inputs, so an
# unset account would reach the AWS step as an empty string in the role ARN.
if [ -z "$AWS_ACCOUNT" ]; then
  echo "::error::s3-bucket-upload: cloud storage is enabled but \`aws_account\` is not set."
  exit 1
fi
if [ -z "$AWS_REGION" ]; then
  echo "::error::s3-bucket-upload: cloud storage is enabled but \`aws_region\` is not set."
  exit 1
fi

if [ -n "$STORAGE_LOCATION" ]; then
  echo "Syncing to $storage_location, set by the \`storage_location\` input."
else
  echo "Syncing to $storage_location, set in $admin_config."
fi
write_output true "$storage_location"
