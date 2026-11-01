extends Node3D
## Reusable corruption component. Drop it under any carnival structure; when a fog bank
## touches it the structure is permanently corrupted:
##   - a shared vein/tint overlay shader goes on every mesh (materials stay untouched),
##   - meshes are bent/stretched (VISUAL ONLY: collision shapes never move),
##   - lights shift to violet/crimson and flicker or fail, bulbs turn sickly,
##   - signs rewrite themselves, animated props (props.gd) go erratic,
##   - looping attraction audio detunes and an uneasy drone starts.
## Interactables (doors, gate, pickups) and emergency displays are never touched.

const INTERACT := preload("res://scripts/interactables.gd")
const TV := preload("res://scripts/news_tv.gd")
const PROPS := preload("res://scripts/props.gd")

const TEXT := {
	"POPCORN": "POP.  CORN.", "COTTON CANDY": "ROTTEN CANDY", "HOOPLA": "HOOP LA LA LA",
	"FORTUNES": "NO FUTURES", "TICKETS": "NO EXIT", "DUCK POND": "DROWN POND",
	"SHOOTING GALLERY": "SHOOT THEM ALL", "WIN A PRIZE!": "WIN A FRIEND!", "FUN HOUSE": "FUN FOREVER",
	"BIG TOP": "BIG  GRIN", "CAROUSEL": "ROUND AND ROUND", "SKY WHEEL": "NEVER STOPS",
	"TEST YOUR STRENGTH": "TEST YOUR SANITY", "ADMIT ONE": "ADMIT ALL", "CHECKPOINT": "NO ONE LEAVES",
	"MAINTENANCE YARD": "MAINTENANCE  YARD", "THE LAST LAUGH": "THE LAST LAUGH IS OURS",
}
const OVERLAY := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled;
uniform float strength = 0.55;
varying vec3 wpos;
float h(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float vn(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h(i), h(i + vec3(1,0,0)), f.x), mix(h(i + vec3(0,1,0)), h(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(h(i + vec3(0,0,1)), h(i + vec3(1,0,1)), f.x), mix(h(i + vec3(0,1,1)), h(i + vec3(1,1,1)), f.x), f.y), f.z);
}
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float n = vn(wpos * 1.6 + vec3(0.0, TIME * 0.12, 0.0)) * 0.6 + vn(wpos * 4.0) * 0.4;
	float veins = smoothstep(0.46, 0.5, n) * (1.0 - smoothstep(0.5, 0.55, n));
	vec3 tint = mix(vec3(0.16, 0.02, 0.22), vec3(0.32, 0.0, 0.08), vn(wpos * 0.35));
	float pulse = 0.65 + 0.35 * sin(TIME * 2.3 + wpos.y * 2.0);
	ALBEDO = tint + veins * vec3(0.9, 0.25, 1.3) * pulse * 1.6;
	ALPHA = clamp(strength * 0.7 + veins * 0.4, 0.0, 0.95);
}
"""
const LIGHT_COLS := [Color(0.65, 0.2, 1.0), Color(0.95, 0.1, 0.25), Color(0.5, 0.9, 0.3)]

static var _overlay: ShaderMaterial
static var _bulb_mats: Array = []

var kind := "generic"   # generic, lamp, carousel, wheel, gallery, balloons, bulbs, sign
var radius := 4.0
var warp := 1.0
var corrupted := false
var _t := 0.0
var _lights: Array = []
var _tune: AudioStreamPlayer3D
var _drone: AudioStreamPlayer3D


func _ready() -> void:
	GameState.corruptibles.append(self)
	if _overlay == null:
		var sh := Shader.new()
		sh.code = OVERLAY
		_overlay = ShaderMaterial.new()
		_overlay.shader = sh
		for c in [Color(0.6, 0.1, 0.9), Color(0.9, 0.05, 0.2), Color(0.35, 0.8, 0.25)]:
			_bulb_mats.append(Build.mat(c, 5.0))
	set_process(false)


## Optional cheerful loop for attractions (carousel music box etc.).
func add_tune(sound: String, vol_db: float = -8.0) -> void:
	_tune = AudioStreamPlayer3D.new()
	_tune.stream = Sfx.sounds.get(sound)
	_tune.bus = "SFX"
	_tune.unit_size = 7.0
	_tune.max_distance = 35.0
	_tune.volume_db = vol_db
	_tune.autoplay = true
	add_child(_tune)


func corrupt() -> void:
	if corrupted:
		return
	corrupted = true
	var nodes: Array = []
	_collect(get_parent(), nodes)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(global_position)
	var w := warp * (0.6 if kind == "lamp" or kind == "bulbs" else 1.0)
	for n in nodes:
		if n is MultiMeshInstance3D:
			n.material_override = _bulb_mats[rng.randi() % _bulb_mats.size()]
		elif n is MeshInstance3D:
			n.material_overlay = _overlay
			if kind != "bulbs":
				# crooked, stretched, leaning - visual only
				n.rotation += Vector3(rng.randf_range(-0.12, 0.12), rng.randf_range(-0.1, 0.1), rng.randf_range(-0.14, 0.14)) * w
				n.scale *= Vector3(rng.randf_range(0.95, 1.08), rng.randf_range(1.0, 1.0 + 0.3 * w), rng.randf_range(0.95, 1.08))
		elif n is Light3D:
			n.light_color = LIGHT_COLS[rng.randi() % 2] if rng.randf() < 0.85 else LIGHT_COLS[2]
			if not (n.get_parent() is PROPS):
				_lights.append([n, n.light_energy, rng.randf() < 0.3])
		elif n is Label3D:
			var key: String = n.text.strip_edges()
			if TEXT.has(key):
				n.text = TEXT[key]
			n.modulate = Color(0.85, 0.25, 1.0) if rng.randf() < 0.5 else Color(1.0, 0.2, 0.25)
			n.rotation.z += rng.randf_range(-0.08, 0.08) * w
		elif n is PROPS:
			n.corrupt()
	if _tune:
		_tune.volume_db += 2.0
	_drone = AudioStreamPlayer3D.new()
	_drone.stream = Sfx.sounds.get("fog_drone")
	_drone.bus = "SFX"
	_drone.unit_size = 5.0
	_drone.max_distance = 22.0
	_drone.volume_db = -14.0
	_drone.pitch_scale = 0.55
	_drone.autoplay = true
	add_child(_drone)
	Sfx.play("corrupt", global_position + Vector3.UP * 2.0, -2.0, randf_range(0.8, 1.1))
	set_process(true)


func _collect(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c == self or c is INTERACT or c is TV:
			continue
		if c.has_method("setup") and c is CharacterBody3D:
			continue
		out.append(c)
		_collect(c, out)


func _process(delta: float) -> void:
	_t += delta
	for l in _lights:
		var light: Light3D = l[0]
		if l[2]:
			light.light_energy = l[1] * (0.6 if randf() < 0.04 else 0.03)  # dead, occasional spark
		else:
			var f := 1.0
			if randf() < 0.12:
				f = randf_range(0.0, 0.5)
			elif randf() < 0.02:
				f = 1.8
			light.light_energy = lerpf(light.light_energy, l[1] * f, 0.4)
	if _tune:
		_tune.pitch_scale = 0.72 + sin(_t * 0.7) * 0.08 + sin(_t * 5.3) * 0.02
