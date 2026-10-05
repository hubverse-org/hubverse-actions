# Releasing hubverse-actions

Hubs reference the composite actions and reusable workflows, like
`post-validation-comment.yaml`, at a floating major tag:

```yaml
uses: hubverse-org/hubverse-actions/validate-config@v2
```

## The floating major tag

`v2` is a git tag that `ci-release.yaml` moves onto each new release. A hub
referencing `@v2` therefore runs the latest `v2.x.y` release on its next
workflow run, without changing its workflows. This is the convention GitHub
Actions use, as in `actions/checkout@v4`.

Each release has two tags, for example `v2.1.3` and `v2`:

- The version tag, `v2.1.3`, is created by the release and never moved. It
  carries the GitHub release.
- The major tag, `v2`, is moved by `ci-release.yaml` when the release is
  published. It never gets a GitHub release of its own, because GitHub
  refuses to move a tag that has a release once immutable releases are
  enabled. `ci-release.yaml` refuses to move it backwards.

A new major is a new tag, `v3`. Hubs stay on `v2` until they change the
reference, and Dependabot opens the pull request for that (see
[`dependabot/README.md`](dependabot/README.md)). A hub that wants no automatic
updates pins `@v2.1.3` or a commit SHA.

## What counts as major, minor and patch

Semantic versioning, applied to actions and workflows:

- **Major.** Removing or renaming an action, reusable workflow, template,
  input or output. Changing the default of an input. Any other change that
  alters what an existing reference does, other than a bug fix.
- **Minor.** A new action, reusable workflow or template. A new input with a
  default, a new output, or new behaviour that is off by default.
- **Patch.** Bug fixes, dependency bumps, documentation, and changes to this
  repository's own CI.

## Release checklist

This follows the [hubverse release process](https://docs.hubverse.io/en/latest/developer/release-process.html),
with these differences:

- Tags are `vX.Y.Z`, with a `v`, as `uses:` references require.
- There is no version file and no `NEWS.md`, so there is no release branch,
  release pull request or post-release version bump. Release notes are
  generated from the merged pull requests.
- Publishing the GitHub release moves the floating major tag.

1. `git checkout main && git pull`. Check that CI is green and that the
   Dependabot pull requests meant for this release are merged.
2. Choose the version from the pull requests merged since the last release:
   `git log --first-parent --oneline v2.1.2..main`.
3. Create and push a signed tag:
   ```sh
   git tag -s v2.1.3 -m 'summary of changes'
   git push origin v2.1.3
   ```
4. Create the release as a draft, review and edit the generated notes, then
   publish it. The notes start from the previous release, named explicitly:
   without `--notes-start-tag`, GitHub takes the floating major tag as the
   previous release and lists only the changes since the tag last moved.
   ```sh
   gh release create v2.1.3 --title v2.1.3 --generate-notes \
     --notes-start-tag v2.1.2 --draft
   ```
5. Check that the `ci-release.yaml` run for the release succeeded.
6. For a major release, announce it on GitHub and the mailing list, with the
   steps a hub takes to migrate.

## Starting a new major

Files in this repository reference each other in full, as
`validate-config/action.yaml` does with
`hubverse-org/hubverse-actions/pr-comment@v2`, because `uses:` takes no
expressions. The new major tag must therefore exist before any file names it,
or every nested call fails to resolve. The steps below use the move from `v2`
to `v3` as the example.

1. Create the new major tag on the tip of `main`, with no release:
   ```sh
   git tag v3 origin/main && git push origin v3
   ```
2. In one pull request, change every reference from the old major tag to the
   new one. `ci-references.yaml` lists any that were missed. The nested calls
   in the pull request's CI resolve to the tag from step 1. Merge it.
3. Release `v3.0.0` from the merge commit with the checklist above.

## Previous majors

A previous major receives no further releases. Its tag stays where it is, so
hubs still referencing it keep working until they move to the new major.
