extends "res://scenes/enemies/enemy.gd"
## Ranged variant: keeps a kiting band, telegraphs (color+scale only), then
## fires a straight, non-homing projectile at the player's position at fire
## time -- the flight time is the dodge window. Inherits HP/knockback/flash/
## death and the state machine from enemy.gd.

# --- Feel dials ---------------------------------------------------------------
const FLEE_DISTANCE := 180.0  # player closer than this -> back away
const MUZZLE_OFFSET := 22.0
# The hold-and-shoot band is FLEE_DISTANCE..attack_range (380 in the .tscn).
# --------------------------------------------------------------------------------

const PROJECTILE_SCENE := preload("res://scenes/projectiles/projectile.tscn")


func _in_attack_position() -> bool:
	return _distance_to_player() <= attack_range and _has_los()


func _chase_velocity() -> Vector2:
	if _distance_to_player() < FLEE_DISTANCE:
		_face_player()
		if _cooldown_left == 0.0 and _has_los():
			_begin_attack()  # cornered but ready: plant and fire point-blank
			return Vector2.ZERO
		# Plain steer-away, no nav: walls simply stop the retreat, so a
		# cornered archer stands its ground -- which is the fun outcome.
		return global_position.direction_to(_player.global_position) * -move_speed
	return super()


func _show_attack_tell() -> void:
	pass  # no blade; body color/scale telegraph is the "when"


func _perform_attack() -> void:
	Sfx.play("shoot")
	var dir := global_position.direction_to(_player.global_position)
	var projectile := PROJECTILE_SCENE.instantiate()
	projectile.direction = dir
	projectile.damage = attack_damage
	# Level owns the projectile (shooter's parent = TestRoom). Plain add_child
	# is fine: we're in _physics_process, not a physics signal callback.
	get_parent().add_child(projectile)
	projectile.global_position = global_position + dir * MUZZLE_OFFSET
