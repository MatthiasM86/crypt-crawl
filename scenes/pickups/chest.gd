extends Area2D
## Loot chest in a dungeon side room. Walk over to open. Cursed chests are
## openly marked (purple glow/lid) and spring a melee ambush on opening --
## informed risk/reward, no gotchas. Contents: usually a relic the run
## doesn't own yet, otherwise souls + a potion.

const RELIC_CHANCE := 0.6
const SOULS_FALLBACK := 15   # split across 3 wisps
const AMBUSH_COUNT := 2

const MELEE_SCENE := preload("res://scenes/enemies/melee_enemy.tscn")
const RELIC_PICKUP_SCENE := preload("res://scenes/pickups/relic_pickup.tscn")
const POTION_SCENE := preload("res://scenes/pickups/potion_pickup.tscn")
const SOUL_SCENE := preload("res://scenes/pickups/soul_wisp.tscn")

@export var cursed := false
@export var ambush_hp_bonus := 0     # generator injects floor scaling
@export var ambush_speed_bonus := 0.0

var _opened := false


func _ready() -> void:
	if cursed:
		$Glow.color = Color(0.75, 0.35, 1.0)
		$Lid.color = Color(0.42, 0.24, 0.55)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _opened:
		return
	_opened = true
	Sfx.play("chest")
	modulate = Color(0.55, 0.5, 0.5)
	$Glow.energy = 0.15
	# Deferred: spawning scenes with collision during the physics flush.
	_spawn_contents.call_deferred(body)


func _spawn_contents(body: Node2D) -> void:
	var parent := get_parent()
	if cursed:
		for i in AMBUSH_COUNT:
			var enemy := MELEE_SCENE.instantiate()
			enemy.max_hp += ambush_hp_bonus
			enemy.move_speed += ambush_speed_bonus
			enemy.position = position + Vector2(42, 0).rotated(TAU * i / AMBUSH_COUNT + 0.8)
			parent.add_child(enemy)
	var owned: Array = body.relics if body.get("relics") != null else []
	var relic_id := GameManager.random_unowned_relic(owned)
	if relic_id != "" and randf() < RELIC_CHANCE:
		var pickup := RELIC_PICKUP_SCENE.instantiate()
		pickup.relic_id = relic_id
		pickup.position = position + Vector2(0, 34)
		parent.add_child(pickup)
	else:
		for i in 3:
			var wisp := SOUL_SCENE.instantiate()
			wisp.value = SOULS_FALLBACK / 3
			wisp.position = position
			parent.add_child(wisp)
		var potion := POTION_SCENE.instantiate()
		potion.position = position + Vector2(0, 34)
		parent.add_child(potion)
