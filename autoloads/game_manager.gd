extends Node
## Global run-state singleton (autoload): floor counter, death -> restart,
## floor -> floor transitions. HP carries between floors via carry_hp
## (-1 = fresh run); the heal potion refills every floor.

const RESTART_DELAY := 0.9

var floor_num := 1
var carry_hp := -1
var carry_potions := 1


func next_floor(current_hp: int, current_potions: int) -> void:
	floor_num += 1
	carry_hp = current_hp
	carry_potions = current_potions
	# Deferred: callers include Area2D physics callbacks, where changing the
	# scene mid-flush is an error.
	get_tree().reload_current_scene.call_deferred()


func player_died() -> void:
	floor_num = 1
	carry_hp = -1
	carry_potions = 1
	await get_tree().create_timer(RESTART_DELAY).timeout
	get_tree().reload_current_scene()
