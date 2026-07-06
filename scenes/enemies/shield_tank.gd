extends "res://scenes/enemies/enemy.gd"
## Schild-Tank: slow, hits hard, and BLOCKS everything from the front
## (100° arc around his facing) -- the first enemy that demands positioning
## instead of timing. Counterplay: dash behind him, or let an exploder /
## fire patch hit him from the flank. Debuts in the Katakomben biome.

const SHIELD_ARC_DEG := 100.0
const BLOCK_TINT := Color(0.6, 0.8, 1.4)


func take_damage(amount: int, source_position: Vector2, knockback_scale := 1.0) -> void:
	if dead:
		return
	var to_source := (source_position - global_position).angle()
	if absf(angle_difference(_pivot.rotation, to_source)) <= deg_to_rad(SHIELD_ARC_DEG) / 2.0:
		_blocked_feedback()
		return
	super(amount, source_position, knockback_scale)


func _blocked_feedback() -> void:
	Sfx.play("clank")
	var t := create_tween()
	_visual.self_modulate = BLOCK_TINT
	t.tween_property(_visual, "self_modulate", _base_color, 0.12)
