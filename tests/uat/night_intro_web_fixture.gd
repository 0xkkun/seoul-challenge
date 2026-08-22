extends Node

const BlockedNightIntro := preload("res://tests/uat/night_intro_blocked_fixture.gd")
const StuckNightIntro := preload("res://tests/uat/night_intro_stuck_fixture.gd")

var _started_at_ms := 0


func _ready() -> void:
	var mode := _fixture_mode()
	var intro: NightIntroCutscene
	if mode == "stuck":
		intro = StuckNightIntro.new()
	else:
		mode = "blocked"
		intro = BlockedNightIntro.new()
	add_child(intro)
	intro.finished.connect(_on_intro_finished.bind(mode))
	_started_at_ms = Time.get_ticks_msec()
	print("UAT_INTRO_STARTED mode=%s" % mode)
	intro.play()


func _fixture_mode() -> String:
	if OS.has_feature("web"):
		var window := JavaScriptBridge.get_interface("window")
		if window != null:
			var search := String(window.location.search)
			for pair in search.trim_prefix("?").split("&"):
				if pair.begins_with("uat_intro_mode="):
					return pair.trim_prefix("uat_intro_mode=")
	for argument in OS.get_cmdline_args():
		if argument.begins_with("--uat-intro-mode="):
			return argument.trim_prefix("--uat-intro-mode=")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--uat-intro-mode="):
			return argument.trim_prefix("--uat-intro-mode=")
	return "blocked"


func _on_intro_finished(mode: String) -> void:
	var elapsed_ms := Time.get_ticks_msec() - _started_at_ms
	print("UAT_INTRO_FINISHED mode=%s elapsed_ms=%d" % [mode, elapsed_ms])
	get_tree().change_scene_to_file("res://scenes/lobby/lobby.tscn")
