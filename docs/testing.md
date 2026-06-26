# Testing

The template uses Godot headless scenes plus small Python static checks.

## Commands

```sh
bash scripts/verify_quick.sh
bash scripts/verify_full.sh
```

Quick verification covers:

- environment and Godot version
- static project contract
- import metadata hygiene
- secret hygiene
- headless editor load
- unit tests
- integration tests

Full verification adds:

- functional smoke
- runtime smoke for the main scene
- runtime smoke for the dev scene
- tooling regression checks

## Test Locations

- `tests/unit/`
- `tests/integration/`
- `tests/functional/`
- `tests/tooling/`
- `tests/support/test_runner.gd`

Every `test_*` method must execute at least one assertion.

## Branch Protection

Recommended `main` protection:

- require pull requests before merging
- require the `Quick verification` status check
- require branches to be up to date before merging
- allow administrators to bypass only for repository recovery

Enable protection after the first green CI run confirms the workflow name and status check label.
