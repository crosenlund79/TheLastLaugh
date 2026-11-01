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
const GUARD_NAMES := ["Officer Briggs", "Officer Kim", "Officer Lutz"]
const CELL := 6.0  # ground corruption grid

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
var crowd: AudioStreamPlayer
var _corrupt_t := 0.0
var _stain_mat: ShaderMaterial
var _crystal_mat: StandardMaterial3D

const STAIN_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
varying vec3 wpos;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y); }
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float r = length(uv);
	float n = vn(wpos.xz * 0.9) * 0.6 + vn(wpos.xz * 3.0) * 0.4;
	float edge = 1.0 - smoothstep(0.55 + n * 0.3, 0.95, r);
	float veins = smoothstep(0.47, 0.5, n) * (1.0 - smoothstep(0.5, 0.54, n));
	float pulse = 0.6 + 0.4 * sin(TIME * 1.7 + wpos.x * 0.5);
	ALBEDO = mix(vec3(0.08, 0.0, 0.1), vec3(0.2, 0.01, 0.06), n) + veins * vec3(0.8, 0.2, 1.2) * pulse * 1.5;
	ALPHA = edge * (0.7 + veins * 0.3);
}
"""


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
	var sh := Shader.new()
	sh.code = STAIN_SHADER
	_stain_mat = ShaderMaterial.new()
	_stain_mat.shader = sh
	_crystal_mat = StandardMaterial3D.new()
	_crystal_mat.albedo_color = Color(0.25, 0.05, 0.35)
	_crystal_mat.roughness = 0.15
	_crystal_mat.emission_enabled = true
	_crystal_mat.emission = Color(0.6, 0.1, 0.9)
	_crystal_mat.emission_energy_multiplier = 1.4
	crowd = AudioStreamPlayer.new()
	crowd.stream = Sfx.sounds.get("crowd")
	crowd.bus = "SFX"
	crowd.volume_db = -14.0
	add_child(crowd)
	crowd.play()
	hud = HUD.new()
	add_child(hud)
	spawn_player(Vector3(0, 0.1, 37))
	GameState.thought.connect(hud.show_thought)
	GameState.radio.connect(_on_radio)
	Music.target_distortion = 0.0
	Music.target_volume = 1.0
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().create_timer(3.0).timeout.connect(func(): GameState.think("The gate slammed shut behind me... I need to find a way out.", "intro"))
	get_tree().create_timer(16.0).timeout.connect(func(): GameState.think("If the gate's locked, the maintenance crew must keep a key somewhere.", "key_hint"))


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
	spawn_pickup("gate_key", info.shed.gate_key)
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
	var civ_spots := [Vector3(-6, 0, 21), Vector3(-5, 0, 23), Vector3(6, 0, 23), Vector3(-14, 0, 29), Vector3(4, 0, -16),
		Vector3(3, 0, -17), Vector3(-14, 0, -6), Vector3(20, 0, 35), Vector3(-3, 0, 9), Vector3(-22, 0, 14)]
	for p in civ_spots:
		var c := PERSON.new()
		add_child(c)
		c.setup("civilian", "normal" if randf() < 0.7 else "belly", p)


func _spawn_staff() -> void:
	# modest randomization: duty areas and patrol routes are drawn from larger pools
	var duties: Array = info.worker_duty.duplicate()
	duties.shuffle()
	var wbodies := ["normal", "belly", "skinny"]
	wbodies.shuffle()
	for i in 3:
		var w := PERSON.new()
		add_child(w)
		var pts: Array = duties[i].pts.duplicate()
		pts.shuffle()
		w.setup("worker", wbodies[i], pts[0] + Vector3(1, 0, 1))
		w.setup_staff(WORKER_NAMES[i], i, pts, duties[i].area, false)
	var routes: Array = info.guard_routes.duplicate()
	routes.shuffle()
	var gbodies := ["belly", "normal", "skinny"]
	gbodies.shuffle()
	for i in 3:
		var g := PERSON.new()
		add_child(g)
		var route: Array = routes[i]
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
	_corrupt_t -= delta
	if _corrupt_t <= 0.0:
		_corrupt_t = 0.25
		_spread_corruption()
	var dist_factor := clampf(1.0 - nearest / 28.0, 0.0, 1.0)
	_update_dread(delta, dist_factor)
	Music.target_distortion = clampf(maxf(dist_factor, GameState.dread * 0.85), 0.0, 1.0)
	var st := GameState.get_stats()
	var lively := float(st.trapped) / maxf(1.0, float(st.total))
	crowd.volume_db = lerpf(crowd.volume_db, linear_to_db(maxf(0.001, lively * lively * 0.22 * (1.0 - GameState.dread))), delta)
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


## Fog permanently corrupts what it touches: attractions/props (corruptible.gd) and the
## ground itself (a coarse grid of stained, crystal-grown cells). Safe houses are exempt.
func _spread_corruption() -> void:
	for f in GameState.fog_banks:
		var fp: Vector3 = f.global_position
		for c in GameState.corruptibles:
			if not c.corrupted:
				var d := Vector2(c.global_position.x - fp.x, c.global_position.z - fp.z).length()
				if d < f.radius + c.radius * 0.6:
					c.corrupt()
		var ci := Vector2i(floori(fp.x / CELL), floori(fp.z / CELL))
		for dx in range(-2, 3):
			for dz in range(-2, 3):
				var cell := ci + Vector2i(dx, dz)
				if GameState.corrupted_cells.has(cell):
					continue
				var center := Vector3((cell.x + 0.5) * CELL, 0, (cell.y + 0.5) * CELL)
				if Vector2(center.x - fp.x, center.z - fp.z).length() > f.radius * 0.85:
					continue
				if absf(center.x) > 41.0 or absf(center.z) > 41.0 or _in_safehouse(center, 1.0):
					continue
				GameState.corrupted_cells[cell] = true
				_stain(center)


func _in_safehouse(p: Vector3, margin: float) -> bool:
	for prof in GameState.safehouses:
		var sh: Dictionary = GameState.safehouses[prof]
		var rel: Vector3 = p - sh.center
		if absf(rel.x) < sh.half.x + margin and absf(rel.z) < sh.half.z + margin:
			return true
	return false


func _stain(center: Vector3) -> void:
	var q := QuadMesh.new()
	q.size = Vector2(CELL * 1.5, CELL * 1.5)
	var m := MeshInstance3D.new()
	m.mesh = q
	m.material_override = _stain_mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	m.global_position = center + Vector3(randf_range(-1, 1), 0.03 + randf() * 0.02, randf_range(-1, 1))
	m.rotation = Vector3(-PI / 2, randf() * TAU, 0)
	# jagged violet crystals pushing up through the dirt (visual only, no collision)
	var pm := PrismMesh.new()
	pm.size = Vector3(0.25, 1.0, 0.25)
	for k in randi_range(1, 3):
		var cr := MeshInstance3D.new()
		cr.mesh = pm
		cr.material_override = _crystal_mat
		cr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(cr)
		var hgt := randf_range(0.3, 1.0)
		cr.scale = Vector3(1, hgt, 1)
		cr.global_position = center + Vector3(randf_range(-2.4, 2.4), hgt * 0.4, randf_range(-2.4, 2.4))
		cr.rotation = Vector3(randf_range(-0.4, 0.4), randf() * TAU, randf_range(-0.4, 0.4))
		cr.scale = Vector3.ZERO
		cr.create_tween().tween_property(cr, "scale", Vector3(1, hgt, 1), 2.0).set_trans(Tween.TRANS_ELASTIC)


## Presentation follows the player's SURROUNDINGS: standing on corrupted ground (or near
## fog) shifts light, sky, fog and post-processing; untouched streets stay cheerful.
func _update_dread(delta: float, fog_near: float) -> void:
	var local := 0.0
	if player:
		var pc := Vector2i(floori(player.global_position.x / CELL), floori(player.global_position.z / CELL))
		var hits := 0.0
		for dx in range(-2, 3):
			for dz in range(-2, 3):
				if GameState.corrupted_cells.has(pc + Vector2i(dx, dz)):
					hits += 1.0 if absi(dx) <= 1 and absi(dz) <= 1 else 0.5
		local = clampf(hits / 7.0, 0.0, 1.0)
	var target := clampf(maxf(local, fog_near * 0.6), 0.0, 1.0)
	GameState.dread = move_toward(GameState.dread, target, delta * 0.25)
	var d := GameState.dread
	env.ambient_light_color = Color(0.5, 0.4, 0.6).lerp(Color(0.3, 0.12, 0.38), d)
	env.ambient_light_energy = lerpf(0.6, 0.35, d)
	env.fog_light_color = Color(0.1, 0.06, 0.14).lerp(Color(0.2, 0.03, 0.22), d)
	env.fog_density = lerpf(0.006, 0.022, d)
	env.volumetric_fog_density = lerpf(0.003, 0.02, d)
	env.volumetric_fog_albedo = Color(0.7, 0.6, 0.85).lerp(Color(0.6, 0.25, 0.75), d)
	env.volumetric_fog_emission = Color(0.01, 0.006, 0.02).lerp(Color(0.06, 0.0, 0.07), d)
	env.adjustment_saturation = lerpf(1.15, 0.85, d)
	env.glow_intensity = lerpf(0.85, 1.25, d)
	sky_mat.sky_horizon_color = Color(0.55, 0.25, 0.38).lerp(Color(0.35, 0.03, 0.2), d)
	sky_mat.sky_top_color = Color(0.06, 0.05, 0.2).lerp(Color(0.03, 0.0, 0.06), d)
	moon.light_energy = lerpf(0.45, 0.22, d)
	moon.light_color = Color(0.6, 0.65, 1.0).lerp(Color(0.75, 0.4, 0.8), d)


## Softlock prevention: the shed (shotgun + gate key) and the gate key must stay reachable.
## Keys never depend on random loot: workers always drop their shed key when defeated.
func _ensure_progression() -> void:
	if player == null:
		return
	var flags := GameState.flags
	# 1) the gate key must exist (in the player's pocket, on the shed bench, or dropped)
	if not player.has_item("gate_key") and not flags.get("gate_open", false):
		if get_tree().get_nodes_in_group("pickup_gate_key").is_empty():
			spawn_pickup("gate_key", info.shed.gate_key)
	# 2) a dropped shed key lying inside a locked safe house nobody can open -> lock gives way
	for k in get_tree().get_nodes_in_group("pickup_shed_key"):
		for prof in GameState.safehouses:
			var sh: Dictionary = GameState.safehouses[prof]
			var rel: Vector3 = k.global_position - sh.center
			if absf(rel.x) < sh.half.x and absf(rel.z) < sh.half.z:
				var flag: String = sh.door.unlock_flag
				if not flags.get(flag, false) and sh.door._human_staff_inside().is_empty():
					flags[flag] = true
	# 3) no worker left who could ever open the shed or drop a key -> spare key at the door
	if not _shed_reachable() and get_tree().get_nodes_in_group("pickup_shed_key").is_empty():
		var any_worker := false
		for p in GameState.people:
			if p.role == "worker" and not p.dead and not p.rescued:
				any_worker = true
		if not any_worker:
			spawn_pickup("shed_key", info.shed.door_pos + Vector3(-1.0, 0.7, 1.5))


func _shed_reachable() -> bool:
	return GameState.flags.get("shed_unlocked", false) or player.has_item("shed_key") or not get_tree().get_nodes_in_group("pickup_shed_key").is_empty()


func _objective() -> String:
	if player == null:
		return ""
	var followers := 0
	var escorted_worker = null
	for p in GameState.people:
		if p.state == PERSON.FOLLOW:
			followers += 1
			if p.role == "worker":
				escorted_worker = p
	var esc := " (%d following you)" % followers if followers > 0 else ""
	if player.weapons.is_empty():
		return "Find a weapon — the shooting gallery should have something."
	if not player.has_item("gate_key"):
		if GameState.flags.get("shed_open", false):
			return "Grab the main gate key (and the shotgun) inside the maintenance shed."
		if player.has_item("shed_key"):
			return "Unlock the maintenance shed (north-east) with the worker's key."
		if escorted_worker:
			return "Escort %s to the maintenance shed (north-east) so he can unlock it." % escorted_worker.staff_name
		if not get_tree().get_nodes_in_group("pickup_shed_key").is_empty():
			return "A maintenance worker's key is lying out there — find it."
		if GameState.flags.get("workers_sheltering", false):
			return "The maintenance crew is holed up in their shed (north-east). Knock."
		return "Get into the maintenance shed (north-east). Any maintenance worker has a key."
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
