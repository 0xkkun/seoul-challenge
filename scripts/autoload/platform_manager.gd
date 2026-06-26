extends Node


func get_platform_name() -> String:
	return OS.get_name()


func has_touch_input() -> bool:
	return DisplayServer.is_touchscreen_available()


func get_feature_flags() -> Dictionary:
	return {
		"platform": get_platform_name(),
		"touch_input": has_touch_input(),
		"web": OS.has_feature("web"),
		"mobile": OS.has_feature("mobile"),
	}
