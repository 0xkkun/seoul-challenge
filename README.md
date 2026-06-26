# Seoul Challenge

Seoul Challenge is a Godot 4.6.3 pixel-art 2D project created from
`0xkkun/pixel-godot-template`. It keeps the template's AI-agent-friendly
verification harness as the project baseline.

## Quickstart

```sh
git clone https://github.com/0xkkun/seoul-challenge.git
cd seoul-challenge
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
