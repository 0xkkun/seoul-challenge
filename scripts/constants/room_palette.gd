extends RefCounted

const ROOM_SIZE := Vector2(1920.0, 640.0)
const ROOM_HALF_SIZE := Vector2(960.0, 320.0)
const PLAY_LEFT := -820.0
const PLAY_TOP := -150.0
const PLAY_RIGHT := 820.0
const PLAY_BOTTOM := 300.0
const PLAY_BOUNDS := Rect2(Vector2(PLAY_LEFT, PLAY_TOP), Vector2(PLAY_RIGHT - PLAY_LEFT, PLAY_BOTTOM - PLAY_TOP))
const DOOR_SIZE := Vector2(36.0, 16.0)
const DOOR_TRIGGER_SIZE := Vector2(32.0, 28.0)
const WALL_THICKNESS := 16.0
const WALL_DOOR_GAP_PADDING := 12.0

const START_ROOM_FLOOR_COLOR := Color(0.352941, 0.490196, 0.352941, 1.0)
const ACTIVITY_ROOM_FLOOR_COLOR := Color(0.690196, 0.254902, 0.243137, 1.0)
const EVENT_ROOM_FLOOR_COLOR := Color(0.227451, 0.431373, 0.647059, 1.0)
const FRIEND_ROOM_FLOOR_COLOR := Color(0.415686, 0.286275, 0.635294, 1.0)
const REWARD_ROOM_FLOOR_COLOR := Color(0.784314, 0.631373, 0.227451, 1.0)
const SHOP_ROOM_FLOOR_COLOR := Color(0.176471, 0.541176, 0.501961, 1.0)
const FINAL_ROOM_FLOOR_COLOR := Color(0.415686, 0.227451, 0.541176, 1.0)
const MINIMAP_PING_COLOR := Color(0.403922, 0.909804, 0.976471, 1.0)
const DOOR_LOCKED_COLOR := Color(0.266667, 0.266667, 0.266667, 1.0)
const DOOR_OPEN_COLOR := Color(0.298039, 0.686275, 0.313725, 1.0)
const STUDENT_MARKER_COLOR := Color(0.164706, 0.631373, 0.596078, 1.0)
const WALL_COLOR := Color(0.188235, 0.188235, 0.215686, 1.0)

const NORTH_DOOR_POSITION := Vector2(0.0, PLAY_TOP)
const SOUTH_DOOR_POSITION := Vector2(0.0, PLAY_BOTTOM)
const EAST_DOOR_POSITION := Vector2(PLAY_RIGHT, 0.0)
const WEST_DOOR_POSITION := Vector2(PLAY_LEFT, 0.0)


static func get_room_bounds() -> Rect2:
	return PLAY_BOUNDS


static func get_wall_bounds() -> Rect2:
	var wall_margin := Vector2(WALL_THICKNESS, WALL_THICKNESS)
	var room_bounds := get_room_bounds()
	return Rect2(room_bounds.position - wall_margin, room_bounds.size + wall_margin * 2.0)


static func get_camera_limits() -> Dictionary:
	var wall_bounds := get_wall_bounds()
	return {
		"left": int(floor(wall_bounds.position.x)),
		"top": int(floor(wall_bounds.position.y)),
		"right": int(ceil(wall_bounds.end.x)),
		"bottom": int(ceil(wall_bounds.end.y)),
	}


static func get_room_floor_color(room_type: StringName) -> Color:
	match room_type:
		&"start":
			return START_ROOM_FLOOR_COLOR
		&"combat":
			return ACTIVITY_ROOM_FLOOR_COLOR
		&"event":
			return EVENT_ROOM_FLOOR_COLOR
		&"friend":
			return FRIEND_ROOM_FLOOR_COLOR
		&"treasure":
			return REWARD_ROOM_FLOOR_COLOR
		&"shop":
			return SHOP_ROOM_FLOOR_COLOR
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
