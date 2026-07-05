extends "res://scenes/enemies/enemy.gd"
## Boss "Kryptwächter" (every 5th floor): two telegraphed patterns.
## Close range: expanding AoE slam ring (dash out!). Far range: a ring of
## 8 projectiles. Enrages below half HP (faster attacks). Heavily
## knockback-resistant so the player's slam can't juggle it. Inherits the
## state machine, hit-flash, knockback and death from enemy.gd.

signal defeated

# --- Feel dials ---------------------------------------------------------------
const AOE_TRIGGER := 150.0    # player closer than this at windup start -> AOE
const AOE_RADIUS := 120.0
const RING_PROJECTILES := 8
const ENRAGE_FRACTION := 0.5
const ENRAGE_SPEEDUP := 0.55  # cooldown multiplier while enraged
const KNOCKBACK_RESIST := 0.25
# --------------------------------------------------------------------------------

const BOSS_PROJECTILE := preload("res://scenes/projectiles/projectile.tscn")

enum Pattern { AOE, RING }

var _pattern := Pattern.RING
var _telegraph_ring: Line2D


func _ready() -> void:
	super()
	add_to_group("boss")


func _begin_attack() -> void:
	# Pattern locks at windup start so the telegraph is honest.
	_pattern = Pattern.AOE if _distance_to_player() <= AOE_TRIGGER else Pattern.RING
	super()


func _show_attack_tell() -> void:
	if _pattern != Pattern.AOE:
		return  # ring pattern: body color/scale telegraph is enough
	_telegraph_ring = _make_ring(AOE_RADIUS, Color(1, 0.3, 0.2, 0.35), 3.0)
	_telegraph_ring.scale = Vector2(0.25, 0.25)
	_telegraph_tween.tween_property(_telegraph_ring, "scale", Vector2.ONE, attack_windup)


func _perform_attack() -> void:
	_clear_telegraph_ring()
	match _pattern:
		Pattern.AOE:
			_do_aoe()
		Pattern.RING:
			_do_ring()
	if hp <= int(max_hp * ENRAGE_FRACTION):
		_cooldown_left *= ENRAGE_SPEEDUP


func _do_aoe() -> void:
	Sfx.play("slam", -2.0)
	var flash_ring := _make_ring(AOE_RADIUS, Color(1, 0.45, 0.25, 0.9), 6.0)
	var t := flash_ring.create_tween().set_parallel()
	t.tween_property(flash_ring, "scale", Vector2(1.15, 1.15), 0.25)
	t.tween_property(flash_ring, "modulate:a", 0.0, 0.25)
	t.chain().tween_callback(flash_ring.queue_free)
	# Distance check instead of a hitbox: boss -> player only, radius is king.
	if _player_alive() and _distance_to_player() <= AOE_RADIUS + 13.0:
		_player.take_damage(attack_damage, global_position)


func _do_ring() -> void:
	Sfx.play("shoot")
	for i in RING_PROJECTILES:
		var dir := Vector2.from_angle(TAU * i / RING_PROJECTILES)
		var projectile := BOSS_PROJECTILE.instantiate()
		projectile.direction = dir
		projectile.damage = 1
		projectile.position = global_position + dir * 30.0
		get_parent().add_child(projectile)


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


func _clear_telegraph_ring() -> void:
	if _telegraph_ring and is_instance_valid(_telegraph_ring):
		_telegraph_ring.queue_free()
	_telegraph_ring = null


func _cancel_attack() -> void:
	_clear_telegraph_ring()
	super()


func take_damage(amount: int, source_position: Vector2, knockback_scale := 1.0) -> void:
	super(amount, source_position, knockback_scale * KNOCKBACK_RESIST)


func _die() -> void:
	defeated.emit()
	super()
