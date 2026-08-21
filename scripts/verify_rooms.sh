#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"

PYTHON="${PYTHON_BIN:-python3}"
GODOT="${GODOT_BIN:-godot}"
GODOT_USER_HOME="${GODOT_USER_HOME:-$ROOT/test-results/godot-user-home}"

echo "== room coverage =="
"$PYTHON" scripts/verify_room_coverage.py

echo "== room editor load =="
mkdir -p test-results
mkdir -p "$GODOT_USER_HOME"
# A clean checkout has tracked remaps but no .godot/imported cache. Prime imports
# once before validating a second editor load so theme startup does not race the scan.
HOME="$GODOT_USER_HOME" XDG_DATA_HOME="$GODOT_USER_HOME/.local/share" \
  "$GODOT" --headless --editor --quit --path "$ROOT" > test-results/rooms-editor-import-prime.log 2>&1
HOME="$GODOT_USER_HOME" XDG_DATA_HOME="$GODOT_USER_HOME/.local/share" \
  "$GODOT" --headless --editor --quit --path "$ROOT" > test-results/rooms-editor-load.log 2>&1
"$PYTHON" scripts/verify_godot_output.py test-results/rooms-editor-load.log
"$PYTHON" scripts/verify_import_metadata.py

echo "== room runtime and performance =="
bash scripts/godot_headless.sh res://tests/performance/performance_runner.tscn

echo "== rooms gate complete =="
echo "[verify_rooms] OK: rooms gate passed"
