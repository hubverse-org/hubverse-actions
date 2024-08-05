# validate-config

Ensure Hub configuration files remain valid.

This hubverse action installs the `hubAdmin` package from GitHub using pak as well as required system dependencies.

It then performs submission validation checks through function `hubAdmin::validate_hub_config()` and assumes you have all three of the required configuration JSON files in your `hub-config/` directory:

 - `admin.json`
 - `model-metadata-schema.json`
 - `tasks.json`

When invalid config files are discovered, a GitHub comment is created (or updated) with a table containing information about the exact locations of the failures using the [`hubAdmin::view_config_val_errors()`](https://hubverse-org.github.io/hubAdmin/reference/view_config_val_errors.html) function. 

The action is triggered by pull requests onto the `main` branch which add or modify files in the `hub-config/` directory. For hubs and repositories which differ in configuration, workflow dispatch will need to be customised manually in the hubs workflow file.

The workflow default will validate files in the `hub-config` directory in the root of the repository. To change the path to the hub to be validated, change the default path defined in the `HUB_PATH` environment variable. For example,  to validate the config of a demo hub included as part of a package you could set `HUB_PATH` to `"inst/demo_hub"`.

