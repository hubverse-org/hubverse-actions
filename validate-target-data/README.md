# validate-target-data


This hubverse action installs the `hubValidations` package from the [hubverse R universe](https://hubverse-org.r-universe.dev/packages) using pak as well as required system dependencies.

It then performs target data validation checks through function `hubValidations::validate_target_pr()`

The action is triggered by pull requests onto the `main` branch which add or modify the contents of the following files or directories (excluding `README` files):
- `target-data/time-series.*`
- `target-data/time-series/**`
- `target-data/oracle-output.*`
- `target-data/oracle-output/**`

For more information on configuring target data validation checks, see the `hubValidations` documentation on the [`validate_target_pr()`](https://hubverse-org.github.io/hubValidations/reference/validate_target_pr.html) function.
