extends "res://scenes/enemies/enemy.gd"
## Shared boss scaffolding (docs/enemies.md): joins the "boss" group, resists
## knockback so the player's slam can't juggle it, emits `defeated` on death
## (the arena spawns the victory portal + loot on that), and exposes `boss_name`
## for the HUD boss bar. Subclasses implement patterns via the enemy.gd hooks
## (_begin_attack / _show_attack_tell / _perform_attack). No `hurt` clip -- a
## boss shouldn't flinch. Every boss telegraphs (plan.md core-feel rule).

signal defeated

@export var boss_name := "Boss"

const KNOCKBACK_RESIST := 0.25
const ENRAGE_FRACTION := 0.5   # below this HP fraction, attacks speed up

var _telegraph_ring: Line2D
var _lane: Polygon2D


func _ready() -> void:
	super()
	add_to_group("boss")


func take_damage(amount: int, source_position: Vector2, knockback_scale := 1.0) -> void:
	super(amount, source_position, knockback_scale * KNOCKBACK_RESIST)


func _die() -> void:
	defeated.emit()
	super()


func _enraged() -> bool:
	return hp <= int(max_hp * ENRAGE_FRACTION)


func _make_ring(radius: float, color: Color, width: float) -> Line2D:
	var ring := Line2D.new()
	ring.width = width
	ring.default_color = color
	var pts := PackedVector2Array()
	for i in 33:
		pts.append(Vector2.from_angle(TAU * i / 32.0) * radius)
	ring.points = pts
	add_child(ring)
	return ring


func _make_lane(dir: Vector2, length: float, half_width: float, color: Color) -> Polygon2D:
	# Charge telegraph: a rectangle from the boss out along `dir`. World-space is
	# fine -- the boss root never rotates (only _pivot does, for facing).
	var perp := dir.orthogonal() * half_width
	var lane := Polygon2D.new()
	lane.polygon = PackedVector2Array([-perp, perp, dir * length + perp, dir * length - perp])
	lane.color = color
	add_child(lane)
	return lane


func _clear_telegraph_ring() -> void:
	if _telegraph_ring and is_instance_valid(_telegraph_ring):
		_telegraph_ring.queue_free()
	_telegraph_ring = null
	if _lane and is_instance_valid(_lane):
		_lane.queue_free()
	_lane = null


func _cancel_attack() -> void:
	_clear_telegraph_ring()
	super()
