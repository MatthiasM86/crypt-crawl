extends Camera2D
## Trauma-based screenshake. Call add_trauma(); shake = trauma^2 * MAX_OFFSET.
## Uses `offset` only, so position smoothing / follow are unaffected.

const TRAUMA_DECAY := 2.4          # trauma units per second
const MAX_OFFSET := Vector2(14, 10)

var _trauma := 0.0


func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func _process(delta: float) -> void:
	if _trauma <= 0.0:
		offset = Vector2.ZERO
		return
	_trauma = maxf(_trauma - TRAUMA_DECAY * delta, 0.0)
	var shake := _trauma * _trauma
	offset = Vector2(
		randf_range(-1.0, 1.0) * MAX_OFFSET.x * shake,
		randf_range(-1.0, 1.0) * MAX_OFFSET.y * shake
	)
