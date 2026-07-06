extends Node2D
## "Brandsiegel" relic: fire patch left behind by the player's slam. Ticks
## damage on enemies standing in it. Visuals are code-drawn (flickering
## disc + orange light) -- no scene file needed; spawners just .new() this.

const LIFETIME := 3.0
const TICK_INTERVAL := 0.5
const RADIUS := 70.0
const DAMAGE := 1

var _age := 0.0
var _tick_left := 0.35


func _ready() -> void:
	z_index = -1  # burns under the characters
	var light := PointLight2D.new()
	light.texture = preload("res://assets/textures/radial_light.tres")
	light.color = Color(1.0, 0.5, 0.15)
	light.energy = 0.9
	light.texture_scale = 0.5
	add_child(light)


func _physics_process(delta: float) -> void:
	_age += delta
	queue_redraw()
	if _age >= LIFETIME:
		queue_free()
		return
	_tick_left -= delta
	if _tick_left <= 0.0:
		_tick_left = TICK_INTERVAL
		_burn()


func _burn() -> void:
	var shape := CircleShape2D.new()
	shape.radius = RADIUS
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0.0, global_position)
	params.collision_mask = 4
	for hit in get_world_2d().direct_space_state.intersect_shape(params, 16):
		var body: Node = hit.collider
		if body.has_method("take_damage") and not body.get("dead"):
			body.take_damage(DAMAGE, global_position, 0.3)


func _draw() -> void:
	var fade := clampf(1.0 - _age / LIFETIME, 0.0, 1.0)
	var flicker := 0.85 + 0.15 * sin(_age * 22.0)
	draw_circle(Vector2.ZERO, RADIUS * flicker, Color(1.0, 0.35, 0.1, 0.28 * fade))
	draw_circle(Vector2.ZERO, RADIUS * 0.55 * flicker, Color(1.0, 0.6, 0.2, 0.3 * fade))
