extends Node

const UiFontRolesScript := preload("res://scripts/ui/ui_font_roles.gd")
const SessionUiScene := preload("res://scenes/ui/session_ui_root.tscn")
const HubDialogueScene := preload("res://scenes/ui/hub_dialogue_ui.tscn")
const LockerMaintenanceScene := preload("res://scenes/ui/locker_maintenance.tscn")
const NightMapSelectScene := preload("res://scenes/ui/night_map_select.tscn")
const SettingsUiScene := preload("res://scenes/ui/settings_ui.tscn")
const ConfirmModalScene := preload("res://scenes/ui/confirm_modal.tscn")
const NightIntroCutsceneScript := preload("res://scripts/cutscene/night_intro_cutscene.gd")
const FONT_LICENSE_NOTICE_PATHS: Array[String] = [
	"res://assets/fonts/licenses/NeoDunggeunmoPro-NOTICE.txt",
	"res://assets/fonts/licenses/ChosunCentennial-LICENSE.txt",
	"res://assets/fonts/licenses/RIDIBatang-NOTICE.txt",
]

var _runner: Node
var _nodes: Array[Node] = []


func _set_runner(runner: Node) -> void:
	_runner = runner


func after_each() -> void:
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()


func test_font_assets_and_project_theme_are_importable() -> void:
	_runner.assert_true(ResourceLoader.exists(UiFontRolesScript.PIXEL_FONT_PATH), "pixel font imports")
	_runner.assert_true(ResourceLoader.exists(UiFontRolesScript.TITLE_FONT_PATH), "title font imports")
	_runner.assert_true(ResourceLoader.exists(UiFontRolesScript.BODY_FONT_PATH), "body font imports")
	_runner.assert_true(FileAccess.file_exists("%s.import" % UiFontRolesScript.PIXEL_FONT_PATH), "pixel font import metadata is committed")
	_runner.assert_true(FileAccess.file_exists("%s.import" % UiFontRolesScript.TITLE_FONT_PATH), "title font import metadata is committed")
	_runner.assert_true(FileAccess.file_exists("%s.import" % UiFontRolesScript.BODY_FONT_PATH), "body font import metadata is committed")
	for notice_path: String in FONT_LICENSE_NOTICE_PATHS:
		_runner.assert_true(FileAccess.file_exists(notice_path), "%s is committed" % notice_path)
	_runner.assert_eq(
		ProjectSettings.get_setting("gui/theme/custom", ""),
		"res://assets/themes/seoul_theme.tres",
		"project uses the Seoul font theme"
	)

	var theme := load("res://assets/themes/seoul_theme.tres") as Theme
	_runner.assert_not_null(theme, "Seoul theme loads")
	if theme == null:
		return
	var default_font := theme.get_default_font()
	_runner.assert_not_null(default_font, "Seoul theme has a default font")
	if default_font == null:
		return
	_runner.assert_eq(default_font.resource_path, UiFontRolesScript.PIXEL_FONT_PATH, "default theme font is NeoDunggeunmo")


func test_role_helper_applies_label_and_rich_text_fonts() -> void:
	var label := Label.new()
	var rich := RichTextLabel.new()
	_nodes.append(label)
	_nodes.append(rich)

	UiFontRolesScript.apply_title(label)
	UiFontRolesScript.apply_body(rich)

	_assert_font(label, &"font", UiFontRolesScript.TITLE_FONT_PATH, "Label title role uses ChosunCentennial")
	_assert_font(rich, &"normal_font", UiFontRolesScript.BODY_FONT_PATH, "RichTextLabel body role uses RIDIBatang")
	_assert_rich_text_role_fonts(rich, UiFontRolesScript.BODY_FONT_PATH, "RichTextLabel BBCode fonts use RIDIBatang")
	_runner.assert_eq(UiFontRolesScript.role_font_path(UiFontRolesScript.ROLE_PIXEL), UiFontRolesScript.PIXEL_FONT_PATH, "pixel role path is stable")
	_runner.assert_eq(UiFontRolesScript.role_font_path(UiFontRolesScript.ROLE_TITLE), UiFontRolesScript.TITLE_FONT_PATH, "title role path is stable")
	_runner.assert_eq(UiFontRolesScript.role_font_path(UiFontRolesScript.ROLE_BODY), UiFontRolesScript.BODY_FONT_PATH, "body role path is stable")


func test_session_summary_and_reward_choices_use_font_roles() -> void:
	var ui = _add_node(SessionUiScene.instantiate())

	_assert_font(ui.get_node("%MapTabButton") as Control, &"font", UiFontRolesScript.PIXEL_FONT_PATH, "session map tab uses pixel font")
	_assert_font(ui.get_node("%ResultTitleLabel") as Control, &"font", UiFontRolesScript.TITLE_FONT_PATH, "session result title uses title font")
	_assert_font(ui.get_node("%NarrativeLabel") as Control, &"font", UiFontRolesScript.BODY_FONT_PATH, "session narrative uses body font")
	_assert_font(ui.get_node("%MemoryAmountLabel") as Control, &"font", UiFontRolesScript.PIXEL_FONT_PATH, "session reward amount uses pixel font")

	ui.show_reward_choices(&"combat_1", [
		{"item_id": &"gung_talisman", "display_name": "강타 부적", "effect": "근접 피해 +1"},
	])
	var reward_title := ui.get_node("Root/RewardChoiceOverlay/RewardChoiceTitle") as Label
	var reward_card_title := ui.find_child("RewardTitleLabel", true, false) as Label
	var reward_card_effect := ui.find_child("RewardEffectLabel", true, false) as Label
	_assert_font(reward_title, &"font", UiFontRolesScript.TITLE_FONT_PATH, "reward overlay title uses title font")
	_assert_font(reward_card_title, &"font", UiFontRolesScript.TITLE_FONT_PATH, "reward item name uses title font")
	_assert_font(reward_card_effect, &"font", UiFontRolesScript.PIXEL_FONT_PATH, "reward effect line uses pixel font")


func test_hub_dialogue_uses_title_body_and_pixel_roles() -> void:
	var ui = _add_node(HubDialogueScene.instantiate())

	_assert_font(ui.get_node("%NameLabel") as Control, &"font", UiFontRolesScript.TITLE_FONT_PATH, "speaker name uses title font")
	_assert_font(ui.get_node("%DialogueLabel") as Control, &"normal_font", UiFontRolesScript.BODY_FONT_PATH, "dialogue text uses body font")
	_assert_rich_text_role_fonts(ui.get_node("%DialogueLabel") as RichTextLabel, UiFontRolesScript.BODY_FONT_PATH, "dialogue BBCode text uses body font")
	_assert_font(ui.get_node("%MemoryLabel") as Control, &"font", UiFontRolesScript.BODY_FONT_PATH, "memory line uses body font")
	_assert_font(ui.get_node("%StageRow").get_child(0) as Control, &"font", UiFontRolesScript.PIXEL_FONT_PATH, "stage chip uses pixel font")
	_assert_font(ui.get_node("%ChoiceRow").get_child(0) as Control, &"font", UiFontRolesScript.PIXEL_FONT_PATH, "dialogue choice uses pixel font")

	var unlock_items: Array[Dictionary] = [
		{"id": &"awakened_bat", "name": "마지막 시즌의 배트"},
	]
	ui.show_unlock("마지막 시즌의 배트", "적의 탄을 배트로 되받아친다", unlock_items)
	_assert_font(ui.get_node("%UnlockTitleLabel") as Control, &"font", UiFontRolesScript.TITLE_FONT_PATH, "unlock title uses title font")
	_assert_font(ui.get_node("%UnlockSubtitleLabel") as Control, &"font", UiFontRolesScript.BODY_FONT_PATH, "unlock subtitle uses body font")
	var unlock_grid := ui.get_node("%UnlockItemGrid") as GridContainer
	var item_panel := unlock_grid.get_child(0)
	var item_row := item_panel.get_child(0)
	var item_label := item_row.get_child(1) as Label
	_assert_font(item_label, &"font", UiFontRolesScript.PIXEL_FONT_PATH, "unlock item label uses pixel font")


func test_locker_and_night_map_screens_use_font_roles() -> void:
	var locker = _add_node(LockerMaintenanceScene.instantiate())
	locker.set("scene_transition_enabled", false)
	_assert_font(locker.get_node("TitleLabel") as Control, &"font", UiFontRolesScript.TITLE_FONT_PATH, "locker title uses title font")
	_assert_font(locker.get_node("SubtitleLabel") as Control, &"font", UiFontRolesScript.BODY_FONT_PATH, "locker subtitle uses body font")
	_assert_font(locker.get_node("WeaponSectionLabel") as Control, &"font", UiFontRolesScript.TITLE_FONT_PATH, "weapon section title uses title font")
	_assert_font(locker.get_node("BatCard") as Control, &"font", UiFontRolesScript.PIXEL_FONT_PATH, "weapon card uses pixel font")
	_assert_font(locker.find_child("UpgradeBalanceLabel", true, false) as Control, &"font", UiFontRolesScript.PIXEL_FONT_PATH, "upgrade balance uses pixel font")

	var map = _add_node(NightMapSelectScene.instantiate())
	map.set("scene_transition_enabled", false)
	_assert_font(map.get_node("TitleLabel") as Control, &"font", UiFontRolesScript.TITLE_FONT_PATH, "night map title uses title font")
	_assert_font(map.get_node("SubtitleLabel") as Control, &"font", UiFontRolesScript.BODY_FONT_PATH, "night map subtitle uses body font")
	_assert_font(map.get_node("RouteMapPanel/MapLabel") as Control, &"font", UiFontRolesScript.BODY_FONT_PATH, "route map copy uses body font")
	_assert_font(map.get_node("DestinationPanel/DestinationLabel") as Control, &"font", UiFontRolesScript.BODY_FONT_PATH, "destination copy uses body font")
	_assert_font(map.get_node("GyeongbokgungButton") as Control, &"font", UiFontRolesScript.PIXEL_FONT_PATH, "departure CTA uses pixel font")


func test_modal_settings_and_intro_roles() -> void:
	var settings = _add_node(SettingsUiScene.instantiate())
	_assert_font(settings.get_node("Root/Panel/Margin/Stack/TitleLabel") as Control, &"font", UiFontRolesScript.TITLE_FONT_PATH, "settings title uses title font")
	_assert_font(settings.get_node("%CloseButton") as Control, &"font", UiFontRolesScript.PIXEL_FONT_PATH, "settings close uses pixel font")

	var confirm = _add_node(ConfirmModalScene.instantiate())
	_assert_font(confirm.get_node("%MessageLabel") as Control, &"font", UiFontRolesScript.BODY_FONT_PATH, "confirm message uses body font")
	_assert_font(confirm.get_node("%YesButton") as Control, &"font", UiFontRolesScript.PIXEL_FONT_PATH, "confirm yes uses pixel font")

	var intro = _add_node(NightIntroCutsceneScript.new())
	_assert_font(intro.get_node("Subtitle") as Control, &"font", UiFontRolesScript.TITLE_FONT_PATH, "intro subtitle uses title font")
	_assert_font(intro.get_node("AdvanceHint") as Control, &"font", UiFontRolesScript.PIXEL_FONT_PATH, "intro advance hint uses pixel font")
	_assert_font(intro.get_node("SkipButton") as Control, &"font", UiFontRolesScript.PIXEL_FONT_PATH, "intro skip button uses pixel font")


func _add_node(node: Node):
	add_child(node)
	_nodes.append(node)
	return node


func _assert_font(control: Control, font_type: StringName, expected_path: String, message: String) -> void:
	_runner.assert_not_null(control, "%s control exists" % message)
	if control == null:
		return
	var font := control.get_theme_font(font_type)
	_runner.assert_not_null(font, "%s font exists" % message)
	if font == null:
		return
	_runner.assert_eq(_font_base_path(font), expected_path, message)


func _assert_rich_text_role_fonts(control: RichTextLabel, expected_path: String, message: String) -> void:
	_assert_font(control, &"normal_font", expected_path, "%s normal" % message)
	_assert_font_variation(control, &"bold_font", expected_path, true, false, "%s bold" % message)
	_assert_font_variation(control, &"italics_font", expected_path, false, true, "%s italic" % message)
	_assert_font_variation(control, &"bold_italics_font", expected_path, true, true, "%s bold italic" % message)
	_assert_font(control, &"mono_font", UiFontRolesScript.PIXEL_FONT_PATH, "%s mono uses pixel font" % message)


func _assert_font_variation(
	control: RichTextLabel,
	font_type: StringName,
	expected_path: String,
	expect_embolden: bool,
	expect_skew: bool,
	message: String
) -> void:
	var font := control.get_theme_font(font_type)
	var variation := font as FontVariation
	_runner.assert_not_null(variation, "%s uses a FontVariation" % message)
	if variation == null:
		return
	_runner.assert_eq(_font_base_path(variation), expected_path, "%s base font" % message)
	_runner.assert_eq(variation.variation_embolden > 0.0, expect_embolden, "%s embolden flag" % message)
	_runner.assert_eq(variation.variation_transform != Transform2D.IDENTITY, expect_skew, "%s skew flag" % message)


func _font_base_path(font: Font) -> String:
	var variation := font as FontVariation
	if variation != null and variation.base_font != null:
		return variation.base_font.resource_path
	return font.resource_path
