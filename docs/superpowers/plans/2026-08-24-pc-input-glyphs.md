# PC Input Glyphs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** PC 온보딩의 개발자 약어를 Kenney 1-bit 입력 그림과 공통 렌더러로 교체한다.

**Architecture:** `InputPromptStrip`이 action id를 TextureRect·키캡·화살표로 렌더링하고, `OnboardingCoachMark`는 `input_actions`가 있을 때 strip을 사용한다. 기존 `key_label` 경로는 모바일과 레거시 호출자를 위한 fallback으로 남긴다.

**Tech Stack:** Godot 4.6.3, GDScript, Kenney Input Prompts Pixel 1-Bit CC0 PNG, custom unit/integration runner, headed Chromium WebGL2

**Spec:** `docs/superpowers/specs/2026-08-24-first-combat-input-language-design.md`

## Global Constraints

- GitHub issue `#546`, branch `feat/issue-546-pc-input-glyphs`, worktree `../seoul-challenge-546`를 `origin/main`에서 생성한다.
- 원본 16×16 PNG는 nearest 정수 배율로만 확대한다.
- 마우스 아이콘은 Kenney pack의 white 1-bit `tile_0077`(좌), `tile_0078`(우)을 이름 있는 파일로 커밋한다.
- `LMB`, `RMB`, `SPACE`를 PC player-facing snapshot·copy에 남기지 않는다.
- 모바일 `key_label`·touch target·`test_id`·`uat_action`을 보존한다.
- 외부 에셋의 `License.txt`와 출처 README를 반드시 함께 커밋한다.
- PR은 ready, assignee, milestone, `P1`, `area:ui`, 렌더링되는 960×540 PC/touch PNG를 갖는다.

---

### Task 1: CC0 에셋을 검증하고 저장소에 추가

**Files:**
- Create: `assets/ui/input_prompts/kenney_pixel_1bit/mouse_left.png`
- Create: `assets/ui/input_prompts/kenney_pixel_1bit/mouse_right.png`
- Create: `assets/ui/input_prompts/kenney_pixel_1bit/LICENSE.txt`
- Create: `assets/ui/input_prompts/kenney_pixel_1bit/README.md`
- Create: corresponding Godot `.import` metadata
- Modify: `tests/unit/test_onboarding_coach_mark.gd`

**Interfaces:**
- Consumes: Kenney archive SHA-256 `c3389d26a51636370efc912710865c7e9ba25564868bbcb59ec3160fcddef1ad`
- Produces: stable resource paths for left/right mouse prompt textures

- [ ] **Step 1: 에셋·라이선스 실패 테스트 작성**

```gdscript
const INPUT_PROMPT_ROOT := "res://assets/ui/input_prompts/kenney_pixel_1bit"


func test_pc_input_prompt_assets_are_importable_and_licensed() -> void:
	for file_name: String in ["mouse_left.png", "mouse_right.png"]:
		var path := "%s/%s" % [INPUT_PROMPT_ROOT, file_name]
		_runner.assert_true(ResourceLoader.exists(path), "%s is importable" % file_name)
		_runner.assert_not_null(load(path) as Texture2D, "%s loads as Texture2D" % file_name)
	_runner.assert_true(FileAccess.file_exists("%s/LICENSE.txt" % INPUT_PROMPT_ROOT), "CC0 license ships with assets")
	_runner.assert_true(FileAccess.file_exists("%s/README.md" % INPUT_PROMPT_ROOT), "asset provenance is recorded")
```

- [ ] **Step 2: unit runner에서 resource 단정이 FAIL인지 확인**

```bash
GODOT_BIN=/opt/homebrew/bin/godot PYTHON_BIN=/opt/homebrew/bin/python3.12 \
  bash scripts/godot_headless.sh res://tests/unit/test_runner.tscn
```

Expected: 두 PNG와 license/README가 없어서 FAIL.

- [ ] **Step 3: 공식 archive를 checksum 검증 후 선택 파일만 복사**

```bash
asset_tmp=$(mktemp -d)
curl -fsSL 'https://kenney.nl/media/pages/assets/input-prompts-pixel-1-bit/ba3f0202e6-1774771290/kenney_input-prompts-pixel-1-bit.zip' -o "$asset_tmp/input.zip"
actual_sha=$(shasum -a 256 "$asset_tmp/input.zip" | awk '{print $1}')
test "$actual_sha" = 'c3389d26a51636370efc912710865c7e9ba25564868bbcb59ec3160fcddef1ad'
unzip -q "$asset_tmp/input.zip" -d "$asset_tmp/unpacked"
mkdir -p assets/ui/input_prompts/kenney_pixel_1bit
cp "$asset_tmp/unpacked/Tiles (White)/tile_0077.png" assets/ui/input_prompts/kenney_pixel_1bit/mouse_left.png
cp "$asset_tmp/unpacked/Tiles (White)/tile_0078.png" assets/ui/input_prompts/kenney_pixel_1bit/mouse_right.png
cp "$asset_tmp/unpacked/License.txt" assets/ui/input_prompts/kenney_pixel_1bit/LICENSE.txt
```

`README.md`에는 다음 값을 그대로 기록한다.

```markdown
# Kenney Input Prompts Pixel 1-Bit

- Source: https://kenney.nl/assets/input-prompts-pixel-1-bit
- License: Creative Commons CC0
- Archive SHA-256: `c3389d26a51636370efc912710865c7e9ba25564868bbcb59ec3160fcddef1ad`
- `mouse_left.png`: upstream `Tiles (White)/tile_0077.png`, SHA-256 `874a1c0b583accf284c8c24f5ab58befe07b8659a9dd8efb658dd37a1fe82b3d`
- `mouse_right.png`: upstream `Tiles (White)/tile_0078.png`, SHA-256 `5a8ffd6ad0eb79709b9a5d67e593368ff9f69468758e2ba11dcb6bb34d056d70`
```

Godot editor import를 한 번 실행해 `.import` metadata를 생성한다.

- [ ] **Step 4: unit runner와 import metadata 검증 실행**

```bash
/opt/homebrew/bin/godot --headless --editor --quit --path .
/opt/homebrew/bin/python3.12 scripts/verify_import_metadata.py
GODOT_BIN=/opt/homebrew/bin/godot PYTHON_BIN=/opt/homebrew/bin/python3.12 bash scripts/godot_headless.sh res://tests/unit/test_runner.tscn
```

Expected: asset/license test PASS, import hygiene PASS.

- [ ] **Step 5: 에셋 provenance 커밋**

```bash
git add assets/ui/input_prompts/kenney_pixel_1bit tests/unit/test_onboarding_coach_mark.gd
git commit -m "[UI] Kenney 입력 글리프 에셋과 라이선스 추가"
```

### Task 2: `InputPromptStrip` deep module 구현

**Files:**
- Create: `scripts/ui/input_prompt_strip.gd`
- Create: `scripts/ui/input_prompt_strip.gd.uid`
- Create: `tests/unit/test_input_prompt_strip.gd`
- Modify: `tests/unit/test_runner.tscn` only if the runner does not auto-discover the new file

**Interfaces:**
- Consumes: `actions: Array[StringName]`, `input_mode: StringName`
- Produces: `configure(actions, input_mode)`, `get_snapshot()`, stable glyph rows

- [ ] **Step 1: action rendering 실패 테스트 작성**

```gdscript
const StripScript := preload("res://scripts/ui/input_prompt_strip.gd")


func test_desktop_strip_renders_mouse_sequence_and_shift_keycap() -> void:
	var strip := StripScript.new()
	add_child(strip)
	strip.configure([&"aim_hold", &"attack", &"dash"], &"desktop")
	var snapshot: Dictionary = strip.get_snapshot()
	_runner.assert_eq(snapshot["actions"], [&"aim_hold", &"attack", &"dash"])
	_runner.assert_eq(snapshot["texture_paths"], [
		"res://assets/ui/input_prompts/kenney_pixel_1bit/mouse_right.png",
		"res://assets/ui/input_prompts/kenney_pixel_1bit/mouse_left.png",
	])
	_runner.assert_eq(snapshot["keycaps"], ["SHIFT"])
	_runner.assert_eq(snapshot["texture_filter"], CanvasItem.TEXTURE_FILTER_NEAREST)
	_runner.assert_false(snapshot["visible_copy"].contains("LMB"))
	_runner.assert_false(snapshot["visible_copy"].contains("RMB"))
	_runner.assert_false(snapshot["visible_copy"].contains("SPACE"))


func test_touch_mode_hides_pc_strip() -> void:
	var strip := StripScript.new()
	add_child(strip)
	strip.configure([&"attack"], &"touch")
	_runner.assert_false(strip.visible)
```

- [ ] **Step 2: unit runner에서 script/resource FAIL 확인**

Run: Task 1 Step 2.

Expected: `input_prompt_strip.gd` preload 실패 또는 method missing FAIL.

- [ ] **Step 3: 최소 renderer 구현**

```gdscript
class_name InputPromptStrip
extends HBoxContainer

const MOUSE_LEFT := preload("res://assets/ui/input_prompts/kenney_pixel_1bit/mouse_left.png")
const MOUSE_RIGHT := preload("res://assets/ui/input_prompts/kenney_pixel_1bit/mouse_right.png")
const ICON_SIZE := Vector2(48.0, 48.0)

var _actions: Array[StringName] = []
var _texture_paths: Array[String] = []
var _keycaps: Array[String] = []


func configure(actions: Array[StringName], input_mode: StringName) -> void:
	_actions = actions.duplicate()
	_clear_children()
	visible = input_mode == &"desktop" and not _actions.is_empty()
	if not visible:
		return
	for index: int in _actions.size():
		if index > 0:
			_add_arrow()
		_add_action(_actions[index])


func _add_action(action: StringName) -> void:
	match action:
		&"move":
			_add_wasd_cluster()
		&"primary_click":
			_add_texture(MOUSE_LEFT, MOUSE_LEFT.resource_path)
		&"aim_hold":
			_add_texture(MOUSE_RIGHT, MOUSE_RIGHT.resource_path)
		&"attack":
			_add_texture(MOUSE_LEFT, MOUSE_LEFT.resource_path)
		&"dash":
			_add_keycap("SHIFT")
		_:
			push_error("Unknown input prompt action: %s" % action)


func _clear_children() -> void:
	_texture_paths.clear()
	_keycaps.clear()
	for child: Node in get_children():
		child.free()


func _add_texture(texture: Texture2D, path: String) -> void:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.custom_minimum_size = ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon)
	_texture_paths.append(path)


func _add_keycap(text: String) -> void:
	var panel := PanelContainer.new()
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	add_child(panel)
	_keycaps.append(text)


func _add_wasd_cluster() -> void:
	var cluster := GridContainer.new()
	cluster.columns = 3
	for text: String in ["", "W", "", "A", "S", "D"]:
		var key := Label.new()
		key.text = text
		cluster.add_child(key)
	add_child(cluster)
	_keycaps.append("WASD")


func _add_arrow() -> void:
	var arrow := Label.new()
	arrow.text = "→"
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(arrow)


func get_snapshot() -> Dictionary:
	return {
		"actions": _actions.duplicate(),
		"texture_paths": _texture_paths.duplicate(),
		"keycaps": _keycaps.duplicate(),
		"visible_copy": " ".join(_keycaps),
		"texture_filter": CanvasItem.TEXTURE_FILTER_NEAREST,
	}
```

W/A/S/D와 Shift의 PanelContainer/Label에는 `OnboardingVisualTokens`의 먹색·상아색·금색을 적용하고 `UiFontRoles.apply_pixel()`을 호출한다. 위 코드는 구조를 고정하며 style 적용도 같은 helper 안에서 완성한다.

- [ ] **Step 4: 새 unit file을 포함해 runner PASS 확인**

Run: Task 1 Step 2.

Expected: 새 strip tests PASS, 기존 tests 0 failed.

- [ ] **Step 5: renderer 커밋**

```bash
git add scripts/ui/input_prompt_strip.gd scripts/ui/input_prompt_strip.gd.uid tests/unit/test_input_prompt_strip.gd tests/unit/test_runner.tscn
git commit -m "[UI] 공통 PC 입력 글리프 렌더러 추가"
```

### Task 3: Coachmark와 첫 조작 flow에 글리프 연결

**Files:**
- Modify: `scripts/ui/onboarding_coach_mark.gd:20-225`
- Modify: `scripts/ui/ingame_control_onboarding.gd:25-115`
- Modify: `scripts/cutscene/night_intro_cutscene.gd:60-125`
- Modify: `scripts/cutscene/night_intro_cutscene.gd:230-265`
- Modify: `tests/unit/test_onboarding_coach_mark.gd`
- Modify: `tests/unit/test_touch_input.gd:210-270`
- Modify: `tests/unit/test_night_intro_cutscene.gd:195-215`
- Modify: `tests/unit/test_ui_font_roles.gd:130-145`
- Modify: `tests/uat/onboarding_coachmark_web_fixture.gd:140-160`

**Interfaces:**
- Consumes: prompt model `input_actions: Array[StringName]`, `input_mode`
- Produces: Coachmark snapshot `input_actions`, `input_strip_visible`, `input_texture_paths`, `input_keycaps`

- [ ] **Step 1: PC glyph와 mobile fallback 실패 테스트 작성**

```gdscript
func test_desktop_coach_uses_glyph_strip_without_key_abbreviations() -> void:
	var coach := _new_coach()
	coach.call("show_prompt", {
		"id": &"aim_attack",
		"input_mode": &"desktop",
		"input_actions": [&"aim_hold", &"attack"],
		"action": "조준하고 타격",
	})
	var snapshot: Dictionary = coach.call("get_snapshot")
	_runner.assert_true(snapshot["input_strip_visible"])
	_runner.assert_eq(snapshot["input_actions"], [&"aim_hold", &"attack"])
	_runner.assert_eq(snapshot["key_label"], "")


func test_mobile_coach_keeps_existing_key_label_fallback() -> void:
	var coach := _new_coach()
	coach.call("show_prompt", {
		"id": &"touch_attack",
		"input_mode": &"touch",
		"key_label": "공격 버튼",
		"action": "공격",
	})
	var snapshot: Dictionary = coach.call("get_snapshot")
	_runner.assert_false(snapshot["input_strip_visible"])
	_runner.assert_eq(snapshot["key_label"], "공격 버튼")
```

`test_touch_input.gd`의 desktop step 기대값은 다음으로 바꾼다.

```gdscript
_runner.assert_eq(move_snapshot["input_actions"], [&"move"])
_runner.assert_eq(attack_snapshot["input_actions"], [&"attack"])
_runner.assert_eq(dash_snapshot["input_actions"], [&"dash"])
_runner.assert_eq(power_snapshot["input_actions"], [&"dash", &"attack"])
```

`test_night_intro_cutscene.gd`는 인트로 desktop hint까지 같은 계약으로 묶는다.

```gdscript
func test_intro_advance_hint_uses_mouse_glyph_without_lmb_copy() -> void:
	var intro := NightIntroCutscene.new()
	add_child(intro)
	var desktop: Dictionary = intro.call("advance_hint_model_for_mode", &"desktop")
	var touch: Dictionary = intro.call("advance_hint_model_for_mode", &"touch")
	_runner.assert_eq(desktop["input_actions"], [&"primary_click"])
	_runner.assert_eq(desktop["label"], "계속")
	_runner.assert_false(String(desktop).contains("LMB"))
	_runner.assert_eq(touch["input_actions"], [])
	_runner.assert_eq(touch["label"], "탭하여 계속")
```

- [ ] **Step 2: unit runner에서 기존 text-only 구현이 FAIL인지 확인**

Run: Task 1 Step 2.

Expected: input strip snapshot key가 없어 FAIL.

- [ ] **Step 3: Coachmark optional strip host와 desktop step models 구현**

`OnboardingCoachMark._build_ui()`는 `_key_panel` 옆에 `InputPromptStrip`을 만들고, `_render_model()`에서 desktop `input_actions`가 있으면 strip만 보인다. mobile/legacy model은 기존 `_key_panel`만 보인다.

`IngameControlOnboarding._refresh_step()`는 coach model에 다음 두 필드를 항상 전달한다.

```gdscript
"input_mode": _input_mode,
"input_actions": step.get("input_actions", []),
```

`NightIntroCutscene`은 기존 `_hint: Label`을 `_hint: PanelContainer`로 바꾸고 내부에 `HintRow/HBoxContainer`, `HintStrip/InputPromptStrip`, `HintLabel/Label`을 둔다. desktop model은 `input_actions=[&"primary_click"]`, label `계속`; touch model은 strip을 숨기고 label `탭하여 계속`을 사용한다. 기존 `AdvanceHint` node name, safe-area offsets, modulate tween, `get_advance_hint_reference_rect()` 계약은 유지한다.

```gdscript
static func advance_hint_model_for_mode(input_mode: StringName) -> Dictionary:
	if input_mode == InputPromptPolicy.MODE_TOUCH:
		return {"input_actions": [], "label": "탭하여 계속"}
	return {"input_actions": [&"primary_click"], "label": "계속"}


func render_advance_hint(input_mode: StringName) -> void:
	var model := advance_hint_model_for_mode(input_mode)
	_hint_strip.configure(model["input_actions"], input_mode)
	_hint_label.text = model["label"]
```

기존 type-specific consumer도 같은 commit에서 migration한다.

```gdscript
# onboarding_coachmark_web_fixture.gd
intro.render_advance_hint(&"touch" if touch_mode else &"desktop")
var hint := intro.get_node("AdvanceHint") as PanelContainer
hint.modulate.a = 1.0

# test_ui_font_roles.gd
_assert_font(
	intro.get_node("AdvanceHint/HintRow/HintLabel") as Control,
	&"font",
	UiFontRolesScript.PIXEL_FONT_PATH,
	"intro advance hint label uses pixel font",
)
```

Desktop steps:

```gdscript
const DESKTOP_STEPS := [
	{"id": &"move", "input_actions": [&"move"], "action": "방 안을 둘러봐"},
	{"id": &"attack", "input_actions": [&"attack"], "action": "타격"},
	{"id": &"dash", "input_actions": [&"dash"], "action": "회피"},
	{"id": &"power_attack", "input_actions": [&"dash", &"attack"], "action": "강하게 타격"},
	{"id": &"minimap", "key_label": "미니맵 클릭", "action": "지도 펼치기"},
	{"id": &"exit", "key_label": "", "action": "열린 문으로 이동"},
]
```

compact legend도 Label 한 줄 대신 `InputPromptStrip` + 한국어 action Labels를 사용한다.

- [ ] **Step 4: unit runner와 quick gate 실행**

```bash
GODOT_BIN=/opt/homebrew/bin/godot PYTHON_BIN=/opt/homebrew/bin/python3.12 bash scripts/godot_headless.sh res://tests/unit/test_runner.tscn
PYTHON_BIN=/opt/homebrew/bin/python3.12 GODOT_BIN=/opt/homebrew/bin/godot bash scripts/verify_quick.sh
```

Expected: unit/integration 0 failed, UI automation and texture filter gates PASS.

- [ ] **Step 5: coachmark 연결 커밋**

```bash
git add scripts/ui/onboarding_coach_mark.gd scripts/ui/ingame_control_onboarding.gd scripts/cutscene/night_intro_cutscene.gd tests/unit/test_onboarding_coach_mark.gd tests/unit/test_touch_input.gd tests/unit/test_night_intro_cutscene.gd tests/unit/test_ui_font_roles.gd tests/uat/onboarding_coachmark_web_fixture.gd
git commit -m "[UI] 첫 PC 조작 안내를 입력 글리프로 교체"
```

### Task 4: Release Web 시각 검증과 merge

**Files:**
- Modify: `tests/uat/onboarding_coachmark_web_fixture.gd`
- Modify: `tests/uat/README.md`
- Modify: `docs/requirements/2026-08-22-improvement-coverage.md`

**Interfaces:**
- Consumes: `uat_coachmark_mode=controls_pc|controls_touch`
- Produces: glyph snapshot marker, PC/touch raw screenshots

- [ ] **Step 1: fixture marker에 glyph 계약 추가**

```gdscript
print("UAT_COACHMARK_READY mode=%s surface=%s input_actions=%s texture_count=%d keycaps=%s legacy_key=%s valid=%s" % [
	_mode,
	snapshot.get("surface", &""),
	str(snapshot.get("input_actions", [])),
	(snapshot.get("input_texture_paths", []) as Array).size(),
	str(snapshot.get("input_keycaps", [])),
	String(snapshot.get("key_label", "")),
	str(valid).to_lower(),
])
```

PC는 `input_strip_visible=true`, touch는 `input_strip_visible=false`와 기존 target/key label을 요구한다.

- [ ] **Step 2: full gate 실행**

```bash
PYTHON_BIN=/opt/homebrew/bin/python3.12 GODOT_BIN=/opt/homebrew/bin/godot bash scripts/verify_full.sh
```

Expected: 모든 suite 0 failed.

- [ ] **Step 3: headed Chromium WebGL2에서 PC/touch fixture 검증**

```text
http://127.0.0.1:8765/?uat_coachmark_mode=controls_pc
http://127.0.0.1:8765/?uat_coachmark_mode=controls_touch
```

Expected: `valid=true`, WebGL2 true, console/page/request error 0.

- [ ] **Step 4: 960×540 raw screenshots 캡처**

```text
pc-input-glyphs-960x540.png
touch-input-controls-regression-960x540.png
```

- [ ] **Step 5: UAT evidence 커밋**

```bash
git add tests/uat/onboarding_coachmark_web_fixture.gd tests/uat/README.md docs/requirements/2026-08-22-improvement-coverage.md
git commit -m "[QA] PC 입력 글리프 Web 증거 추가"
```

- [ ] **Step 6: ready PR과 merge loop 완료**

PR title: `[UI] PC 입력 글리프 에셋과 렌더러 도입`

PR body에 Kenney CC0 출처, asset SHA-256, exact test counts, PC/touch inline PNG, `Closes #546`를 기록한다. current-head Codex·CI green·unresolved 0이면 즉시 merge한다.
