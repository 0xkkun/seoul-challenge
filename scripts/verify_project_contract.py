#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path

EXPECTED_GODOT_VERSION = "4.6.3.stable.official.7d41c59c4"
EXPECTED_AUTOLOADS = {
    "GameManager": "res://scripts/autoload/game_manager.gd",
    "EventBus": "res://scripts/autoload/event_bus.gd",
    "SceneTransition": "res://scripts/autoload/scene_transition.gd",
    "SaveManager": "res://scripts/autoload/save_manager.gd",
    "CurrencySystem": "res://scripts/autoload/currency_system.gd",
    "ProgressionSystem": "res://scripts/autoload/progression_system.gd",
    "Settings": "res://scripts/autoload/settings.gd",
    "AudioManager": "res://scripts/autoload/audio_manager.gd",
    "PoolManager": "res://scripts/autoload/pool_manager.gd",
    "PlatformManager": "res://scripts/autoload/platform_manager.gd",
    "HapticManager": "res://scripts/autoload/haptic_manager.gd",
    "HitStopManager": "res://scripts/autoload/hit_stop_manager.gd",
}

REQUIRED_FILES = [
    "README.md",
    "AGENTS.md",
    "docs/customizing.md",
    "docs/environment.md",
    "project.godot",
    "export_presets.cfg",
    "scripts/godot_headless.sh",
    "scripts/verify_quick.sh",
    "scripts/verify_full.sh",
    "scripts/constants/render_layers.gd",
    "scripts/constants/render_layers.gd.uid",
    "scenes/lobby/lobby.tscn",
    "scenes/session/session_root.tscn",
    "scenes/dev/main_dev.tscn",
    "tests/unit/test_runner.tscn",
    "tests/integration/integration_runner.tscn",
    "tests/functional/playtest_runner.tscn",
]

PROJECT_NEEDLES = {
    "config_version=5": "config_version=5",
    "feature marker": 'config/features=PackedStringArray("4.6")',
    "main scene": 'run/main_scene="res://scenes/lobby/lobby.tscn"',
    "viewport width": "window/size/viewport_width=960",
    "viewport height": "window/size/viewport_height=540",
    "stretch mode": 'window/stretch/mode="canvas_items"',
    "stretch aspect": 'window/stretch/aspect="expand"',
    "landscape orientation": "window/handheld/orientation=0",
    "nearest texture filter": "textures/canvas_textures/default_texture_filter=0",
    "compatibility renderer": 'renderer/rendering_method="gl_compatibility"',
    "mobile compatibility renderer": 'renderer/rendering_method.mobile="gl_compatibility"',
}

ANDROID_EXPORT_NEEDLES = {
    "android preset": 'name="Android"',
    "debug package": 'package/unique_name="com.oxkkun.afterschool.debug"',
    "vibrate permission": '"android.permission.VIBRATE"',
}


def fail(message: str) -> None:
    print(f"[verify_project_contract] FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)


def read(path: str) -> str:
    return Path(path).read_text(encoding="utf-8")


def verify_required_files() -> None:
    missing = [path for path in REQUIRED_FILES if not Path(path).is_file()]
    if missing:
        fail("missing required file(s): " + ", ".join(missing))


def verify_project_settings() -> None:
    text = read("project.godot")
    missing = [name for name, needle in PROJECT_NEEDLES.items() if needle not in text]
    if missing:
        fail("missing project.godot invariant(s): " + ", ".join(missing))

    found = {
        name: path
        for name, path in re.findall(
            r'^([A-Za-z0-9_]+)="\*?(res://[^"]+)"$', text, flags=re.MULTILINE
        )
    }
    if found != EXPECTED_AUTOLOADS:
        details = [f"{name}={path}" for name, path in sorted(found.items())]
        fail("autoload inventory drift: " + ", ".join(details))

    for name, resource_path in EXPECTED_AUTOLOADS.items():
        local_path = Path(resource_path.removeprefix("res://"))
        if not local_path.is_file():
            fail(f"autoload {name} points to missing file: {resource_path}")


def verify_docs_match() -> None:
    readme = read("README.md")
    agents = read("AGENTS.md")
    env = read("docs/environment.md")
    architecture = read("docs/architecture.md")
    for label, text in {
        "README.md": readme,
        "AGENTS.md": agents,
        "docs/environment.md": env,
    }.items():
        if EXPECTED_GODOT_VERSION not in text:
            fail(f"{label} must mention {EXPECTED_GODOT_VERSION}")
        if "scripts/verify_quick.sh" not in text:
            fail(f"{label} must mention scripts/verify_quick.sh")

    if "scripts/constants/render_layers.gd" not in architecture:
        fail("docs/architecture.md must describe the render layer contract")
    if "WORLD_BACKGROUND_Z" not in architecture or "UI_SESSION_LAYER" not in architecture:
        fail("docs/architecture.md must list world and UI render layer constants")


def verify_android_export_preset() -> None:
    text = read("export_presets.cfg")
    missing = [name for name, needle in ANDROID_EXPORT_NEEDLES.items() if needle not in text]
    if missing:
        fail("missing Android export preset invariant(s): " + ", ".join(missing))


def main() -> None:
    verify_required_files()
    verify_project_settings()
    verify_docs_match()
    verify_android_export_preset()
    print("[verify_project_contract] OK: project contract matches template baseline")


if __name__ == "__main__":
    main()
