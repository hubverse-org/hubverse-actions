
# hubverse-actions <img src="https://github.com/hubverse-org/hubDocs/blob/main/docs/_static/LOGO-hubverse.png?raw=true" align="right" width="50px"/>

<!-- badges: start -->
<!-- badges: end -->

This repository stores [GitHub Actions](https://github.com/features/actions) for hubverse hubs, which can be used to do a variety of CI tasks. 

The repository holds two kinds of GitHub Actions file, and a Dependabot configuration:

- A **workflow** is the file named after its directory, such as `validate-config/validate-config.yaml`. A hub copies it into its own `.github/workflows/` directory, and GitHub runs it from there.
- A **composite action** is the `action.yaml` file in a directory. It is not copied into the hub. A workflow calls it from this repository with `uses:`.

Some directories hold both: the workflow a hub adds, and the composite action that workflow calls. Consult individual READMEs for details on each.

## Workflows

A workflow can be downloaded using `hubCI::use_hub_github_action()` and the name of the directory as the action name.

| Workflow | What it does |
|---|---|
| [`validate-submission`](validate-submission) | Validates the model output and model metadata files in a pull request and posts the result as a comment. From hubCI 0.1.0, adding it also adds its companion, [`validate-submission-comment`](validate-submission-comment), which does the posting. |
| [`validate-target-data`](validate-target-data) | Validates the target data files in a pull request and posts the result as a comment. |
| [`validate-config`](validate-config) | Validates the hub's config files when a pull request changes them and posts the result as a comment. |
| [`cache-hubval-deps`](cache-hubval-deps) | Caches the dependencies of hubValidations on `main` each night, which speeds up submission validation. |
| [`hubverse-aws-upload`](hubverse-aws-upload) | Uploads the hub's data to its hubverse-hosted cloud storage on every push to `main`. |

## Composite actions

A composite action is called with `uses: hubverse-org/hubverse-actions/<directory>@main`. The workflows above call these actions, and a hub writing its own workflow can call them directly.

| Action | What it does |
|---|---|
| [`validate-submission`](validate-submission/action.yaml) | Called by the `validate-submission` workflow. Runs `hubValidations::validate_pr()` and writes the result up for a pull request comment. |
| [`validate-target-data`](validate-target-data/action.yaml) | Called by the `validate-target-data` workflow. Runs `hubValidations::validate_target_pr()` and posts the result as a pull request comment. |
| [`validate-config`](validate-config/action.yaml) | Called by the `validate-config` workflow. Runs `hubAdmin::validate_hub_config()` and posts the result as a pull request comment. |
| [`s3-bucket-upload`](s3-bucket-upload) | Called by the `hubverse-aws-upload` workflow. Syncs a hub's directories to the S3 bucket named in the hub's admin config. |
| [`pr-comment`](pr-comment) | Creates or updates a single pull request comment identified by a marker key. |
| [`resolve-pr`](resolve-pr) | Finds the pull request behind a completed workflow run, for a job triggered by `workflow_run`. |

## Dependabot configuration

The [`dependabot`](dependabot) directory holds a Dependabot configuration a hub installs to keep the actions its workflows use up to date. It is installed with `hubCI::use_hub_dependabot()`, available from hubCI 0.1.0.

## Releases

[`RELEASING.md`](RELEASING.md) describes how versions are chosen and how a release is cut.

## Additional resources

- [GitHub Actions for R](https://www.jimhester.com/talk/2020-rsc-github-actions/), Jim Hester's talk at rstudio::conf 2020. [Recording](https://resources.rstudio.com/rstudio-conf-2020/azure-pipelines-and-github-actions-jim-hester), [slidedeck](https://speakerdeck.com/jimhester/github-actions-for-r).
- [GitHub Actions advent calendar](https://www.edwardthomson.com/blog/github_actions_advent_calendar.html) a series of blogposts by Edward Thomson, one of the GitHub Actions product managers
  highlighting features of GitHub Actions.
- [GitHub Actions with R](https://ropenscilabs.github.io/actions_sandbox/) - a short online book about using GitHub Actions with R, produced as part of the [rOpenSci OzUnconf](https://ozunconf19.ropensci.org/).
- [Awesome Actions](https://github.com/sdras/awesome-actions#awesome-actions---) - a curated list of custom actions. **Note** that many of these are from early in the GitHub Actions beta and may no longer work.
