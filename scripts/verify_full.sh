#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"

PYTHON="${PYTHON_BIN:-python3}"

echo "== quick gate =="
bash scripts/verify_quick.sh

echo "== functional smoke =="
bash scripts/godot_headless.sh res://tests/functional/playtest_runner.tscn

echo "== runtime smoke =="
bash scripts/godot_headless.sh --quit-after 120
bash scripts/godot_headless.sh res://scenes/dev/main_dev.tscn --quit-after 120

echo "== tooling tests =="
"$PYTHON" tests/tooling/test_static_scripts.py

echo "== full verification complete =="
echo "[verify_full] OK: full gate passed"
