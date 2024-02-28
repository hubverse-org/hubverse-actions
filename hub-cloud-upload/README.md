# hub-cloud-upload


This hubverse action uploads hub data to the cloud. Currently, the workflow has a single job, `upload`,
that pushes data to an AWS S3 bucket.

The `upload` job perform the following steps:

1. Inspect the hub's admin config (`admin.json`) for a `cloud` group.
2. If `cloud.enabled` is set to `true`:
    - authenticate to AWS
    - use `cloud.host.storage` to determine the name of the hub's S3 bucket
    - sync the hub's `hub-config`, `model-metadata`, and `model-output` directories to the S3 bucket

**Note**: This action is safe to use with non cloud-enabled hubs. 
If the hub's `admin.config` does not contain a `cloud` group or has `cloud.enabled` set to anything other than `true`,
the action will skip AWS-related steps.


## AWS setup

Before using this action, a member of the hubverse development team will need to "onboard" the hub to AWS. Onboarding is
a one-time process that creates:

- An AWS S3 bucket for the hub
- A set of AWS permissions that allow the repo's GitHub workflows to write to the bucket

**Important**: The repo's write permissions are limited to the `main` branch. Running this action on another branch
or on a fork will fail.

