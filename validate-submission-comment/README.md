# validate-submission-comment

Posts the result of [`validate-submission`](../validate-submission) as a comment
on the pull request it came from.

This is the second of the two workflows a hub needs. Add both:

```r
hubCI::use_hub_github_action("validate-submission")
hubCI::use_hub_github_action("validate-submission-comment")
```

Without this one, validation still runs and still fails the check — the result
just never reaches the pull request.

## Why it is a separate file

Most submissions come from forks, and GitHub gives a fork's pull request
read-only access, so the workflow running the checks cannot comment on its own
result. The result has to be posted by a second run, triggered by the first
finishing, which happens in the hub's own context.

That second run has to be a **separate workflow file**: GitHub rejects a workflow
that names itself as its own trigger, with `Workflow '...' cannot listen to
itself`.

Like the validation workflow, it does not run on forks of your hub — a submitter
should see results on their pull request here, not in their own copy.

## Keeping the two in step

The trigger matches the validation workflow by name:

```yaml
on:
  workflow_run:
    workflows: ["Hub Submission Validation (R)"]
```

If you rename the validation workflow, change this to match. Nothing reports an
error when it stops matching — results simply stop being posted.

## What is in it

Almost nothing. The steps live in a
[shared workflow](../.github/workflows/post-validation-comment.yaml) in
hubverse-actions, so the artifact name, the action versions and the concurrency
key stay fixable there rather than frozen in your copy. See
[validate-submission's README](../validate-submission#what-a-submitter-sees) for
what gets posted and how the two stages fit together.
