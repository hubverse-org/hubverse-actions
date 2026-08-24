# validate-config

Checks a hub's config files whenever a pull request changes them, and reports
the errors on that pull request.

When a pull request adds or changes files under `hub-config/`, those files are
validated against the [hubverse schema](https://github.com/hubverse-org/schemas)
with [`hubAdmin`](https://hubverse-org.github.io/hubAdmin/). The result is posted
as a comment, and the pull request's check fails if anything did not pass.

Everything in this directory serves that one job:

| File | What it does |
|---|---|
| `validate-config.yaml` | The workflow you add to your hub — the file GitHub runs. Most hubs use it exactly as it comes. |
| `action.yaml` | The action it calls — a reusable piece of work: sets up R, runs the checks, writes up the result and posts it. |
| `validate.R`, `summary.R` | The R behind it — running the checks, and turning their output into a comment. |
| `tests/` | Checks on the comment formatting, run in this repository's own CI. |

## Setting it up

From the root of your hub:

```r
hubCI::use_hub_github_action("validate-config")
```

The common case needs no settings at all. The workflow runs on pull requests
onto `main` that touch `hub-config/`, and can also be run manually from the
repository's Actions tab.

## What you see

A comment giving a pass or fail line and, when something failed, a table locating
each error: the config file, the location within it, the schema rule that was
violated and the value that failed.

Each new commit gets its own comment, which notifies you that the result has
changed. Re-running the same commit edits that commit's comment instead of adding
another, so the pull request keeps a history of results without filling up with
duplicates.

The same report is written to the [workflow run's summary
page](https://docs.github.com/actions/using-workflows/workflow-commands-for-github-actions#adding-a-job-summary),
so it is also there when there is no comment — see [pull requests from
forks](#pull-requests-from-forks) below.

If the checks never get to run at all — a config file that is not valid JSON, an
outage while installing R packages — you still get a comment saying so, rather
than a bare red cross with no explanation.

### Pull requests from forks

GitHub gives a pull request opened from a **fork** a read-only token, so the
workflow cannot comment on one.[^token] Config changes normally come from hub
administrators pushing a branch in the hub itself, where commenting works. When
one does arrive from a fork, the checks still run and still decide whether the
pull request's check passes; the result appears on the run's summary page rather
than as a comment, and the log records why. The action determines this itself, so
nothing in your copy of the workflow needs to.

The `validate-submission` workflows solve this differently, with [a second
workflow that posts the result](../validate-submission/README.md#how-it-works),
because every submission comes from a fork and the comment is the whole point.
Here the fork case is the exception, and it costs a hub two workflow files that
have to keep referring to each other by name.

## Customising

Add settings under `with:` on the `validate-config` step in your workflow file.
The one most hubs need is `hub_path`, when the hub is not at the root of the
repository — a demo hub shipped inside an R package, say. Change the `paths:`
filter at the top of the workflow to match:

```diff
 on:
   workflow_dispatch:
   pull_request:
     branches: main
     paths:
-      - 'hub-config/**'
+      - 'inst/demo_hub/hub-config/**'
       - '!**README**'
 ...
       - uses: hubverse-org/hubverse-actions/validate-config@main
+        with:
+          hub_path: inst/demo_hub
```

| Input | Default | Description |
|---|---|---|
| `hub_path` | `.` | Path to the hub, relative to the checkout root. |
| `schema_version` | `from_config` | Schema version to validate against, e.g. `v3.0.0`. The default takes it from the hub's own `admin.json`. |
| `schema_branch` | `main` | Branch of the hubverse schemas repository to read the schema from. |
| `comment` | `true` | Post the result as a pull request comment. Turn it off to keep the result to the job summary and the workflow log. |
| `comment_header` | `config-validation` | Key identifying the comment, so re-running a commit edits it in place. A repository validating [more than one hub](#validating-more-than-one-hub) needs a distinct key for each. |
| `extra_repositories` | hubverse r-universe | Extra R package repositories. |
| `github_token` | `${{ github.token }}` | Token used to install R packages from GitHub and to comment. |

### Validating more than one hub

A repository holding more than one hub — a real hub and a demo hub inside a
package, say — runs the action once per hub. Give each run its own
`comment_header`, or the second overwrites the first's comment:

```yaml
- uses: hubverse-org/hubverse-actions/validate-config@main
  with:
    hub_path: inst/demo_hub
    comment_header: config-validation-demo
```

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
  - uses: hubverse-org/hubverse-actions/validate-config@main
```

It reports one output, for a workflow that also needs the result as a file:

| Output | Description |
|---|---|
| `summary-path` | Where the written-up result was saved. Always written, including when validation could not run. |

## For maintainers: why the error table is stripped down

The table is `hubAdmin`'s.
[`view_config_val_errors()`](https://hubverse-org.github.io/hubAdmin/reference/view_config_val_errors.html)
decides which errors are worth showing and how to present them, and `summary.R`
takes what that returns. What it changes is the HTML, not the table.

`hubAdmin` renders through [`gt`](https://gt.rstudio.com), which produces HTML
meant for a browser: the whole visual design is repeated inline on every cell.
GitHub's comment sanitiser discards `style` and `class`, so none of that weight
reaches the reader.

The cost is not only wasted bytes. `gt` lays the error paths out with
`white-space: pre` and emits no line breaks of its own, so once the styling has
been dropped every path arrives flattened onto a single line.

`summary.R` therefore reduces the markup to what GitHub actually renders, and
turns the line breaks within cells into `<br>`. That leaves it readable and
around a seventh of its original size. It matters at the size a real config
reaches: GitHub rejects a comment over 65,536 characters outright, and before
this a single mistyped key in `tasks.json` could produce enough errors to pass
that and get no comment at all. What is still too large is cut to fit, keeping the
earliest errors, since config errors cascade and fixing those often clears the
rest. The run's summary page has a far larger budget and keeps them all.

[^token]: In GitHub's own terms: a `pull_request` workflow triggered from a fork
    gets a read-only `GITHUB_TOKEN`. `pull-requests: write` is downgraded and
    secrets are withheld, whatever the workflow asks for.
