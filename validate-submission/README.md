# validate-submission


This hubverse action installs the `hubValidations` package from GitHub using remotes as well as required system dependencies.

It then performs submission validation checks through function `hubValidations::validate_pr()`

The action is triggered by pull requests onto the `main` branch which add or modify files in the `model-output` and/or `model-metadata` directories. For hubs and repositories which differ in configuration, workflow dispatch will need to be customised manually in the hubs workflow file.
