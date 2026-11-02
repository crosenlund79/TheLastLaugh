extends Node
## Dev tool: renders the showcase's photo-mode viewpoints to PNG.
## OUT=<dir> VIEWS=1,2,3 WARM=40 SETTLE=12 godot --path . res://tools/capture.tscn
var scene
var frame := 0
var views: Array = []
var vi := 0
var wait := 0
var out := ""

func _ready() -> void:
	out = OS.get_environment("OUT")
	var vs := OS.get_environment("VIEWS")
	views = Array(vs.split(",")).map(func(x): return int(x) - 1) if vs != "" else [0, 1, 2, 3, 4, 5, 6]
	scene = load("res://showcase/showcase.tscn").instantiate()
	var off := OS.get_environment("PROFILE_OFF")  # profiling only: comma list of features to disable
	if off != "":
		scene.set_meta("profile_off", off.split(","))
	add_child(scene)
	wait = int(OS.get_environment("WARM")) if OS.get_environment("WARM") != "" else 40
	scene.go_view(views[0])
	print("start ", Time.get_ticks_msec())

var _last := 0
var _abl := ["particles", "grass", "trees", "vfog", "sdfgi", "shadow", "ssr_ssao", "glow_fog"]
var _abl_i := -1

func _ablate(step: String) -> void:
	var env: Environment = scene.env
	match step:
		"particles":
			for n in scene.find_children("*", "GPUParticles3D", true, false): n.visible = false
		"grass":
			for n in scene.find_children("*", "MultiMeshInstance3D", true, false):
				if n.multimesh.use_custom_data: n.visible = false
		"trees":
			for n in scene.find_children("*", "MultiMeshInstance3D", true, false): n.visible = false
			for n in scene.find_children("*", "MeshInstance3D", true, false):
				if n.material_override and n.material_override is ShaderMaterial and str(n.material_override.shader.resource_path).ends_with("foliage.gdshader"): n.visible = false
		"vfog": env.volumetric_fog_enabled = false
		"sdfgi": env.sdfgi_enabled = false
		"shadow": scene.sun.shadow_enabled = false
		"ssr_ssao":
			env.ssr_enabled = false
			env.ssao_enabled = false
		"glow_fog":
			env.glow_enabled = false
			env.fog_enabled = false

func _process(_d: float) -> void:
	frame += 1
	var now := Time.get_ticks_msec()
	print("frame ", frame, " dt ", now - _last, " config ", "all" if _abl_i < 0 else "-" + ",".join(_abl.slice(0, _abl_i + 1)))
	_last = now
	if OS.get_environment("ABLATE") != "" and frame >= 4 and (frame - 4) % 2 == 0:
		_abl_i += 1
		if _abl_i >= _abl.size():
			get_tree().quit()
			return
		_ablate(_abl[_abl_i])
		return
	wait -= 1
	if wait > 0:
		return
	var img := get_viewport().get_texture().get_image()
	var path := "%s/view%d.png" % [out, views[vi] + 1]
	img.save_png(path)
	print("saved ", path, " at frame ", frame, " t=", Time.get_ticks_msec())
	vi += 1
	if vi >= views.size():
		get_tree().quit()
		return
	scene.go_view(views[vi])
	wait = int(OS.get_environment("SETTLE")) if OS.get_environment("SETTLE") != "" else 12
