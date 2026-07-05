extends Node
## Sound autoload: synthesizes all placeholder SFX in memory at startup
## (retro noise-bursts/sweeps -- no asset files needed) and plays them via
## a round-robin player pool with slight pitch variation. A low ambient
## drone loops permanently. Swap-in path for real audio later: check for
## res://assets/sfx/<name>.wav before falling back to synthesis.

const MIX_RATE := 22050
const POOL_SIZE := 8
const AMBIENT_DB := -22.0
const SFX_DB := -8.0

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _pool_index := 0


func _ready() -> void:
	_build_streams()
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.volume_db = SFX_DB
		add_child(p)
		_pool.append(p)
	var ambient := AudioStreamPlayer.new()
	ambient.stream = _streams["ambient"]
	ambient.volume_db = AMBIENT_DB
	add_child(ambient)
	ambient.play()


func play(name_: String, volume_offset_db := 0.0) -> void:
	if not _streams.has(name_):
		push_warning("Sfx: unknown sound '%s'" % name_)
		return
	var p := _pool[_pool_index]
	_pool_index = (_pool_index + 1) % POOL_SIZE
	p.stream = _streams[name_]
	p.pitch_scale = randf_range(0.92, 1.08)
	p.volume_db = SFX_DB + volume_offset_db
	p.play()


func _build_streams() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# hit: short bright noise burst
	_streams["hit"] = _synth(0.09, func(t: float, d: float) -> float:
		return rng.randf_range(-1, 1) * exp(-t * 55.0) * 0.9)
	# hurt: harsher, lower, longer
	_streams["hurt"] = _synth(0.18, func(t: float, d: float) -> float:
		return (rng.randf_range(-1, 1) * 0.7 + sin(TAU * 70.0 * t) * 0.5) * exp(-t * 22.0))
	# dash: airy whoosh (noise with rise-fall envelope)
	_streams["dash"] = _synth(0.16, func(t: float, d: float) -> float:
		var env := sin(PI * t / d)
		return rng.randf_range(-1, 1) * env * env * 0.5)
	# slam: deep thump with falling pitch + noise tail
	_streams["slam"] = _synth(0.35, func(t: float, d: float) -> float:
		var f := lerpf(130.0, 36.0, t / d)
		return (sin(TAU * f * t) * 0.9 + rng.randf_range(-1, 1) * 0.25) * exp(-t * 9.0))
	# shoot: quick mid chirp down
	_streams["shoot"] = _synth(0.08, func(t: float, d: float) -> float:
		var f := lerpf(900.0, 380.0, t / d)
		return sin(TAU * f * t) * exp(-t * 30.0) * 0.6)
	# potion: two ascending notes
	_streams["potion"] = _synth(0.25, func(t: float, d: float) -> float:
		var f := 440.0 if t < d * 0.5 else 660.0
		return sin(TAU * f * t) * exp(-fmod(t, d * 0.5) * 18.0) * 0.5)
	# soul: tiny high sparkle chirp up
	_streams["soul"] = _synth(0.07, func(t: float, d: float) -> float:
		var f := lerpf(900.0, 1600.0, t / d)
		return sin(TAU * f * t) * exp(-t * 35.0) * 0.35)
	# pickup: soft pop + note
	_streams["pickup"] = _synth(0.12, func(t: float, d: float) -> float:
		return sin(TAU * 520.0 * t) * exp(-t * 25.0) * 0.55)
	# death_enemy: falling square-ish growl
	_streams["death_enemy"] = _synth(0.22, func(t: float, d: float) -> float:
		var f := lerpf(220.0, 60.0, t / d)
		return signf(sin(TAU * f * t)) * exp(-t * 12.0) * 0.4)
	# death_player: long dark descend
	_streams["death_player"] = _synth(0.7, func(t: float, d: float) -> float:
		var f := lerpf(300.0, 40.0, t / d)
		return (sin(TAU * f * t) * 0.8 + rng.randf_range(-1, 1) * 0.2) * exp(-t * 4.0))
	# stairs/portal: ascending shimmer
	_streams["stairs"] = _synth(0.4, func(t: float, d: float) -> float:
		var f := lerpf(300.0, 900.0, t / d)
		return sin(TAU * f * t) * sin(PI * t / d) * 0.45)
	# ambient: loopable low crypt drone
	var drone := _synth(6.0, func(t: float, d: float) -> float:
		var lfo := 0.75 + 0.25 * sin(TAU * t / d)  # period == length -> seamless
		return (sin(TAU * 42.0 * t) * 0.5 + sin(TAU * 63.0 * t) * 0.3
				+ rng.randf_range(-1, 1) * 0.06) * lfo)
	drone.loop_mode = AudioStreamWAV.LOOP_FORWARD
	drone.loop_end = drone.data.size() / 2
	_streams["ambient"] = drone


func _synth(duration: float, sample_fn: Callable) -> AudioStreamWAV:
	var count := int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var t := float(i) / MIX_RATE
		var v: float = clampf(sample_fn.call(t, duration), -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.data = data
	return stream
