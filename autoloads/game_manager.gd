extends Node
## Global run-state singleton (autoload). First real responsibility
## (docs/plan.md Phase 4/6): the death -> restart loop. The player calls
## player_died(); we hold a beat so the death pop reads, then reload the
## run. Floor transitions / run stats extend this later.

const RESTART_DELAY := 0.9


func player_died() -> void:
	await get_tree().create_timer(RESTART_DELAY).timeout
	get_tree().reload_current_scene()
