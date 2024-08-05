# validate-config

Ensure Hub configuration files remain valid.

This hubverse action installs the `hubAdmin` package from GitHub using pak as well as required system dependencies.

It then performs submission validation checks through function `hubAdmin::validate_hub_config()` and assumes you have all three of the required configuration JSON files in your `hub-config/` directory:

 - `admin.json`
 - `model-metadata-schema.json`
 - `tasks.json`

When invalid config files are discovered, a GitHub comment is created (or updated) with a table containing information about the exact locations of the failures using the [`hubAdmin::view_config_val_errors()`](https://hubverse-org.github.io/hubAdmin/reference/view_config_val_errors.html) function. 

## Modifying

The action is triggered in two ways:

1. By pull requests onto the `main` branch which add or modify files in the `hub-config/` directory. 
2. Manually by an administrator of the hub on the repository's Actions interface.

For hubs and repositories which differ in configuration, workflow dispatch will need to be customised manually in the hub's workflow file **in two places**: `on/pull_request/paths` and the `jobs/validate-hub-config/env/HUB_PATH` environment variable (see example below).

For example, to validate the config of a demo hub included as part of a package you would want make sure the hub path is set to `"inst/demo_hub"`:

```diff
 on:
   workflow_dispatch:
   pull_request:
     branches: main
     paths:
-      - 'hub-config/**'
+      - 'inst/demo_hub/hub-config/**'
       - '!**README**'
 
 jobs:
   validate-hub-config:
     runs-on: ubuntu-latest
     env:
       GITHUB_PAT: ${{ secrets.GITHUB_TOKEN }}
       PR_NUMBER: ${{ github.event.number }}
-      HUB_PATH: ${{ github.workspace }}
+      HUB_PATH: ${{ github.workspace }}/inst/demo_hub
```

