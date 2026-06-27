#!/usr/bin/env bash
#
# deploy.sh — 방과후요괴뎐 Web 빌드를 itch.io로 한 방에 배포
#
# 사용법:
#   ./deploy.sh            # 버전 자동 생성 (dev-YYYYMMDD-HHMM)
#   ./deploy.sh 0.1.1      # 버전 직접 지정
#
# 사전 준비 (최초 1회): 진짜 터미널에서 `butler login` 한 번
#
set -euo pipefail

# ── 설정 ─────────────────────────────────────────────
EXPORT_PRESET="Web"
WEB_DIR="build/web"
ITCH_TARGET="Ferv0r2/afterschool:html"
# ────────────────────────────────────────────────────

cd "$(dirname "$0")"

VERSION="${1:-dev-$(date +%Y%m%d-%H%M)}"

# 의존성 확인
command -v godot  >/dev/null || { echo "❌ godot 가 PATH에 없습니다."; exit 1; }
command -v butler >/dev/null || { echo "❌ butler 가 PATH에 없습니다."; exit 1; }

echo "▶ [1/2] Web 빌드 export 중... (preset: $EXPORT_PRESET)"
mkdir -p "$WEB_DIR"
godot --headless --export-release "$EXPORT_PRESET" "$WEB_DIR/index.html"

# export 결과 검증
if [[ ! -f "$WEB_DIR/index.html" || ! -f "$WEB_DIR/index.wasm" ]]; then
  echo "❌ export 산출물이 없습니다 ($WEB_DIR/index.html). 빌드 실패."
  exit 1
fi
echo "  ✓ 빌드 완료: $(du -sh "$WEB_DIR" | cut -f1)"

echo "▶ [2/2] itch.io 로 push 중... (target: $ITCH_TARGET, version: $VERSION)"
butler push "$WEB_DIR" "$ITCH_TARGET" --userversion "$VERSION"

echo ""
echo "✅ 배포 완료!  버전: $VERSION"
echo "   처리 상태:  butler status $ITCH_TARGET"
echo "   플레이 URL: https://ferv0r2.itch.io/afterschool"
