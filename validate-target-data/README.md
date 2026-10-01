# validate-target-data

Checks a hub's target data whenever a pull request changes it, and reports the
result on that pull request.

When a pull request adds or changes files under `target-data/`, those files are
run through
[`hubValidations`](https://hubverse-org.github.io/hubValidations/reference/validate_target_pr.html):
each file on its own, and each affected target type (`time-series`,
`oracle-output`) as a whole dataset. The result is posted as a comment, and the
pull request's check fails if anything did not pass.

Everything in this directory serves that one job:

| File | What it does |
|---|---|
| `validate-target-data.yaml` | The workflow you add to your hub — the file GitHub runs. Most hubs use it exactly as it comes. |
| `action.yaml` | The action it calls — a reusable piece of work: sets up R, runs the checks, writes up the result and posts it. |
| `validate.R` | The R behind it — running the checks. Turning their output into a comment is shared with [`validate-submission`](../validate-submission), whose `summary.R` this sources. |
| `tests/` | Checks that the shared comment formatting takes target data results, run in this repository's own CI. |

## Setting it up

From the root of your hub:

```r
hubCI::use_hub_github_action("validate-target-data")
```

The common case needs no settings at all. The workflow runs on pull requests
onto `main` that add or change any of the following (`README` files excluded):

- `target-data/time-series.*`
- `target-data/time-series/**`
- `target-data/oracle-output.*`
- `target-data/oracle-output/**`

## What you see

A comment giving a pass or fail line and the check results, shown in full when
something failed and tucked behind a toggle when everything passed.

Each new commit gets its own comment, which notifies you that the result has
changed. Re-running the same commit edits that commit's comment instead of adding
another, so the pull request keeps a history of results without filling up with
duplicates.

The same report is written to the [job
summary](https://docs.github.com/actions/using-workflows/workflow-commands-for-github-actions#adding-a-job-summary),
so it is also there when there is no comment — see [pull requests from
forks](#pull-requests-from-forks) below.

If the checks never get to run at all — a bad hub config, an outage while
installing R packages — you still get a comment saying so, rather than a bare
red cross with no explanation.

A very large change can produce more output than GitHub will accept in a single
comment. When that happens the comment is trimmed to fit, keeping the end, where
the failures are listed. The workflow log always has the whole thing.

### Pull requests from forks

GitHub gives a pull request opened from a **fork** a read-only token, so the
workflow cannot comment on one.[^token] Target data changes normally come from
hub administrators pushing a branch in the hub itself, where commenting works.
When one does arrive from a fork, the checks still run and still decide whether
the pull request's check passes; the result appears in the job summary
rather than as a comment, and the log records why. The action determines this
itself, so nothing in your copy of the workflow needs to.

The `validate-submission` workflows solve this differently, with [a second
workflow that posts the result](../validate-submission/README.md#how-it-works),
because every submission comes from a fork and the comment is the whole point.
Here the fork case is the exception, and it costs a hub two workflow files that
have to keep referring to each other by name.

## Customising

Most hubs need none of this, but every option
[`validate_target_pr()`](https://hubverse-org.github.io/hubValidations/reference/validate_target_pr.html)
takes is available as a setting. Add them under `with:` on the
`validate-target-data` step in your workflow file:

```yaml
- uses: hubverse-org/hubverse-actions/validate-target-data@main
  with:
    file_modification_check: error
```

When the hub is not at the root of the repository, set `hub_path` and change the
`paths:` filter at the top of the workflow to match.

| Input | Default | Description |
|---|---|---|
| `hub_path` | `.` | Path to the hub, relative to the checkout root. |
| `gh_repo` | workflow repo | Hub repository as `owner/name`. |
| `pr_number` | triggering PR | Pull request number to validate. |
| `output_type_id_datatype` | `from_config` | Type to convert `output_type_id` to. |
| `date_col` | *(empty)* | Column holding the date an observation occurred, when that column is not a task ID. Ignored when the hub has a `target-data.json` config. |
| `allow_extra_dates` | `false` | Allow time-series date values that are not in `tasks.json`. Oracle output is always checked strictly. |
| `round_id` | `default` | Round ID naming the block of custom validation checks to run. |
| `validations_cfg_path` | *(empty)* | Path to a custom validations config file. |
| `file_modification_check` | `none` | How to treat changes to target data files already in the hub: `none`, `message`, `failure` or `error`. |
| `allow_target_type_deletion` | `false` | Allow a pull request to delete every file of a target type. |
| `verbose` | `true` | Print the result of every check before the summary. |
| `show_warnings` | `false` | Print check-level warnings inline. |
| `comment` | `true` | Post the result as a pull request comment. Turn it off to keep the result to the job summary and the workflow log. |
| `comment_header` | `target-data-validation` | Key identifying the comment, so re-running a commit edits it in place. A repository validating more than one hub needs a distinct key for each. |
| `extra_packages` | *(empty)* | Extra R packages to install, for custom checks that need them. |
| `extra_repositories` | hubverse r-universe | Extra R package repositories. |
| `github_token` | `${{ github.token }}` | Token used to read the pull request's files and to comment. |

The `na` argument of `validate_target_pr()`, the strings read as missing values,
is not a setting. Its default is what hubs need, so it always applies.

## Using the action on its own

If your hub needs a workflow of its own rather than the supplied one, the action
can be called directly. It assumes the repository is already checked out, and it
needs `pull-requests: write` to comment.

```yaml
permissions:
  contents: read
  pull-requests: write

steps:
  - uses: actions/checkout@v7
  - uses: hubverse-org/hubverse-actions/validate-target-data@main
```

It reports one output, for a workflow that also needs the result as a file:

| Output | Description |
|---|---|
| `summary-path` | Where the written-up result was saved. Always written, including when validation could not run. |

[^token]: In GitHub's own terms: a `pull_request` workflow triggered from a fork
    gets a read-only `GITHUB_TOKEN`. `pull-requests: write` is downgraded and
    secrets are withheld, whatever the workflow asks for.
