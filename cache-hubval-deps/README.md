# cache-hubval-deps


This hubverse action builds a cache of dependencies for the `hubValidations` package on the `main` branch using `r-lib/actions/setup-r-dependencies@v2` Github Action. This makes the dependency cache available to all child branches, including on forks, speeding up most submission validation workflows. 

The action is run on a `schedule` nightly at 00:10 UTC, rebuilding the cache if any dependencies have changed.
It is also triggered by any `push` to the workflow file itself on the `main` branch  (i.e. `.github/workflows/cache-hubval-deps.yaml`). This ensures the workflow is triggered the first time it is added to the repo.
