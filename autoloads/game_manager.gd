extends Node
## Global run/meta-state singleton (autoload): floor counter, death/floor
## transitions, and persistent meta-progression (souls + permanent upgrades,
## saved to user://save.cfg). The hub scene is home base: runs start via
## start_run() from the hub portal and end back in the hub on death.

const RESTART_DELAY := 0.9
const SAVE_PATH := "user://save.cfg"
const HUB_SCENE := "res://scenes/hub/hub.tscn"
const RUN_SCENE := "res://scenes/levels/generated_level.tscn"

## Permanent upgrades: player._ready() applies levels to its stat vars,
## shrine.gd renders labels/costs from these defs.
const UPGRADE_DEFS := {
	"vitality": {"label": "Vitalität", "effect": "+2 Start-HP", "costs": [30, 60, 90, 120, 150]},
	"might": {"label": "Wucht", "effect": "+1 Schaden", "costs": [100, 250]},
	"reflexes": {"label": "Reflexe", "effect": "-0,1s Dash-CD", "costs": [40, 80, 120]},
	"belt": {"label": "Gürtel", "effect": "+1 Trank-Slot", "costs": [50, 150]},
}

signal upgrades_changed

var floor_num := 1
var carry_hp := -1
var carry_potions := 1
var souls := 0
var upgrades := {"vitality": 0, "might": 0, "reflexes": 0, "belt": 0}


func _ready() -> void:
	_load()


func add_souls(amount: int) -> void:
	souls += amount


func upgrade_level(id: String) -> int:
	return upgrades[id]


func upgrade_cost(id: String) -> int:
	## Cost of the next level, or -1 when maxed out.
	var costs: Array = UPGRADE_DEFS[id]["costs"]
	var level: int = upgrades[id]
	return -1 if level >= costs.size() else costs[level]


func buy_upgrade(id: String) -> bool:
	var cost := upgrade_cost(id)
	if cost < 0 or souls < cost:
		return false
	souls -= cost
	upgrades[id] += 1
	_save()
	upgrades_changed.emit()
	return true


func start_run() -> void:
	floor_num = 1
	carry_hp = -1
	carry_potions = 1
	_save()
	get_tree().change_scene_to_file.call_deferred(RUN_SCENE)


func next_floor(current_hp: int, current_potions: int) -> void:
	floor_num += 1
	carry_hp = current_hp
	carry_potions = current_potions
	_save()
	# Deferred: callers include Area2D physics callbacks, where changing the
	# scene mid-flush is an error.
	get_tree().reload_current_scene.call_deferred()


func player_died() -> void:
	floor_num = 1
	carry_hp = -1
	carry_potions = 1
	_save()
	await get_tree().create_timer(RESTART_DELAY).timeout
	get_tree().change_scene_to_file.call_deferred(HUB_SCENE)


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "souls", souls)
	cfg.set_value("meta", "upgrades", upgrades)
	cfg.save(SAVE_PATH)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	souls = cfg.get_value("meta", "souls", 0)
	var saved: Dictionary = cfg.get_value("meta", "upgrades", {})
	for key in upgrades:
		upgrades[key] = int(saved.get(key, 0))
