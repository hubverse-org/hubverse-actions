# .github/workflows

Two unrelated kinds of file share this directory, because GitHub only recognises
workflows in `.github/workflows/` — they cannot live in subdirectories the way
actions can.

## Shipped to hubs

Reusable workflows that hubs call, and part of this repository's public surface.
Changing one changes behaviour in every hub using it, and they move to the release
tag along with the actions.

| | |
|---|---|
| `post-validation-comment.yaml` | Posts a validation result to the pull request it came from. Called by the [`validate-submission`](../../validate-submission) template; written to suit the other `validate-*` actions as they adopt the same pattern. |

## This repository's own CI

Everything prefixed `test-`. These run against pull requests here and are not
consumed by anyone.

| | |
|---|---|
| `test-pr-comment.yaml` | Self-tests [`pr-comment`](../../pr-comment) against the pull request it runs on. |
| `test-validate-submission.yaml` | Runs [`validate-submission`](../../validate-submission) against fixture PRs in `ci-testhub-simple`, and its summary rendering against bundled test hubs. |
| `test-submission-comment.yaml` | Exercises the upload-then-comment handoff, calling the same reusable workflow the template calls. |

If you add a reusable workflow here, add it to the first table. If you add CI,
prefix it `test-` so the distinction keeps holding.
