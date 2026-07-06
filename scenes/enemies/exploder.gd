extends "res://scenes/enemies/enemy.gd"
## Exploder: sprints at the player FASTER than they can run, inflates in a
## telegraphed windup (growing ring shows the honest blast radius), then
## detonates -- friendly fire included, the blast hurts other enemies too.
## Killing it lights a short fuse instead of dying: it still blows after
## FUSE_TIME. Counterplay: kill it at range, or dash out at the last moment.

# --- Feel dials ---------------------------------------------------------------
const EXPLOSION_RADIUS := 90.0
const EXPLOSION_KNOCKBACK := 1.5
const FUSE_TIME := 0.45       # death -> delayed blast; blink warns
# --------------------------------------------------------------------------------

var _detonated := false
var _fusing := false
var _fuse_left := 0.0
var _telegraph_ring: Line2D


func _physics_process(delta: float) -> void:
	super(delta)
	if _fusing:
		_fuse_left -= delta
		if _fuse_left <= 0.0:
			_explode()


func _show_attack_tell() -> void:
	# Honest blast telegraph: ring grows to the real radius during the windup.
	_telegraph_ring = _make_ring(EXPLOSION_RADIUS, Color(1, 0.35, 0.15, 0.4), 3.0)
	_telegraph_ring.scale = Vector2(0.2, 0.2)
	_telegraph_tween.tween_property(_telegraph_ring, "scale", Vector2.ONE, attack_windup)


func _perform_attack() -> void:
	_explode()


func take_damage(amount: int, source_position: Vector2, knockback_scale := 1.0) -> void:
	if _fusing:
		return  # already lit; no double-death, knockback can't defuse it
	super(amount, source_position, knockback_scale)


func _die() -> void:
	if _detonated:
		super()
		return
	if not _fusing:
		_start_fuse()


func _start_fuse() -> void:
	_fusing = true
	_fuse_left = FUSE_TIME
	_cancel_attack()
	ai_enabled = false  # stops chasing; body still slides with knockback
	# Rapid red blink = get away NOW.
	var t := create_tween().set_loops(3)
	t.tween_property(_visual, "self_modulate", Color(1, 0.25, 0.2), FUSE_TIME / 6.0)
	t.tween_property(_visual, "self_modulate", _base_color, FUSE_TIME / 6.0)


func _explode() -> void:
	if _detonated:
		return
	_detonated = true
	_fusing = false
	_clear_telegraph_ring()
	Sfx.play("slam", -1.0)
	var flash := _make_ring(EXPLOSION_RADIUS, Color(1, 0.5, 0.2, 0.9), 6.0)
	var t := flash.create_tween().set_parallel()
	t.tween_property(flash, "scale", Vector2(1.2, 1.2), 0.22)
	t.tween_property(flash, "modulate:a", 0.0, 0.22)
	t.chain().tween_callback(flash.queue_free)
	# Blast hits player AND enemies (mask 2|4 = 6) -- corridor packs beware.
	var shape := CircleShape2D.new()
	shape.radius = EXPLOSION_RADIUS
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0.0, global_position)
	params.collision_mask = 6
	for hit in get_world_2d().direct_space_state.intersect_shape(params, 16):
		var body: Node = hit.collider
		if body != self and body.has_method("take_damage") and not body.get("dead"):
			body.take_damage(attack_damage, global_position, EXPLOSION_KNOCKBACK)
	_die()


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
