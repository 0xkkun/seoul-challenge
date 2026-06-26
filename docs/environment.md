# Environment

This template is pinned to Godot `4.6.3.stable.official.7d41c59c4`.

## Required

- Git
- Bash-compatible shell
- Python 3.10 or newer
- Godot `4.6.3.stable.official.7d41c59c4`, standard non-.NET build

The verification scripts expect a `godot` executable on `PATH`.

If your Godot binary uses another name or path, set `GODOT_BIN`:

```sh
GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot" bash scripts/verify_quick.sh
```

You can also set `PYTHON_BIN` if `python3` points to an older interpreter:

```sh
PYTHON_BIN=python3.12 bash scripts/verify_quick.sh
```

The Godot verification commands use a repo-local user home under `test-results/godot-user-home`
by default. This keeps headless editor settings and logs out of your real home directory and
makes sandboxed agent runs reproducible. Override it only when you intentionally want a shared
Godot user profile:

```sh
GODOT_USER_HOME=/tmp/pixel-godot-user bash scripts/verify_quick.sh
```

## Optional

- Godot MCP for editor and runtime checks from an AI coding agent
- GitHub CLI for maintainers who create issues and pull requests locally
- A local editor that understands GDScript

## Sanity Check

Run:

```sh
godot --version
python3 --version
bash scripts/verify_quick.sh
```

Expected Godot output:

```text
4.6.3.stable.official.7d41c59c4
```

## CI

GitHub Actions installs Godot 4.6.3 with `chickensoft-games/setup-godot@v2.4.1` and runs the same `scripts/verify_quick.sh` command used locally.
