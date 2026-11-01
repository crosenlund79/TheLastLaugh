extends Node
## Procedurally synthesized placeholder sound effects.

const RATE := 22050
var sounds := {}
var _ui_player: AudioStreamPlayer
var _active_3d := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ui_player = AudioStreamPlayer.new()
	_ui_player.bus = "SFX"
	add_child(_ui_player)
	_build_all()


func play(sound: String, pos: Vector3, vol_db: float = 0.0, pitch: float = 1.0, max_dist: float = 60.0) -> void:
	if not sounds.has(sound):
		return
	var tree := get_tree()
	if tree.current_scene == null or not (tree.current_scene is Node3D):
		return
	if _active_3d > 40:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = sounds[sound]
	p.bus = "SFX"
	p.volume_db = vol_db
	p.pitch_scale = pitch * randf_range(0.92, 1.08)
	p.unit_size = 8.0
	p.max_distance = max_dist
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	tree.current_scene.add_child(p)
	p.global_position = pos
	p.play()
	_active_3d += 1
	p.finished.connect(func():
		_active_3d -= 1
		p.queue_free())


func play_ui(sound: String, vol_db: float = 0.0, pitch: float = 1.0) -> void:
	if not sounds.has(sound):
		return
	var p := AudioStreamPlayer.new()
	p.stream = sounds[sound]
	p.bus = "SFX"
	p.volume_db = vol_db
	p.pitch_scale = pitch
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


# ------------------------------------------------------------- synthesis
func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


func _gen(dur: float, f: Callable) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		s[i] = f.call(float(i) / RATE, float(i) / n)
	return _wav(s)


func _build_all() -> void:
	# Clown nose honk: buzzy two-partial horn with pitch bend.
	var ph := [0.0]
	sounds["honk"] = _gen(0.45, func(t: float, u: float):
		var f := 330.0 + 60.0 * (1.0 - u) + 10.0 * sin(t * 60.0)
		ph[0] += TAU * f / RATE
		var v := 0.55 * signf(sin(ph[0])) * 0.5 + 0.4 * sin(ph[0] * 1.5) + 0.25 * sin(ph[0] * 2.0)
		var env := minf(1.0, t * 40.0) * (1.0 - u) * (1.0 - u * 0.3)
		return v * env * 0.6)

	sounds["pistol"] = _gen(0.35, func(t: float, u: float):
		return (randf_range(-1, 1) * exp(-t * 28.0) + 0.8 * sin(TAU * 90.0 * t) * exp(-t * 18.0)) * 0.8)
	var lp := [0.0]
	sounds["shotgun"] = _gen(0.6, func(t: float, u: float):
		lp[0] = lerpf(lp[0], randf_range(-1, 1), 0.35)
		return (lp[0] * 2.2 * exp(-t * 10.0) + 0.9 * sin(TAU * 60.0 * t) * exp(-t * 9.0)) * 0.8)
	sounds["smg"] = _gen(0.14, func(t: float, u: float):
		return (randf_range(-1, 1) * exp(-t * 45.0) + 0.6 * sin(TAU * 120.0 * t) * exp(-t * 30.0)) * 0.7)
	sounds["clown_gun"] = _gen(0.4, func(t: float, u: float):
		return (randf_range(-1, 1) * exp(-t * 20.0) * 0.8 + 0.5 * sin(TAU * (140.0 - 80.0 * u) * t) * exp(-t * 10.0)) * 0.7)
	sounds["ricochet"] = _gen(0.35, func(t: float, u: float):
		return sin(TAU * (3200.0 - 2400.0 * u) * t) * exp(-t * 9.0) * 0.25 + randf_range(-1, 1) * exp(-t * 60.0) * 0.4)

	var sq := [0.0]
	sounds["squeak"] = _gen(0.4, func(t: float, u: float):
		var f := 1300.0 + 900.0 * sin(u * PI) + 60.0 * sin(t * 80.0)
		sq[0] += TAU * f / RATE
		return sin(sq[0]) * sin(u * PI) * 0.45)
	var bo := [0.0]
	sounds["hammer_hit"] = _gen(0.7, func(t: float, u: float):
		bo[0] += TAU * (180.0 + 90.0 * sin(t * 35.0)) / RATE
		return (sin(TAU * 52.0 * t) * exp(-t * 7.0) + randf_range(-1, 1) * exp(-t * 35.0) * 0.6 + sin(bo[0]) * exp(-t * 5.0) * 0.45) * 0.9)
	sounds["whoosh"] = _gen(0.3, func(t: float, u: float):
		return randf_range(-1, 1) * sin(u * PI) * 0.3)

	var st := [0.0]
	sounds["step"] = _gen(0.09, func(t: float, u: float):
		st[0] = lerpf(st[0], randf_range(-1, 1), 0.2)
		return st[0] * exp(-t * 45.0) * 1.5)
	var fl := [0.0]
	sounds["flop"] = _gen(0.18, func(t: float, u: float):
		fl[0] = lerpf(fl[0], randf_range(-1, 1), 0.15)
		return (fl[0] * 1.2 + sin(TAU * (160.0 - 90.0 * u) * t) * 0.6) * exp(-t * 22.0))

	var sc := [0.0]
	sounds["scream"] = _gen(0.9, func(t: float, u: float):
		var f := 650.0 + 250.0 * u + 70.0 * sin(t * 38.0)
		sc[0] += TAU * f / RATE
		var v := sin(sc[0]) * 0.5 + (fmod(sc[0], TAU) / TAU - 0.5) * 0.4
		return v * minf(1.0, t * 12.0) * (1.0 - u) * 0.5)
	var gr := [0.0]
	sounds["transform"] = _gen(2.2, func(t: float, u: float):
		var f := 110.0 - 70.0 * u + 8.0 * sin(t * 13.0)
		gr[0] += TAU * f / RATE
		var saw := fmod(gr[0], TAU) / TAU - 0.5
		var trem := 0.6 + 0.4 * sin(t * 22.0)
		return (saw * 0.8 + randf_range(-1, 1) * 0.15) * trem * sin(u * PI) * 0.7)
	var gi := [0.0]
	sounds["giggle"] = _gen(0.8, func(t: float, u: float):
		var f := 520.0 + 120.0 * sin(t * 50.0) - 200.0 * u
		gi[0] += TAU * f / RATE
		var pulse := maxf(0.0, sin(t * 42.0))
		return sin(gi[0]) * pulse * (1.0 - u) * 0.4)

	sounds["click"] = _gen(0.05, func(t: float, u: float): return randf_range(-1, 1) * exp(-t * 150.0) * 0.6)
	sounds["reload"] = _gen(0.5, func(t: float, u: float):
		var a := randf_range(-1, 1) * exp(-t * 120.0)
		var b := 0.0
		if t > 0.3:
			b = randf_range(-1, 1) * exp(-(t - 0.3) * 100.0)
		return (a + b) * 0.6)
	sounds["pickup"] = _gen(0.35, func(t: float, u: float):
		var notes := [523.25, 659.25, 783.99]
		var f: float = notes[mini(2, int(u * 3.0))]
		return sin(TAU * f * t) * 0.35 * (1.0 - fmod(u * 3.0, 1.0) * 0.5))
	sounds["clunk"] = _gen(0.4, func(t: float, u: float):
		return (sin(TAU * 80.0 * t) * exp(-t * 14.0) + randf_range(-1, 1) * exp(-t * 50.0) * 0.5) * 0.8)
	var cr := [0.0]
	sounds["creak"] = _gen(1.4, func(t: float, u: float):
		cr[0] += TAU * (70.0 + 25.0 * sin(t * 6.0)) / RATE
		var saw := fmod(cr[0], TAU) / TAU - 0.5
		return saw * sin(u * PI) * 0.5)
	sounds["hurt"] = _gen(0.3, func(t: float, u: float):
		return (sin(TAU * 70.0 * t) * 0.8 + randf_range(-1, 1) * 0.3) * exp(-t * 12.0))
	sounds["flesh"] = _gen(0.15, func(t: float, u: float):
		return (sin(TAU * 110.0 * t) + randf_range(-1, 1) * 0.5) * exp(-t * 30.0) * 0.6)
	var boi := [0.0]
	sounds["boing"] = _gen(0.6, func(t: float, u: float):
		boi[0] += TAU * (220.0 + 160.0 * sin(t * 28.0) * (1.0 - u)) / RATE
		return sin(boi[0]) * exp(-t * 4.0) * 0.45)
