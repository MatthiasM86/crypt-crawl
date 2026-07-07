extends Area2D
## Loot chest in a dungeon side room. Walk over to open. Cursed chests are
## openly marked (purple glow/lid) and spring a melee ambush on opening --
## informed risk/reward, no gotchas. Contents: usually a relic, weapon or
## skill (docs/plan.md Ausblick 6), otherwise souls + a potion.

const LOOT_CHANCE := 0.6
const SOULS_FALLBACK := 15   # split across 3 wisps
const AMBUSH_COUNT := 2

const MELEE_SCENE := preload("res://scenes/enemies/melee_enemy.tscn")
const RELIC_PICKUP_SCENE := preload("res://scenes/pickups/relic_pickup.tscn")
const WEAPON_PICKUP_SCENE := preload("res://scenes/pickups/weapon_pickup.tscn")
const SKILL_PICKUP_SCENE := preload("res://scenes/pickups/skill_pickup.tscn")
const POTION_SCENE := preload("res://scenes/pickups/potion_pickup.tscn")
const SOUL_SCENE := preload("res://scenes/pickups/soul_wisp.tscn")

@export var cursed := false
@export var ambush_hp_bonus := 0     # generator injects floor scaling
@export var ambush_speed_bonus := 0.0

var _opened := false


func _ready() -> void:
	if cursed:
		$Glow.color = Color(0.75, 0.35, 1.0)
		$Visual.modulate = Color(0.8, 0.55, 1.0)  # violet-tinted cursed chest
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _opened:
		return
	_opened = true
	Sfx.play("chest")
	# 2-frame lid pop; "open" is non-looping so it holds the open frame and the
	# chest node persists -> it stays open for the rest of the run.
	$Visual.play("open")
	var t := create_tween()
	t.tween_property($Visual, "scale", Vector2(1.14, 1.14), 0.07)
	t.tween_property($Visual, "scale", Vector2.ONE, 0.13) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	$Glow.energy = 0.18
	# Deferred: spawning scenes with collision during the physics flush.
	_spawn_contents.call_deferred(body)


func _spawn_contents(body: Node2D) -> void:
	var parent := get_parent()
	if cursed:
		for i in AMBUSH_COUNT:
			var enemy := MELEE_SCENE.instantiate()
			enemy.max_hp += ambush_hp_bonus
			enemy.move_speed += ambush_speed_bonus
			# Snapped: chests can sit near walls; ambushers must not spawn in them.
			enemy.position = GameManager.snap_to_walkable(self,
					position + Vector2(42, 0).rotated(TAU * i / AMBUSH_COUNT + 0.8))
			parent.add_child(enemy)
	if randf() < LOOT_CHANCE and _spawn_loot(body, parent):
		return
	for i in 3:
		var wisp := SOUL_SCENE.instantiate()
		wisp.value = SOULS_FALLBACK / 3
		wisp.position = position
		parent.add_child(wisp)
	var potion := POTION_SCENE.instantiate()
	potion.position = GameManager.snap_to_walkable(self, position + Vector2(0, 34))
	parent.add_child(potion)


func _spawn_loot(body: Node2D, parent: Node) -> bool:
	## Even split relic/weapon/skill; false (-> soul/potion fallback) only
	## when the roll lands on relics and the run already owns all seven.
	match ["relic", "weapon", "skill"].pick_random():
		"relic":
			var owned: Array = body.relics if body.get("relics") != null else []
			var relic_id := GameManager.random_unowned_relic(owned)
			if relic_id == "":
				return false
			var pickup := RELIC_PICKUP_SCENE.instantiate()
			pickup.relic_id = relic_id
			pickup.position = GameManager.snap_to_walkable(self, position + Vector2(0, 34))
			parent.add_child(pickup)
		"weapon":
			var pickup := WEAPON_PICKUP_SCENE.instantiate()
			pickup.weapon_id = GameManager.random_other_weapon(body.get("weapon_id"))
			pickup.position = GameManager.snap_to_walkable(self, position + Vector2(0, 34))
			parent.add_child(pickup)
		"skill":
			var pickup := SKILL_PICKUP_SCENE.instantiate()
			pickup.skill_id = GameManager.random_other_skill(body.get("skill_id"))
			pickup.position = GameManager.snap_to_walkable(self, position + Vector2(0, 34))
			parent.add_child(pickup)
	return true
