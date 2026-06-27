extends CharacterBody2D
## #18 요괴화 친구 중간보스 — 처치가 아니라 기절→정화.
##
## 추적(CHASING) → 데미지로 기절 게이지가 차면 STUNNED → 그동안 플레이어가 근접 유지로
## 정화 진행 → 완료 시 purified 방출(친구 구출). 기절이 풀리면 다시 추적.
## 최종 보스(#17)와는 별개. 적 프리미티브를 재사용하되 죽지 않는다.

## 정화 완료 — 친구 구출. RoomManager/전투방·구출 카운트가 듣는다(계약).
signal purified(friend)
## 기절 진입 — UI(정화 프롬프트) 표시용.
signal stunned

const HitReactionController = preload("res://scripts/combat/hit_reaction_controller.gd")

const FACING_DEADZONE := 0.01
const PURIFY_CUE_NAME := "PurifyCue"
const PURIFY_RANGE_RING_NAME := "RangeRing"
const PURIFY_PROGRESS_RING_NAME := "ProgressRing"
const PURIFY_BEAM_NAME := "PurifyBeam"
const PURIFY_BEAM_GLOW_NAME := "PurifyBeamGlow"
const PURIFY_CORE_NAME := "PurifyCore"
const PURIFY_COMPLETION_BURST_NAME := "PurifyCompletionBurst"
const PURIFY_RING_SEGMENTS := 48
const PURIFY_READY_COLOR := Color(0.42, 0.78, 1.0, 0.55)
const PURIFY_ACTIVE_COLOR := Color(0.88, 0.98, 1.0, 0.95)
const PURIFY_PROGRESS_COLOR := Color(1.0, 0.46, 0.08, 1.0)
const PURIFY_BEAM_COLOR := Color(1.0, 0.98, 0.58, 1.0)
const PURIFY_BEAM_GLOW_COLOR := Color(0.15, 0.86, 1.0, 0.58)
const PURIFY_STUNNED_MODULATE := Color(0.72, 0.82, 1.0, 0.88)
const PURIFY_BURST_COLOR := Color(1.0, 0.9, 0.45, 0.9)
const PURIFY_BURST_LIFETIME := 0.38

enum State { CHASING, STUNNED, PURIFIED }

@export var max_stun: int = 5            ## 기절까지 필요한 누적 피해
@export var stun_duration: float = 3.0   ## 기절 지속(이 안에 정화 못하면 복귀)
@export var purify_time: float = 1.2      ## 정화 완료까지 근접 유지 시간 (s)
@export var purify_range: float = 60.0    ## 정화 가능 거리 (px)
@export var purify_progress_radius: float = 52.0
@export var move_speed: float = 80.0
@export var contact_damage: int = 1
@export var contact_range: float = 30.0
@export var contact_cooldown: float = 0.7
@export var hit_invuln_time: float = 0.12
@export var target_group: StringName = &"player"
@export var move_animation: StringName = &"move"
@export var attack_animation: StringName = &"attack"

var _state: State = State.CHASING
var _stun_accum: int = 0
var _stun_timer: float = 0.0
var _purify_progress: float = 0.0
var _contact_timer: float = 0.0
var _hit_reaction: Node = null
var _purify_cue: Node2D = null
var _range_ring: Line2D = null
var _progress_ring: Line2D = null
var _beam_glow: Line2D = null
var _beam_line: Line2D = null
var _core_pulse: Polygon2D = null
var _purify_visual_state: StringName = &"hidden"
var _purify_in_range := false
var _purify_channeling := false
var _purify_completion_spawned := false
@onready var _sprite: AnimatedSprite2D = get_node_or_null(^"Sprite")


func _ready() -> void:
	add_to_group(&"enemy")
	add_to_group(&"yokai_friend")
	_ensure_hit_reaction()
	_ensure_purify_cue()
	_hide_purify_cue()


func is_stunned() -> bool:
	return _state == State.STUNNED


func is_purified() -> bool:
	return _state == State.PURIFIED


func _physics_process(delta: float) -> void:
	tick_hit_reaction(delta)
	match _state:
		State.CHASING:
			_process_chase(delta)
		State.STUNNED:
			_process_stun(delta)
	_update_animation()


# --- 순수 함수(테스트 대상) ---

func chase_velocity(from: Vector2, to: Vector2, speed: float) -> Vector2:
	var dir := to - from
	return dir.normalized() * speed if dir.length() > 0.001 else Vector2.ZERO


func accumulate_stun(current: int, amount: int) -> int:
	return current + amount


func reached_stun_threshold(accum: int, threshold: int) -> bool:
	return accum >= threshold


func purify_progress_fraction(progress: float, duration: float) -> float:
	if duration <= 0.0:
		return 1.0
	return clampf(progress / duration, 0.0, 1.0)


func purify_arc_points(radius: float, fraction: float, segments: int = PURIFY_RING_SEGMENTS) -> PackedVector2Array:
	var clamped_fraction := clampf(fraction, 0.0, 1.0)
	if clamped_fraction <= 0.0:
		return PackedVector2Array()
	var point_count := maxi(2, int(ceil(float(segments) * clamped_fraction)) + 1)
	var points := PackedVector2Array()
	for index: int in range(point_count):
		var t := 0.0 if point_count == 1 else float(index) / float(point_count - 1)
		var angle := -PI * 0.5 + TAU * clamped_fraction * t
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points


# --- 피격 반응 (계약 #136) ---

func is_hit_invulnerable() -> bool:
	return bool(_ensure_hit_reaction().call("is_active"))


func tick_hit_reaction(delta: float) -> void:
	_ensure_hit_reaction().call("tick", delta)


func _trigger_hit_reaction() -> void:
	_ensure_hit_reaction().call("trigger", hit_invuln_time)


func _ensure_hit_reaction() -> Node:
	if _hit_reaction != null and is_instance_valid(_hit_reaction):
		return _hit_reaction
	_hit_reaction = HitReactionController.new()
	_hit_reaction.name = "HitReaction"
	add_child(_hit_reaction)
	var visual := _get_visual_node()
	if visual != null:
		_hit_reaction.call("bind_visual", visual)
	return _hit_reaction


# --- 피격/기절/정화 (I/O) ---

## 정화탄 등이 호출(계약). CHASING 중에만 기절 게이지를 채운다.
func take_damage(amount: int) -> void:
	if _state != State.CHASING or is_hit_invulnerable():
		return
	HapticManager.on_enemy_hit()
	_stun_accum = accumulate_stun(_stun_accum, amount)
	if reached_stun_threshold(_stun_accum, max_stun):
		_enter_stunned()
	else:
		_trigger_hit_reaction()


## 정화 진행을 delta만큼 누적하고, 완료되면 true. (테스트에서 직접 호출 가능)
func apply_purify(delta: float) -> bool:
	_purify_progress = minf(purify_time, _purify_progress + delta)
	return _purify_progress >= purify_time


func get_purify_visual_snapshot() -> Dictionary:
	_ensure_purify_cue()
	return {
		"visible": _purify_cue.visible,
		"state": _purify_visual_state,
		"progress": purify_progress_fraction(_purify_progress, purify_time),
		"in_range": _purify_in_range,
		"channeling": _purify_channeling,
		"range_point_count": _range_ring.points.size() if _range_ring != null else 0,
		"progress_point_count": _progress_ring.points.size() if _progress_ring != null else 0,
		"progress_visible": _progress_ring.visible if _progress_ring != null else false,
		"beam_visible": _beam_line.visible if _beam_line != null else false,
		"beam_glow_visible": _beam_glow.visible if _beam_glow != null else false,
		"has_text_prompt": _has_visible_text_prompt(),
	}


func get_visual_snapshot() -> Dictionary:
	var sprite := _get_sprite()
	var frames := sprite.sprite_frames if sprite != null else null
	var placeholder := get_node_or_null(^"Placeholder") as CanvasItem
	var move_frame_count := _animation_frame_count(frames, move_animation)
	var attack_frame_count := _animation_frame_count(frames, attack_animation)
	return {
		"has_sprite": sprite != null,
		"sprite_type": "AnimatedSprite2D" if sprite != null else "",
		"sprite_frames_path": frames.resource_path if frames != null else "",
		"texture_path": _animation_frame_atlas_path(frames, move_animation, 0),
		"frame_count": move_frame_count,
		"move_frame_count": move_frame_count,
		"attack_frame_count": attack_frame_count,
		"move_loops": frames.get_animation_loop(move_animation) if frames != null and frames.has_animation(move_animation) else false,
		"attack_loops": frames.get_animation_loop(attack_animation) if frames != null and frames.has_animation(attack_animation) else false,
		"animation": sprite.animation if sprite != null else &"",
		"sprite_visible": sprite.visible if sprite != null else false,
		"placeholder_visible": placeholder.visible if placeholder != null else false,
	}


func _enter_stunned() -> void:
	_state = State.STUNNED
	_stun_timer = stun_duration
	_purify_progress = 0.0
	_purify_completion_spawned = false
	velocity = Vector2.ZERO
	_play_move_animation()
	_set_stunned_visual(true)
	_update_purify_cue(null, false, false)
	stunned.emit()


func _process_chase(delta: float) -> void:
	_contact_timer = maxf(0.0, _contact_timer - delta)
	var target := _find_target()
	if target == null:
		return
	velocity = chase_velocity(global_position, target.global_position, move_speed)
	move_and_slide()
	_try_contact(target)


func _process_stun(delta: float) -> void:
	_stun_timer = maxf(0.0, _stun_timer - delta)
	var target := _find_target()
	var in_range := _player_in_purify_range(target)
	var channeling := _player_is_purifying(target)
	if channeling:
		if apply_purify(delta):
			_update_purify_cue(target, in_range, true)
			_complete_purify()
			return
	else:
		_purify_progress = 0.0
	_update_purify_cue(target, in_range, channeling)
	if _stun_timer <= 0.0:
		_return_to_chase_after_stun()


## 플레이어가 정화 중인가 — 공격 입력과 분리하고 근접 유지로만 판정한다.
func _player_is_purifying(target: Node2D) -> bool:
	return _player_in_purify_range(target)


func _complete_purify() -> void:
	_state = State.PURIFIED
	_purify_visual_state = &"complete"
	_spawn_completion_burst()
	purified.emit(self)
	queue_free()


func _return_to_chase_after_stun() -> void:
	_state = State.CHASING
	_stun_accum = 0
	_purify_progress = 0.0
	_play_move_animation()
	_set_stunned_visual(false)
	_hide_purify_cue()


func _player_in_purify_range(target: Node2D) -> bool:
	if target == null:
		return false
	return global_position.distance_to(target.global_position) <= purify_range


func _find_target() -> Node2D:
	return get_tree().get_first_node_in_group(target_group) as Node2D


func _try_contact(target: Node2D) -> void:
	if _contact_timer > 0.0:
		return
	if global_position.distance_to(target.global_position) > contact_range:
		return
	_play_attack_animation(target.global_position - global_position)
	if target.has_method("take_damage"):
		target.call("take_damage", contact_damage)
	_contact_timer = contact_cooldown


func _ensure_purify_cue() -> Node2D:
	if _purify_cue != null and is_instance_valid(_purify_cue):
		return _purify_cue
	_purify_cue = Node2D.new()
	_purify_cue.name = PURIFY_CUE_NAME
	_purify_cue.z_index = 18
	add_child(_purify_cue)

	_range_ring = _make_line(PURIFY_RANGE_RING_NAME, PURIFY_READY_COLOR, 3.0, true)
	_core_pulse = Polygon2D.new()
	_core_pulse.name = PURIFY_CORE_NAME
	_core_pulse.color = Color(0.94, 0.98, 1.0, 0.52)
	_core_pulse.z_index = 4
	_core_pulse.polygon = _circle_points(22.0, 20)
	_purify_cue.add_child(_core_pulse)
	_beam_glow = _make_line(PURIFY_BEAM_GLOW_NAME, PURIFY_BEAM_GLOW_COLOR, 22.0, false)
	_beam_line = _make_line(PURIFY_BEAM_NAME, PURIFY_BEAM_COLOR, 8.0, false)
	_progress_ring = _make_line(PURIFY_PROGRESS_RING_NAME, PURIFY_PROGRESS_COLOR, 12.0, false)
	_range_ring.points = _circle_points(purify_range, PURIFY_RING_SEGMENTS)
	return _purify_cue


func _make_line(line_name: String, color: Color, width: float, closed: bool) -> Line2D:
	var line := Line2D.new()
	line.name = line_name
	line.default_color = color
	line.width = width
	line.closed = closed
	match line_name:
		PURIFY_BEAM_GLOW_NAME:
			line.z_index = 2
		PURIFY_BEAM_NAME:
			line.z_index = 3
		PURIFY_PROGRESS_RING_NAME:
			line.z_index = 5
		_:
			line.z_index = 1
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	_purify_cue.add_child(line)
	return line


func _update_purify_cue(target: Node2D, in_range: bool, channeling: bool) -> void:
	_ensure_purify_cue()
	_purify_in_range = in_range
	_purify_channeling = channeling
	_purify_visual_state = &"channeling" if channeling else &"ready"
	_purify_cue.visible = true
	_range_ring.visible = true
	_range_ring.default_color = PURIFY_ACTIVE_COLOR if in_range else PURIFY_READY_COLOR
	_range_ring.points = _circle_points(purify_range, PURIFY_RING_SEGMENTS)
	var progress_fraction := purify_progress_fraction(_purify_progress, purify_time)
	_progress_ring.visible = progress_fraction > 0.0
	_progress_ring.points = purify_arc_points(purify_progress_radius, progress_fraction)
	_core_pulse.visible = true
	_core_pulse.scale = Vector2.ONE * (1.0 + progress_fraction * 0.22)
	_core_pulse.color = Color(0.94, 0.98, 1.0, 0.52 + progress_fraction * 0.28)
	_beam_line.visible = channeling and target != null
	_beam_glow.visible = _beam_line.visible
	if _beam_line.visible:
		var beam_points := PackedVector2Array([Vector2.ZERO, to_local(target.global_position)])
		_beam_glow.points = beam_points
		_beam_line.points = beam_points
	else:
		_beam_glow.points = PackedVector2Array()
		_beam_line.points = PackedVector2Array()
	_lift_active_purify_marks()


func _hide_purify_cue() -> void:
	_ensure_purify_cue()
	_purify_visual_state = &"hidden"
	_purify_in_range = false
	_purify_channeling = false
	_purify_cue.visible = false
	_range_ring.visible = false
	_progress_ring.visible = false
	_progress_ring.points = PackedVector2Array()
	_beam_glow.visible = false
	_beam_glow.points = PackedVector2Array()
	_beam_line.visible = false
	_beam_line.points = PackedVector2Array()
	_core_pulse.visible = false


func _lift_active_purify_marks() -> void:
	if _beam_glow != null:
		_purify_cue.move_child(_beam_glow, _purify_cue.get_child_count() - 1)
	if _beam_line != null:
		_purify_cue.move_child(_beam_line, _purify_cue.get_child_count() - 1)
	if _progress_ring != null:
		_purify_cue.move_child(_progress_ring, _purify_cue.get_child_count() - 1)


func _circle_points(radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	var count := maxi(8, segments)
	for index: int in range(count):
		var angle := TAU * float(index) / float(count)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points


func _set_stunned_visual(enabled: bool) -> void:
	var visual := _get_visual_node()
	if visual == null:
		return
	visual.modulate = PURIFY_STUNNED_MODULATE if enabled else Color.WHITE


func _get_visual_node() -> CanvasItem:
	var sprite := _get_sprite() as CanvasItem
	if sprite != null:
		return sprite
	return get_node_or_null(^"Placeholder") as CanvasItem


func _update_animation() -> void:
	var sprite := _get_sprite()
	if sprite == null or sprite.sprite_frames == null:
		return
	if sprite.animation == attack_animation and sprite.is_playing():
		return
	_set_sprite_facing_from_direction(velocity)
	if sprite.sprite_frames.has_animation(move_animation) and sprite.animation != move_animation:
		sprite.play(move_animation)


func _play_attack_animation(facing_direction: Vector2 = Vector2.ZERO) -> void:
	var sprite := _get_sprite()
	if sprite == null or sprite.sprite_frames == null:
		return
	_set_sprite_facing_from_direction(facing_direction)
	if sprite.sprite_frames.has_animation(attack_animation):
		sprite.play(attack_animation)


func _play_move_animation() -> void:
	var sprite := _get_sprite()
	if sprite == null or sprite.sprite_frames == null:
		return
	if sprite.sprite_frames.has_animation(move_animation):
		sprite.play(move_animation)


func _set_sprite_facing_from_direction(direction: Vector2) -> void:
	var sprite := _get_sprite()
	if sprite == null:
		return
	if direction.x < -FACING_DEADZONE:
		sprite.flip_h = true
	elif direction.x > FACING_DEADZONE:
		sprite.flip_h = false


func _get_sprite() -> AnimatedSprite2D:
	if _sprite != null and is_instance_valid(_sprite):
		return _sprite
	return get_node_or_null(^"Sprite") as AnimatedSprite2D


func _animation_frame_count(frames: SpriteFrames, animation_name: StringName) -> int:
	if frames == null or not frames.has_animation(animation_name):
		return 0
	return frames.get_frame_count(animation_name)


func _animation_frame_atlas_path(frames: SpriteFrames, animation_name: StringName, frame_index: int) -> String:
	if frames == null or not frames.has_animation(animation_name):
		return ""
	if frame_index < 0 or frame_index >= frames.get_frame_count(animation_name):
		return ""
	var texture := frames.get_frame_texture(animation_name, frame_index)
	if texture is AtlasTexture:
		var atlas := (texture as AtlasTexture).atlas
		return atlas.resource_path if atlas != null else ""
	return texture.resource_path if texture != null else ""


func _spawn_completion_burst() -> void:
	if _purify_completion_spawned:
		return
	_purify_completion_spawned = true
	var parent := get_parent() as Node
	if parent == null:
		return
	var burst := Node2D.new()
	burst.name = PURIFY_COMPLETION_BURST_NAME
	burst.global_position = global_position
	burst.z_index = 40
	parent.add_child(burst)
	var outer := _make_burst_ring("OuterRing", purify_range, PURIFY_BURST_COLOR, 3.0)
	var inner := _make_burst_ring("InnerRing", purify_progress_radius, Color(0.74, 0.93, 1.0, 0.9), 4.0)
	burst.add_child(outer)
	burst.add_child(inner)
	if burst.is_inside_tree():
		var tween := burst.create_tween()
		tween.parallel().tween_property(burst, "scale", Vector2(1.22, 1.22), PURIFY_BURST_LIFETIME)
		tween.parallel().tween_property(burst, "modulate:a", 0.0, PURIFY_BURST_LIFETIME)
		tween.tween_callback(burst.queue_free)


func _make_burst_ring(line_name: String, radius: float, color: Color, width: float) -> Line2D:
	var line := Line2D.new()
	line.name = line_name
	line.default_color = color
	line.width = width
	line.closed = true
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.points = _circle_points(radius, PURIFY_RING_SEGMENTS)
	return line


func _has_visible_text_prompt() -> bool:
	_ensure_purify_cue()
	for child: Node in _purify_cue.get_children():
		if child is Label and (child as Label).visible:
			return true
	return false
