extends RefCounted

const ROOM_SIZE := Vector2(256.0, 192.0)
const ROOM_HALF_SIZE := Vector2(128.0, 96.0)
const DOOR_SIZE := Vector2(36.0, 16.0)
const DOOR_TRIGGER_SIZE := Vector2(32.0, 28.0)

const START_ROOM_FLOOR_COLOR := Color(0.352941, 0.490196, 0.352941, 1.0)
const ACTIVITY_ROOM_FLOOR_COLOR := Color(0.690196, 0.254902, 0.243137, 1.0)
const EVENT_ROOM_FLOOR_COLOR := Color(0.227451, 0.431373, 0.647059, 1.0)
const REWARD_ROOM_FLOOR_COLOR := Color(0.784314, 0.631373, 0.227451, 1.0)
const FINAL_ROOM_FLOOR_COLOR := Color(0.415686, 0.227451, 0.541176, 1.0)
const DOOR_LOCKED_COLOR := Color(0.266667, 0.266667, 0.266667, 1.0)
const DOOR_OPEN_COLOR := Color(0.298039, 0.686275, 0.313725, 1.0)
const STUDENT_MARKER_COLOR := Color(0.164706, 0.631373, 0.596078, 1.0)

const NORTH_DOOR_POSITION := Vector2(0.0, -96.0)
const SOUTH_DOOR_POSITION := Vector2(0.0, 96.0)
const EAST_DOOR_POSITION := Vector2(128.0, 0.0)
const WEST_DOOR_POSITION := Vector2(-128.0, 0.0)


static func get_room_floor_color(room_type: StringName) -> Color:
	match room_type:
		&"start":
			return START_ROOM_FLOOR_COLOR
		&"combat":
			return ACTIVITY_ROOM_FLOOR_COLOR
		&"event":
			return EVENT_ROOM_FLOOR_COLOR
		&"treasure":
			return REWARD_ROOM_FLOOR_COLOR
		&"final":
			return FINAL_ROOM_FLOOR_COLOR
	return START_ROOM_FLOOR_COLOR


static func get_door_position(door_dir: StringName) -> Vector2:
	match door_dir:
		&"N":
			return NORTH_DOOR_POSITION
		&"S":
			return SOUTH_DOOR_POSITION
		&"E":
			return EAST_DOOR_POSITION
		&"W":
			return WEST_DOOR_POSITION
	return Vector2.ZERO
