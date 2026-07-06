extends Node
## Global run/meta-state singleton (autoload): floor counter, death/floor
## transitions, and persistent meta-progression (souls + permanent upgrades,
## saved to user://save.cfg). The hub scene is home base: runs start via
## start_run() from the hub portal and end back in the hub on death.

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

## Run-bound weapons (docs/plan.md Ausblick 6, Entscheidung Juli 2026): full
## movesets, not stat modifiers -- hitbox size/position, range, timing and
## knockback all differ. Visuals still reuse the one attack animation
## (interim; asset-spec.md tracks the per-weapon swing-animation backlog).
const DEFAULT_WEAPON := "kurzschwert"
const WEAPON_DEFS := {
	"kurzschwert": {"label": "Kurzschwert", "desc": "Ausgewogen: mittlere Reichweite, mittleres Tempo",
		"color": Color(0.75, 0.75, 0.8), "damage": 1, "range": 56.0,
		"hitbox_size": Vector2(44, 36), "hitbox_pos": Vector2(34, 0),
		"windup": 0.12, "recover": 0.15, "cooldown": 0.5, "knockback": 1.0},
	"spiess": {"label": "Spieß", "desc": "Lange Reichweite, schnell, weniger Wucht",
		"color": Color(0.6, 0.85, 0.6), "damage": 1, "range": 78.0,
		"hitbox_size": Vector2(66, 20), "hitbox_pos": Vector2(50, 0),
		"windup": 0.10, "recover": 0.12, "cooldown": 0.4, "knockback": 0.75},
	"kriegshammer": {"label": "Kriegshammer", "desc": "Kurze Reichweite, langsam, brutale Wucht",
		"color": Color(0.85, 0.5, 0.3), "damage": 3, "range": 48.0,
		"hitbox_size": Vector2(52, 52), "hitbox_pos": Vector2(28, 0),
		"windup": 0.32, "recover": 0.25, "cooldown": 0.95, "knockback": 2.4},
}

## Run-bound active skills (docs/plan.md Ausblick 6, Entscheidung Juli 2026):
## the RMB slot, previously hardcoded to Rundumschlag. Behavior lives in
## player.gd's _perform_skill(); these defs only carry display info + cooldown.
const DEFAULT_SKILL := "rundumschlag"
const SKILL_DEFS := {
	"rundumschlag": {"label": "Rundumschlag", "desc": "AoE-Schlag um dich herum", "color": Color(1.0, 0.75, 0.35), "cooldown": 3.0},
	"frostnova": {"label": "Frostnova", "desc": "Friert Gegner im Umkreis kurz ein", "color": Color(0.55, 0.85, 1.0), "cooldown": 4.0},
	"blutopfer": {"label": "Blutopfer", "desc": "Opfert HP für Schadens-Nova + Lebensraub bei Kills", "color": Color(0.75, 0.15, 0.2), "cooldown": 5.0},
	"seelenkette": {"label": "Seelenkette", "desc": "Zieht Gegner in einem Kegel heran", "color": Color(0.6, 0.4, 0.9), "cooldown": 4.5},
}

signal upgrades_changed

## Depth biomes (docs/plan.md Ausblick 3): look, mood and spawn mix per band.
## Interim tilesets are hue-shifts of the crypt atlas; real PixelLab tilesets
## replace the same files (asset-spec §4.5). Exploders stay off on floor 1.
const BIOMES := [
	{"name": "Krypta", "from": 1,
	 "tileset": "res://assets/sprites/tileset_placeholder.png",
	 "darkness": Color(0.16, 0.16, 0.21),
	 "weights": {"melee": 0.45, "ranged": 0.35, "exploder": 0.2, "tank": 0.0, "summoner": 0.0},
	 "elite_chance": 0.12},
	{"name": "Katakomben", "from": 6,
	 "tileset": "res://assets/sprites/tileset_katakomben.png",
	 "darkness": Color(0.17, 0.15, 0.12),
	 "weights": {"melee": 0.25, "ranged": 0.3, "exploder": 0.3, "tank": 0.15, "summoner": 0.0},
	 "elite_chance": 0.15},
	{"name": "Fleischgrube", "from": 11,
	 "tileset": "res://assets/sprites/tileset_fleischgrube.png",
	 "darkness": Color(0.2, 0.12, 0.12),
	 "weights": {"melee": 0.2, "ranged": 0.25, "exploder": 0.35, "tank": 0.1, "summoner": 0.1},
	 "elite_chance": 0.18},
]

var floor_num := 1
var carry_hp := -1
var carry_potions := 1
var carry_relics: Array = []
var carry_weapon: String = DEFAULT_WEAPON
var carry_skill: String = DEFAULT_SKILL
var souls := 0
var run_souls := 0  # earned this run only; feeds the death-screen recap
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
	run_souls += amount


func random_unowned_relic(owned: Array) -> String:
	## "" when the run already holds every relic.
	var pool: Array = []
	for id in RELIC_DEFS:
		if not owned.has(id):
			pool.append(id)
	return "" if pool.is_empty() else pool.pick_random()


func random_other_weapon(exclude_id: String) -> String:
	var pool: Array = WEAPON_DEFS.keys().filter(func(id): return id != exclude_id)
	return "" if pool.is_empty() else pool.pick_random()


func random_other_skill(exclude_id: String) -> String:
	var pool: Array = SKILL_DEFS.keys().filter(func(id): return id != exclude_id)
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
	carry_weapon = DEFAULT_WEAPON
	carry_skill = DEFAULT_SKILL
	run_souls = 0
	_save()
	get_tree().change_scene_to_file.call_deferred(RUN_SCENE)


func next_floor(current_hp: int, current_potions: int, current_relics: Array,
		current_weapon: String, current_skill: String) -> void:
	floor_num += 1
	carry_hp = current_hp
	carry_potions = current_potions
	carry_relics = current_relics
	carry_weapon = current_weapon
	carry_skill = current_skill
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
	carry_weapon = DEFAULT_WEAPON
	carry_skill = DEFAULT_SKILL
	_save()
	get_tree().change_scene_to_file.call_deferred(HUB_SCENE)


func player_died() -> void:
	var floor_reached := floor_num
	var souls_earned := run_souls
	floor_num = 1
	carry_hp = -1
	carry_potions = 1
	carry_relics = []
	carry_weapon = DEFAULT_WEAPON
	carry_skill = DEFAULT_SKILL
	_save()
	DeathScreen.show_recap(floor_reached, souls_earned)


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
