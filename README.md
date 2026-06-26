# Pixel Godot Template

A Godot 4.6.3 template for pixel-art 2D projects, built around an AI-agent-friendly verification harness.

## Quickstart

Preferred path:

1. Click **Use this template** on GitHub.
2. Create a new repository under your own account or organization.
3. Clone your new repository, not this template repository.

With GitHub CLI:

```sh
gh repo create my-game --template 0xkkun/pixel-godot-template --private --clone
cd my-game
```

Use `--public` instead of `--private` when the new project should be public.

Clone-only fallback:

```sh
git clone https://github.com/0xkkun/pixel-godot-template.git my-game
cd my-game
git remote set-url origin https://github.com/YOUR_ORG_OR_USER/my-game.git
godot --path .
bash scripts/verify_quick.sh
```

Use `GODOT_BIN=/path/to/godot` if the `godot` executable is not on `PATH`.

## Baseline

- Godot: `4.6.3.stable.official.7d41c59c4`
- Runtime target: pixel-art 2D projects
- Renderer: Compatibility
- Stretch: `canvas_items` + `expand`
- Texture filtering: nearest by default
- Main scene: `res://scenes/lobby/lobby.tscn`

## Working With The Template

- Confirm your local setup with [docs/environment.md](docs/environment.md).
- Start customization with [docs/customizing.md](docs/customizing.md).
- Keep PR titles and metadata consistent with [docs/pr-hygiene.md](docs/pr-hygiene.md).
- Ask coding agents to follow [AGENTS.md](AGENTS.md).
- Run `bash scripts/verify_quick.sh` before every PR.
- Run `bash scripts/verify_full.sh` before merging larger changes.

The reusable template surface uses neutral names so it can become many different games without carrying a sample game's vocabulary into the final project.
