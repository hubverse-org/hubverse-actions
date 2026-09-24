# dependabot

Keeps the actions a hub's workflows use up to date.

The workflows a hub adds from this repository reference actions by a floating
major tag, such as `actions/checkout@v4`. Minor and patch releases of those
actions reach the hub at runtime with no change to the workflow. A new major
does not: the hub stays on the old major until someone edits the workflow by
hand. With this configuration installed, Dependabot opens a pull request in the
hub for each new major, so the change is reviewed against the action's release
notes instead of being discovered when the old major stops working.

| File | What it does |
|---|---|
| `dependabot.yml` | The configuration a hub installs at `.github/dependabot.yml`. |

## Setting it up

Copy `dependabot.yml` to `.github/dependabot.yml` in the hub and commit it.
Dependabot runs from the default branch, so nothing happens until the file is on
`main`. The file must keep that exact name and location for GitHub to read it.

If the hub already has a `.github/dependabot.yml` for another ecosystem, add the
`github-actions` entry from this file to it rather than replacing the file.

## What a hub admin sees

Once a week, a pull request for each action with a new major release, titled
along the lines of `Dependabot: Bump actions/checkout from 4 to 5`, and nothing
at all in weeks where there is none. Each action gets its own pull request, so a
major that needs work does not hold up one that does not.

Minor and patch releases never produce a pull request, because the workflow's
`@v4` already picks them up. Actions referenced by branch, such as `@main`, are
not updated at all.
