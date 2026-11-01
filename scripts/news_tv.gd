extends Node3D
## Frozen emergency news broadcast showing live population numbers.

var _text: Label3D
var _ticker: Label3D
var _screen_mat: StandardMaterial3D
var _t := 0.0
var _acc := 0.0


func _ready() -> void:
	Build.box(self, Vector3(1.9, 1.35, 0.35), Vector3(0, 0, -0.2), Color(0.12, 0.1, 0.1), false)
	_screen_mat = StandardMaterial3D.new()
	_screen_mat.albedo_color = Color(0.05, 0.08, 0.25)
	_screen_mat.emission_enabled = true
	_screen_mat.emission = Color(0.1, 0.15, 0.5)
	_screen_mat.emission_energy_multiplier = 1.2
	var q := QuadMesh.new()
	q.size = Vector2(1.7, 1.15)
	Build.mesh(self, q, Vector3(0, 0, -0.01), _screen_mat)
	Build.box(self, Vector3(1.7, 0.18, 0.01), Vector3(0, 0.45, 0.0), Color(0.8, 0.05, 0.05), false, 2.0)
	var head := Build.label(self, "EMERGENCY BROADCAST", Vector3(0, 0.45, 0.01), Color(1, 1, 1), 22)
	head.outline_size = 4
	_text = Build.label(self, "", Vector3(-0.78, -0.05, 0.01), Color(0.9, 0.95, 1.0), 17)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_text.outline_size = 4
	_ticker = Build.label(self, "", Vector3(0, -0.5, 0.01), Color(1, 0.85, 0.2), 15)
	_ticker.outline_size = 4
	var o := Build.omni(self, Vector3(0, 0, 0.6), Color(0.4, 0.5, 1.0), 1.0, 4.0)
	o.shadow_enabled = false
	_refresh()


func _process(delta: float) -> void:
	_t += delta
	_acc += delta
	_screen_mat.emission_energy_multiplier = 1.0 + 0.25 * sin(_t * 23.0) * randf()
	if _acc > 1.0:
		_acc = 0.0
		_refresh()


func _refresh() -> void:
	var s := GameState.get_stats()
	_text.text = "LIVE: INCIDENT AT HAPPY HOLLOW CARNIVAL\n" \
		+ "People in the carnival tonight:  %d\n" % s.total \
		+ "Affected by the purple fog:      %d\n" % s.affected \
		+ "Rescued so far:                  %d\n" % s.rescued \
		+ "Still trapped inside:            %d\n" % s.remaining \
		+ "  (unaffected, alive:            %d)" % s.trapped
	_ticker.text = "AUTHORITIES: DO NOT ENTER THE FOG  ***  AFFECTED PERSONS MAY STILL BE ALIVE"
