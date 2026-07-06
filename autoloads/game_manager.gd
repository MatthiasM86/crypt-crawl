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

## Run-bound relics (docs/plan.md Ausblick 6): one clear effect each, no
## inventory, lost on death. Effects hook into player.gd / add_souls.
const RELIC_DEFS := {
	"fire_slam": {"label": "Brandsiegel", "desc": "Rundumschlag hinterlässt Feuer", "color": Color(1.0, 0.55, 0.2)},
	"lifesteal": {"label": "Blutdurst", "desc": "Kills heilen 1 HP", "color": Color(0.9, 0.2, 0.25)},
	"dash_charge": {"label": "Schattenschritt", "desc": "+1 Dash-Ladung", "color": Color(0.45, 0.55, 1.0)},
	"heavy_hits": {"label": "Wuchtklinge", "desc": "Doppelter Knockback", "color": Color(0.85, 0.9, 1.0)},
	"swift": {"label": "Hetzjagd", "desc": "+40 Tempo", "color": Color(0.4, 0.9, 0.5)},
	"potion_power": {"label": "Konzentrat", "desc": "Tränke heilen vollständig", "color": Color(1.0, 0.5, 0.8)},
	"soul_greed": {"label": "Seelengier", "desc": "+50% Seelen", "color": Color(0.55, 0.9, 1.0)},
}

signal upgrades_changed

## Depth biomes (docs/plan.md Ausblick 3): look, mood and spawn mix per band.
## Interim tilesets are hue-shifts of the crypt atlas; real PixelLab tilesets
## replace the same files (asset-spec §4.5). Exploders stay off on floor 1.
const BIOMES := [
	{"name": "Krypta", "from": 1,
	 "tileset": "res://assets/sprites/tileset_placeholder.png",
	 "darkness": Color(0.16, 0.16, 0.21),
	 "weights": {"melee": 0.45, "ranged": 0.35, "exploder": 0.2},
	 "elite_chance": 0.12},
	{"name": "Katakomben", "from": 6,
	 "tileset": "res://assets/sprites/tileset_katakomben.png",
	 "darkness": Color(0.17, 0.15, 0.12),
	 "weights": {"melee": 0.35, "ranged": 0.35, "exploder": 0.3},
	 "elite_chance": 0.15},
	{"name": "Fleischgrube", "from": 11,
	 "tileset": "res://assets/sprites/tileset_fleischgrube.png",
	 "darkness": Color(0.2, 0.12, 0.12),
	 "weights": {"melee": 0.3, "ranged": 0.3, "exploder": 0.4},
	 "elite_chance": 0.18},
]

var floor_num := 1
var carry_hp := -1
var carry_potions := 1
var carry_relics: Array = []
var souls := 0
var wins := 0
var upgrades := {"vitality": 0, "might": 0, "reflexes": 0, "belt": 0}


func biome() -> Dictionary:
	var current: Dictionary = BIOMES[0]
	for b in BIOMES:
		if floor_num >= int(b["from"]):
			current = b
	return current


func _ready() -> void:
	_load()


func add_souls(amount: int) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("has_relic") and player.has_relic("soul_greed"):
		amount = ceili(amount * 1.5)
	souls += amount


func random_unowned_relic(owned: Array) -> String:
	## "" when the run already holds every relic.
	var pool: Array = []
	for id in RELIC_DEFS:
		if not owned.has(id):
			pool.append(id)
	return "" if pool.is_empty() else pool.pick_random()


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
	carry_relics = []
	_save()
	get_tree().change_scene_to_file.call_deferred(RUN_SCENE)


func next_floor(current_hp: int, current_potions: int, current_relics: Array) -> void:
	floor_num += 1
	carry_hp = current_hp
	carry_potions = current_potions
	carry_relics = current_relics
	_save()
	# Deferred: callers include Area2D physics callbacks, where changing the
	# scene mid-flush is an error.
	get_tree().reload_current_scene.call_deferred()


func bank_win() -> void:
	## Called the moment a boss dies: the win survives even if the player
	## descends further and dies down there.
	wins += 1
	_save()


func return_to_hub() -> void:
	## Victory-portal exit: run ends cleanly (win was already banked).
	floor_num = 1
	carry_hp = -1
	carry_potions = 1
	carry_relics = []
	_save()
	get_tree().change_scene_to_file.call_deferred(HUB_SCENE)


func player_died() -> void:
	floor_num = 1
	carry_hp = -1
	carry_potions = 1
	carry_relics = []
	_save()
	await get_tree().create_timer(RESTART_DELAY).timeout
	get_tree().change_scene_to_file.call_deferred(HUB_SCENE)


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "souls", souls)
	cfg.set_value("meta", "wins", wins)
	cfg.set_value("meta", "upgrades", upgrades)
	cfg.save(SAVE_PATH)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	souls = cfg.get_value("meta", "souls", 0)
	wins = cfg.get_value("meta", "wins", 0)
	var saved: Dictionary = cfg.get_value("meta", "upgrades", {})
	for key in upgrades:
		upgrades[key] = int(saved.get(key, 0))
