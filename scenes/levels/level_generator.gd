extends Node2D
## Procedural rooms-and-corridors level (docs/plan.md Phase 4.5).
## Grid-based generation: scatter non-overlapping rooms, chain-connect them
## with 2-cell-wide L-corridors (connectivity by construction, still verified
## with the plan-mandated flood-fill check), fill every non-floor cell with
## wall colliders, then bake the navmesh at runtime -- the exact same
## NavigationRegion2D + static-collider carve flow as the hand-built
## test_room, just with generated geometry. Death reloads this scene, which
## regenerates with a fresh seed: that IS the roguelike loop.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const MELEE_SCENE := preload("res://scenes/enemies/melee_enemy.tscn")
const RANGED_SCENE := preload("res://scenes/enemies/ranged_enemy.tscn")

# --- Generation dials ---------------------------------------------------------
const CELL := 32                  # px per grid cell
const MAP_W := 64                 # cells (2048 px)
const MAP_H := 36                 # cells (1152 px)
const ROOM_TRIES := 24            # placement attempts
const MAX_ROOMS := 10
const ROOM_MIN := 5               # room side, cells
const ROOM_MAX := 10
const CORRIDOR_W := 2             # cells; 64 px - agent_radius inset leaves 32 px
const AGENT_RADIUS := 16.0        # navmesh inset; matches test_room
const WALL_EPS := 0.1             # px overlap between wall rects: exactly
                                  # coincident edges make the navmesh bake's
                                  # convex partition fail; overlaps are fine
const ENEMIES_PER_ROOM_MAX := 2   # 1..this per room (player's room stays empty)
const RANGED_CHANCE := 0.35       # per spawned enemy
const FLOOR_COLOR := Color(0.14, 0.13, 0.15, 1)
# ------------------------------------------------------------------------------

var _rooms: Array[Rect2i] = []
var _floor := {}  # Set: Vector2i -> true

@onready var _region: NavigationRegion2D = $NavigationRegion2D


func _ready() -> void:
	randomize()
	for attempt in 3:
		_rooms.clear()
		_floor.clear()
		_generate_layout()
		if _all_rooms_reachable():
			break
		if attempt == 2:
			push_error("Level generation failed the reachability check 3x; using last layout")
	_build_geometry()
	_spawn_player_and_enemies()
	_bake_navmesh()


func _generate_layout() -> void:
	for i in ROOM_TRIES:
		if _rooms.size() >= MAX_ROOMS:
			break
		var w := randi_range(ROOM_MIN, ROOM_MAX)
		var h := randi_range(ROOM_MIN, ROOM_MAX)
		var room := Rect2i(
				randi_range(1, MAP_W - w - 1), randi_range(1, MAP_H - h - 1), w, h)
		if _overlaps_existing(room):
			continue
		if not _rooms.is_empty():
			_carve_corridor(_rooms[_rooms.size() - 1].get_center(), room.get_center())
		_carve_room(room)
		_rooms.append(room)


func _overlaps_existing(room: Rect2i) -> bool:
	for other in _rooms:
		if room.grow(1).intersects(other):
			return true
	return false


func _carve_room(room: Rect2i) -> void:
	for x in range(room.position.x, room.end.x):
		for y in range(room.position.y, room.end.y):
			_floor[Vector2i(x, y)] = true


func _carve_corridor(from: Vector2i, to: Vector2i) -> void:
	# L-shape: horizontal at from.y, then vertical at to.x, CORRIDOR_W wide.
	for x in range(mini(from.x, to.x), maxi(from.x, to.x) + 1):
		for w in CORRIDOR_W:
			_floor[Vector2i(x, from.y + w)] = true
	for y in range(mini(from.y, to.y), maxi(from.y, to.y) + 1):
		for w in CORRIDOR_W:
			_floor[Vector2i(to.x + w, y)] = true


func _all_rooms_reachable() -> bool:
	# Flood-fill over floor cells from the spawn room (docs/plan.md demands
	# the check even though chain-corridors connect by construction).
	if _rooms.is_empty():
		return false
	var start: Vector2i = _rooms[0].get_center()
	var visited := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		for offset in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + offset
			if _floor.has(next) and not visited.has(next):
				visited[next] = true
				queue.append(next)
	for room in _rooms:
		if not visited.has(room.get_center()):
			return false
	return true


func _build_geometry() -> void:
	# Walls: every non-floor cell, row-merged into runs, as colliders under
	# the NavigationRegion2D so the bake carves them (parsed geometry =
	# static colliders, mask 1). No wall visuals needed: the void already
	# renders as the dark clear color, floors are the lit rectangles.
	var walls := StaticBody2D.new()
	walls.name = "Walls"
	walls.collision_layer = 1
	walls.collision_mask = 0
	_region.add_child(walls)
	for run in _row_runs(false):
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(run.size.x * CELL + 2 * WALL_EPS, CELL + 2 * WALL_EPS)
		shape.shape = rect
		shape.position = Vector2(
				(run.position.x + run.size.x / 2.0) * CELL,
				(run.position.y + 0.5) * CELL)
		walls.add_child(shape)
	for run in _row_runs(true):
		var floor_visual := Polygon2D.new()
		floor_visual.color = FLOOR_COLOR
		var origin := Vector2(run.position.x * CELL, run.position.y * CELL)
		var size := Vector2(run.size.x * CELL, CELL)
		floor_visual.polygon = PackedVector2Array([
			origin, origin + Vector2(size.x, 0), origin + size, origin + Vector2(0, size.y),
		])
		add_child(floor_visual)


func _row_runs(want_floor: bool) -> Array[Rect2i]:
	## Horizontal runs of consecutive cells whose floor-ness == want_floor.
	var runs: Array[Rect2i] = []
	for y in MAP_H:
		var run_start := -1
		for x in MAP_W + 1:
			var matches := x < MAP_W and _floor.has(Vector2i(x, y)) == want_floor
			if matches and run_start < 0:
				run_start = x
			elif not matches and run_start >= 0:
				runs.append(Rect2i(run_start, y, x - run_start, 1))
				run_start = -1
	return runs


func _spawn_player_and_enemies() -> void:
	# Player first: enemies resolve the "player" group in their _ready().
	var player := PLAYER_SCENE.instantiate()
	player.position = _cell_center(_rooms[0].get_center())
	add_child(player)
	for i in range(1, _rooms.size()):
		var room := _rooms[i]
		for j in randi_range(1, ENEMIES_PER_ROOM_MAX):
			var scene := RANGED_SCENE if randf() < RANGED_CHANCE else MELEE_SCENE
			var enemy := scene.instantiate()
			enemy.position = _cell_center(Vector2i(
					randi_range(room.position.x + 1, room.end.x - 2),
					randi_range(room.position.y + 1, room.end.y - 2)))
			add_child(enemy)


func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2((cell.x + 0.5) * CELL, (cell.y + 0.5) * CELL)


func _bake_navmesh() -> void:
	var nav_poly := NavigationPolygon.new()
	nav_poly.add_outline(PackedVector2Array([
		Vector2.ZERO,
		Vector2(MAP_W * CELL, 0),
		Vector2(MAP_W * CELL, MAP_H * CELL),
		Vector2(0, MAP_H * CELL),
	]))
	nav_poly.parsed_geometry_type = NavigationPolygon.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_poly.parsed_collision_mask = 1
	nav_poly.agent_radius = AGENT_RADIUS
	_region.navigation_polygon = nav_poly
	_region.bake_navigation_polygon(false)
