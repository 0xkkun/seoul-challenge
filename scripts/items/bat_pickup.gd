extends Area2D
## 야구배트 보상 픽업(#24) — 플레이어가 닿으면 배트를 장착시키고 소멸한다.
## 맵 클리어 보상으로 배치(통합 단계). 충돌 마스크 = 플레이어 레이어(2)만.

func _ready() -> void:
	body_entered.connect(_on_body)


func _on_body(body: Node) -> void:
	if body != null and body.has_method("equip_bat"):
		body.call("equip_bat")
		queue_free()
