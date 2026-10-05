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

Everything prefixed `test-` or `ci-`. These are not consumed by anyone.
`test-` workflows test the actions and scripts in this repository against
pull requests here. `ci-` workflows are the repository's other automation,
such as `ci-release.yaml`, which moves the floating major tag on each release.
Each file's header comment says what it does.

If you add a reusable workflow here, add it to the table above. If you add CI,
prefix it `test-` or `ci-` and leave this file alone.
