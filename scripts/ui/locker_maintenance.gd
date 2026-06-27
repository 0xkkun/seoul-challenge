class_name LockerMaintenance
extends Control

signal return_requested
signal weapon_changed(weapon_id: StringName)
signal departure_requested(stage_id: StringName)

const DungeonTheme := preload("res://scripts/ui/dungeon_ui_theme.gd")
const PixelButton := preload("res://scripts/ui/pixel_button_style.gd")
const MetaUpgradeCatalog := preload("res://scripts/items/meta_upgrade_catalog.gd")
const MobileSafeArea := preload("res://scripts/ui/mobile_safe_area.gd")
const FontRoles := preload("res://scripts/ui/ui_font_roles.gd")

const WEAPON_BAT := &"bat"
const WEAPON_AWAKENED_BAT := &"awakened_bat"
const STAGE_GYEONGBOKGUNG := &"gyeongbokgung"
const STAGE_GYEONGBOKGUNG_NAME := "경복궁"
const BAT_NAME_CRACKED := "마지막 시즌의 배트"
const BAT_NAME_AWAKENED := "마지막 시즌의 배트"
const BAT_DESC_CRACKED := "평범한 야구 방망이다.\n자칫하면 부러질 것 같다."
const BAT_DESC_AWAKENED := "적의 탄을 배트로 되받아친다.\n마지막 시즌의 기억이 깨어났다."

const ACTION_RETURN := "locker_maintenance.return"
const ACTION_SELECT_BAT := "locker_maintenance.weapon.bat"
const ACTION_CYCLE_WEAPON := "locker_maintenance.weapon.cycle"
const ACTION_START_GYEONGBOKGUNG := "locker_maintenance.map"
const ACTION_UPGRADE_PREFIX := "locker_maintenance.upgrade."
const BAT_ICON_PATH := "res://assets/ui/icons/seoul_challenge/baseball_bat.png"
const BG_PATH := "res://assets/backgrounds/locker/locker_maintenance_bg.png"
const SHARD_ICON_PATH := "res://assets/ui/icons/memory_shard.png"

@export var scene_transition_enabled := true

var _selected_weapon_id := WEAPON_BAT
var _weapon_status_label: Label
var _bat_card: Button
var _loadout_panel: PanelContainer
var _weapon_button: Button
var _departure_button: Button
var _return_button: Button
var _upgrade_balance_label: Label
var _upgrade_pip_labels: Dictionary = {}
var _upgrade_cost_labels: Dictionary = {}
var _upgrade_buttons: Dictionary = {}
var _is_departure_requested := false


func _ready() -> void:
	_build_ui()
	select_weapon(_get_initial_weapon_id())
	_refresh_upgrades()


func get_selected_weapon_id() -> StringName:
	return _selected_weapon_id


func get_departure_entry_count() -> int:
	return _count_action_entries(self, ACTION_START_GYEONGBOKGUNG)


func get_weapon_card_icon_path(weapon_id: StringName) -> String:
	var card := _bat_card if weapon_id == WEAPON_BAT else null
	if card == null or card.icon == null:
		return ""
	return card.icon.resource_path


func select_weapon(weapon_id: StringName) -> void:
	if weapon_id != WEAPON_BAT:
		return
	if _selected_weapon_id == weapon_id and _weapon_status_label != null:
		_apply_weapon_card_state()
		return
	_selected_weapon_id = weapon_id
	_apply_weapon_card_state()
	weapon_changed.emit(_selected_weapon_id)


func get_departure_config() -> Dictionary:
	var config := SceneTransition.get_pending_run_config()
	config["source"] = "locker_maintenance"
	config["stage_id"] = STAGE_GYEONGBOKGUNG
	config["stage_name"] = STAGE_GYEONGBOKGUNG_NAME
	config[SceneTransition.RUN_CONFIG_SELECTED_WEAPON_ID] = _selected_weapon_id
	return config


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_build_background()
	_build_title()
	_build_weapon_cards()
	_build_upgrade_panel()
	_build_action_bar()


func _build_background() -> void:
	# 레터박스 여백이 생겨도 테마 안에 머물도록 깊은 베이스를 먼저 깐다.
	var backdrop := ColorRect.new()
	backdrop.name = "Background"
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = DungeonTheme.COLOR_BACKDROP
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	# 밤 복도 + 사물함 플레이트. 비율을 유지하며 화면을 가득 덮는다.
	var photo := TextureRect.new()
	photo.name = "LockerPhoto"
	photo.set_anchors_preset(Control.PRESET_FULL_RECT)
	photo.texture = load(BG_PATH)
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(photo)

	# 전역 스크림 — 사물함 글로우는 살리되 플레이트를 한 톤 가라앉혀 UI와 묶는다.
	var scrim := ColorRect.new()
	scrim.name = "Scrim"
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0.02, 0.03, 0.05, 0.34)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)

	# 좌측 판독 컬럼 — 제목/카드가 복도 위에서도 또렷하게 읽히도록 왼쪽을 더 어둡게 페이드.
	var left_fade := TextureRect.new()
	left_fade.name = "LeftReadingFade"
	left_fade.anchor_left = 0.0
	left_fade.anchor_top = 0.0
	left_fade.anchor_right = 0.6
	left_fade.anchor_bottom = 1.0
	left_fade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	left_fade.stretch_mode = TextureRect.STRETCH_SCALE
	left_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_fade.texture = _linear_fade_texture(
		Color(0.012, 0.018, 0.03, 0.78),
		Color(0.012, 0.018, 0.03, 0.0),
		Vector2(0.0, 0.0),
		Vector2(1.0, 0.0)
	)
	add_child(left_fade)

	# 하단 그라운딩 — 반사된 밝은 바닥을 가라앉혀 하단 출발 버튼이 떠 보이지 않게 한다.
	var bottom_fade := TextureRect.new()
	bottom_fade.name = "BottomGroundingFade"
	bottom_fade.anchor_left = 0.0
	bottom_fade.anchor_top = 0.6
	bottom_fade.anchor_right = 1.0
	bottom_fade.anchor_bottom = 1.0
	bottom_fade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bottom_fade.stretch_mode = TextureRect.STRETCH_SCALE
	bottom_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_fade.texture = _linear_fade_texture(
		Color(0.01, 0.015, 0.025, 0.0),
		Color(0.01, 0.015, 0.025, 0.82),
		Vector2(0.0, 0.0),
		Vector2(0.0, 1.0)
	)
	add_child(bottom_fade)


func _linear_fade_texture(
	from_color: Color, to_color: Color, fill_from: Vector2, fill_to: Vector2
) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, from_color)
	gradient.set_color(1, to_color)
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.width = 16 if fill_to.x == fill_from.x else 256
	tex.height = 256 if fill_to.y == fill_from.y else 16
	tex.fill_from = fill_from
	tex.fill_to = fill_to
	return tex


func _apply_outline(label: Label, size: int) -> void:
	# 배경 플레이트가 분주하므로 어두운 외곽선으로 글자를 떼어 읽기 쉽게 한다.
	label.add_theme_constant_override("outline_size", size)
	label.add_theme_color_override("font_outline_color", Color(0.01, 0.015, 0.025, 0.92))


func _build_title() -> void:
	var title := Label.new()
	title.name = "TitleLabel"
	title.anchor_left = 0.05
	title.anchor_top = 0.045
	title.anchor_right = 0.52
	title.anchor_bottom = 0.13
	title.text = "출정 준비"
	title.add_theme_font_size_override("font_size", 40)
	FontRoles.apply_title(title)
	title.add_theme_color_override("font_color", DungeonTheme.COLOR_GOLD)
	_apply_outline(title, 6)
	add_child(title)

	var subtitle := Label.new()
	subtitle.name = "SubtitleLabel"
	subtitle.anchor_left = 0.05
	subtitle.anchor_top = 0.155
	subtitle.anchor_right = 0.72
	subtitle.anchor_bottom = 0.22
	subtitle.text = "어둠에 들어서기 전, 장비를 점검한다."
	subtitle.add_theme_font_size_override("font_size", 18)
	FontRoles.apply_body(subtitle)
	subtitle.add_theme_color_override("font_color", DungeonTheme.COLOR_MUTED_TEXT)
	_apply_outline(subtitle, 5)
	add_child(subtitle)

	var section := Label.new()
	section.name = "WeaponSectionLabel"
	section.anchor_left = 0.065
	section.anchor_top = 0.215
	section.anchor_right = 0.40
	section.anchor_bottom = 0.27
	section.text = "장비"
	section.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	section.add_theme_font_size_override("font_size", 24)
	FontRoles.apply_title(section)
	section.add_theme_color_override("font_color", Color(0.86, 0.80, 0.62, 1.0))
	_apply_outline(section, 5)
	add_child(section)


func _build_weapon_cards() -> void:
	# 좌측 컬럼: 우측 강화 패널과 같은 상/하단(0.30~0.74)·같은 폭(0.41)으로 맞춘다.
	_bat_card = _make_weapon_card("BatCard", "", Rect2(0.065, 0.29, 0.41, 0.49), ACTION_SELECT_BAT)
	add_child(_bat_card)

	# 키 큰 슬롯이 비지 않도록 [큰 배트 아이콘 · 이름 · 설명]을 세로 중앙 쇼케이스로 채운다.
	var showcase := VBoxContainer.new()
	showcase.name = "WeaponShowcase"
	showcase.anchor_left = 0.1
	showcase.anchor_top = 0.11
	showcase.anchor_right = 0.9
	showcase.anchor_bottom = 0.84
	showcase.alignment = BoxContainer.ALIGNMENT_CENTER
	showcase.add_theme_constant_override("separation", 8)
	showcase.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bat_card.add_child(showcase)

	var icon := TextureRect.new()
	icon.texture = load(BAT_ICON_PATH)
	icon.custom_minimum_size = Vector2(0.0, 78.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	showcase.add_child(icon)

	var weapon_name := Label.new()
	weapon_name.name = "WeaponName"
	weapon_name.text = _bat_display_name()
	weapon_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weapon_name.add_theme_font_size_override("font_size", 23)
	FontRoles.apply_title(weapon_name)
	weapon_name.add_theme_color_override("font_color", Color(0.98, 0.86, 0.55))
	_apply_outline(weapon_name, 4)
	weapon_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	showcase.add_child(weapon_name)

	var weapon_desc := Label.new()
	weapon_desc.name = "WeaponDesc"
	weapon_desc.text = _bat_description()
	weapon_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weapon_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	weapon_desc.add_theme_font_size_override("font_size", 15)
	FontRoles.apply_body(weapon_desc)
	weapon_desc.add_theme_color_override("font_color", DungeonTheme.COLOR_MUTED_TEXT)
	weapon_desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	showcase.add_child(weapon_desc)

	# 선택 피드백은 무기 카드 골드 테두리로 표시하고, 우측 컬럼은 강화 패널에 양보한다.
	# (노드·라벨·텍스트는 UI 계약 테스트를 위해 유지하되 화면에는 숨긴다.)
	_loadout_panel = PanelContainer.new()
	_loadout_panel.name = "LoadoutSummaryPanel"
	_loadout_panel.visible = false
	_loadout_panel.anchor_left = 0.66
	_loadout_panel.anchor_top = 0.255
	_loadout_panel.anchor_right = 0.95
	_loadout_panel.anchor_bottom = 0.40
	_loadout_panel.add_theme_stylebox_override(
		"panel",
		DungeonTheme.framed_panel_style(14.0, 12.0)
	)
	add_child(_loadout_panel)

	_weapon_status_label = Label.new()
	_weapon_status_label.name = "WeaponStatusLabel"
	_weapon_status_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_weapon_status_label.add_theme_font_size_override("font_size", 18)
	FontRoles.apply_pixel(_weapon_status_label)
	_weapon_status_label.add_theme_color_override("font_color", DungeonTheme.COLOR_TEXT)
	_weapon_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_weapon_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_weapon_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_loadout_panel.add_child(_weapon_status_label)


func _build_upgrade_panel() -> void:
	# 좌측 "장비" 컬럼과 대칭: 헤더 라벨 + 잔액 칩은 패널 위에 두고, 패널엔 강화 행만.
	# 헤더 Y와 패널 상/하단을 무기 슬롯과 똑같이 맞춰 두 컬럼이 한 쌍으로 읽히게 한다.
	var header := Label.new()
	header.name = "UpgradeSectionLabel"
	header.anchor_left = 0.525
	header.anchor_top = 0.215
	header.anchor_right = 0.80
	header.anchor_bottom = 0.27
	header.text = "장비 강화"
	header.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 24)
	FontRoles.apply_title(header)
	header.add_theme_color_override("font_color", Color(0.86, 0.80, 0.62, 1.0))
	_apply_outline(header, 5)
	add_child(header)

	# 보유 재화 칩 — 헤더 우측, 제목과 붙어 읽히지 않게 분리.
	var balance_chip := PanelContainer.new()
	balance_chip.name = "BalanceChip"
	balance_chip.anchor_left = 0.83
	balance_chip.anchor_top = 0.222
	balance_chip.anchor_right = 0.935
	balance_chip.anchor_bottom = 0.272
	# 패널과 같은 카드 프레임 패밀리로 — 우측 모서리 라인이 패널/출발 버튼과 일치하게.
	balance_chip.add_theme_stylebox_override(
		"panel",
		DungeonTheme.card_style(10.0, 4.0, Color.WHITE, 16.0)
	)
	add_child(balance_chip)

	# 혼 조각 아이콘 + 보유 수량.
	var balance_box := HBoxContainer.new()
	balance_box.alignment = BoxContainer.ALIGNMENT_CENTER
	balance_box.add_theme_constant_override("separation", 5)
	balance_chip.add_child(balance_box)

	var shard_icon := TextureRect.new()
	shard_icon.texture = load(SHARD_ICON_PATH)
	shard_icon.custom_minimum_size = Vector2(20.0, 20.0)
	shard_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shard_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	shard_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	balance_box.add_child(shard_icon)

	_upgrade_balance_label = Label.new()
	_upgrade_balance_label.name = "UpgradeBalanceLabel"
	_upgrade_balance_label.add_theme_font_size_override("font_size", 19)
	FontRoles.apply_pixel(_upgrade_balance_label)
	_upgrade_balance_label.add_theme_color_override("font_color", DungeonTheme.COLOR_GOLD)
	_upgrade_balance_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	balance_box.add_child(_upgrade_balance_label)

	var panel := PanelContainer.new()
	panel.name = "UpgradePanel"
	panel.unique_name_in_owner = true
	panel.anchor_left = 0.525
	panel.anchor_top = 0.29
	panel.anchor_right = 0.935
	panel.anchor_bottom = 0.78
	# 무기 슬롯과 같은 카드 프레임으로 통일 (얇은 골드 트림 — 팝업 모서리 장식이 행을 가리지 않음).
	panel.add_theme_stylebox_override(
		"panel",
		DungeonTheme.card_style(42.0, 22.0, Color.WHITE)
	)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.name = "UpgradeList"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	for id: StringName in MetaUpgradeCatalog.upgrade_ids():
		vbox.add_child(_make_upgrade_row(id))


func _make_upgrade_row(id: StringName) -> Control:
	var row := HBoxContainer.new()
	row.name = "UpgradeRow_%s" % id
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)

	var name_label := Label.new()
	name_label.text = MetaUpgradeCatalog.display_name(id)
	name_label.add_theme_font_size_override("font_size", 20)
	FontRoles.apply_pixel(name_label)
	name_label.add_theme_color_override("font_color", DungeonTheme.COLOR_TEXT)
	name_label.custom_minimum_size = Vector2(70.0, 0.0)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name_label)

	var pips := RichTextLabel.new()
	pips.bbcode_enabled = true
	pips.fit_content = true
	pips.scroll_active = false
	pips.autowrap_mode = TextServer.AUTOWRAP_OFF
	pips.add_theme_font_size_override("normal_font_size", 20)
	FontRoles.apply_pixel(pips)
	pips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pips)
	_upgrade_pip_labels[id] = pips

	# 비용: 혼 조각 아이콘 + 숫자 (인라인 이미지라 RichTextLabel 사용).
	var cost_label := RichTextLabel.new()
	cost_label.bbcode_enabled = true
	cost_label.fit_content = true
	cost_label.scroll_active = false
	cost_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	cost_label.add_theme_font_size_override("normal_font_size", 19)
	FontRoles.apply_pixel(cost_label)
	cost_label.custom_minimum_size = Vector2(64.0, 0.0)
	cost_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(cost_label)
	_upgrade_cost_labels[id] = cost_label

	var action := ACTION_UPGRADE_PREFIX + String(id)
	var button := Button.new()
	button.name = "UpgradeButton_%s" % id
	button.text = "강화"
	button.focus_mode = Control.FOCUS_NONE
	PixelButton.apply(button, PixelButton.VARIANT_SECONDARY, Vector2(76.0, 50.0))
	FontRoles.apply_pixel(button)
	_set_button_meta(button, "upgrade_%s" % id, action)
	button.pressed.connect(_on_upgrade_pressed.bind(id))
	row.add_child(button)
	_upgrade_buttons[id] = button

	return row


func _refresh_upgrades() -> void:
	if _upgrade_balance_label == null:
		return
	var balance := _permanent_balance()
	_upgrade_balance_label.text = "%d" % balance
	for id: StringName in MetaUpgradeCatalog.upgrade_ids():
		var level := _saved_upgrade_level(id)
		var max_level := MetaUpgradeCatalog.max_level(id)
		var pips := _upgrade_pip_labels.get(id) as RichTextLabel
		var cost_label := _upgrade_cost_labels.get(id) as RichTextLabel
		var button := _upgrade_buttons.get(id) as Button
		if pips != null:
			pips.text = _pip_bbcode(level, max_level)
		var maxed := MetaUpgradeCatalog.is_maxed(id, level)
		var affordable := MetaUpgradeCatalog.can_purchase(id, level, balance)
		if cost_label != null:
			if maxed:
				cost_label.text = ""
			else:
				var col := "f0bb40" if affordable else "9eadba"
				cost_label.text = "[right][img=15]%s[/img] [color=#%s]%d[/color][/right]" % [
					SHARD_ICON_PATH, col, MetaUpgradeCatalog.cost_to_next(id, level)
				]
		if button != null:
			if maxed:
				button.text = "MAX"
				button.disabled = true
			else:
				button.text = "강화"
				button.disabled = not affordable


func _on_upgrade_pressed(id: StringName) -> void:
	var level := _saved_upgrade_level(id)
	var balance := _permanent_balance()
	if not MetaUpgradeCatalog.can_purchase(id, level, balance):
		return
	var cost := MetaUpgradeCatalog.cost_to_next(id, level)
	if not has_node("/root/CurrencySystem"):
		return
	if CurrencySystem.spend_permanent(cost, "meta_upgrade:%s" % String(id)):
		if has_node("/root/SaveManager"):
			SaveManager.set_meta_upgrade_level(id, level + 1)
		_refresh_upgrades()


func _saved_upgrade_level(id: StringName) -> int:
	if has_node("/root/SaveManager"):
		return SaveManager.get_meta_upgrade_level(id)
	return 0


func _permanent_balance() -> int:
	if has_node("/root/CurrencySystem"):
		return CurrencySystem.get_permanent()
	return 0


func _pip_bbcode(level: int, max_level: int) -> String:
	var bb := ""
	for i in range(max_level):
		if i < level:
			bb += "[color=#f5cf6a]●[/color]"
		else:
			bb += "[color=#7a6a3a]○[/color]"
	return bb


func _build_action_bar() -> void:
	# 각 버튼을 자기 컬럼과 같은 폭(0.41)·같은 좌우 모서리에 맞춰 좌우 대칭으로 둔다.
	var return_rect := MobileSafeArea.bottom_anchored_rect(0.065, 0.41, 0.12, 43.0)
	var departure_rect := MobileSafeArea.bottom_anchored_rect(0.525, 0.41, 0.12, 43.0)
	_return_button = _make_action_button("ReturnButton", "이전으로", return_rect, ACTION_RETURN)
	add_child(_return_button)

	_departure_button = _make_action_button("GyeongbokgungButton", "경복궁으로", departure_rect, ACTION_START_GYEONGBOKGUNG)
	add_child(_departure_button)

	_return_button.pressed.connect(_on_return_pressed)
	_departure_button.pressed.connect(_on_departure_pressed)


func _make_weapon_card(node_name: String, text: String, relative_rect: Rect2, action: String) -> Button:
	var card := Button.new()
	card.name = node_name
	card.unique_name_in_owner = true
	card.anchor_left = relative_rect.position.x
	card.anchor_top = relative_rect.position.y
	card.anchor_right = relative_rect.position.x + relative_rect.size.x
	card.anchor_bottom = relative_rect.position.y + relative_rect.size.y
	card.text = text
	if action == ACTION_SELECT_BAT:
		# 아이콘은 왼쪽, 스탯 텍스트는 오른쪽 — 가운데 정렬로 겹치던 문제를 분리한다.
		card.icon = load(BAT_ICON_PATH)
		# 표시는 자식 쇼케이스가 담당. 버튼 자체 아이콘은 계약 테스트용으로만 들고 그리지 않는다.
		card.add_theme_constant_override("icon_max_width", 1)
	card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.focus_mode = Control.FOCUS_NONE
	card.add_theme_font_size_override("font_size", 17)
	FontRoles.apply_pixel(card)
	card.add_theme_color_override("font_color", DungeonTheme.COLOR_TEXT)
	card.add_theme_color_override("font_hover_color", DungeonTheme.COLOR_TEXT)
	card.add_theme_color_override("font_pressed_color", DungeonTheme.COLOR_GOLD)
	card.add_theme_color_override("font_disabled_color", DungeonTheme.COLOR_MUTED_TEXT)
	card.add_theme_stylebox_override("normal", DungeonTheme.slot_style(false))
	card.add_theme_stylebox_override("hover", DungeonTheme.card_style(12.0, 10.0, Color(0.78, 0.95, 1.0)))
	card.add_theme_stylebox_override("pressed", DungeonTheme.card_style(12.0, 10.0, Color(1.0, 0.92, 0.6)))
	card.add_theme_stylebox_override("disabled", DungeonTheme.slot_style(false, true))
	PixelButton.attach_press_sfx(card)
	if action != "":
		_set_button_meta(card, action.replace(".", "_"), action)
		card.pressed.connect(select_weapon.bind(WEAPON_BAT))
	return card


func _make_action_button(node_name: String, text: String, relative_rect: Rect2, action: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.unique_name_in_owner = true
	button.anchor_left = relative_rect.position.x
	button.anchor_top = relative_rect.position.y
	button.anchor_right = relative_rect.position.x + relative_rect.size.x
	button.anchor_bottom = relative_rect.position.y + relative_rect.size.y
	button.text = text
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_font_size_override("font_size", 21)
	button.focus_mode = Control.FOCUS_NONE
	var variant := PixelButton.VARIANT_PRIMARY if action == ACTION_START_GYEONGBOKGUNG else PixelButton.VARIANT_SECONDARY
	var with_press_sfx := action != ACTION_START_GYEONGBOKGUNG
	PixelButton.apply(button, variant, Vector2(0.0, 64.0), with_press_sfx)
	FontRoles.apply_pixel(button)
	_set_button_meta(button, action.replace(".", "_"), action)
	return button


func _set_button_meta(button: Button, test_id_suffix: String, action: String) -> void:
	button.set_meta("test_id", "locker_maintenance.%s" % test_id_suffix)
	button.set_meta("uat_action", action)


func _apply_weapon_card_state() -> void:
	if _bat_card == null or _weapon_status_label == null:
		return
	_bat_card.add_theme_stylebox_override(
		"normal",
		_make_weapon_state_style(true)
	)
	_weapon_status_label.text = "선택한 장비\n\n%s\n\n경복궁으로\n바로 이동" % _bat_display_name()


func _bat_display_name() -> String:
	return BAT_NAME_AWAKENED if _is_awakened_bat_unlocked() else BAT_NAME_CRACKED


func _bat_description() -> String:
	return BAT_DESC_AWAKENED if _is_awakened_bat_unlocked() else BAT_DESC_CRACKED


func _is_awakened_bat_unlocked() -> bool:
	return has_node("/root/ProgressionSystem") and ProgressionSystem.is_weapon_unlocked(WEAPON_AWAKENED_BAT)


func _make_weapon_state_style(selected: bool) -> StyleBox:
	# 무기 슬롯은 텍스처 카드 프레임 + 넉넉한 내부 패딩(아이콘/설명이 테두리에 붙지 않게).
	var trim := Color(1.0, 0.93, 0.62) if selected else Color(0.82, 0.86, 0.93)
	return DungeonTheme.card_style(28.0, 22.0, trim)


func _count_action_entries(node: Node, action: String) -> int:
	var count := 1 if node.get_meta("uat_action", "") == action else 0
	for child: Node in node.get_children():
		count += _count_action_entries(child, action)
	return count


func _on_return_pressed() -> void:
	SceneTransition.clear_pending_run_config()
	return_requested.emit()
	if scene_transition_enabled:
		SceneTransition.go_to_day_lobby()


func _on_cycle_weapon_pressed() -> void:
	select_weapon(WEAPON_BAT)


func _on_departure_pressed() -> void:
	if _is_departure_requested:
		return
	_is_departure_requested = true
	if _departure_button != null:
		_departure_button.disabled = true
	_save_pending_loadout()
	departure_requested.emit(STAGE_GYEONGBOKGUNG)
	if scene_transition_enabled:
		var result := SceneTransition.start_session(get_departure_config())
		if result == OK:
			SceneTransition.clear_pending_run_config()
		else:
			_is_departure_requested = false
			if _departure_button != null:
				_departure_button.disabled = false


func _get_initial_weapon_id() -> StringName:
	return WEAPON_BAT


func _save_pending_loadout() -> void:
	SceneTransition.merge_pending_run_config({
		SceneTransition.RUN_CONFIG_SELECTED_WEAPON_ID: _selected_weapon_id,
	})
