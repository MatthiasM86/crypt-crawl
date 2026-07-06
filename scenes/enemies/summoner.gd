extends "res://scenes/enemies/ranged_enemy.gd"
## Beschwörer: kites like the cultist (inherited), but the long ritual windup
## summons 1-2 lesser Brutes instead of shooting. Capped at 3 living summons.
## The classic priority target: ignore him and you drown. Summons are worth
## almost no souls (no farming). Debuts in the Fleischgrube biome.

const SUMMON_CAP := 3
const SUMMON_COUNT := 2
const SUMMON_HP := 2
const SUMMON_SOULS := 1
const SUMMON_TINT := Color(0.55, 0.75, 0.5)
const MELEE_SCENE := preload("res://scenes/enemies/melee_enemy.tscn")

var _summons: Array = []


func _perform_attack() -> void:
	_prune_summons()
	Sfx.play("relic", -4.0)
	for i in SUMMON_COUNT:
		if _summons.size() >= SUMMON_CAP:
			return
		var minion := MELEE_SCENE.instantiate()
		minion.max_hp = SUMMON_HP
		minion.soul_value = SUMMON_SOULS
		minion.get_node("Visual").self_modulate = SUMMON_TINT
		minion.position = global_position + Vector2(36, 0).rotated(TAU * i / SUMMON_COUNT + randf() * 0.8)
		get_parent().add_child(minion)
		_summons.append(minion)


func _prune_summons() -> void:
	_summons = _summons.filter(func(m): return is_instance_valid(m) and not m.dead)
