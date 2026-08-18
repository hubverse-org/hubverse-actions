#!/usr/bin/env bash
# Determine whether cloud storage is enabled and which bucket to sync to. Both
# values can come from the hub's admin config or from the action's inputs, and
# an input takes precedence.
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
# cloud_enabled has no default: an empty value leaves the decision to the config.
if [ -n "$CLOUD_ENABLED" ]; then
  check_flag cloud_enabled "$CLOUD_ENABLED"
fi

write_output() {
  {
    echo "cloud_enabled=$1"
    echo "storage_location=$2"
  } >> "$GITHUB_OUTPUT"
}

config_enabled=""
config_location=""
admin_config="$HUB_PATH/hub-config/admin.json"
if [ -f "$admin_config" ]; then
  # A hub that does not use cloud storage either omits the cloud group from its
  # admin config or sets cloud.enabled to false. Both are ordinary, so a missing
  # group means disabled, not a broken config.
  config_enabled=$(jq -r '.cloud.enabled // false' "$admin_config")
  config_location=$(jq -r '.cloud.host.storage_location // ""' "$admin_config")
else
  echo "No hub config at $admin_config; taking both values from the action's inputs."
fi

cloud_enabled="${CLOUD_ENABLED:-$config_enabled}"
if [ -z "$cloud_enabled" ]; then
  echo "::error::s3-bucket-upload: cannot determine whether cloud storage is enabled. There is no hub config at $admin_config and no \`cloud_enabled\` input. Point \`hub_path\` at the hub root, or set \`cloud_enabled\` and \`storage_location\`."
  exit 1
fi

if [ "$cloud_enabled" != "true" ]; then
  echo "Cloud storage is not enabled. Nothing to sync."
  write_output false ""
  exit 0
fi

storage_location="${STORAGE_LOCATION:-$config_location}"
if [ -z "$storage_location" ]; then
  echo "::error::s3-bucket-upload: cloud storage is enabled but no bucket is configured. Set cloud.host.storage_location in $admin_config, or pass the \`storage_location\` input."
  exit 1
fi

if [ -n "$STORAGE_LOCATION" ]; then
  echo "Syncing to $storage_location, set by the \`storage_location\` input."
else
  echo "Syncing to $storage_location, set in $admin_config."
fi
write_output true "$storage_location"
