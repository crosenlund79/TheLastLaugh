extends Node
## Procedural calliope waltz. `distortion` (0..1) slows, detunes and crushes it.

const RATE := 22050.0

# Original little minor-key waltz, one note per beat (MIDI, -1 = hold).
const MELODY := [
	76, 75, 76,  72, 69, 72,  71, 70, 71,  68, 64, -1,
	69, 71, 72,  74, 77, 74,  76, 74, 71,  69, -1, -1,
	77, 76, 77,  79, 76, 72,  74, 71, 74,  76, 72, -1,
	77, 74, 69,  72, 76, 81,  80, 76, 74,  69, 64, 69,
]
const CHORDS := [
	[45, 0], [45, 0], [40, 1], [40, 1], [45, 0], [38, 0], [40, 1], [45, 0],
	[41, 1], [48, 1], [43, 1], [48, 1], [38, 0], [45, 0], [40, 1], [45, 0],
]

var distortion := 0.0
var target_distortion := 0.0
var volume := 1.0
var target_volume := 1.0

var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _beat := 0.0
var _t := 0.0
var _mel_ph := 0.0
var _bass_ph := 0.0
var _ch_ph := [0.0, 0.0, 0.0]
var _mel_freq := 440.0
var _note_age := 0.0
var _last_beat := -1
var _drop_note := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.3
	_player = AudioStreamPlayer.new()
	_player.stream = gen
	_player.bus = "Music"
	_player.volume_db = -6.0
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback()


func _midi(n: float) -> float:
	return 440.0 * pow(2.0, (n - 69.0) / 12.0)


func _organ(ph: float) -> float:
	return sin(ph) * 0.6 + sin(ph * 2.0) * 0.25 + sin(ph * 3.0) * 0.12 + sin(ph * 4.0) * 0.06


func _process(delta: float) -> void:
	distortion = move_toward(distortion, target_distortion, delta * 0.4)
	volume = move_toward(volume, target_volume, delta * 0.8)
	if _playback == null:
		return
	var frames := _playback.get_frames_available()
	if frames <= 0:
		return
	var d := distortion
	var tempo := 2.5 * (1.0 - 0.5 * d)
	var crush := d > 0.35
	var levels := 4.0 + (1.0 - d) * 60.0
	var buf := PackedVector2Array()
	buf.resize(frames)
	for i in frames:
		_t += 1.0 / RATE
		_beat += tempo / RATE
		var bi := int(_beat) % MELODY.size()
		var frac := _beat - floorf(_beat)
		if bi != _last_beat:
			_last_beat = bi
			var n: int = MELODY[bi]
			if n >= 0:
				_mel_freq = _midi(n)
				_note_age = 0.0
			_drop_note = d > 0.5 and randf() < d * 0.35
		_note_age += 1.0 / RATE
		# wow / flutter: pitch sagging like a dying tape machine
		var wow := 1.0 - d * (0.12 + 0.07 * sin(_t * 0.9) + 0.03 * sin(_t * 7.0))
		var vib := 1.0 + 0.006 * sin(_t * 33.0)
		_mel_ph += TAU * _mel_freq * wow * vib / RATE
		var mel := _organ(_mel_ph) * exp(-_note_age * 1.6) * 0.32
		if _drop_note:
			mel *= 0.15
		# oom-pah-pah
		var bar := int(_beat / 3.0) % CHORDS.size()
		var chord: Array = CHORDS[bar]
		var root: float = chord[0]
		var beat_in_bar := int(_beat) % 3
		var acc := 0.0
		if beat_in_bar == 0:
			_bass_ph += TAU * _midi(root - 12.0 + 12.0) * 0.5 * wow / RATE
			acc += _organ(_bass_ph) * exp(-frac * 4.0) * 0.35
		else:
			var third := 3.0 if chord[1] == 0 else 4.0
			var offs := [12.0, 12.0 + third, 19.0]
			for k in 3:
				_ch_ph[k] += TAU * _midi(root + offs[k]) * wow / RATE
				acc += sin(_ch_ph[k]) * exp(-frac * 7.0) * 0.08
		var s := (mel + acc) * volume
		if crush:
			s = roundf(s * levels) / levels
		s = clampf(s * (1.0 + d * 1.5), -0.9, 0.9)
		buf[i] = Vector2(s, s)
	_playback.push_buffer(buf)
