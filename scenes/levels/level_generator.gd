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
const BOSS_SCENES := [
	preload("res://scenes/enemies/boss.tscn"),              # tier 1 (floor 5): Kryptwächter
	preload("res://scenes/enemies/fleischkoloss.tscn"),     # tier 2 (floor 10): rusher
	preload("res://scenes/enemies/beschwoererkoenig.tscn"), # tier 3 (floor 15): summoner
	preload("res://scenes/enemies/seuchenbischof.tscn"),    # tier 4 (floor 20): zoner
]                                                          # then the cycle repeats, scaled up
const QUELLE_SCENE := preload("res://scenes/enemies/quelle.tscn")  # final boss on FINAL_FLOOR
const VICTORY_PORTAL_SCENE := preload("res://scenes/levels/victory_portal.tscn")
const CHEST_SCENE := preload("res://scenes/pickups/chest.tscn")
const BONE_PILE_TEX := preload("res://assets/sprites/props/bone_pile.png")
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
const CORRIDOR_W := 2             # cells; 64 px - agent_radius inset leaves 16 px
const AGENT_RADIUS := 24.0        # navmesh inset. Must clear the player's real
                                  # need (r14 body at y=-3 -> 17 px toward walls
                                  # above) with margin: waypoint switching cuts
                                  # corners by path_desired_distance (4 px), so
                                  # effective clearance is ~20 px. Going higher
                                  # seals 2-cell corridors (64 - 2*24 = 16 px
                                  # left). Matches test_room + hub.
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
# No outer "." ring on templates: "." stamps floor onto floor (a no-op), but
# inflates the size requirement -- with the +2 placement margin a 9-wide
# template needs an 11-wide room, which ROOM_MAX = 10 can never provide
# (Schatzkammer/Säulenhalle silently never spawned until trimmed).
const PREFABS := [
	{"name": "Schatzkammer", "rows": [
		"##...##",
		"#C...K#",
		".......",
		".......",
		".......",
	]},
	{"name": "Blutschrein", "rows": [
		"#...#",
		"..B..",
		".....",
	]},
	{"name": "Säulenhalle", "rows": [
		".#...#.",
		".......",
		".......",
	]},
]
const BLOOD_SHRINE_SCENE := preload("res://scenes/levels/blood_shrine.tscn")
const SOUL_SHRINE_SCENE := preload("res://scenes/levels/soul_shrine.tscn")
const SOUL_SHRINE_FROM_FLOOR := 3  # Seelen-Ökonomie (plan.md Punkt 1): 1x/Ebene
# ------------------------------------------------------------------------------

# --- Floor difficulty scaling (applied via enemy @export dials at spawn) ------
const SCALE_HP_EVERY := 2         # +1 enemy max_hp every N floors...
const SCALE_HP_CAP := 12          # ...flattened here (reached ~floor 25). Late
                                  # difficulty is meant to come from the biome
                                  # mix / elites / count, not HP sponges -- the
                                  # 50-floor descent stays killable (plan.md §4).
const SCALE_COUNT_EVERY := 3      # +1 max enemies/room every N floors...
const SCALE_COUNT_CAP := 4        # ...capped here
const SCALE_SPEED_PER_FLOOR := 8.0
const SCALE_SPEED_CAP := 60.0     # melee stays slower than the 300px/s player
const BOSS_HP_SCALE_CAP := 60     # cap the +15/tier boss HP ramp (tiers 1-9);
                                  # the FINAL_FLOOR boss (Quelle) sets its own HP
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
	if GameManager.floor_num % BOSS_EVERY == 0:
		_generate_boss_arena()
		_build_tiles()
		_build_geometry()
		_bake_navmesh()
		_spawn_boss_encounter()
		return
	# Generate -> stamp -> build -> bake -> VALIDATE ON THE REAL NAVMESH.
	# The grid passes (_widen_pinches) catch almost everything cheaply, but
	# the bake's agent-radius offsetting seals diagonal squeezes the grid
	# math calls open (two inner wall corners ~45 px apart diagonally need
	# 48 px; mitered corner offsets eat even more). The only trustworthy
	# check is a path query per floor cell: small sealed pockets get walled
	# up (map stays honest), a sealed room center rerolls the whole layout.
	# Spawning happens only after the level passed.
	for attempt in 4:
		_reset_generation()
		_generate_layout()
		if not _all_rooms_reachable():
			if attempt == 3:
				push_error("Level generation failed the reachability check 4x; using last layout")
			continue
		_stamp_prefab()
		_build_tiles()
		_build_geometry()
		_bake_navmesh()
		if await _seal_nav_pockets():
			break
		if attempt == 3:
			push_error("Level generation: no fully navigable layout in 4 attempts; using last")
	_spawn_player_and_enemies()


func _reset_generation() -> void:
	_rooms.clear()
	_floor.clear()
	_prefab_spawns.clear()
	_prefab_room_index = -1
	_clear_built()


func _clear_built() -> void:
	# Tear down tiles + wall colliders/occluders so a rebuild starts clean.
	# free() MUST be immediate (not queue_free): rebuild + bake run in the
	# same frame, and a deferred-freed Walls node still sits in the tree
	# then -- the bake would parse OLD and new walls together and produce a
	# garbage mesh (this broke every reroll attempt). We only run outside
	# physics callbacks (scene _ready / after awaiting physics_frame), so an
	# immediate free is safe.
	var walls := _region.get_node_or_null("Walls")
	if walls:
		walls.free()
	_tiles.clear()


func _seal_nav_pockets() -> bool:
	## Final navigability authority (runs once per generated floor): waits for
	## the nav map to sync, then path-checks every floor cell from the spawn
	## room center. Cells the mesh cannot reach -- although they render as
	## walkable floor -- get walled up and the geometry rebuilt (repeat, since
	## new walls erode into neighbors). Returns false when a room center or a
	## prefab loot marker sits in a sealed pocket, or the damage is too large:
	## the caller rerolls the layout then.
	for repair in 3:
		await _await_nav_sync()
		var map := _region.get_navigation_map()
		var from := _cell_center(_rooms[0].get_center())
		var sealed: Array[Vector2i] = []
		for cell: Vector2i in _floor:
			var to := _cell_center(cell)
			var path := NavigationServer2D.map_get_path(map, from, to, true)
			if path.size() == 0 or (path[path.size() - 1] - to).length() > CELL * 1.5:
				sealed.append(cell)
		if sealed.is_empty():
			return true
		if sealed.size() > _floor.size() / 5:
			return false
		for room in _rooms:
			if sealed.has(room.get_center()):
				return false
		for spawn in _prefab_spawns:
			if sealed.has(spawn["cell"]):
				return false
		push_warning("Level generation: walling up %d nav-sealed cells (repair %d)"
				% [sealed.size(), repair + 1])
		for cell in sealed:
			_floor.erase(cell)
		_clear_built()
		_build_tiles()
		_build_geometry()
		_bake_navmesh()
	return false


func _stamp_prefab() -> void:
	# Stamp one hand-built template into a fitting middle room (never the
	# spawn or stairs room). "#" erases floor unconditionally -- including
	# cells of corridors from UNRELATED room pairs that happen to cross this
	# room -- so after stamping the narrow-passage invariants must be
	# re-established (see the _widen_pinches call below); if the walls break
	# reachability outright, they get carved away again (markers stay).
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
	var stamped := {}
	for y in ph:
		for x in pw:
			var cell := origin + Vector2i(x, y)
			match (rows[y] as String)[x]:
				"#":
					_floor.erase(cell)
					stamped[cell] = true
				"C":
					_prefab_spawns.append({"type": "chest", "cell": cell, "cursed": false})
				"K":
					_prefab_spawns.append({"type": "chest", "cell": cell, "cursed": true})
				"B":
					_prefab_spawns.append({"type": "shrine", "cell": cell})
	if not _all_rooms_reachable():
		_carve_room(room)  # fallback: drop the walls, keep the loot spawns
		return
	# A template wall that cut into a crossing corridor's 2-wide band leaves
	# a 1-wide or diagonal squeeze the flood fill can't see (it treats 1-wide
	# as connected; the navmesh seals it). Re-widen around the stamped walls
	# without eating them; if that can't fix everything, drop the walls like
	# the reachability fallback does.
	_widen_pinches(stamped)
	if _has_narrow_passages():
		_carve_room(room)
		_widen_pinches()


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
	var boss: Node2D
	if GameManager.is_final_floor():
		# The run's win condition (docs/plan.md "Rahmen & Run-Ziel"): a dedicated
		# boss with its own tuned HP, not the scaled cycle.
		boss = QUELLE_SCENE.instantiate()
		boss.defeated.connect(_on_final_boss_defeated)
	else:
		var tier := GameManager.floor_num / BOSS_EVERY
		# Rotate the boss type per tier (floor 5/10/15/20...), cycling and scaling up.
		boss = BOSS_SCENES[(tier - 1) % BOSS_SCENES.size()].instantiate()
		boss.max_hp += mini(15 * (tier - 1), BOSS_HP_SCALE_CAP)  # deeper tiers, but capped
		boss.soul_value += 20 * (tier - 1)
		boss.defeated.connect(_on_boss_defeated)
	boss.position = _cell_center(Vector2i(room.end.x - 4, room.get_center().y))
	add_child(boss)


func _on_final_boss_defeated() -> void:
	# Killing "Die Quelle" wins the run. Reuse the normal boss-death payout
	# (bank + victory portal + stairs + loot) so the "Endlos weiter" path keeps
	# its loot and descent, then raise the victory screen whose two buttons
	# mirror that physical portal (hub) vs. stairs (endless) choice. bank_win()
	# runs first, so the screen's "Gesamt-Siege" already counts this win.
	_on_boss_defeated()
	WinScreen.show_win(GameManager.floor_num, GameManager.run_souls, GameManager.wins)


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
	_widen_pinches()


func _widen_pinches(protected := {}) -> void:
	# Two invariants against passages that LOOK walkable but bake to nothing
	# (click-to-move refuses, dash sometimes slips through -- the worst kind
	# of inconsistency):
	# 1. No 1-wide passages: every floor cell must sit in at least one
	#    all-floor 2x2 block. The navmesh inset (24 px per side) seals
	#    anything narrower than 2 cells. Typical source: a corridor mouth
	#    meeting a room corner offset by one cell (jutting single brick).
	# 2. No diagonal-only contacts: a checkerboard 2x2 (two floor cells
	#    sharing just a corner) passes check 1 on both sides but connects
	#    with zero width. Typical source: two independently-carved regions
	#    happening to touch corner-to-corner.
	# Both fixes only ADD floor, so reachability never regresses; one loop
	# runs them to convergence (each carve can expose the other pattern).
	# Runs inside _generate_layout so prefab stamping (authored niche
	# pockets) comes after and stays untouched.
	var block_corners := [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i.ZERO]
	var block_cells := [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.ONE]
	var changed := true
	while changed:
		changed = false
		for cell: Vector2i in _floor.keys():
			var best: Array = []
			var open := false
			for corner in block_corners:
				var missing: Array = []
				var valid := true
				for off in block_cells:
					var c: Vector2i = cell + corner + off
					if _floor.has(c):
						continue
					# Keep the map-border wall ring and protected cells
					# (stamped prefab walls) intact.
					if c.x < 1 or c.y < 1 or c.x > MAP_W - 2 or c.y > MAP_H - 2 \
							or protected.has(c):
						valid = false
						break
					missing.append(c)
				if not valid:
					continue
				if missing.is_empty():
					open = true
					break
				if best.is_empty() or missing.size() < best.size():
					best = missing
			if open:
				continue
			for c in best:
				_floor[c] = true
				changed = true
		for y in range(MAP_H - 1):
			for x in range(MAP_W - 1):
				var a := Vector2i(x, y)          # 2x2 block: a b
				var b := Vector2i(x + 1, y)      #            c d
				var c := Vector2i(x, y + 1)
				var d := Vector2i(x + 1, y + 1)
				if _floor.has(a) and _floor.has(d) \
						and not _floor.has(b) and not _floor.has(c):
					changed = _carve_first_legal(b, c, protected) or changed
				elif _floor.has(b) and _floor.has(c) \
						and not _floor.has(a) and not _floor.has(d):
					changed = _carve_first_legal(a, d, protected) or changed


func _carve_first_legal(p: Vector2i, q: Vector2i, protected: Dictionary) -> bool:
	## Opens the first of two candidate wall cells that is neither in the
	## map's 1-cell border ring nor protected (checkerboard fix above).
	for c in [p, q]:
		if c.x >= 1 and c.y >= 1 and c.x <= MAP_W - 2 and c.y <= MAP_H - 2 \
				and not protected.has(c):
			_floor[c] = true
			return true
	return false


func _has_narrow_passages() -> bool:
	## True if any _widen_pinches invariant is violated (pinched cell or
	## checkerboard contact) -- used to decide the prefab-wall fallback.
	for cell: Vector2i in _floor.keys():
		var open := false
		for corner in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i.ZERO]:
			var all := true
			for off in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.ONE]:
				if not _floor.has(cell + corner + off):
					all = false
					break
			if all:
				open = true
				break
		if not open:
			return true
	for y in range(MAP_H - 1):
		for x in range(MAP_W - 1):
			var af := _floor.has(Vector2i(x, y))
			var bf := _floor.has(Vector2i(x + 1, y))
			var cf := _floor.has(Vector2i(x, y + 1))
			var df := _floor.has(Vector2i(x + 1, y + 1))
			if (af and df and not bf and not cf) or (bf and cf and not af and not df):
				return true
	return false


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
	var hp_bonus := mini(depth / SCALE_HP_EVERY, SCALE_HP_CAP)
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
			enemy.position = _cell_center(_random_floor_cell_in(room))
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
	# Scattered bone-pile deco (docs/asset-spec §4.4): a few piles on the ground.
	var _tiles_idx: int = $Tiles.get_index()
	for i in range(1, _rooms.size()):
		if randf() > 0.35:
			continue
		var deco_room := _rooms[i]
		var bones := Sprite2D.new()
		bones.texture = BONE_PILE_TEX
		bones.texture_filter = TEXTURE_FILTER_NEAREST
		bones.rotation = randf() * TAU
		bones.position = _cell_center(Vector2i(
				randi_range(deco_room.position.x + 1, deco_room.end.x - 2),
				randi_range(deco_room.position.y + 1, deco_room.end.y - 2)))
		add_child(bones)
		move_child(bones, _tiles_idx + 1)
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
		chest.position = _cell_center(_random_floor_cell_in(room, 2))
		add_child(chest)
		chests += 1
	# Soul shrine: guaranteed once per floor from SOUL_SHRINE_FROM_FLOOR on,
	# in a middle room (never spawn/stairs/prefab room) -- overflow souls buy
	# run-bound boons there.
	if GameManager.floor_num >= SOUL_SHRINE_FROM_FLOOR:
		var candidates: Array = []
		for i in range(1, _rooms.size() - 1):
			if i != _prefab_room_index:
				candidates.append(i)
		if not candidates.is_empty():
			var shrine_room: Rect2i = _rooms[candidates.pick_random()]
			var soul_shrine := SOUL_SHRINE_SCENE.instantiate()
			soul_shrine.position = _cell_center(_random_floor_cell_in(shrine_room))
			add_child(soul_shrine)


func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2((cell.x + 0.5) * CELL, (cell.y + 0.5) * CELL)


func _random_floor_cell_in(room: Rect2i, inset := 1) -> Vector2i:
	## Random FLOOR cell in the room interior. Rooms are no longer guaranteed
	## solid floor: prefab walls and nav-repair walling can eat arbitrary
	## cells, so placements (enemies, chests, shrines) must check.
	for i in 16:
		var cell := Vector2i(
				randi_range(room.position.x + inset, room.end.x - 1 - inset),
				randi_range(room.position.y + inset, room.end.y - 1 - inset))
		if _floor.has(cell):
			return cell
	for y in range(room.position.y, room.end.y):
		for x in range(room.position.x, room.end.x):
			if _floor.has(Vector2i(x, y)):
				return Vector2i(x, y)
	return room.get_center()


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


func _await_nav_sync() -> void:
	## The map commits bakes on its own physics-step schedule; region polygon
	## updates can land a sync AFTER the map's first iteration bump, so
	## neither iteration ids nor an immediate probe are trustworthy right
	## after the bake. Empirically 10 physics frames always suffice (any
	## queued server command lands within 1-2 steps); the from->from probe
	## afterwards is a guard with a hard cap, not the primary wait.
	var map := _region.get_navigation_map()
	for i in 10:
		await get_tree().physics_frame
	var from := _cell_center(_rooms[0].get_center())
	for i in 50:
		if NavigationServer2D.map_get_path(map, from, from, true).size() > 0:
			return
		await get_tree().physics_frame


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
