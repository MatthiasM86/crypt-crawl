extends Node2D
## Hand-built test room. Bakes the navmesh synchronously on load:
## the NavigationPolygon's outline is the walkable base, StaticBody2D
## children of the region (walls, pillar) are carved out, inset by
## agent_radius. Same flow the procedural LevelGenerator will use later.


func _ready() -> void:
	$NavigationRegion2D.bake_navigation_polygon(false)
	var camera: Camera2D = $Player/Camera2D
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = 1152
	camera.limit_bottom = 648
