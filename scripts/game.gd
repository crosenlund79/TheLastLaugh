extends Node3D
## Run controller: builds the carnival, bakes navigation, spawns people/staff/player/fog,
## drives the cheerful->nightmare "dread" presentation and tracks objectives.

const PERSON := preload("res://scripts/person.gd")
const PLAYER := preload("res://scripts/player.gd")
const HUD := preload("res://scripts/hud.gd")
const FOG := preload("res://scripts/fog_bank.gd")
const INTERACT := preload("res://scripts/interactables.gd")

const FIRST_FOG_TIME := 40.0
const MAX_FOG := 6
const WORKER_NAMES := ["Dale", "Rosa", "Marty"]
const WORKER_AREAS := ["the Fun House", "the carousel", "the Big Top"]
const GUARD_NAMES := ["Officer Briggs", "Officer Kim", "Officer Lutz"]

var info: Dictionary
var player
var hud
var next_fog := FIRST_FOG_TIME
var fog_count := 0
var ended := false
var _impact_mesh: SphereMesh
var _fog_seen_t := -1.0
var _check_t := 0.0
var env: Environment
var sky_mat: ProceduralSkyMaterial
var moon: DirectionalLight3D
var nav_region: NavigationRegion3D


func _ready() -> void:
	randomize()
	GameState.reset_run()
	_environment()
	nav_region = NavigationRegion3D.new()
	add_child(nav_region)
	info = Carnival.build(nav_region)
	_bake_navigation()
	GameState.flags["shed_door"] = info.shed.door
	GameState.flags["shed_door_pos"] = info.shed.door_pos
	GameState.safehouses["worker"] = {"door": info.shed.door, "slots": info.shed.slots, "center": Vector3(30, 0, -26), "half": Vector3(3.5, 3, 3.0)}
	GameState.safehouses["guard"] = {"door": info.office.door, "slots": info.office.slots, "center": Vector3(33, 0, 31), "half": Vector3(4.0, 3, 3.0)}
	_impact_mesh = SphereMesh.new()
	_impact_mesh.radius = 0.08
	_impact_mesh.height = 0.16
	_impact_mesh.radial_segments = 4
	_impact_mesh.rings = 2
	_spawn_pickups()
	_spawn_people()
	_spawn_staff()
	hud = HUD.new()
	add_child(hud)
	spawn_player(Vector3(0, 0.1, 37))
	GameState.thought.connect(hud.show_thought)
	GameState.radio.connect(_on_radio)
	Music.target_distortion = 0.0
	Music.target_volume = 1.0
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().create_timer(3.0).timeout.connect(func(): GameState.think("The gate slammed shut behind me... I need to find a way out.", "intro"))
	get_tree().create_timer(14.0).timeout.connect(func(): GameState.think("The maintenance crew must have keys to that gate.", "key_hint"))


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


func _bake_navigation() -> void:
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1  # doors & gate live on layer 16: paths go through doorways
	nm.agent_radius = 0.5
	nm.agent_height = 1.75
	nm.agent_max_climb = 0.25
	nm.cell_size = 0.25
	nm.cell_height = 0.25
	nm.filter_baking_aabb = AABB(Vector3(-43, -1, -43), Vector3(86, 8, 92))
	nav_region.navigation_mesh = nm
	nav_region.bake_navigation_mesh(false)


func _environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.06, 0.05, 0.2)
	sky_mat.sky_horizon_color = Color(0.55, 0.25, 0.38)
	sky_mat.sky_curve = 0.12
	sky_mat.ground_bottom_color = Color(0.01, 0.01, 0.02)
	sky_mat.ground_horizon_color = Color(0.2, 0.1, 0.18)
	sky_mat.sun_angle_max = 1.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.4, 0.6)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.85
	env.glow_bloom = 0.1
	env.glow_hdr_threshold = 0.9
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6
	env.fog_enabled = true
	env.fog_light_color = Color(0.1, 0.06, 0.14)
	env.fog_density = 0.006
	env.fog_sky_affect = 0.4
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.003
	env.volumetric_fog_albedo = Color(0.7, 0.6, 0.85)
	env.volumetric_fog_emission = Color(0.01, 0.006, 0.02)
	env.volumetric_fog_length = 70.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
	we.environment = env
	add_child(we)
	moon = DirectionalLight3D.new()
	moon.rotation = Vector3(deg_to_rad(-48), deg_to_rad(35), 0)
	moon.light_color = Color(0.6, 0.65, 1.0)
	moon.light_energy = 0.45
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 60.0
	moon.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(moon)
	Build.sphere(self, 7.0, Vector3(70, 80, -140), Build.mat(Color(0.9, 0.9, 1.0), 2.5, true), 16)
	# stars
	var stars := []
	for k in 260:
		var a := randf() * TAU
		var e := randf_range(0.15, 1.4)
		stars.append(Transform3D(Basis().scaled(Vector3.ONE * randf_range(0.5, 1.4)), Vector3(cos(a) * cos(e), sin(e), sin(a) * cos(e)) * 190.0))
	var sm := SphereMesh.new()
	sm.radius = 0.35
	sm.height = 0.7
	sm.radial_segments = 4
	sm.rings = 2
	Build.multi(self, sm, stars, Build.mat(Color(1, 1, 1), 3.0, true))


func _spawn_pickups() -> void:
	spawn_pickup("pistol", info.gallery.pistol)
	for p in info.gallery.ammo:
		spawn_pickup("ammo_pistol", p)
	spawn_pickup("shotgun", info.shed.shotgun)
	spawn_pickup("ammo_shells", info.shed.ammo)
	spawn_pickup("ammo_smg", info.office.ammo)
	for p in [Vector3(-12, 1.4, 6), Vector3(14.5, 1.4, -6), Vector3(-34, 1.4, -12), Vector3(33, 1.4, -12), Vector3(6, 1.0, 30), Vector3(-24, 1.4, 24), Vector3(20, 1.4, -27)]:
		spawn_pickup(["ammo_pistol", "ammo_shells", "ammo"].pick_random(), p)


func _spawn_people() -> void:
	var bodies := ["tall", "squat", "round", "belly", "skinny"]
	var clown_spots := [
		Vector3(-4, 0, -12), Vector3(5, 0, -11), Vector3(-9, 0, 4), Vector3(8, 0, 6),
		Vector3(0, 0, 14), Vector3(-3, 0, 26), Vector3(16, 0, 4), Vector3(17, 0, -3),
		Vector3(-27, 0, -21), Vector3(-22, 0, -24), Vector3(10, 0, -24), Vector3(22, 0, -31),
		Vector3(-20, 0, 8), Vector3(26, 0, 16),
	]
	for i in clown_spots.size():
		var c := PERSON.new()
		add_child(c)
		c.setup("clown", bodies[i % bodies.size()] if randf() < 0.85 else bodies.pick_random(), clown_spots[i])
	var civ_spots := [Vector3(-6, 0, 21), Vector3(6, 0, 23), Vector3(-14, 0, 29), Vector3(4, 0, -16), Vector3(-14, 0, -6), Vector3(20, 0, 35)]
	for p in civ_spots:
		var c := PERSON.new()
		add_child(c)
		c.setup("civilian", "normal" if randf() < 0.7 else "belly", p)


func _spawn_staff() -> void:
	var key_idx := randi() % 3
	var wbodies := ["normal", "belly", "skinny"]
	wbodies.shuffle()
	for i in 3:
		var w := PERSON.new()
		add_child(w)
		var pts: Array = info.worker_duty[i]
		w.setup("worker", wbodies[i], pts[0] + Vector3(1, 0, 1))
		w.setup_staff(WORKER_NAMES[i], i, pts, WORKER_AREAS[i], i == key_idx)
	var gbodies := ["belly", "normal", "normal"]
	for i in 3:
		var g := PERSON.new()
		add_child(g)
		var route: Array = info.guard_routes[i]
		g.setup("guard", gbodies[i], route[0])
		g.setup_staff(GUARD_NAMES[i], i, route, "", false)


func spawn_pickup(kind: String, pos: Vector3) -> void:
	var p := INTERACT.new()
	add_child(p)
	p.setup_pickup(kind)
	p.global_position = pos
	if kind.ends_with("_key"):
		p.add_to_group("pickup_" + kind)


func spawn_impact(pos: Vector3, col: Color) -> void:
	var m := MeshInstance3D.new()
	m.mesh = _impact_mesh
	m.material_override = Build.mat(col, 4.0, true)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
		a = -PI * 0.6
	else:
		a = randf_range(-PI, 0.2)
	f.global_position = Vector3(cos(a) * 52.0, 0, sin(a) * 52.0)
	f.target = Vector3(0, 0, -4) if fog_count == 0 else Vector3(randf_range(-25, 25), 0, randf_range(-25, 25))
	GameState.fog_banks.append(f)
	fog_count += 1
	if fog_count == 1:
		_fog_seen_t = 0.0


func _on_radio(speaker: String, text: String) -> void:
	hud.show_radio(speaker, text)
	get_tree().create_timer(7.5).timeout.connect(func(): GameState.think("The staff are falling back to their safe houses... I might have to knock.", "radio_first"))


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
	Music.target_distortion = clampf(maxf(maxf(dist_factor, base), GameState.dread * 0.5), 0.0, 1.0)
	_update_dread(delta)
	if hud:
		hud.set_fog(clampf(1.0 - (nearest + 2.0) / 8.0, 0.0, 1.0))
		if nearest < 2.0 and nearest > -1.0:
			GameState.think("Don't breathe it in. Don't breathe it in...", "fog_close")
		hud.set_objective(_objective())

	_check_t -= delta
	if _check_t <= 0.0:
		_check_t = 2.0
		_ensure_progression()

	if player and not player.dead and GameState.flags.get("gate_open", false) and player.global_position.z > 46.0:
		end_run()


## Cheerful -> nightmare. Driven by how much of the park the fog has taken.
func _update_dread(delta: float) -> void:
	var s := GameState.get_stats()
	var target := clampf(float(s.affected) / maxf(1.0, float(s.total)) * 1.6 + minf(float(fog_count), 4.0) * 0.07, 0.0, 1.0)
	GameState.dread = move_toward(GameState.dread, target, delta * 0.03)
	var d := GameState.dread
	env.ambient_light_color = Color(0.5, 0.4, 0.6).lerp(Color(0.24, 0.16, 0.36), d)
	env.ambient_light_energy = lerpf(0.6, 0.3, d)
	env.fog_light_color = Color(0.1, 0.06, 0.14).lerp(Color(0.16, 0.04, 0.22), d)
	env.fog_density = lerpf(0.006, 0.02, d)
	env.volumetric_fog_density = lerpf(0.003, 0.017, d)
	env.volumetric_fog_albedo = Color(0.7, 0.6, 0.85).lerp(Color(0.6, 0.3, 0.85), d)
	env.volumetric_fog_emission = Color(0.01, 0.006, 0.02).lerp(Color(0.05, 0.0, 0.08), d)
	env.adjustment_saturation = lerpf(1.15, 0.8, d)
	env.glow_intensity = lerpf(0.85, 1.2, d)
	sky_mat.sky_horizon_color = Color(0.55, 0.25, 0.38).lerp(Color(0.28, 0.06, 0.38), d)
	sky_mat.sky_top_color = Color(0.06, 0.05, 0.2).lerp(Color(0.02, 0.0, 0.05), d)
	moon.light_energy = lerpf(0.45, 0.18, d)
	moon.light_color = Color(0.6, 0.65, 1.0).lerp(Color(0.65, 0.45, 0.95), d)


## Softlock prevention: the gate key and the shed must always stay reachable.
func _ensure_progression() -> void:
	if player == null:
		return
	var flags := GameState.flags
	# 1) the gate key must exist somewhere obtainable
	if not player.has_item("gate_key") and not flags.get("gate_open", false):
		var exists := not get_tree().get_nodes_in_group("pickup_gate_key").is_empty()
		for p in GameState.people:
			if p.keyholder and not p.dead and not p.fog_affected and not p.rescued:
				exists = true
		if not exists:
			var pos: Vector3 = flags.get("gate_key_last_pos", info.shed.door_pos)
			spawn_pickup("gate_key", Vector3(clampf(pos.x, -40, 40), 0.7, clampf(pos.z, -40, 40)))
	# 2) a key lying inside a safe house nobody can open -> the lock gives way
	for kind in ["gate_key", "shed_key"]:
		for k in get_tree().get_nodes_in_group("pickup_" + kind):
			for prof in GameState.safehouses:
				var sh: Dictionary = GameState.safehouses[prof]
				var rel: Vector3 = k.global_position - sh.center
				if absf(rel.x) < sh.half.x and absf(rel.z) < sh.half.z:
					var flag: String = sh.door.unlock_flag
					if not flags.get(flag, false) and sh.door._human_staff_inside().is_empty():
						flags[flag] = true
	# 3) the shed (shotgun) must stay openable once no worker can let you in
	if not flags.get("shed_unlocked", false) and not player.has_item("shed_key") and get_tree().get_nodes_in_group("pickup_shed_key").is_empty():
		var human_worker := false
		for p in GameState.people:
			if p.role == "worker" and not p.dead and not p.fog_affected and not p.rescued:
				human_worker = true
		if not human_worker:
			flags["shed_key_dropped"] = true
			spawn_pickup("shed_key", info.shed.door_pos + Vector3(-1.0, 0.7, 1.5))


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
	if not player.has_item("gate_key"):
		if not get_tree().get_nodes_in_group("pickup_gate_key").is_empty():
			return "The gate key was dropped — look for its golden glow."
		var holder = null
		for p in GameState.people:
			if p.keyholder and not p.dead and not p.fog_affected:
				holder = p
		if holder:
			if holder.state == PERSON.SAFE or holder.state == PERSON.RETREAT:
				return "Get the gate key from %s — the maintenance crew fled to their shed (north-east)." % holder.staff_name
			return "Find the maintenance worker with the gate key (look for the gold keyring)."
		return "Find the gate key."
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
