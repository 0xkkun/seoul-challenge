#!/usr/bin/env python3
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

MANIFEST = [
    {
        "id": "room",
        "script": "scripts/systems/room.gd",
        "tests": ["tests/unit/test_room.gd", "tests/integration/test_session_contract.gd"],
        "enabled": True,
    },
    {
        "id": "room_door",
        "script": "scripts/systems/room_door.gd",
        "tests": ["tests/unit/test_room_door.gd", "tests/integration/test_room_transition.gd"],
        "enabled": True,
    },
    {
        "id": "room_manager",
        "script": "scripts/systems/room_manager.gd",
        "tests": [
            "tests/integration/test_room_manager_contract.gd",
            "tests/performance/test_room_perf.gd",
        ],
        "enabled": True,
    },
    {
        "id": "room_layout",
        "script": "scripts/systems/room_layout.gd",
        "tests": [
            "tests/integration/test_room_manager_contract.gd",
            "tests/unit/test_room_layout_generator.gd",
            "tests/performance/test_room_perf.gd",
        ],
        "enabled": True,
    },
    {
        "id": "room_def",
        "script": "scripts/systems/room_def.gd",
        "tests": [
            "tests/integration/test_room_manager_contract.gd",
            "tests/unit/test_room_layout_generator.gd",
        ],
        "enabled": True,
    },
    {
        "id": "room_layout_generator",
        "script": "scripts/systems/room_layout_generator.gd",
        "tests": ["tests/unit/test_room_layout_generator.gd", "tests/performance/test_room_perf.gd"],
        "enabled": True,
    },
    {
        "id": "event_room",
        "script": "scripts/interactables/event_room.gd",
        "tests": ["tests/integration/test_event_room_contract.gd"],
        "enabled": True,
    },
    {
        "id": "rescue_student",
        "script": "scripts/interactables/rescue_student.gd",
        "tests": ["tests/integration/test_event_room_contract.gd"],
        "enabled": True,
    },
    {
        "id": "currency_system",
        "script": "scripts/autoload/currency_system.gd",
        "tests": ["tests/unit/test_currency_system.gd"],
        "enabled": True,
    },
    {
        "id": "run_controller",
        "script": "scripts/session/run_controller.gd",
        "tests": ["tests/integration/test_run_flow.gd"],
        "enabled": True,
    },
]

MONITORED_EXACT_PATHS = {
    "scripts/autoload/currency_system.gd",
    "scripts/interactables/event_room.gd",
    "scripts/interactables/rescue_student.gd",
    "scripts/session/run_controller.gd",
}

MONITORED_GLOBS = [
    "scripts/systems/room*.gd",
]


def fail(message: str) -> None:
    print(f"[verify_room_coverage] FAIL: {message}", file=sys.stderr)


def existing_monitored_scripts() -> set[str]:
    paths = {path for path in MONITORED_EXACT_PATHS if (ROOT / path).is_file()}
    for pattern in MONITORED_GLOBS:
        for file_path in ROOT.glob(pattern):
            paths.add(file_path.relative_to(ROOT).as_posix())
    return paths


def has_test_methods(path: Path) -> bool:
    if not path.is_file():
        return False
    return "func test_" in path.read_text(encoding="utf-8", errors="ignore")


def main() -> None:
    problems: list[str] = []
    registered_scripts = {str(entry["script"]) for entry in MANIFEST}
    monitored_scripts = existing_monitored_scripts()

    for script_path in sorted(monitored_scripts - registered_scripts):
        problems.append(f"{script_path} is room-domain code but is not registered in MANIFEST")

    for entry in MANIFEST:
        script_path = str(entry["script"])
        script_file = ROOT / script_path
        enabled = bool(entry["enabled"])

        if enabled and not script_file.is_file():
            problems.append(f"{entry['id']} is enabled but script is missing: {script_path}")
            continue
        if not enabled:
            if script_file.is_file():
                problems.append(
                    f"{entry['id']} script exists but manifest entry is disabled: {script_path}"
                )
            continue

        test_paths = [str(path) for path in entry["tests"]]
        if not test_paths:
            problems.append(f"{entry['id']} has no mapped tests")
            continue

        for test_path in test_paths:
            test_file = ROOT / test_path
            if not test_file.is_file():
                problems.append(f"{entry['id']} maps to missing test: {test_path}")
            elif not has_test_methods(test_file):
                problems.append(f"{entry['id']} maps to a file without test_* methods: {test_path}")

    if problems:
        for problem in problems:
            fail(problem)
        raise SystemExit(1)

    active = [entry["id"] for entry in MANIFEST if entry["enabled"]]
    inactive = [entry["id"] for entry in MANIFEST if not entry["enabled"]]
    print(
        "[verify_room_coverage] OK: %d active domain scripts locked (%s)"
        % (len(active), ", ".join(active))
    )
    print(
        "[verify_room_coverage] OK: %d future manifest entries disabled until their scripts land (%s)"
        % (len(inactive), ", ".join(inactive))
    )


if __name__ == "__main__":
    main()
