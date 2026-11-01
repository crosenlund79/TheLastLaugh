extends Node3D
## Run controller: builds the carnival, spawns people/player/fog, tracks objectives.

const PERSON := preload("res://scripts/person.gd")
const PLAYER := preload("res://scripts/player.gd")
const HUD := preload("res://scripts/hud.gd")
const FOG := preload("res://scripts/fog_bank.gd")
const INTERACT := preload("res://scripts/interactables.gd")

const FIRST_FOG_TIME := 40.0
const MAX_FOG := 6

var info: Dictionary
var player
var hud
var next_fog := FIRST_FOG_TIME
var fog_count := 0
var ended := false
var _impact_mesh: SphereMesh
var _fog_seen_t := -1.0


func _ready() -> void:
	randomize()
	GameState.reset_run()
	_environment()
	info = Carnival.build(self)
	GameState.flags["shed_door"] = info.shed.door
	GameState.flags["shed_door_pos"] = info.shed.door_pos
	_impact_mesh = SphereMesh.new()
	_impact_mesh.radius = 0.08
	_impact_mesh.height = 0.16
	_impact_mesh.radial_segments = 4
	_impact_mesh.rings = 2
	_spawn_pickups()
	_spawn_people()
	hud = HUD.new()
	add_child(hud)
	spawn_player(Vector3(0, 0.1, 37))
	GameState.thought.connect(hud.show_thought)
	Music.target_distortion = 0.0
	Music.target_volume = 1.0
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().create_timer(3.0).timeout.connect(func(): GameState.think("The gate slammed shut behind me... I need to find a way out.", "intro"))


## Kept separate so co-op can spawn additional players later.
func spawn_player(pos: Vector3):
	var p := PLAYER.new()
	add_child(p)
	p.global_position = pos
	p.yaw = 0.0
	p.hud = hud
	hud.player = p
	player = p
	return p


func _environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.025, 0.015, 0.06)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.26, 0.55)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.12
	env.fog_enabled = true
	env.fog_light_color = Color(0.07, 0.04, 0.12)
	env.fog_density = 0.012
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.006
	env.volumetric_fog_albedo = Color(0.6, 0.5, 0.8)
	env.volumetric_fog_emission = Color(0.015, 0.005, 0.03)
	env.volumetric_fog_length = 70.0
	we.environment = env
	add_child(we)
	var moon := DirectionalLight3D.new()
	moon.rotation = Vector3(deg_to_rad(-48), deg_to_rad(35), 0)
	moon.light_color = Color(0.55, 0.6, 1.0)
	moon.light_energy = 0.35
	moon.shadow_enabled = true
	add_child(moon)
	Build.sphere(self, 7.0, Vector3(70, 80, -140), Build.mat(Color(0.85, 0.85, 1.0), 2.0, true), 12)


func _spawn_pickups() -> void:
	spawn_pickup("pistol", info.gallery.pistol)
	for p in info.gallery.ammo:
		spawn_pickup("ammo_pistol", p)
	spawn_pickup("shotgun", info.shed.shotgun)
	spawn_pickup("gate_key", info.shed.gate_key)
	spawn_pickup("ammo_shells", info.shed.ammo)
	for p in [Vector3(-12, 1.4, 6), Vector3(14.5, 1.4, -6), Vector3(-34, 1.4, -12), Vector3(32, 1.4, -12), Vector3(6, 1.0, 30), Vector3(-24, 1.4, 24), Vector3(20, 1.4, -24)]:
		spawn_pickup(["ammo_pistol", "ammo_shells", "ammo"].pick_random(), p)


func _spawn_people() -> void:
	var bodies := ["tall", "squat", "round", "belly"]
	var clown_spots := [
		Vector3(-4, 0, -12), Vector3(5, 0, -11), Vector3(-9, 0, 4), Vector3(8, 0, 6),
		Vector3(0, 0, 14), Vector3(-3, 0, 26), Vector3(16, 0, 4), Vector3(17, 0, -3),
		Vector3(-27, 0, -21), Vector3(-22, 0, -24), Vector3(10, 0, -24), Vector3(22, 0, -30),
		Vector3(-20, 0, 8), Vector3(26, 0, 16),
	]
	for i in clown_spots.size():
		var c := PERSON.new()
		add_child(c)
		c.setup("clown", bodies[i % 4] if randf() < 0.85 else bodies.pick_random(), clown_spots[i])
	var civ_spots := [Vector3(-6, 0, 21), Vector3(6, 0, 23), Vector3(-14, 0, 29), Vector3(4, 0, -16), Vector3(-14, 0, -6), Vector3(30, 0, 30)]
	for p in civ_spots:
		var c := PERSON.new()
		add_child(c)
		c.setup("civilian", "normal" if randf() < 0.7 else "belly", p)
	var w := PERSON.new()
	add_child(w)
	w.setup("worker", "normal", info.worker_hide)
	var g := PERSON.new()
	add_child(g)
	g.setup("guard", "belly", info.guard_post)


func spawn_pickup(kind: String, pos: Vector3) -> void:
	var p := INTERACT.new()
	add_child(p)
	p.setup_pickup(kind)
	p.global_position = pos


func spawn_impact(pos: Vector3, col: Color) -> void:
	var m := MeshInstance3D.new()
	m.mesh = _impact_mesh
	m.material_override = Build.mat(col, 4.0, true)
	add_child(m)
	m.global_position = pos
	var tw := m.create_tween()
	tw.tween_property(m, "scale", Vector3.ONE * 2.5, 0.08)
	tw.tween_property(m, "scale", Vector3.ZERO, 0.2)
	tw.tween_callback(m.queue_free)


func spawn_tracer(a: Vector3, b: Vector3) -> void:
	var len := a.distance_to(b)
	if len < 0.5:
		return
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.02, 0.02, len)
	m.mesh = bm
	m.material_override = Build.mat(Color(1, 0.85, 0.5), 3.0, true)
	add_child(m)
	m.global_position = (a + b) * 0.5
	if absf((b - a).normalized().dot(Vector3.UP)) < 0.99:
		m.look_at(b, Vector3.UP)
	var tw := m.create_tween()
	tw.tween_interval(0.04)
	tw.tween_callback(m.queue_free)


func _spawn_fog() -> void:
	var f := FOG.new()
	f.radius = randf_range(6.0, 8.5)
	f.speed = randf_range(0.9, 1.5)
	add_child(f)
	var a: float
	if fog_count == 0:
		a = -PI * 0.6  # first bank rolls in from the north-west toward the carousel
	else:
		a = randf_range(-PI, 0.2)
	f.global_position = Vector3(cos(a) * 52.0, 0, sin(a) * 52.0)
	f.target = Vector3(0, 0, -4) if fog_count == 0 else Vector3(randf_range(-25, 25), 0, randf_range(-25, 25))
	GameState.fog_banks.append(f)
	fog_count += 1
	if fog_count == 1:
		_fog_seen_t = 0.0


func _process(delta: float) -> void:
	if ended:
		return
	var t := GameState.run_time
	if fog_count < MAX_FOG and t >= next_fog:
		_spawn_fog()
		next_fog = t + randf_range(28.0, 40.0)
	if _fog_seen_t >= 0.0:
		_fog_seen_t += delta
		if _fog_seen_t > 12.0:
			GameState.think("That fog wasn't here a minute ago...", "fog_first")
			_fog_seen_t = -1.0

	# fog exposure (people) and proximity (music / screen tint)
	var nearest := 999.0
	for f in GameState.fog_banks:
		for p in GameState.people:
			if not p.fog_affected and not p.dead and not p.rescued and f.contains(p.global_position):
				p.add_fog(delta)
		if player:
			var d: float = Vector2(player.global_position.x - f.global_position.x, player.global_position.z - f.global_position.z).length() - f.radius
			nearest = minf(nearest, d)
	var dist_factor := clampf(1.0 - nearest / 28.0, 0.0, 1.0)
	var base := 0.08 * minf(float(fog_count), 3.0)
	Music.target_distortion = clampf(maxf(dist_factor, base), 0.0, 1.0)
	if hud:
		hud.set_fog(clampf(-nearest / 4.0, 0.0, 0.35))
		if nearest < 2.0 and nearest > -1.0:
			GameState.think("Don't breathe it in. Don't breathe it in...", "fog_close")
		hud.set_objective(_objective())

	if player and not player.dead and GameState.flags.get("gate_open", false) and player.global_position.z > 46.0:
		end_run()


func _objective() -> String:
	if player == null:
		return ""
	var followers := 0
	for p in GameState.people:
		if p.state == PERSON.FOLLOW:
			followers += 1
	var esc := " (%d following you)" % followers if followers > 0 else ""
	if player.weapons.is_empty():
		return "Find a weapon — the shooting gallery should have something."
	if not GameState.flags.get("shed_open", false):
		if player.has_item("shed_key"):
			return "Open the maintenance shed (north-east)."
		if GameState.flags.get("worker_following", false):
			return "Escort the maintenance worker to his shed (north-east)." + esc
		return "Find the maintenance worker — he has the shed key. Try behind the Fun House."
	if not player.has_item("gate_key"):
		return "Grab the gate key from the maintenance shed."
	if not GameState.flags.get("gate_open", false):
		return "Unlock the main exit gate (south)." + esc
	return "Walk out through the gate to escape — or bring more survivors first." + esc


func end_run() -> void:
	if ended:
		return
	ended = true
	GameState.escaped = true
	for p in GameState.people:
		if p.state == PERSON.FOLLOW and p.global_position.distance_to(player.global_position) < 15.0:
			p._get_rescued()
	GameState.running = false
	var score := GameState.compute_score()
	Music.target_distortion = 0.0
	hud.show_results(score)
	get_tree().paused = true
