# s3-bucket-upload

Syncs a hub's directories to the hubverse-hosted AWS S3 bucket that serves the
hub's data, using [rclone](https://rclone.org). The hub's admin config decides
whether anything is uploaded and to which bucket, so a cloud-enabled hub needs
no settings, and a hub without cloud storage is unaffected: the action reads the
config and stops.

Most hubs get this through the [`hubverse-aws-upload`](../hubverse-aws-upload)
workflow, which is this action with the triggers and permissions already set up.
Use the action directly when assembling your own workflow, or to upload as one
step of a larger pipeline.

## Usage

The job needs `id-token: write` to request the hub's AWS role, and a checkout
for the action to read.

```yaml
permissions:
  contents: read
  id-token: write

steps:
  - uses: actions/checkout@v7

  - uses: hubverse-org/hubverse-actions/s3-bucket-upload@main
```

Before this works, a member of the hubverse development team needs to
["onboard" the hub to AWS](https://github.com/hubverse-org/hubverse-infrastructure?tab=readme-ov-file#onboarding-a-hub).
That one-time process creates the hub's bucket and the permissions that let the
hub's workflows write to it. Those permissions cover the hub's default branch
only, so a sync from anywhere else is refused by AWS.

## Inputs

| Input | Default | Description |
|---|---|---|
| `hub_path` | `.` | Path to the hub root, relative to the checkout root. |
| `cloud_enabled` | *(empty)* | Whether to sync at all. Empty takes it from the hub's admin config. |
| `storage_location` | *(empty)* | Bucket to sync to. Empty takes it from the hub's admin config. |
| `directories` | the six directories below | Hub directories to sync, one per line. |
| `dry_run` | `false` | Report what a sync would change without writing anything. |
| `enforce_default_branch` | `true` | Fail rather than sync when running from any branch other than the repository's default branch. |
| `aws_account` | `767397675902` | AWS account the hub's role belongs to. Defaults to the hubverse account. |
| `aws_region` | `us-east-1` | AWS region the bucket lives in. |

## Outputs

| Output | Description |
|---|---|
| `storage_location` | Bucket the action synced to. Empty when cloud storage is not enabled, so a later step can tell that nothing was uploaded. |

## What is uploaded, and where it lands

Each directory is synced to a directory of the same name in the bucket, except
`model-output`:

| Hub directory | In the bucket |
|---|---|
| `auxiliary-data` | `auxiliary-data` |
| `hub-config` | `hub-config` |
| `model-abstracts` | `model-abstracts` |
| `model-metadata` | `model-metadata` |
| `target-data` | `target-data` |
| `model-output` | `raw/model-output` |

Model output goes to `raw/` because the hubverse pipeline transforms it into
the formats the bucket serves and reads it from there. Every other directory is
served as submitted.

Syncing makes the bucket match the hub, so a file deleted from the hub is
deleted from the bucket on the next run. A shorter `directories` list leaves a
directory out altogether, and whatever the bucket already holds for it
untouched. Directories the hub does not have are skipped, so the default list
suits a hub with no `model-abstracts`.

## Checking a sync before running it

`dry_run` reports what a sync would change and writes nothing:

```yaml
- uses: hubverse-org/hubverse-actions/s3-bucket-upload@main
  with:
    dry_run: true
```

A dry run still needs the AWS role, since working out what would change means
reading the bucket. That is also why it has to run from the default branch: a
hub's role cannot be assumed from anywhere else, so `enforce_default_branch:
false` moves the failure from this action to AWS rather than avoiding it.

## Where the settings come from

Whether cloud storage is enabled and which bucket to sync to can each come from
the hub's admin config or from the matching input, and an input takes precedence
over the config. A hub normally sets neither and lets its config decide.

`storage_location` sends the sync to a different bucket from the one in the
config, which is how to sync against a staging bucket. It still has to be a
bucket the hub's AWS role can write to, which for a hubverse-hosted hub means its
own. `cloud_enabled` decides whether the sync runs at all, whatever the config
says.

Together the two inputs also cover a repository with no admin config, since
neither value is then read from one. If there is no config and neither input is
set, the action fails: it cannot determine whether cloud storage is enabled.

## Notes

- The action installs rclone from its
  [official script](https://rclone.org/install/) rather than from apt. The Debian
  version is [too old](https://github.com/rclone/rclone/issues/6060) to parse the
  inline connection string the sync uses, and fails with "config name contains
  invalid characters".
- `enforce_default_branch` fails the run before it reaches AWS, which is a
  clearer error than the permission failure AWS returns for the same situation.
  It applies only to a hub with cloud storage enabled, and is skipped with a
  warning when the triggering event does not include the repository's default
  branch.
- A fork of the hub has no AWS role, so a workflow that may run on forks should
  skip the job there: `if: github.event.repository.fork != true`.
- The role assumed to reach the bucket is named after the bucket:
  `arn:aws:iam::<aws_account>:role/<storage_location>`. Onboarding sets a hub's
  role up that way, so `aws_account` only reaches an account whose roles follow
  the same convention.
