extends Node2D
## Hand-built test room. Bakes the navmesh synchronously on load:
## the NavigationPolygon's outline is the walkable base, StaticBody2D
## children of the region (walls, pillar) are carved out, inset by
## agent_radius. Same flow the procedural LevelGenerator will use later.


func _ready() -> void:
	$NavigationRegion2D.bake_navigation_polygon(false)
