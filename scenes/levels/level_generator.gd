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
const STAIRS_SCENE := preload("res://scenes/levels/stairs.tscn")
const BOSS_SCENE := preload("res://scenes/enemies/boss.tscn")
const VICTORY_PORTAL_SCENE := preload("res://scenes/levels/victory_portal.tscn")
const CHEST_SCENE := preload("res://scenes/pickups/chest.tscn")
const RELIC_PICKUP_SCENE := preload("res://scenes/pickups/relic_pickup.tscn")
const WEAPON_PICKUP_SCENE := preload("res://scenes/pickups/weapon_pickup.tscn")
const SKILL_PICKUP_SCENE := preload("res://scenes/pickups/skill_pickup.tscn")
const EXPLODER_SCENE := preload("res://scenes/enemies/exploder.tscn")
const TANK_SCENE := preload("res://scenes/enemies/shield_tank.tscn")
const SUMMONER_SCENE := preload("res://scenes/enemies/summoner.tscn")

## Maps GameManager.BIOMES weight keys to scenes; fixed order for the roll.
const SPAWN_TYPES := ["exploder", "tank", "summoner", "ranged", "melee"]
const SPAWN_SCENES := {
	"exploder": EXPLODER_SCENE, "tank": TANK_SCENE, "summoner": SUMMONER_SCENE,
	"ranged": RANGED_SCENE, "melee": MELEE_SCENE,
}
const ELITE_EXCLUDED := ["exploder", "summoner"]  # elite bombs/spawners = chaos

const BOSS_EVERY := 5             # every Nth floor is a boss arena
const CHEST_ROOM_CHANCE := 0.3    # per room (player's room excluded)...
const CHEST_MAX := 2              # ...capped per floor
const CHEST_CURSED_CHANCE := 0.4

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
# Spawn mix + elite chance now live per-biome in GameManager.BIOMES.

# --- Prefab rooms (plan.md Ausblick 4): hand-built templates stamped into a
# fitting middle room. "#" = wall cell (never overwrites carved corridors),
# "C" chest, "K" cursed chest, "B" blood shrine. Interior-only: outer walls
# come from the surrounding void like every room. -----------------------------
var prefab_chance := 0.6          # per floor (var so probes can force it)
const PREFABS := [
	{"name": "Schatzkammer", "rows": [
		".........",
		".##...##.",
		".#C...K#.",
		".........",
		".........",
		".........",
		".........",
	]},
	{"name": "Blutschrein", "rows": [
		".......",
		".#...#.",
		"...B...",
		".......",
		".......",
	]},
	{"name": "Säulenhalle", "rows": [
		".........",
		"..#...#..",
		".........",
		".........",
		".........",
	]},
]
const BLOOD_SHRINE_SCENE := preload("res://scenes/levels/blood_shrine.tscn")
# ------------------------------------------------------------------------------

# --- Floor difficulty scaling (applied via enemy @export dials at spawn) ------
const SCALE_HP_EVERY := 2         # +1 enemy max_hp every N floors
const SCALE_COUNT_EVERY := 3      # +1 max enemies/room every N floors...
const SCALE_COUNT_CAP := 4        # ...capped here
const SCALE_SPEED_PER_FLOOR := 8.0
const SCALE_SPEED_CAP := 60.0     # melee stays slower than the 300px/s player
# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# --- Tile atlas coords (per-biome texture comes from GameManager.biome(),
# all biome atlases share this 256x64 layout; see docs/asset-spec.md) ---------
const FLOOR_PLAIN := Vector2i(0, 0)
const FLOOR_VARIANTS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]
const FLOOR_CRACKED := Vector2i(4, 0)
const WALL_VARIANTS: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)]
# ------------------------------------------------------------------------------

var _rooms: Array[Rect2i] = []
var _floor := {}  # Set: Vector2i -> true
var _prefab_spawns: Array = []    # [{type, cell, cursed?}] from stamped prefabs
var _prefab_room_index := -1

# Minimap/full-map fog-of-war: cells revealed as the player walks near them
# (public -- read by hud.gd's minimap and FullMap; see get_map_data()).
const REVEAL_RADIUS := 2   # cells around the player revealed per tick
var visited := {}          # Set: Vector2i -> true, floor cells only

@onready var _region: NavigationRegion2D = $NavigationRegion2D
@onready var _tiles: TileMapLayer = $Tiles


func _ready() -> void:
	randomize()
	$Darkness.color = GameManager.biome()["darkness"]
	var boss_floor := GameManager.floor_num % BOSS_EVERY == 0
	if boss_floor:
		_generate_boss_arena()
	else:
		for attempt in 3:
			_rooms.clear()
			_floor.clear()
			_generate_layout()
			if _all_rooms_reachable():
				break
			if attempt == 2:
				push_error("Level generation failed the reachability check 3x; using last layout")
		_stamp_prefab()
	_build_tiles()
	_build_geometry()
	if boss_floor:
		_spawn_boss_encounter()
	else:
		_spawn_player_and_enemies()
	_bake_navmesh()


func _stamp_prefab() -> void:
	# Stamp one hand-built template into a fitting middle room (never the
	# spawn or stairs room). "#" only erases floor that a corridor didn't
	# already claim, so entrances survive; if the walls still break
	# reachability, they get carved away again (markers stay).
	if randf() > prefab_chance or _rooms.size() < 3:
		return
	var prefab: Dictionary = PREFABS.pick_random()
	var rows: Array = prefab["rows"]
	var ph := rows.size()
	var pw := (rows[0] as String).length()
	var candidates: Array[int] = []
	for i in range(1, _rooms.size() - 1):
		# +2 margin: a template wall only 1 cell from the room's own outer
		# wall becomes a 1-wide squeeze with nothing to fall back on.
		if _rooms[i].size.x >= pw + 2 and _rooms[i].size.y >= ph + 2:
			candidates.append(i)
	if candidates.is_empty():
		return
	_prefab_room_index = candidates.pick_random()
	var room := _rooms[_prefab_room_index]
	var origin := room.position + Vector2i((room.size.x - pw) / 2, (room.size.y - ph) / 2)
	for y in ph:
		for x in pw:
			var cell := origin + Vector2i(x, y)
			match (rows[y] as String)[x]:
				"#":
					_floor.erase(cell)
				"C":
					_prefab_spawns.append({"type": "chest", "cell": cell, "cursed": false})
				"K":
					_prefab_spawns.append({"type": "chest", "cell": cell, "cursed": true})
				"B":
					_prefab_spawns.append({"type": "shrine", "cell": cell})
	if not _all_rooms_reachable():
		_carve_room(room)  # fallback: drop the walls, keep the loot spawns


func _generate_boss_arena() -> void:
	# One big room, no corridors, no stairs -- the victory portal spawns on
	# the boss's death instead. Four 2x2 pillars give dodge cover (erased
	# floor cells automatically become walls/occluders/tiles downstream).
	var room := Rect2i((MAP_W - 30) / 2, (MAP_H - 18) / 2, 30, 18)
	_carve_room(room)
	_rooms.append(room)
	for px in [room.position.x + 7, room.end.x - 9]:
		for py in [room.position.y + 5, room.end.y - 7]:
			for dx in 2:
				for dy in 2:
					_floor.erase(Vector2i(px + dx, py + dy))


func _spawn_boss_encounter() -> void:
	var room := _rooms[0]
	var player := PLAYER_SCENE.instantiate()
	player.position = _cell_center(Vector2i(room.position.x + 3, room.get_center().y))
	add_child(player)
	_clamp_camera(player)
	var boss := BOSS_SCENE.instantiate()
	var tier := GameManager.floor_num / BOSS_EVERY
	boss.max_hp += 15 * (tier - 1)   # floor 10, 15, ... bring him back stronger
	boss.soul_value += 20 * (tier - 1)
	boss.position = _cell_center(Vector2i(room.end.x - 4, room.get_center().y))
	boss.defeated.connect(_on_boss_defeated)
	add_child(boss)


func _on_boss_defeated() -> void:
	GameManager.bank_win()
	# Risk/reward choice: safe exit to the hub OR stairs deeper (stronger
	# boss every BOSS_EVERY floors, better soul pay).
	var center := _rooms[0].get_center()
	var portal := VICTORY_PORTAL_SCENE.instantiate()
	portal.position = _cell_center(center + Vector2i(-2, 0))
	add_child(portal)
	var stairs := STAIRS_SCENE.instantiate()
	stairs.position = _cell_center(center + Vector2i(2, 0))
	add_child(stairs)
	# Boss always pays out -- relic, weapon or skill (even split); falls back
	# to nothing only if the roll lands on relics and the run owns all seven.
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var drop_pos := _cell_center(center + Vector2i(0, 2))
	match ["relic", "weapon", "skill"].pick_random():
		"relic":
			var relic_id := GameManager.random_unowned_relic(player.relics)
			if relic_id != "":
				var pickup := RELIC_PICKUP_SCENE.instantiate()
				pickup.relic_id = relic_id
				pickup.position = drop_pos
				add_child(pickup)
		"weapon":
			var pickup := WEAPON_PICKUP_SCENE.instantiate()
			pickup.weapon_id = GameManager.random_other_weapon(player.weapon_id)
			pickup.position = drop_pos
			add_child(pickup)
		"skill":
			var pickup := SKILL_PICKUP_SCENE.instantiate()
			pickup.skill_id = GameManager.random_other_skill(player.skill_id)
			pickup.position = drop_pos
			add_child(pickup)


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
	# At least 2 rooms: the stairs live in the last room and must not share
	# the spawn room, or the player would transition on frame one.
	if _rooms.size() < 2:
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


func _build_tiles() -> void:
	# TileSet built in code: zero hand-authored .tres risk, and swapping in
	# real art later is just a texture/coord change. Visual only -- physics
	# and navmesh still come from the collider rects in _build_geometry().
	var atlas := TileSetAtlasSource.new()
	atlas.texture = load(GameManager.biome()["tileset"])
	atlas.texture_region_size = Vector2i(CELL, CELL)
	for coord in [FLOOR_PLAIN, FLOOR_CRACKED] + FLOOR_VARIANTS + WALL_VARIANTS:
		atlas.create_tile(coord)
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(CELL, CELL)
	tile_set.add_source(atlas, 0)
	_tiles.tile_set = tile_set
	for cell: Vector2i in _floor:
		var roll := randf()
		var coord := FLOOR_PLAIN
		if roll < 0.06:
			coord = FLOOR_CRACKED
		elif roll < 0.3:
			coord = FLOOR_VARIANTS[randi() % FLOOR_VARIANTS.size()]
		_tiles.set_cell(cell, 0, coord)
	# Wall tiles only where a wall borders floor (8-dir) -- deep void stays
	# untiled and renders as the near-black clear color.
	for y in MAP_H:
		for x in MAP_W:
			var cell := Vector2i(x, y)
			if not _floor.has(cell) and _touches_floor(cell):
				_tiles.set_cell(cell, 0, WALL_VARIANTS[randi() % WALL_VARIANTS.size()])


func _touches_floor(cell: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if (dx != 0 or dy != 0) and _floor.has(cell + Vector2i(dx, dy)):
				return true
	return false


func _build_geometry() -> void:
	# Walls: every non-floor cell, row-merged into runs, as colliders under
	# the NavigationRegion2D so the bake carves them (parsed geometry =
	# static colliders, mask 1). Visuals are tiles (_build_tiles); this
	# builds physics + light occluders only.
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
		# Matching light occluder: walls cast shadows -> fog of war for free.
		# CULL_CLOCKWISE: only edges facing away from the light cast shadow,
		# so the torch still lights the brick face of the wall itself (flip
		# to CULL_COUNTER_CLOCKWISE if wall tiles render unlit/black).
		var occluder := LightOccluder2D.new()
		var opoly := OccluderPolygon2D.new()
		opoly.cull_mode = OccluderPolygon2D.CULL_CLOCKWISE
		var hw := run.size.x * CELL / 2.0
		var hh := CELL / 2.0
		opoly.polygon = PackedVector2Array([
			Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh),
		])
		occluder.occluder = opoly
		occluder.position = shape.position
		walls.add_child(occluder)


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
	_clamp_camera(player)
	var stairs := STAIRS_SCENE.instantiate()
	stairs.position = _cell_center(_rooms[_rooms.size() - 1].get_center())
	add_child(stairs)
	var depth := GameManager.floor_num - 1
	var hp_bonus := depth / SCALE_HP_EVERY
	var speed_bonus := minf(depth * SCALE_SPEED_PER_FLOOR, SCALE_SPEED_CAP)
	var room_max := mini(ENEMIES_PER_ROOM_MAX + depth / SCALE_COUNT_EVERY, SCALE_COUNT_CAP)
	var elite_placed := false
	var biome := GameManager.biome()
	var elite_chance: float = biome["elite_chance"]
	var weights := (biome["weights"] as Dictionary).duplicate()
	if GameManager.floor_num < 2:
		weights["exploder"] = 0.0  # learn curve: floor 1 stays basics-only
	var weight_total := 0.0
	for type in SPAWN_TYPES:
		weight_total += float(weights.get(type, 0.0))
	for i in range(1, _rooms.size()):
		var room := _rooms[i]
		for j in randi_range(1, room_max):
			var roll := randf() * weight_total
			var picked := "melee"
			for type in SPAWN_TYPES:
				roll -= float(weights.get(type, 0.0))
				if roll < 0.0:
					picked = type
					break
			var enemy: Node2D = (SPAWN_SCENES[picked] as PackedScene).instantiate()
			enemy.position = _cell_center(Vector2i(
					randi_range(room.position.x + 1, room.end.x - 2),
					randi_range(room.position.y + 1, room.end.y - 2)))
			# Scaling via the @export dials, set before add_child so the
			# enemy's _ready() picks them up (hp = max_hp there).
			enemy.max_hp += hp_bonus
			enemy.move_speed += speed_bonus
			enemy.soul_value += depth / 3  # deeper floors pay better
			# One elite per floor at most; exploders/summoners excluded.
			if not elite_placed and not ELITE_EXCLUDED.has(picked) \
					and GameManager.floor_num >= 2 and randf() < elite_chance:
				enemy.elite = true
				elite_placed = true
			add_child(enemy)
	# Prefab markers first: their chests/shrines are hand-placed.
	for spawn in _prefab_spawns:
		match spawn["type"]:
			"chest":
				var pchest := CHEST_SCENE.instantiate()
				pchest.cursed = spawn["cursed"]
				pchest.ambush_hp_bonus = hp_bonus
				pchest.ambush_speed_bonus = speed_bonus
				pchest.position = _cell_center(spawn["cell"])
				add_child(pchest)
			"shrine":
				var shrine := BLOOD_SHRINE_SCENE.instantiate()
				shrine.position = _cell_center(spawn["cell"])
				add_child(shrine)
	# Loot chests in side rooms (never the spawn, stairs, or prefab room);
	# cursed ambushes use the same floor scaling as regular spawns.
	var chests := 0
	for i in range(1, _rooms.size() - 1):
		if chests >= CHEST_MAX:
			break
		if i == _prefab_room_index or randf() > CHEST_ROOM_CHANCE:
			continue
		var room := _rooms[i]
		if room.size.x < 5 or room.size.y < 5:
			continue
		var chest := CHEST_SCENE.instantiate()
		chest.cursed = randf() < CHEST_CURSED_CHANCE
		chest.ambush_hp_bonus = hp_bonus
		chest.ambush_speed_bonus = speed_bonus
		chest.position = _cell_center(Vector2i(
				randi_range(room.position.x + 2, room.end.x - 3),
				randi_range(room.position.y + 2, room.end.y - 3)))
		add_child(chest)
		chests += 1


func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2((cell.x + 0.5) * CELL, (cell.y + 0.5) * CELL)


func _clamp_camera(player: Node2D) -> void:
	# Stops the camera from panning past the map edge into the void; the
	# unlit space *within* the map (past unreached rooms) is the intentional
	# fog-of-war look and is left alone.
	var camera: Camera2D = player.get_node("Camera2D")
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = MAP_W * CELL
	camera.limit_bottom = MAP_H * CELL


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


func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var cell := Vector2i(player.position / CELL)
	for dy in range(-REVEAL_RADIUS, REVEAL_RADIUS + 1):
		for dx in range(-REVEAL_RADIUS, REVEAL_RADIUS + 1):
			var c := cell + Vector2i(dx, dy)
			if _floor.has(c):
				visited[c] = true


func get_map_data() -> Dictionary:
	## Read by hud.gd's minimap and the FullMap overlay.
	return {"floor": _floor, "visited": visited, "cell": CELL, "map_w": MAP_W, "map_h": MAP_H}
