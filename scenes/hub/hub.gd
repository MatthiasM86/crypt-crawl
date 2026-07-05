extends Node2D
## Home base between runs: four upgrade shrines and the run portal.
## Same runtime navmesh bake flow as every other level.


func _ready() -> void:
	$NavigationRegion2D.bake_navigation_polygon(false)
