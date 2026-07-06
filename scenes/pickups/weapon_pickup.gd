extends Area2D
## Run-bound weapon lying on the ground (from chests or the boss). The
## weapon slot has no free space -- it's always exactly one -- so touching
## it always offers a LoadoutChoice swap against the currently equipped
## weapon; touching your own equipped weapon is a deliberate non-event.

@export var weapon_id := "spiess"


func _ready() -> void:
	var def: Dictionary = GameManager.WEAPON_DEFS[weapon_id]
	$Visual.color = def["color"]
	$Glow.color = def["color"]
	$Name.text = def["label"]
	body_entered.connect(_on_body_entered)
	_start_bob.call_deferred()


func _start_bob() -> void:
	var t := create_tween().set_loops()
	t.tween_property(self, "position:y", position.y - 4.0, 0.7).set_trans(Tween.TRANS_SINE)
	t.tween_property(self, "position:y", position.y + 4.0, 0.7).set_trans(Tween.TRANS_SINE)


func _on_body_entered(body: Node2D) -> void:
	if not body.has_method("set_weapon") or body.weapon_id == weapon_id:
		return
	LoadoutChoice.offer("weapon", weapon_id, [body.weapon_id], body, self)
