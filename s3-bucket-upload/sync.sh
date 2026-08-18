#!/usr/bin/env bash
# Sync each of the hub's directories to the bucket.
set -euo pipefail

dry_run_flag=""
if [ "$DRY_RUN" = "true" ]; then
  echo "Dry run: reporting what a sync would change, writing nothing."
  dry_run_flag="--dry-run"
fi

# `read` splits the line on whitespace, and strips any that surrounds it.
while read -r directory extra; do
  # A blank line leaves both empty, and the input ends with one. Syncing an
  # empty directory name would send the whole hub to the top of the bucket,
  # deleting everything already there.
  if [ -z "$directory" ]; then
    continue
  fi
  # A line holding more than one word would sync the first directory and drop
  # the rest.
  if [ -n "$extra" ]; then
    echo "::error::s3-bucket-upload: \`directories\` takes one directory per line; got \"$directory $extra\"."
    exit 1
  fi

  destination="$STORAGE_LOCATION"
  # The hubverse pipeline transforms model output into the formats the bucket
  # serves, and reads it from raw/model-output. Every other directory is
  # served as submitted.
  if [ "$directory" = "model-output" ]; then
    destination="$STORAGE_LOCATION/raw"
  fi

  if [ ! -d "$HUB_PATH/$directory" ]; then
    echo "No $directory directory in the hub; skipping it."
    continue
  fi

  echo "Syncing $directory to $destination/$directory"
  rclone sync \
    "$HUB_PATH/$directory/" \
    ":s3,provider=AWS,env_auth:$destination/$directory" \
    --checksum --verbose --stats-one-line --config=/dev/null ${dry_run_flag:+"$dry_run_flag"}
done <<< "$DIRECTORIES"
