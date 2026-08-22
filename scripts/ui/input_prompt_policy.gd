class_name InputPromptPolicy
extends RefCounted

const MODE_DESKTOP := &"desktop"
const MODE_TOUCH := &"touch"


static func input_mode_from_features(features: Dictionary) -> StringName:
	return MODE_TOUCH if (
		bool(features.get("mobile", false))
		or bool(features.get("web_android", false))
		or bool(features.get("web_ios", false))
	) else MODE_DESKTOP


static func continue_hint(input_mode: StringName) -> String:
	return action_hint(&"continue", input_mode)


static func action_hint(action: StringName, input_mode: StringName) -> String:
	var gesture := "탭하여" if input_mode == MODE_TOUCH else "클릭하여"
	var verb := "시작" if action == &"start" else "계속"
	return "%s %s" % [gesture, verb]
