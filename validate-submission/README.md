# validate-submission

Validates the model-output and model-metadata files in a hub pull request with
[`hubValidations::validate_pr()`](https://hubverse-org.github.io/hubValidations/articles/validate-pr.html).

It installs `hubValidations` from the
[hubverse R universe](https://hubverse-org.r-universe.dev/packages) along with the
required system dependencies, then runs the submission checks and reports the
result in the workflow log, failing the job if any check does not pass.

This directory provides two things:

- **A template workflow** (`validate-submission.yaml`) that most hubs use as-is.
  It is scaffolded into a hub with `hubCI::use_hub_github_action("validate-submission")`
  and triggers on pull requests that add or modify files under `model-output/` or
  `model-metadata/`.
- **A composite action** (`action.yml`) holding the logic, which the template
  calls and which advanced hubs can drop into their own workflows.

## Using the action directly

The action assumes the repository is already checked out.

```yaml
steps:
  - uses: actions/checkout@v7
  - uses: hubverse-org/hubverse-actions/validate-submission@main
    with:
      skip_submit_window_check: true
```

Every `validate_pr()` argument is exposed as an input. `gh_repo` and `pr_number`
default to the workflow context, so the turnkey case needs no inputs at all.

| Input | Default | Description |
|---|---|---|
| `hub_path` | `.` | Path to the hub, relative to the checkout root. |
| `gh_repo` | workflow repo | Hub repository as `owner/name`. |
| `pr_number` | triggering PR | Pull request number to validate. |
| `round_id_col` | *(empty)* | Column holding round IDs, if not configured in `tasks.json`. |
| `output_type_id_datatype` | `from_config` | Type to coerce `output_type_id` to. |
| `validations_cfg_path` | *(empty)* | Path to a custom validations config file. |
| `skip_submit_window_check` | `false` | Skip the submission window check. |
| `file_modification_check` | `error` | How to treat modification/deletion of submitted files. |
| `allow_submit_window_mods` | `true` | Allow in-window modification/deletion of model-output files. |
| `submit_window_ref_date_from` | `file` | Where the submission window reference date comes from. |
| `derived_task_ids` | *(empty)* | Comma-separated task IDs derived from other task IDs. |
| `verbose` | `true` | Print the result of every check before the summary. |
| `show_warnings` | `false` | Print check-level warnings inline. |
| `extra_packages` | *(empty)* | Extra R packages to install (`setup-r-dependencies` syntax). |
| `extra_repositories` | hubverse r-universe | Extra R package repositories. |
| `github_token` | `${{ github.token }}` | Token used to read PR files via the GitHub API. |

For more on configuring validation checks, see the `hubValidations` vignette on
[Validating Pull Requests on GitHub](https://hubverse-org.github.io/hubValidations/articles/validate-pr.html).
