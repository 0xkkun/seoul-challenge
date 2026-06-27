#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"

GODOT="${GODOT_BIN:-godot}"
PRESET="${WEB_PREVIEW_PRESET:-Web}"
OUTPUT_DIR="${WEB_PREVIEW_DIR:-build/web}"

fail() {
  echo "[export_web_preview] FAIL: $1" >&2
  exit 1
}

case "$OUTPUT_DIR" in
  ""|/*|..|../*|*/..|*/../*) fail "WEB_PREVIEW_DIR must be a relative path without '..', got '$OUTPUT_DIR'" ;;
esac

case "$OUTPUT_DIR" in
  build/web|build/web/*) ;;
  *) fail "WEB_PREVIEW_DIR must stay under build/web, got '$OUTPUT_DIR'" ;;
esac

INDEX_PATH="$OUTPUT_DIR/index.html"

command -v "$GODOT" >/dev/null 2>&1 || fail "Godot executable not found: $GODOT"

rm -rf -- "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

echo "[export_web_preview] exporting preset '$PRESET' to $INDEX_PATH"
"$GODOT" --headless --path "$ROOT" --export-release "$PRESET" "$INDEX_PATH"

[ -f "$INDEX_PATH" ] || fail "missing exported index: $INDEX_PATH"

echo "[export_web_preview] OK: $INDEX_PATH"
