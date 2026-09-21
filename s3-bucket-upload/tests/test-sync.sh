#!/usr/bin/env bash
# Checks on which rclone calls sync.sh makes. rclone is replaced by a stub that
# records the arguments it was called with, so nothing here touches a bucket.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=s3-bucket-upload/tests/helpers.sh
. "$here/helpers.sh"
script="$here/../sync.sh"

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

hub="$workdir/hub"
mkdir -p "$hub/hub-config" "$hub/target-data" "$hub/model-output"

stub_dir="$workdir/bin"
mkdir -p "$stub_dir"
cat > "$stub_dir/rclone" <<'STUB'
#!/usr/bin/env bash
echo "$*" >> "$RCLONE_LOG"
STUB
chmod +x "$stub_dir/rclone"

export RCLONE_LOG="$workdir/rclone.log"

# Run sync.sh against the fixture hub and print one line per rclone call.
run_sync() {
  local directories="$1" dry_run="${2:-false}" status
  : > "$RCLONE_LOG"
  PATH="$stub_dir:$PATH" \
    HUB_PATH="$hub" STORAGE_LOCATION="test-bucket" \
    DIRECTORIES="$directories" DRY_RUN="$dry_run" \
    bash "$script" > /dev/null 2>&1
  status=$?
  cat "$RCLONE_LOG"
  return $status
}

flags="--checksum --verbose --stats-one-line --config=/dev/null"

expect_equal "each directory syncs to its own name in the bucket" \
  "sync $hub/hub-config/ :s3,provider=AWS,env_auth:test-bucket/hub-config $flags
sync $hub/target-data/ :s3,provider=AWS,env_auth:test-bucket/target-data $flags" \
  "$(run_sync "$(printf 'hub-config\ntarget-data')")"

expect_equal "model output syncs to raw/" \
  "sync $hub/model-output/ :s3,provider=AWS,env_auth:test-bucket/raw/model-output $flags" \
  "$(run_sync "model-output")"

expect_equal "a directory the hub does not have is skipped" \
  "sync $hub/hub-config/ :s3,provider=AWS,env_auth:test-bucket/hub-config $flags" \
  "$(run_sync "$(printf 'hub-config\nmodel-abstracts')")"

expect_equal "blank lines are skipped" \
  "sync $hub/hub-config/ :s3,provider=AWS,env_auth:test-bucket/hub-config $flags" \
  "$(run_sync "$(printf '\nhub-config\n\n  \n')")"

expect_equal "a dry run passes --dry-run to rclone" \
  "sync $hub/hub-config/ :s3,provider=AWS,env_auth:test-bucket/hub-config $flags --dry-run" \
  "$(run_sync "hub-config" true)"

expect_failure "several directories on one line fail" \
  run_sync "hub-config target-data"

finish sync
