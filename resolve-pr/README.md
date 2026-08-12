# resolve-pr

Finds the pull request behind a completed workflow run, for a `workflow_run` job
that needs to act on that run's result.

```yaml
- id: pr
  uses: hubverse-org/hubverse-actions/resolve-pr@main

- if: steps.pr.outputs.number != ''
  uses: hubverse-org/hubverse-actions/pr-comment@main
  with:
    pr: ${{ steps.pr.outputs.number }}
    header: my-workflow
    body_path: result.md
```

## Why not read the number from the run

A `workflow_run` job runs in the base repository's context with a write token,
while the run that triggered it may have come from a fork — and a fork pull
request runs **its own copy** of the triggering workflow, so everything that run
produced is submitter-controlled. Taking the pull request number from an artifact
would let a fork have the repository act on any pull request it named.

Everything this action reads comes from the `workflow_run` payload, which the
submitter cannot forge.

`github.event.workflow_run.pull_requests` is not usable for this: it is empty for
fork pull requests, which is the case that matters. The lookup goes by head
repository and branch instead, disambiguated by head commit when a branch has
been reused across pull requests.

## Inputs

Every input defaults to the right field of `github.event.workflow_run`, so a
`workflow_run` job needs none of them.

| Input | Default | Description |
|---|---|---|
| `head_owner` | run's head repo owner | Owner of that repository. |
| `head_branch` | run's head branch | Head branch of the run. |
| `head_sha` | run's head commit | Used to pick between pull requests sharing a branch name. |
| `token` | `${{ github.token }}` | Token used to look the pull request up. |

## Outputs

| Output | Description |
|---|---|
| `number` | The pull request number, or **empty** if no open pull request matches. |

An empty `number` is not an error, so gate later steps on
`steps.<id>.outputs.number != ''` rather than letting them fail. It means one of:
the pull request was closed or merged while the first run was finishing; the fork
it came from was deleted; or the branch backs several open pull requests and none
is at this commit, in which case the action will not guess between them.

It fails only when given nothing at all to work with, which happens outside a
`workflow_run` job, where the defaults resolve to nothing. Pass the inputs
explicitly if you need it elsewhere.
