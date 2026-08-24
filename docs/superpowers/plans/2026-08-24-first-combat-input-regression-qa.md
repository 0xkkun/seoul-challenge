# First Combat Input Regression QA Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** #545–#549가 병합된 최신 main에서 다섯 사용자 지적과 기존 첫 5분 흐름을 사용자 관점으로 재검증하고 #543을 merge한다.

**Architecture:** 자동 gate를 baseline으로 사용하고, headed Chromium production/fixture UAT를 기능 pass/fail 경로로 사용한다. Android는 좌표 탭 없이 debug APK 설치·launch·landscape/safe-area 시각 증거와 기존 touch 계약 회귀만 담당한다.

**Tech Stack:** Godot 4.6.3, GDScript, gstack browse headed Chromium WebGL2, Android adb visual capture, custom QA report

**Spec:** `docs/superpowers/specs/2026-08-24-first-combat-input-language-design.md`

## Global Constraints

- 기존 GitHub issue `#543`, branch `qa/issue-543-post-merge-regression`, worktree `../seoul-challenge-543`를 사용한다.
- #545, #546, #547, #548, #549가 모두 merge된 뒤 `origin/main`을 branch에 merge한다.
- browser pass/fail은 production signals 또는 test-only fixture marker로 판정한다. screenshot만으로 기능 성공을 주장하지 않는다.
- Android에서 `adb shell input tap`, `tap_pct`, app-private command file, `run-as` write를 사용하지 않는다.
- 발견한 독립 회귀는 severity와 screenshot을 가진 별도 이슈/worktree로 분리한다.
- PR은 ready, assignee, milestone, `P1`, `area:run`, `area:combat`, `area:ui`, inline screenshots를 갖는다.

---

### Task 1: 최신 main baseline과 자동 gate

**Files:**
- Modify: `docs/requirements/2026-08-22-improvement-coverage.md`
- Create/Update locally: `.gstack/qa-reports/qa-report-localhost-2026-08-24.md`
- Create/Update locally: `.gstack/qa-reports/baseline.json`

**Interfaces:**
- Consumes: merged PR SHAs #545–#549
- Produces: exact gate counts와 QA baseline score

- [ ] **Step 1: branch에 최신 main을 merge하고 변경 범위 기록**

```bash
git fetch origin main
git merge origin/main -m "[QA] 첫 전투 입력 변경 최신 main 병합"
git log --first-parent --oneline --decorate -12
git diff d56fd73..HEAD --name-only
```

- [ ] **Step 2: quick/full gate 실행**

```bash
PYTHON_BIN=/opt/homebrew/bin/python3.12 GODOT_BIN=/opt/homebrew/bin/godot bash scripts/verify_quick.sh
PYTHON_BIN=/opt/homebrew/bin/python3.12 GODOT_BIN=/opt/homebrew/bin/godot bash scripts/verify_full.sh
```

Expected: unit, integration, functional, runtime, tooling 모두 0 failed. exact counts를 report에 기록한다.

- [ ] **Step 3: QA report metadata와 baseline 작성**

Report scope는 #545–#549 plus first-five-minute smoke, tier Standard, URL `http://127.0.0.1:8765/`다. baseline category score는 관찰 전 100에서 시작하고 finding마다 gstack rubric을 적용한다.

- [ ] **Step 4: baseline evidence를 coverage ledger에 추가**

행에는 issue/PR/merge SHA, unit/integration/functional/tooling counts, 아직 pending인 Web/Android 칸을 분리한다. Web을 실행하기 전에 완료로 표시하지 않는다.

- [ ] **Step 5: baseline 문서 커밋**

```bash
git add docs/requirements/2026-08-22-improvement-coverage.md
git commit -m "[QA] 첫 전투 입력 회귀 baseline 기록"
```

### Task 2: Release Web production first-run smoke

**Files:**
- Update locally: `.gstack/qa-reports/qa-report-localhost-2026-08-24.md`
- Add screenshots under `.gstack/qa-reports/screenshots/`

**Interfaces:**
- Consumes: production `res://scenes/lobby/lobby.tscn`, real browser keyboard/mouse input
- Produces: production flow evidence, console/page/request error summary

- [ ] **Step 1: release Web export와 local server 시작**

```bash
GODOT_BIN=/opt/homebrew/bin/godot bash scripts/export_web_preview.sh
/opt/homebrew/bin/python3.12 -m http.server 8765 --bind 127.0.0.1 --directory build/web
```

- [ ] **Step 2: headed Chromium WebGL2 확인과 fresh storage 시작**

`document.createElement('canvas').getContext('webgl2') != null`을 단정하고 localStorage/sessionStorage를 비운 뒤 reload한다. console/network buffer도 clear한다.

- [ ] **Step 3: production 첫 런 핵심 경로 실행**

실제 입력 순서:

1. 로비 시작 → 인트로 자동 진행.
2. WASD 실제 이동 ≥96px.
3. 좌클릭 기본 타격.
4. Space keydown/up: 대시·단계 변화 없음.
5. Shift 대시.
6. Shift 직후 좌클릭 강공격.
7. 지도 확대 → 열린 문 → 첫 전투방.

각 단계에서 visual prompt가 `LMB`, `RMB`, `SPACE`를 포함하지 않고 action glyph가 보이는지 기록한다.

- [ ] **Step 4: production RMB aim 실행**

RMB hold + W를 동시에 유지해 이동이 계속되는지, cursor inside/outside reach에서 ring/arc가 clamp되는지, LMB가 cursor direction으로 `attack_executed`를 발생시키는지 확인한다. RMB release는 attack count를 늘리지 않아야 한다.

- [ ] **Step 5: production console/network/performance 기록**

Expected: console/page error 0, HTTP 4xx/5xx 0, WebGL2 true. `perf`와 screenshot timing은 보고서에 기록하되 임의 성능 숫자를 pass 기준으로 만들지 않는다.

- [ ] **Step 6: production screenshots 저장**

```text
production-input-glyphs-960x540.png
production-shift-dash-960x540.png
production-rmb-aim-moving-960x540.png
production-first-combat-960x540.png
```

### Task 3: 결정론 fixture 회귀 매트릭스

**Files:**
- Update locally: `.gstack/qa-reports/qa-report-localhost-2026-08-24.md`
- Add screenshots under `.gstack/qa-reports/screenshots/`

**Interfaces:**
- Consumes: session cleanup, onboarding coachmark, mouse aim, ranged parry fixtures
- Produces: per-contract marker matrix

- [ ] **Step 1: 온보딩 사망 matrix 실행**

```text
session_cleanup: onboarding_death_retry
session_cleanup: onboarding_retry_failure
```

Expected: return hidden, retry visible, same onboarding kind replacement; failure leaves summary retryable.

- [ ] **Step 2: PC/touch prompt와 Shift matrix 실행**

```text
onboarding_coachmark: controls_pc
onboarding_coachmark: controls_touch
onboarding_coachmark: shift_dash_input
```

Expected: PC glyphs, touch fallback, Space false, Shift true, power true.

- [ ] **Step 3: RMB aim 5-mode matrix 실행**

```text
mouse_melee_aim: inside
mouse_melee_aim: clamped
mouse_melee_aim: moving
mouse_melee_aim: release
mouse_melee_aim: ui_hover
```

Expected: every marker `valid=true`; moving ≥96px; clamped distance==reach; release/ui hover hidden.

- [ ] **Step 4: ranged parry 7-mode matrix 실행**

```text
ranged_parry: desktop_prompt
ranged_parry: touch_prompt
ranged_parry: miss
ranged_parry: retry
ranged_parry: success
ranged_parry: completed_hidden
ranged_parry: teardown
```

Expected: miss/retry ranged flag false; success ranged true/wolf false; completed hidden; teardown connections 0.

- [ ] **Step 5: fixture 전체 오류 집계와 최악 상태 캡처**

각 navigation 뒤 console/page/request error를 확인한다. 최소 캡처:

```text
onboarding-death-retry-960x540.png
pc-input-glyphs-960x540.png
mouse-aim-clamped-960x540.png
ranged-parry-prompt-960x540.png
ranged-parry-success-960x540.png
```

### Task 4: Android visual regression

**Files:**
- Update locally: `.gstack/qa-reports/qa-report-localhost-2026-08-24.md`
- Create ignored output: `build/android/afterschool.debug.apk`

**Interfaces:**
- Consumes: connected Android device, `com.oxkkun.afterschool.debug`
- Produces: install/launch/orientation/safe-area screenshots

- [ ] **Step 1: debug APK build**

```bash
mkdir -p build/android
/opt/homebrew/bin/godot --headless --path . --export-debug Android build/android/afterschool.debug.apk
```

- [ ] **Step 2: stale debugger state 제거와 install/launch**

```bash
adb shell am clear-debug-app
adb install -r build/android/afterschool.debug.apk
adb shell monkey -p com.oxkkun.afterschool.debug -c android.intent.category.LAUNCHER 1
```

- [ ] **Step 3: orientation/package/log 검증**

Expected: debug package foreground, landscape render, crash/ANR 0. `adb logcat`의 Godot error를 기록한다. 상호작용 pass/fail에 coordinate tap을 쓰지 않는다.

- [ ] **Step 4: launch와 first visible screen 캡처**

```bash
adb exec-out screencap -p > .gstack/qa-reports/screenshots/android-launch-landscape.png
```

safe-area는 screenshot 시각 검토와 기존 automated `MobileSafeArea`/touch tests를 함께 근거로 사용한다.

### Task 5: finding triage, final report, PR merge

**Files:**
- Modify: `docs/requirements/2026-08-22-improvement-coverage.md`
- Modify: `TODOS.md` only if it already exists and a deferred finding remains
- Update locally: `.gstack/qa-reports/qa-report-localhost-2026-08-24.md`
- Update locally: `.gstack/qa-reports/baseline.json`

**Interfaces:**
- Consumes: all automated/Web/Android evidence
- Produces: health score, issue/fix/deferred counts, ship readiness, merged #543

- [ ] **Step 1: 발견 즉시 severity·repro·screenshot으로 기록**

Standard tier는 critical/high/medium을 수정 대상으로 삼는다. 독립 계약은 새 issue/worktree/PR로 분리하고 #543 report에서 링크한다. low는 deferred로 기록한다.

- [ ] **Step 2: 모든 수정 merge 후 affected matrix 재실행**

최종 score가 baseline보다 낮으면 merge하지 않고 새 finding을 해결한다. 동일하거나 높고 P0/P1/P2 open finding 0일 때만 다음 단계로 간다.

- [ ] **Step 3: coverage ledger와 local QA report 완결**

Report summary는 total issues, verified fixes, deferred, health score delta, console/request counts, Android scope limitation을 포함한다. Ledger는 #545–#549와 #543의 merge/test/UAT evidence를 완결한다.

- [ ] **Step 4: final docs commit**

```bash
git add docs/requirements/2026-08-22-improvement-coverage.md
git commit -m "[QA] 첫 전투 입력 언어 통합 회귀 검수 완료"
```

- [ ] **Step 5: final quick/full gate와 branch diff review**

```bash
PYTHON_BIN=/opt/homebrew/bin/python3.12 GODOT_BIN=/opt/homebrew/bin/godot bash scripts/verify_quick.sh
PYTHON_BIN=/opt/homebrew/bin/python3.12 GODOT_BIN=/opt/homebrew/bin/godot bash scripts/verify_full.sh
git diff --check origin/main...HEAD
```

- [ ] **Step 6: ready PR과 merge loop 완료**

PR title: `[QA] 첫 전투 입력 언어 통합 회귀 검수`

PR body에 exact counts, Web matrix summary, Android visual evidence, health score, inline screenshots, `Closes #543`를 넣는다. current-head Codex·CI green·unresolved 0이면 즉시 merge한다. merge 후 `origin/main`에서 quick gate를 한 번 더 실행해 최종 상태를 기록한다.
