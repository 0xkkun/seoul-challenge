class_name ShopRoom
extends Room

const TemplateGroups = preload("res://scripts/constants/template_groups.gd")

const OFFER_BAT := &"bat"
const OFFER_DODGE_REFILL := &"dodge_refill"
const OFFER_IDS: Array[StringName] = [OFFER_BAT, OFFER_DODGE_REFILL]

@export_range(0, 99, 1) var bat_cost := 4
@export_range(0, 99, 1) var dodge_refill_cost := 3
@export var interaction_radius := RoomPalette.DOOR_TRIGGER_SIZE.x
@export var offer_layer_path: NodePath

var _sold_offers := {}
var _offer_labels := {}

@onready var _offer_layer: Node2D = _resolve_offer_layer()


func _ready() -> void:
	room_type = &"shop"
	super._ready()
	_cache_offer_labels()
	_apply_offer_visuals()
	_render_offers()
	_add_interactable_group()


func enter() -> void:
	_sync_sold_offers_from_actor()
	super.enter()
	_render_offers()


func is_cleared() -> bool:
	return true


func check_interaction(source: Node, _delta: float) -> void:
	var buyer := source as Node2D
	if buyer == null:
		return
	var offer_id := _nearest_available_offer_id(buyer.global_position)
	if offer_id == &"":
		return
	purchase_offer(offer_id, source)


func purchase_offer(offer_id: StringName, buyer: Node = null) -> bool:
	if not OFFER_IDS.has(offer_id) or is_offer_sold(offer_id):
		_render_offers()
		return false
	if buyer == null:
		buyer = _actor
	if buyer == null:
		return false

	var cost := get_offer_cost(offer_id)
	if _ingame_balance() < cost:
		_emit_shop_event("shop_purchase_failed", offer_id, cost)
		_render_offers()
		return false
	if not _apply_offer(offer_id, buyer):
		_emit_shop_event("shop_purchase_failed", offer_id, cost)
		_render_offers()
		return false

	_sold_offers[offer_id] = true
	_spend_ingame(cost, offer_id)
	_emit_shop_event("shop_purchase_completed", offer_id, cost)
	_render_offers()
	return true


func is_offer_sold(offer_id: StringName) -> bool:
	return bool(_sold_offers.get(offer_id, false))


func get_offer_cost(offer_id: StringName) -> int:
	match offer_id:
		OFFER_BAT:
			return bat_cost
		OFFER_DODGE_REFILL:
			return dodge_refill_cost
	return 0


func get_offer_text(offer_id: StringName) -> String:
	var label := _offer_labels.get(offer_id) as Label
	if label != null:
		return label.text
	return _offer_text(offer_id)


func get_offer_position(offer_id: StringName) -> Vector2:
	var node := _offer_node(offer_id)
	if node != null:
		return node.global_position
	return global_position


func _add_interactable_group() -> void:
	if not is_in_group(TemplateGroups.INTERACTABLE):
		add_to_group(TemplateGroups.INTERACTABLE)


func _nearest_available_offer_id(source_position: Vector2) -> StringName:
	var nearest_id := &""
	var nearest_distance := INF
	for offer_id: StringName in OFFER_IDS:
		if is_offer_sold(offer_id):
			continue
		var distance := source_position.distance_to(get_offer_position(offer_id))
		if distance > interaction_radius or distance >= nearest_distance:
			continue
		nearest_id = offer_id
		nearest_distance = distance
	return nearest_id


func _apply_offer(offer_id: StringName, buyer: Node) -> bool:
	match offer_id:
		OFFER_BAT:
			if not buyer.has_method("equip_bat"):
				return false
			buyer.call("equip_bat")
			return true
		OFFER_DODGE_REFILL:
			if not buyer.has_method("equip_special_skill"):
				return false
			buyer.call("equip_special_skill", &"emergency_dodge", 5, 1.0)
			return true
	return false


func _sync_sold_offers_from_actor() -> void:
	if _actor == null:
		return
	if _actor_has_bat_equipped():
		_sold_offers[OFFER_BAT] = true
	if not _has_actor_property("special_skill_max_uses") or not _has_actor_property("special_skill_cooldown"):
		return
	var max_uses := int(_actor.get("special_skill_max_uses"))
	var cooldown := float(_actor.get("special_skill_cooldown"))
	if max_uses >= 5 and cooldown <= 1.0:
		_sold_offers[OFFER_DODGE_REFILL] = true


func _actor_has_bat_equipped() -> bool:
	if _actor == null:
		return false
	if _actor.has_method("has_bat"):
		return bool(_actor.call("has_bat"))
	if _actor.has_method("current_weapon_name"):
		return String(_actor.call("current_weapon_name")) in ["금 간 나무 배트", "마지막 시즌의 배트", "야구배트"]
	return false


func _has_actor_property(property_name: String) -> bool:
	if _actor == null:
		return false
	for property: Dictionary in _actor.get_property_list():
		if String(property.get("name", "")) == property_name:
			return true
	return false


func _spend_ingame(cost: int, offer_id: StringName) -> void:
	if cost <= 0 or not has_node("/root/EventBus"):
		return
	EventBus.emit_currency_changed({
		"kind": "ingame",
		"amount": -cost,
		"reason": "shop_purchase",
		"room_id": room_id,
		"room_type": room_type,
		"offer_id": offer_id,
	})


func _emit_shop_event(kind: String, offer_id: StringName, cost: int) -> void:
	if not has_node("/root/EventBus"):
		return
	EventBus.emit_interaction_completed({
		"kind": kind,
		"room_id": room_id,
		"room_type": room_type,
		"offer_id": offer_id,
		"cost": cost,
		"ingame": _ingame_balance(),
	})


func _ingame_balance() -> int:
	if has_node("/root/CurrencySystem"):
		return CurrencySystem.get_ingame()
	return 0


func _cache_offer_labels() -> void:
	_offer_labels.clear()
	_offer_labels[OFFER_BAT] = get_node_or_null("Offers/BatOffer/Label") as Label
	_offer_labels[OFFER_DODGE_REFILL] = get_node_or_null("Offers/DodgeOffer/Label") as Label


func _apply_offer_visuals() -> void:
	_apply_pad_visual(OFFER_BAT, Color(0.36, 0.52, 0.74, 1.0))
	_apply_pad_visual(OFFER_DODGE_REFILL, Color(0.42, 0.62, 0.46, 1.0))


func _apply_pad_visual(offer_id: StringName, color: Color) -> void:
	var pad := _offer_pad(offer_id)
	if pad == null:
		return
	pad.size = Vector2(142, 38)
	pad.position = -pad.size * 0.5
	pad.color = color


func _render_offers() -> void:
	for offer_id: StringName in OFFER_IDS:
		var label := _offer_labels.get(offer_id) as Label
		if label == null:
			continue
		label.text = _offer_text(offer_id)


func _offer_text(offer_id: StringName) -> String:
	var name := _offer_display_name(offer_id)
	if name == "":
		return ""
	if is_offer_sold(offer_id):
		return "%s 구매 완료" % name
	return "%s %d엽전" % [name, get_offer_cost(offer_id)]


func _offer_display_name(offer_id: StringName) -> String:
	match offer_id:
		OFFER_BAT:
			return "금 간 나무 배트"
		OFFER_DODGE_REFILL:
			return "회피부적"
	return ""


func _offer_node(offer_id: StringName) -> Node2D:
	match offer_id:
		OFFER_BAT:
			return get_node_or_null("Offers/BatOffer") as Node2D
		OFFER_DODGE_REFILL:
			return get_node_or_null("Offers/DodgeOffer") as Node2D
	return null


func _offer_pad(offer_id: StringName) -> ColorRect:
	var node := _offer_node(offer_id)
	if node == null:
		return null
	return node.get_node_or_null("Pad") as ColorRect


func _resolve_offer_layer() -> Node2D:
	if not offer_layer_path.is_empty():
		var configured := get_node_or_null(offer_layer_path) as Node2D
		if configured != null:
			return configured
	var layer := get_node_or_null("Offers") as Node2D
	if layer != null:
		return layer
	layer = Node2D.new()
	layer.name = "Offers"
	add_child(layer)
	return layer
