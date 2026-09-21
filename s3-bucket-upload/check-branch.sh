#!/usr/bin/env bash
# Refuse to sync from anywhere other than the repository's default branch.
set -euo pipefail

# Some events do not include the repository in their payload, which leaves the
# default branch unknown. Warn rather than fail: there is nothing to compare
# against, and the run may well be legitimate.
if [ -z "$DEFAULT_BRANCH" ]; then
  echo "::warning::s3-bucket-upload: the triggering event does not include the repository's default branch, so \`enforce_default_branch\` was not applied."
  exit 0
fi

if [ "$REF" != "refs/heads/$DEFAULT_BRANCH" ]; then
  echo "::error::s3-bucket-upload: refusing to sync from $REF, which is not the default branch ($DEFAULT_BRANCH). Set \`enforce_default_branch: false\` if this is deliberate."
  exit 1
fi

echo "Running from $REF, the default branch."
