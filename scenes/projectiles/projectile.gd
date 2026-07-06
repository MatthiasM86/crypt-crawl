extends Area2D
## Straight-flying enemy projectile. Spawn pattern (ranged_enemy.gd):
## shooter sets `direction` and `damage`, adds it to the level (the shooter's
## parent, NOT the shooter -- it must outlive and not move with it), then
## places it at the muzzle. collision_mask = world|player only, so it can
## never hit the shooter or other enemies. Despawns on any contact or after
## LIFETIME.

# --- Feel dials ---------------------------------------------------------------
const SPEED := 420.0    # vs player 300 px/s: dodgeable on reaction mid-band
const LIFETIME := 2.0   # failsafe; walls normally despawn it first
# --------------------------------------------------------------------------------

var direction := Vector2.RIGHT
var damage := 1

var _age := 0.0


func _ready() -> void:
	rotation = direction.angle()
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	position += direction * SPEED * delta
	_age += delta
	$Visual.scale = Vector2.ONE * (1.0 + 0.15 * sin(_age * 40.0))  # crackle flicker
	if _age >= LIFETIME:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	# Walls (layer 1) just despawn it; the player takes damage first.
	# queue_free (deferred deletion) is safe inside a physics callback.
	if body.has_method("take_damage") and not body.get("dead"):
		body.take_damage(damage, global_position)
	queue_free()
