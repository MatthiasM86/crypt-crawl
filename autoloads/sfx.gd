extends Node
## Sound autoload: synthesizes placeholder SFX in memory at startup and then
## swaps in any real audio file found at res://assets/sfx/<name>.mp3
## (ElevenLabs pipeline, see docs/audio-spec.md) -- synthesis stays as the
## fallback for sounds without a file. Playback goes through a round-robin
## player pool with slight pitch variation; a low ambient drone loops
## permanently.

const MIX_RATE := 22050
const POOL_SIZE := 8
const AMBIENT_DB := -22.0
const MUSIC_DB := -18.0
const SFX_DB := -8.0
# Per-key mix trim on top of SFX_DB (and any caller offset): death sounds sit
# under the combat feedback (hit/hurt/clank), not over it; the boss death stays
# a bit more present as the floor's climax.
const KEY_OFFSET_DB := {
	"death_enemy": -5.0,
	"death_cultist": -5.0,
	"death_tank": -5.0,
	"death_summoner": -5.0,
	"death_exploder": -5.0,
	"death_boss": -3.0,
}

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _pool_index := 0


func _ready() -> void:
	# Keep audio (esp. the ambient drone) running while the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	var music := AudioStreamPlayer.new()
	music.stream = _streams["music"]
	music.volume_db = MUSIC_DB
	add_child(music)
	music.play()


func play(name_: String, volume_offset_db := 0.0) -> void:
	if not _streams.has(name_):
		push_warning("Sfx: unknown sound '%s'" % name_)
		return
	var p := _pool[_pool_index]
	_pool_index = (_pool_index + 1) % POOL_SIZE
	p.stream = _streams[name_]
	p.pitch_scale = randf_range(0.92, 1.08)
	p.volume_db = SFX_DB + volume_offset_db + KEY_OFFSET_DB.get(name_, 0.0)
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
	# death_enemy: falling square-ish growl (brute / death_sound default)
	_streams["death_enemy"] = _synth(0.22, func(t: float, d: float) -> float:
		var f := lerpf(220.0, 60.0, t / d)
		return signf(sin(TAU * f * t)) * exp(-t * 12.0) * 0.4)
	# death_cultist: raspier, higher falling growl
	_streams["death_cultist"] = _synth(0.2, func(t: float, d: float) -> float:
		var f := lerpf(320.0, 110.0, t / d)
		return (signf(sin(TAU * f * t)) * 0.3 + rng.randf_range(-1, 1) * 0.15) * exp(-t * 14.0))
	# death_tank: armor clatter -- clank partials over a low thud
	_streams["death_tank"] = _synth(0.3, func(t: float, d: float) -> float:
		return (sin(TAU * 1100.0 * t) * 0.3 + sin(TAU * 1650.0 * t) * 0.2
				+ sin(TAU * 70.0 * t) * 0.4 + rng.randf_range(-1, 1) * 0.2) * exp(-t * 13.0))
	# death_summoner: arcane dissipate -- tremolo shimmer sweeping down
	_streams["death_summoner"] = _synth(0.35, func(t: float, d: float) -> float:
		var f := lerpf(1100.0, 250.0, t / d)
		return sin(TAU * f * t) * (0.6 + 0.4 * sin(TAU * 30.0 * t)) * exp(-t * 8.0) * 0.4)
	# death_exploder: wet burst layered under the slam explosion
	_streams["death_exploder"] = _synth(0.15, func(t: float, d: float) -> float:
		return (rng.randf_range(-1, 1) * 0.6 + sin(TAU * 150.0 * t) * 0.3) * exp(-t * 20.0))
	# death_boss: longer, deeper dramatic descend than death_player
	_streams["death_boss"] = _synth(1.0, func(t: float, d: float) -> float:
		var f := lerpf(180.0, 30.0, t / d)
		return (sin(TAU * f * t) * 0.8 + rng.randf_range(-1, 1) * 0.25) * exp(-t * 3.0))
	# death_player: long dark descend
	_streams["death_player"] = _synth(0.7, func(t: float, d: float) -> float:
		var f := lerpf(300.0, 40.0, t / d)
		return (sin(TAU * f * t) * 0.8 + rng.randf_range(-1, 1) * 0.2) * exp(-t * 4.0))
	# stairs/portal: ascending shimmer
	_streams["stairs"] = _synth(0.4, func(t: float, d: float) -> float:
		var f := lerpf(300.0, 900.0, t / d)
		return sin(TAU * f * t) * sin(PI * t / d) * 0.45)
	# relic: three-note ascending arpeggio (the "important find" cue)
	_streams["relic"] = _synth(0.36, func(t: float, d: float) -> float:
		var third := d / 3.0
		var f := 520.0 if t < third else (660.0 if t < 2.0 * third else 880.0)
		return sin(TAU * f * t) * exp(-fmod(t, third) * 14.0) * 0.5)
	# boon: soul-shrine purchase -- two soft DESCENDING notes (spend, not find;
	# the relic arpeggio's inverse)
	_streams["boon"] = _synth(0.3, func(t: float, d: float) -> float:
		var half := d / 2.0
		var f := 780.0 if t < half else 520.0
		return sin(TAU * f * t) * exp(-fmod(t, half) * 12.0) * 0.45)
	# clank: metallic shield block
	_streams["clank"] = _synth(0.09, func(t: float, d: float) -> float:
		return (sin(TAU * 1250.0 * t) * 0.45 + sin(TAU * 1870.0 * t) * 0.25
				+ rng.randf_range(-1, 1) * 0.3) * exp(-t * 40.0))
	# chest: low wooden creak-thud
	_streams["chest"] = _synth(0.28, func(t: float, d: float) -> float:
		var f := lerpf(90.0, 55.0, t / d)
		return (sin(TAU * f * t) * 0.6 + rng.randf_range(-1, 1) * 0.3) * exp(-t * 10.0))
	# ambient: loopable low crypt drone
	var drone := _synth(6.0, func(t: float, d: float) -> float:
		var lfo := 0.75 + 0.25 * sin(TAU * t / d)  # period == length -> seamless
		return (sin(TAU * 42.0 * t) * 0.5 + sin(TAU * 63.0 * t) * 0.3
				+ rng.randf_range(-1, 1) * 0.06) * lfo)
	drone.loop_mode = AudioStreamWAV.LOOP_FORWARD
	drone.loop_end = drone.data.size() / 2
	_streams["ambient"] = drone
	# music: sparse dark minor arpeggio over the drone -- interim until a real
	# track lands (ElevenLabs Music API needs a paid plan; see audio-spec).
	var slot := 1.6
	var notes := [110.0, 164.81, 130.81, 110.0, 146.83, 164.81, 130.81, 98.0]
	var tune := _synth(slot * notes.size(), func(t: float, d: float) -> float:
		var nt := fmod(t, slot)
		var f: float = notes[int(t / slot) % notes.size()]
		return (sin(TAU * f * nt) + sin(TAU * f * 2.0 * nt) * 0.35) * exp(-nt * 2.2) * 0.5)
	tune.loop_mode = AudioStreamWAV.LOOP_FORWARD
	tune.loop_end = tune.data.size() / 2
	_streams["music"] = tune
	# Real files win over synthesis; generic so future files auto-apply.
	for key in _streams.keys():
		var path := "res://assets/sfx/%s.mp3" % key
		if ResourceLoader.exists(path):
			var stream: AudioStreamMP3 = load(path)
			if key == "ambient" or key == "music":
				stream.loop = true
			_streams[key] = stream


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
