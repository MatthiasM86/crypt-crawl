extends Node2D
## Home base between runs: four upgrade shrines and the run portal.
## Floor/walls are tiled from the shared dungeon atlas (mirrors
## level_generator._build_tiles); same runtime navmesh bake flow as every level.

const TILESET_TEXTURE := preload("res://assets/sprites/tileset_placeholder.png")
const CELL := 32
const FLOOR_PLAIN := Vector2i(0, 0)
const FLOOR_VARIANTS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]
const FLOOR_CRACKED := Vector2i(4, 0)
const WALL_VARIANTS: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)]
# Interior floor tiles (1,1)..(24,14), framed by a one-tile wall ring -- matches
# the collider rects in hub.tscn (walls at rows/cols 0 and 25/15).
const FLOOR_MIN := Vector2i(1, 1)
const FLOOR_MAX := Vector2i(24, 14)


func _ready() -> void:
	_build_tiles()
	$NavigationRegion2D.bake_navigation_polygon(false)


func _build_tiles() -> void:
	var atlas := TileSetAtlasSource.new()
	atlas.texture = TILESET_TEXTURE
	atlas.texture_region_size = Vector2i(CELL, CELL)
	for coord in [FLOOR_PLAIN, FLOOR_CRACKED] + FLOOR_VARIANTS + WALL_VARIANTS:
		atlas.create_tile(coord)
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(CELL, CELL)
	tile_set.add_source(atlas, 0)
	var tiles: TileMapLayer = $Tiles
	tiles.tile_set = tile_set
	for y in range(FLOOR_MIN.y - 1, FLOOR_MAX.y + 2):
		for x in range(FLOOR_MIN.x - 1, FLOOR_MAX.x + 2):
			var cell := Vector2i(x, y)
			var inside := x >= FLOOR_MIN.x and x <= FLOOR_MAX.x and y >= FLOOR_MIN.y and y <= FLOOR_MAX.y
			if inside:
				var roll := randf()
				var coord := FLOOR_PLAIN
				if roll < 0.06:
					coord = FLOOR_CRACKED
				elif roll < 0.3:
					coord = FLOOR_VARIANTS[randi() % FLOOR_VARIANTS.size()]
				tiles.set_cell(cell, 0, coord)
			else:
				tiles.set_cell(cell, 0, WALL_VARIANTS[randi() % WALL_VARIANTS.size()])
