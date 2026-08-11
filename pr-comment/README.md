# pr-comment

Creates or updates a **single** pull request comment identified by a marker key.
Each distinct `header` keeps its own sticky comment on a PR, so re-running a
workflow updates its comment in place and independent workflows never clobber
each other's.

It wraps [`actions/github-script`](https://github.com/actions/github-script) —
no external dependencies — and embeds a hidden marker
(`<!-- hubverse-comment:<header> -->`, with the `revision` appended when set) in
the comment to find it again on the next run, paging through all PR comments so it
works on long threads.

## Usage

The caller needs `permissions: pull-requests: write`.

```yaml
permissions:
  pull-requests: write

steps:
  - uses: hubverse-org/hubverse-actions/pr-comment@main
    with:
      pr: ${{ github.event.number }}
      header: submission-validation
      body_path: ${{ runner.temp }}/results.md
```

## Inputs

| Input | Default | Description |
|---|---|---|
| `pr` | *(required)* | Pull request number to comment on. |
| `header` | *(required)* | Unique key for this comment; each header owns one sticky comment. Must be a slug of letters, digits, `-` or `_`. |
| `body` | *(empty)* | Comment body (markdown). Provide this or `body_path`. |
| `body_path` | *(empty)* | Path to a file holding the body. Takes precedence over `body`. |
| `revision` | *(empty)* | Optional key (e.g. the PR head commit SHA) enabling per-revision comments. See [Notifying on changes](#notifying-on-changes). |
| `token` | `${{ github.token }}` | Token used to read and write PR comments. |

## Outputs

| Output | Description |
|---|---|
| `comment-id` | ID of the comment that was created or updated. |

## Notifying on changes

Without `revision`, the action keeps a **single** comment per `header` and edits
it in place. GitHub sends no notification for an edit, so this is quiet — good for
CI that updates often, but a submitter is not pinged when a re-run changes the
result.

Set `revision` (typically the PR head commit SHA) to post a **new** comment when
the revision changes — which notifies — while a re-run on the **same** revision
edits that revision's comment in place. Earlier revisions' comments are left
untouched, so the PR accumulates a history of results across commits.

Because those comments share a heading, each one gains a footer saying which
revision it is for (`Results for commit \`a1b2c3d\``, with 40-character SHAs
abbreviated). Timeline position usually implies it, but not when pushes land
faster than runs finish, when GitHub groups several commits into one entry, or
when the comment is read from a notification.

```yaml
- uses: hubverse-org/hubverse-actions/pr-comment@main
  with:
    pr: ${{ github.event.number }}
    header: submission-validation
    revision: ${{ github.event.pull_request.head.sha }}
    body_path: ${{ runner.temp }}/results.md
```

Use `github.event.pull_request.head.sha` (the submitted commit), not `github.sha`
(the temporary merge commit, which changes on every base update). In the fork-safe
`workflow_run` pattern below, the PR number and head SHA come from the uploaded
artifact instead of the event context.

## Notes

- `header` must be a slug of letters, digits, `-` or `_`; it is embedded in an
  HTML comment marker used to find the comment again. Anything else fails the
  step. `revision` is checked the same way, allowing `.` as well, since it goes
  into the marker too.
- Only comments posted by a **bot** are ever adopted and updated. The marker is
  predictable, so without that check someone could post a comment carrying it and
  have the next run edit theirs instead. This means `token` must belong to a bot
  or app identity; a personal access token posts a fresh comment every time
  rather than updating its own.
- Create-or-update is not atomic. Two runs with the same `header` racing on one
  PR can each create a comment, so callers that may fire concurrently should
  serialise with a workflow [`concurrency`](https://docs.github.com/actions/using-jobs/using-concurrency)
  group.

## Posting from fork pull requests

A `pull_request` workflow triggered from a **fork** gets a read-only
`GITHUB_TOKEN` — GitHub downgrades `pull-requests: write` and withholds secrets —
so it cannot post comments. Since most submissions to a hub come from forks, this
action must be invoked from a workflow that runs in the **base repository's**
context with a write token.

The recommended pattern is a two-stage
[`workflow_run`](https://docs.github.com/actions/using-workflows/events-that-trigger-workflows#workflow_run)
split: the `pull_request` workflow does the read-only work and uploads its result
(plus the PR number) as an artifact; a `workflow_run` workflow downloads the
artifact and calls this action to post. Avoid `pull_request_target` for anything
that checks out or acts on PR content — it exposes the write token to
submitter-controlled code.
