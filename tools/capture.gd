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
	add_child(scene)
	wait = int(OS.get_environment("WARM")) if OS.get_environment("WARM") != "" else 40
	scene.go_view(views[0])
	print("start ", Time.get_ticks_msec())

func _process(_d: float) -> void:
	frame += 1
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
