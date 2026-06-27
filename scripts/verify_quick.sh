#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"

GODOT="${GODOT_BIN:-godot}"
# 로컬은 4.6 마이너 라인(4.6.x) 허용 — 4.6.2/4.6.3 혼용 가능. CI는 RECOMMENDED로 고정.
EXPECTED_GODOT_MINOR="4.6"
RECOMMENDED_GODOT_VERSION="4.6.3.stable.official.7d41c59c4"
PYTHON="${PYTHON_BIN:-python3}"
GODOT_USER_HOME="${GODOT_USER_HOME:-$ROOT/test-results/godot-user-home}"

fail() {
  echo "[verify_quick] FAIL: $1" >&2
  exit 1
}

ok() {
  echo "[verify_quick] OK: $1"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "$1 not found. See docs/environment.md."
}

echo "== environment =="
require_cmd git
require_cmd "$PYTHON"
require_cmd "$GODOT"

"$PYTHON" - <<'PY'
import sys
if sys.version_info < (3, 10):
    raise SystemExit("python >= 3.10 required, got " + sys.version.split()[0])
print("[verify_quick] OK: python", sys.version.split()[0])
PY

godot_version="$("$GODOT" --version 2>/dev/null | head -n 1 | tr -d '\r')"
case "$godot_version" in
  "$EXPECTED_GODOT_MINOR".*) ok "Godot $godot_version (line $EXPECTED_GODOT_MINOR)" ;;
  *) fail "expected Godot $EXPECTED_GODOT_MINOR.x (recommended $RECOMMENDED_GODOT_VERSION), got '$godot_version'. Set GODOT_BIN if needed." ;;
esac

echo "== static contract =="
"$PYTHON" scripts/verify_project_contract.py
"$PYTHON" scripts/verify_import_metadata.py
"$PYTHON" scripts/verify_secret_hygiene.py
"$PYTHON" scripts/verify_ui_automation_contract.py
"$PYTHON" scripts/verify_pixel_texture_filters.py
"$PYTHON" scripts/verify_web_preview_contract.py
"$PYTHON" scripts/verify_script_coverage.py

echo "== editor load =="
mkdir -p test-results
mkdir -p "$GODOT_USER_HOME"
HOME="$GODOT_USER_HOME" XDG_DATA_HOME="$GODOT_USER_HOME/.local/share" \
  "$GODOT" --headless --editor --quit --path "$ROOT" > test-results/editor-load.log 2>&1
"$PYTHON" scripts/verify_godot_output.py test-results/editor-load.log
"$PYTHON" scripts/verify_import_metadata.py
ok "headless editor load"

echo "== unit tests =="
bash scripts/godot_headless.sh res://tests/unit/test_runner.tscn

echo "== integration tests =="
bash scripts/godot_headless.sh res://tests/integration/integration_runner.tscn

echo "== quick verification complete =="
ok "quick gate passed"
