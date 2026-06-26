# Pull Request Hygiene

Use this checklist before opening a PR and again before marking it ready.

## Title

Format:

```text
[Area] Imperative summary
```

Use one primary area prefix:

- `[UI]` for visible scene, layout, control, or interaction changes
- `[Docs]` for README, guide, or contributor documentation changes
- `[Harness]` for verification scripts, test runners, or agent workflow changes
- `[CI]` for GitHub Actions and required status checks
- `[Scene]` for scene tree or scene transition structure
- `[Autoload]` for boot services and global runtime contracts
- `[Interaction]` for interaction dispatch and pooled object behavior
- `[Assets]` for committed source assets and import metadata
- `[Config]` for project settings, export presets, or example config

When a PR crosses multiple areas, choose the prefix for the user-visible or highest
risk part of the diff. Let labels carry the secondary areas.

Examples:

```text
[Docs] Clarify first-hour template consumer workflow
[UI] Add session summary controls
[Harness] Add import metadata guard
[CI] Require quick verification on main
```

## Metadata

Set these before asking for review:

- Assignee: the person or agent responsible for landing the PR
- Milestone: the current delivery slice
- Priority label: `p0`, `p1`, or `p2`
- Area label: at least one `area:*` label
- Optional labels: `agent-ready`, `domain-neutrality`, or standard GitHub labels

## Body

The PR body should include:

- linked issue with `Closes #N` when the PR fully resolves it
- concise scope summary
- verification commands and results
- known limitations or follow-up issues

For template work, also confirm:

- reusable names remain domain-neutral
- no private project references are copied
- no generated caches, local config, or credentials are tracked
- README, `docs/customizing.md`, `docs/pr-hygiene.md`, and `AGENTS.md` still agree
  with the commands and workflow in the repo
