# validate-submission


This hubverse action installs the `hubValidations` package from GitHub using pak as well as required system dependencies.

It then performs submission validation checks through function `hubValidations::validate_pr()`

The action is triggered by pull requests onto the `main` branch which add or modify files in the `model-output` and/or `model-metadata` directories. For hubs and repositories which differ in configuration, workflow dispatch will need to be customised manually in the hubs workflow file.

For more information on configuring validation checks, see the `hubValidations` vignette on [Validating Pull Requests on GitHub](https://infectious-disease-modeling-hubs.github.io/hubValidations/articles/validate-pr.html).
