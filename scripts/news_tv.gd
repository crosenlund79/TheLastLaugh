extends Node3D
## Emergency TV broadcast showing live population numbers (same partition as the results
## screen: rescued + affected + casualties + still-inside == total, no double counting).

const SCREEN := """
shader_type spatial;
render_mode unshaded, cull_back;
uniform float alarm = 0.0;
float h(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec2 uv = UV;
	vec3 base = mix(vec3(0.02, 0.05, 0.2), vec3(0.03, 0.12, 0.35), uv.y);
	// red alert band pulsing at the top and bottom
	float band = step(0.84, uv.y) + step(uv.y, 0.12);
	base = mix(base, vec3(0.55, 0.02, 0.05) * (0.75 + 0.25 * sin(TIME * 5.0)), band);
	float scan = 0.82 + 0.18 * sin(uv.y * 340.0);
	float roll = smoothstep(0.0, 0.04, abs(fract(uv.y - TIME * 0.18) - 0.5));
	float stat = h(uv * vec2(160.0, 90.0) + floor(TIME * 24.0));
	vec3 c = base * scan * (0.85 + 0.15 * roll) + vec3(stat) * (0.06 + alarm * 0.1);
	if (h(vec2(floor(TIME * 3.0), 1.0)) > 0.93) { c += vec3(stat) * 0.35; }  // brief signal dropouts
	ALBEDO = c;
	EMISSION = c * 1.6;
}
"""

var _text: Label3D
var _ticker: Label3D
var _live: Label3D
var _mat: ShaderMaterial
var _t := 0.0
var _acc := 0.0


func _ready() -> void:
	Build.box(self, Vector3(1.95, 1.4, 0.4), Vector3(0, 0, -0.22), Color(0.1, 0.09, 0.1), false)
	Build.box(self, Vector3(0.6, 0.06, 0.3), Vector3(0, -0.74, -0.2), Color(0.1, 0.09, 0.1), false)
	var sh := Shader.new()
	sh.code = SCREEN
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	var q := QuadMesh.new()
	q.size = Vector2(1.75, 1.2)
	Build.mesh(self, q, Vector3(0, 0, -0.01), _mat)
	# warning triangle
	var tri := PrismMesh.new()
	tri.size = Vector3(0.2, 0.18, 0.01)
	Build.mesh(self, tri, Vector3(-0.72, 0.47, 0.0), Build.mat(Color(1, 0.8, 0.1), 2.0, true))
	var ex := Build.label(self, "!", Vector3(-0.72, 0.455, 0.008), Color(0, 0, 0), 30)
	ex.pixel_size = 0.005
	ex.outline_size = 0
	var head := Build.label(self, "EMERGENCY BROADCAST", Vector3(0.1, 0.47, 0.01), Color(1, 1, 1), 26)
	head.pixel_size = 0.005
	head.outline_size = 4
	_live = Build.label(self, "LIVE", Vector3(0.72, 0.47, 0.01), Color(1, 0.3, 0.3), 22)
	_live.pixel_size = 0.005
	_live.outline_size = 3
	_text = Build.label(self, "", Vector3(-0.8, -0.02, 0.01), Color(0.92, 0.96, 1.0), 24)
	_text.pixel_size = 0.0033
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_text.outline_size = 4
	_ticker = Build.label(self, "", Vector3(0, -0.5, 0.01), Color(1, 0.85, 0.2), 22)
	_ticker.pixel_size = 0.0032
	_ticker.outline_size = 4
	var o := Build.omni(self, Vector3(0, 0, 0.6), Color(0.4, 0.5, 1.0), 1.0, 4.0)
	o.shadow_enabled = false
	_refresh()


func _process(delta: float) -> void:
	_t += delta
	_acc += delta
	_live.visible = fmod(_t, 1.0) < 0.6
	if _acc > 1.0:
		_acc = 0.0
		_refresh()


func _refresh() -> void:
	var s := GameState.get_stats()
	_mat.set_shader_parameter("alarm", clampf(float(s.affected) / maxf(1.0, s.total), 0.0, 1.0))
	_text.text = "INCIDENT AT HAPPY HOLLOW CARNIVAL\n" \
		+ "People in the park tonight:   %d\n" % s.total \
		+ "Affected by purple fog:       %d\n" % s.affected \
		+ "Rescued:                      %d\n" % s.rescued \
		+ "Remaining inside (unharmed):  %d\n" % s.trapped \
		+ "Confirmed casualties:         %d" % s.casualties
	var msgs := ["*** DO NOT ENTER THE FOG ***", "AFFECTED PERSONS MAY STILL BE ALIVE", "%d PEOPLE STILL TRAPPED INSIDE" % s.trapped, "RESCUE SERVICES CANNOT ENTER THE PARK"]
	_ticker.text = msgs[int(_t / 3.0) % msgs.size()]
