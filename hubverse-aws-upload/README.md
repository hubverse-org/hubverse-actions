# hubverse-aws-upload

Uploads the hub's data to its hubverse-hosted cloud storage on every push to
`main`, so that what the cloud serves matches the repository.

The workflow's single job, `upload`, calls the
[`s3-bucket-upload`](../s3-bucket-upload) action, which reads the hub's admin
config (`admin.json`) and, when `cloud.enabled` is `true`, syncs these
directories to the S3 bucket named in `cloud.host.storage_location`:
`auxiliary-data`, `hub-config`, `model-abstracts`, `model-metadata`,
`target-data` and `model-output`.

This workflow is safe to add to a hub that does not use cloud storage. If the
admin config has no `cloud` group, or has `cloud.enabled` set to anything other
than `true`, the job finds nothing to upload and stops before authenticating to
AWS.

## Setting it up

From the root of your hub:

```r
hubCI::use_hub_github_action("hubverse-aws-upload")
```

Nothing else needs configuring. To change what is uploaded, or to try a sync
without writing anything, pass the action's inputs from the workflow's `uses:`
step. [Its README](../s3-bucket-upload#inputs) lists them.

## AWS setup

Before using this workflow, a member of the hubverse development team will need
to ["onboard" the hub to AWS](https://github.com/hubverse-org/hubverse-infrastructure?tab=readme-ov-file#onboarding-a-hub).
Onboarding is a one-time process that creates:

- An AWS S3 bucket for the hub
- A set of AWS permissions that allow the repo's GitHub workflows to write to the bucket

**Important**: The repo's write permissions are limited to the `main` branch.
Running this workflow on another branch or on a fork will fail.
