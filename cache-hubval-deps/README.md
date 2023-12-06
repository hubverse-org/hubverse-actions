# cache-hubval-deps


This hubverse action builds a cache of dependencies for the `hubValidations` package on the `main` branch using `r-lib/actions/setup-r-dependencies@v2` Github Action. This makes the dependency cache available to all child branches, including on forks, speeding up most submission validation workflows. 

The action is run on a `schedule` nightly at 00:10 UTC, rebuilding the cache if any dependencies have changed.
It is also triggered by any `push` to the workflow file itself on the `main` branch  (i.e. `.github/workflows/cache-hubval-deps.yaml`). This ensures the workflow is triggered the first time it is added to the repo.

## Restrict workflow to main Hub repository

To ensure the workflow only runs on the main hub repository - so as not to use contributor resources unnecessarily - change the `if` statement on line 12 from:

```yaml
jobs:
  build-deps-cache-on-main:
    if: ${{ github.repository_owner == github.repository_owner }}
```
to 
```yaml
jobs:
  build-deps-cache-on-main:
    if: ${{ github.repository_owner == '<MAIN-HUB-REPO-OWNER-USERNAME>' }}
```

e.g. the following restricts the workflow to only run on repositories owned by `cdcepi`.

```yaml
jobs:
  build-deps-cache-on-main:
    if: ${{ github.repository_owner == 'cdcepi' }}
```
