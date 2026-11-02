extends Node3D
## Last Light Shrine — assembles the environment from Blender-built GLBs, layout data,
## procedural textures and custom shaders, then lights it for late golden hour.
## Photo mode: keys 1-7 jump to curated viewpoints, P saves a screenshot to user://.

const T := "res://showcase/textures/"
const M := "res://showcase/models/"
const SH := "res://showcase/shaders/"
const PLAYER := preload("res://showcase/player.gd")

# toward the sun: low in the south-west, raking golden light across the stair and hall facade
const SUN_DIR := Vector3(-0.60, 0.30, 0.74)

var VIEWS := [
	[Vector3(0.6, 1.75, 36.0), Vector3(0.0, 7.5, -20.0)],          # 1 arrival: bridge, path, torii stair
	[Vector3(19.0, 9.5, 14.0), Vector3(-3.0, 5.0, -22.0)],          # 2 wide: garden and hillside
	[Vector3(-0.9, 1.45, -0.6), Vector3(-2.75, 1.55, -2.5)],        # 3 close: stone lantern
	[Vector3(0.0, 5.75, -17.6), Vector3(0.0, 9.6, -29.0)],          # 4 senbon torii tunnel
	[Vector3(0.0, 13.65, -43.5), Vector3(0.0, 16.2, -64.0)],         # 5 courtyard and hall
	[Vector3(-16.0, 13.65, -47.0), Vector3(-118.0, 14.0, 6.0)],      # 6 overlook: pagoda across the valley
	[Vector3(0.6, 13.75, -40.5), Vector3(0.0, 3.0, 12.0)],          # 7 looking back down
]

var L: Dictionary
var mats := {}
var tex_cache := {}
var sun: DirectionalLight3D
var env: Environment
var player: CharacterBody3D


func _off(f: String) -> bool:
	return has_meta("profile_off") and f in get_meta("profile_off")


func _ready() -> void:
	L = JSON.parse_string(FileAccess.get_file_as_string("res://showcase/data/layout.json"))
	_environment()
	if _off("sdfgi"):
		env.sdfgi_enabled = false
	if _off("vfog"):
		env.volumetric_fog_enabled = false
	if _off("shadow"):
		sun.shadow_enabled = false
	_materials()
	_static_world()
	_props()
	if not _off("trees"):
		_trees()
	if not _off("grass"):
		_grass()
	_water()
	_courtyard()
	_fallen_petals()
	_atmosphere()
	_spawn_player()


# ------------------------------------------------------------------ helpers
func tex(name: String) -> Texture2D:
	if not tex_cache.has(name):
		tex_cache[name] = load(T + name + ".png")
	return tex_cache[name]


func shader_mat(shader: String, params: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(SH + shader + ".gdshader")
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m


func std(albedo: String, normal: String = "", rough: String = "", scale: float = 1.0, triplanar: bool = true, tint := Color.WHITE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex(albedo)
	m.albedo_color = tint
	if normal != "":
		m.normal_enabled = true
		m.normal_texture = tex(normal)
	if rough != "":
		m.roughness_texture = tex(rough)
		m.roughness = 1.0
	m.uv1_triplanar = triplanar
	m.uv1_scale = Vector3.ONE * scale
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


func apply_materials(root: Node) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = mi.mesh
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			var m := mesh.surface_get_material(i)
			var key := m.resource_name if m else ""
			if mats.has(key):
				mi.set_surface_override_material(i, mats[key])


func place(scene: PackedScene, pos: Vector3, rot_y: float = 0.0, s: float = 1.0) -> Node3D:
	var n: Node3D = scene.instantiate()
	add_child(n)
	n.position = pos
	n.rotation.y = rot_y
	n.scale = Vector3.ONE * s
	apply_materials(n)
	return n


func V(d: Dictionary) -> Vector3:
	return Vector3(d.x, d.y, d.z)


# ------------------------------------------------------------------ look & light
func _environment() -> void:
	env = Environment.new()
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	sm.shader = load(SH + "sky.gdshader")
	sky.sky_material = sm
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.45
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	env.ssr_enabled = true
	env.ssr_max_steps = 96
	env.ssr_fade_in = 0.1
	env.ssr_fade_out = 2.0
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6
	env.ssao_power = 1.4
	env.ssao_light_affect = 0.15
	env.sdfgi_enabled = true
	env.sdfgi_use_occlusion = true
	env.sdfgi_cascades = 4
	env.sdfgi_min_cell_size = 0.25
	env.sdfgi_energy = 1.0
	env.sdfgi_bounce_feedback = 0.45
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_strength = 1.0
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.4
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.fog_enabled = true
	env.fog_light_color = Color(0.82, 0.62, 0.58)
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.12
	env.fog_density = 0.0015
	env.fog_aerial_perspective = 0.4
	env.fog_sky_affect = 0.0
	env.fog_height = -6.0
	env.fog_height_density = 0.08
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.0035
	env.volumetric_fog_albedo = Color(0.95, 0.85, 0.8)
	env.volumetric_fog_anisotropy = 0.55
	env.volumetric_fog_length = 90.0
	env.volumetric_fog_detail_spread = 1.5
	env.volumetric_fog_gi_inject = 0.6
	env.volumetric_fog_ambient_inject = 0.15
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.06
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	add_child(sun)
	sun.look_at_from_position(Vector3.ZERO, -SUN_DIR.normalized(), Vector3.UP)
	sun.light_color = Color(1.0, 0.8, 0.62)
	sun.light_energy = 3.0
	sun.light_angular_distance = 1.2
	sun.shadow_enabled = true
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.shadow_blur = 1.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 100.0
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_split_1 = 0.06
	sun.directional_shadow_split_2 = 0.16
	sun.directional_shadow_split_3 = 0.4
	sun.light_volumetric_fog_energy = 1.6


func _materials() -> void:
	var lq := {"albedo_tex": tex("lacquer_albedo"), "normal_tex": tex("lacquer_normal"), "rough_tex": tex("lacquer_rough")}
	mats["lacquer"] = shader_mat("lacquer", lq.merged({"tint": Color(0.86, 0.8, 0.78), "rough_bias": 0.12}))
	mats["black_lacquer"] = shader_mat("lacquer", lq.merged({"use_texture": 0.0, "tint": Color(0.045, 0.04, 0.038), "rough_bias": 0.0, "variation": 0.05}))
	mats["wood"] = std("wood_albedo", "wood_normal", "wood_rough", 0.55)
	mats["dark_wood"] = std("wood_albedo", "wood_normal", "wood_rough", 0.55, true, Color(0.42, 0.34, 0.3))
	mats["plaster"] = std("plaster_albedo", "plaster_normal", "", 0.4)
	var shoji := std("shoji_albedo", "", "", 1.0, false)
	shoji.emission_enabled = true
	shoji.emission_texture = tex("shoji_mask")
	shoji.emission = Color(1.0, 0.68, 0.38)
	shoji.emission_energy_multiplier = 1.4
	shoji.roughness = 0.9
	mats["shoji"] = shoji
	mats["roof"] = std("roof_albedo", "roof_normal", "roof_rough", 1.0, false)
	(mats["roof"] as StandardMaterial3D).normal_scale = 1.2
	var ridge := std("roof_albedo", "roof_normal", "", 0.6, true, Color(0.8, 0.82, 0.86))
	mats["ridge"] = ridge
	mats["bark"] = std("bark_albedo", "bark_normal", "", 0.7)
	(mats["bark"] as StandardMaterial3D).roughness = 0.95
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(1.0, 0.74, 0.36)
	gold.metallic = 1.0
	gold.roughness = 0.32
	mats["gold"] = gold
	var bronze := std("granite_albedo", "granite_normal", "", 1.4, true, Color(0.42, 0.58, 0.5))
	bronze.metallic = 0.55
	bronze.roughness = 0.5
	mats["bronze"] = bronze
	var rope := std("bark_albedo", "bark_normal", "", 2.5, true, Color(2.6, 2.3, 1.55))
	rope.roughness = 0.95
	mats["rope"] = rope
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color(0.96, 0.95, 0.92)
	paper.cull_mode = BaseMaterial3D.CULL_DISABLED
	paper.roughness = 0.9
	paper.backlight_enabled = true
	paper.backlight = Color(0.6, 0.55, 0.5)
	mats["paper"] = paper
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.85, 0.6)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.62, 0.3)
	glow.emission_energy_multiplier = 5.0
	mats["lantern_glow"] = glow
	var stone_params := {"albedo_tex": tex("granite_albedo"), "normal_tex": tex("granite_normal"), "rough_tex": tex("granite_rough"), "moss_tex": tex("moss_albedo"), "scale": 0.55, "moss_amount": 0.55}
	mats["granite"] = shader_mat("stone", stone_params)
	mats["boulder"] = shader_mat("stone", stone_params.merged({"tint": Color(0.68, 0.66, 0.64), "moss_amount": 0.9, "scale": 0.35}, true))
	mats["stair"] = shader_mat("stone", stone_params.merged({"moss_amount": 0.85, "cell": 0.42}, true))
	var masonry := stone_params.duplicate()
	masonry.merge({"albedo_tex": tex("masonry_albedo"), "normal_tex": tex("masonry_normal"), "rough_tex": tex("masonry_rough"), "scale": 0.42, "moss_amount": 0.45}, true)
	mats["masonry"] = shader_mat("stone", masonry)
	var flag := stone_params.duplicate()
	flag.merge({"albedo_tex": tex("flagstone_albedo"), "normal_tex": tex("flagstone_normal"), "rough_tex": tex("flagstone_rough"), "scale": 0.3, "moss_amount": 0.3}, true)
	mats["flagstone"] = shader_mat("stone", flag)
	mats["terrain"] = shader_mat("terrain", {
		"grass_a": tex("grass_albedo"), "grass_n": tex("grass_normal"), "moss_a": tex("moss_albedo"), "moss_n": tex("moss_normal"),
		"dirt_a": tex("dirt_albedo"), "dirt_n": tex("dirt_normal"), "cliff_a": tex("cliff_albedo"), "cliff_n": tex("cliff_normal")})
	mats["mountain"] = shader_mat("mountains", {"sun_dir": SUN_DIR, "near_col": Color(0.25, 0.28, 0.38), "far_col": Color(0.6, 0.6, 0.74), "sun_side": Color(0.95, 0.72, 0.56)})
	mats["farland"] = shader_mat("farland", {"sun_dir": SUN_DIR})
	mats["blossom"] = shader_mat("foliage", {"albedo_tex": tex("blossom_card"), "tint": Color(1.05, 1.0, 1.02), "backlight_col": Color(0.85, 0.6, 0.66), "translucency": 0.65, "wind": 0.1, "ao_strength": 0.55})
	mats["needles"] = shader_mat("foliage", {"albedo_tex": tex("needle_card"), "tint": Color(0.85, 0.95, 0.8), "backlight_col": Color(0.55, 0.75, 0.3), "translucency": 0.45, "wind": 0.05, "roughness": 0.85})
	mats["maple"] = shader_mat("foliage", {"albedo_tex": tex("leaf_card"), "tint": Color(2.1, 0.72, 0.36), "backlight_col": Color(0.8, 0.3, 0.12), "translucency": 0.6, "wind": 0.12})
	mats["leaves"] = shader_mat("foliage", {"albedo_tex": tex("leaf_card"), "tint": Color(0.85, 0.95, 0.75), "backlight_col": Color(0.6, 0.8, 0.3), "translucency": 0.55, "wind": 0.06})


# ------------------------------------------------------------------ world
func _static_world() -> void:
	for name in ["terrain", "stairs", "bounds", "balustrade"]:
		var n: Node3D = load(M + name + ".glb").instantiate()
		add_child(n)
		apply_materials(n)
		if name == "stairs":
			for mi in n.find_children("*", "MeshInstance3D", true, false):
				for i in mi.mesh.get_surface_count():
					if mi.get_surface_override_material(i) == mats["granite"]:
						mi.set_surface_override_material(i, mats["stair"])
	for mi in find_children("*", "MeshInstance3D", true, false):
		if mi.name.begins_with("mountains"):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		elif mi.name.begins_with("far_terrain"):
			mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
			mi.set_surface_override_material(0, mats["farland"])
	place(load(M + "hall.glb"), V(L.hall), 0.0, L.hall.s)
	place(load(M + "bridge.glb"), Vector3(L.bridge.x, 0.0, L.bridge.z))
	place(load(M + "bell_pavilion.glb"), V(L.bell), -0.35)
	place(load(M + "azumaya.glb"), V(L.pavilion), 0.25)
	place(load(M + "pagoda.glb"), V(L.pagoda), 0.4)
	# warm interior light behind the hall's shoji screens
	var inner := OmniLight3D.new()
	inner.position = V(L.hall) + Vector3(0, 3.0, 3.0) * L.hall.s
	inner.light_color = Color(1.0, 0.62, 0.32)
	inner.light_energy = 2.0
	inner.omni_range = 7.0
	add_child(inner)
	for sx in [-1.0, 1.0]:
		var hl := OmniLight3D.new()
		hl.position = V(L.hall) + Vector3(sx * 5.4, 5.3, 6.0) * L.hall.s
		hl.light_color = Color(1.0, 0.6, 0.3)
		hl.light_energy = 1.2
		hl.omni_range = 5.0
		add_child(hl)


func _props() -> void:
	var torii: PackedScene = load(M + "torii.glb")
	var torii_s: PackedScene = load(M + "torii_small.glb")
	for t in L.torii:
		place(torii, V(t), 0.0, t.s)
	for t in L.senbon:
		place(torii_s, V(t), 0.0, 1.0)
	var lantern: PackedScene = load(M + "lantern.glb")
	for l in L.lanterns:
		var n := place(lantern, V(l), l.rot)
		if l.lit:
			var o := OmniLight3D.new()
			o.position = Vector3(0, 1.72, 0)
			o.light_color = Color(1.0, 0.6, 0.28)
			o.light_energy = 1.6
			o.omni_range = 6.0
			o.omni_attenuation = 1.4
			n.add_child(o)
		else:
			for mi in n.find_children("*", "MeshInstance3D", true, false):
				for i in mi.mesh.get_surface_count():
					if mi.get_surface_override_material(i) == mats["lantern_glow"]:
						mi.set_surface_override_material(i, mats["paper"])
	# rocks: six sculpted variants
	var rocks: Node3D = load(M + "rocks.glb").instantiate()
	var variants := rocks.find_children("rock*", "MeshInstance3D", true, false)
	variants.sort_custom(func(a, b): return a.name < b.name)
	for r in L.rocks:
		var src: MeshInstance3D = variants[int(r.v) % variants.size()]
		var mi := MeshInstance3D.new()
		mi.mesh = src.mesh
		mi.set_surface_override_material(0, mats["boulder"])
		add_child(mi)
		mi.position = V(r) - Vector3(0, r.sink * r.s, 0)
		mi.rotation.y = r.rot
		mi.scale = Vector3.ONE * r.s
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := SphereShape3D.new()
		sh.radius = 0.9
		cs.shape = sh
		body.add_child(cs)
		mi.add_child(body)
	rocks.free()


func _tree_lib() -> Dictionary:
	var lib := {}
	var n: Node3D = load(M + "trees.glb").instantiate()
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		lib[str(mi.name)] = mi.mesh
	n.free()
	return lib


func _tree(lib: Dictionary, kind: String, leaf_mat: String, pos: Vector3, rot: float, s: float, trunk_r: float) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	root.position = pos
	root.rotation.y = rot
	root.scale = Vector3.ONE * s
	var t := MeshInstance3D.new()
	t.mesh = lib[kind + "_trunk"]
	t.material_override = mats["bark"]
	root.add_child(t)
	var l := MeshInstance3D.new()
	l.mesh = lib[kind + "_leaves"]
	l.material_override = mats[leaf_mat]
	root.add_child(l)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = trunk_r
	cyl.height = 4.0
	cs.shape = cyl
	cs.position.y = 2.0
	body.add_child(cs)
	root.add_child(body)
	return root


func _trees() -> void:
	var lib := _tree_lib()
	var i := 0
	for t in L.sakura:
		var tr := _tree(lib, "sakura%d" % (i % 2), "blossom", V(t), t.rot, t.s, 0.35)
		_petals(tr)
		i += 1
	for t in L.maple:
		_tree(lib, "maple0", "maple", V(t), t.rot, t.s, 0.25)
	var st: Dictionary = L.sacred_tree
	var sacred := _tree(lib, "sacred", "leaves", V(st), st.rot, st.s, 1.2)
	var rope := MeshInstance3D.new()
	rope.mesh = lib["sacred_rope"]
	rope.material_override = mats["rope"]
	sacred.add_child(rope)
	# cedars: three MultiMesh variants (trunk + needles), cheap even in large numbers
	var groups := [[], [], []]
	for c in L.cedars:
		groups[int(abs(c.x * 7.0 + c.z * 3.0)) % 3].append(c)
	for c in L.vista_cedars:
		c["vista"] = true
		groups[int(abs(c.x * 7.0 + c.z * 3.0)) % 3].append(c)
	var body := StaticBody3D.new()
	add_child(body)
	for v in 3:
		for part in ["_trunk", "_leaves"]:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = lib["cedar%d%s" % [v, part]]
			mm.instance_count = groups[v].size()
			for k in groups[v].size():
				var c: Dictionary = groups[v][k]
				var b := Basis(Vector3.UP, c.rot).scaled(Vector3.ONE * c.s)
				mm.set_instance_transform(k, Transform3D(b, V(c) - Vector3(0, 0.2, 0)))
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.material_override = mats["bark"] if part == "_trunk" else mats["needles"]
			add_child(mmi)
		for c in groups[v]:
			if c.get("vista", false):
				continue
			var cs := CollisionShape3D.new()
			var cy := CylinderShape3D.new()
			cy.radius = 0.6 * c.s
			cy.height = 6.0
			cs.shape = cy
			cs.position = V(c) + Vector3(0, 3, 0)
			body.add_child(cs)


func _grass() -> void:
	var raw := FileAccess.get_file_as_bytes("res://showcase/data/grass.bin").to_float32_array()
	var mesh := _grass_clump()
	var mat := shader_mat("grass", {})
	var cell := 14.0
	var buckets := {}
	for i in range(0, raw.size(), 6):
		var key := Vector2i(floori(raw[i] / cell), floori(raw[i + 2] / cell))
		if not buckets.has(key):
			buckets[key] = PackedInt32Array()
		buckets[key].append(i)
	for key in buckets:
		var idx: PackedInt32Array = buckets[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = mesh
		mm.instance_count = idx.size()
		for k in idx.size():
			var i: int = idx[k]
			var b := Basis(Vector3.UP, raw[i + 3]).scaled(Vector3.ONE * raw[i + 4])
			mm.set_instance_transform(k, Transform3D(b, Vector3(raw[i], raw[i + 1] - 0.03, raw[i + 2])))
			mm.set_instance_custom_data(k, Color(raw[i + 5], 0, 0, 0))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		mmi.visibility_range_end = 70.0
		mmi.visibility_range_end_margin = 10.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		add_child(mmi)


func _grass_clump() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for b in 6:
		var a := rng.randf() * TAU
		var root := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.0, 0.12)
		var h := rng.randf_range(0.18, 0.4)
		var w := rng.randf_range(0.028, 0.045)
		var lean := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.08, 0.25)
		var side := Vector3(-sin(a + 1.3), 0, cos(a + 1.3))
		var segs := 3
		var prev_l := Vector3.ZERO
		var prev_r := Vector3.ZERO
		for sgi in segs + 1:
			var u := float(sgi) / segs
			var c := root + Vector3(0, h * u, 0) + lean * u * u
			var ww := w * (1.0 - u * 0.92)
			var pl := c - side * ww
			var pr := c + side * ww
			if sgi > 0:
				var n := (pr - prev_l).cross(prev_r - prev_l).normalized()
				var u0 := float(sgi - 1) / segs
				for v in [[prev_l, u0], [prev_r, u0], [pr, u], [prev_l, u0], [pr, u], [pl, u]]:
					st.set_normal(n)
					st.set_uv(Vector2(0.5, v[1]))
					st.add_vertex(v[0])
			prev_l = pl
			prev_r = pr
	return st.commit()


func _water() -> void:
	var p: Dictionary = L.pond
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(p.rx * 2.4, p.rz * 2.4)
	pm.subdivide_width = 8
	pm.subdivide_depth = 8
	mi.mesh = pm
	mi.material_override = shader_mat("water", {"normal_tex": tex("water_normal")})
	mi.position = Vector3(p.x, p.water_y, p.z)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	# lily pads and a few floating blossoms
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var pad_mat := StandardMaterial3D.new()
	pad_mat.albedo_color = Color(0.16, 0.3, 0.1)
	pad_mat.roughness = 0.45
	var flower_mat := StandardMaterial3D.new()
	flower_mat.albedo_color = Color(1.0, 0.8, 0.86)
	flower_mat.emission_enabled = true
	flower_mat.emission = Color(0.4, 0.2, 0.25)
	for k in 26:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 0.85
		var pos := Vector3(p.x + cos(a) * p.rx * r, p.water_y + 0.01, p.z + sin(a) * p.rz * r)
		if absf(pos.x) < 2.0:
			continue
		var pad := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		var rad := rng.randf_range(0.18, 0.38)
		cm.top_radius = rad
		cm.bottom_radius = rad
		cm.height = 0.015
		cm.radial_segments = 16
		pad.mesh = cm
		pad.material_override = pad_mat
		pad.position = pos
		pad.rotation.y = rng.randf() * TAU
		add_child(pad)
		if rng.randf() < 0.3:
			var fl := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.09
			sm.height = 0.1
			fl.mesh = sm
			fl.material_override = flower_mat
			fl.position = pos + Vector3(0.05, 0.04, 0)
			add_child(fl)


func _courtyard() -> void:
	var pl: Array = L.plateau
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(pl[1] - pl[0] - 1.0, pl[3] - pl[2] - 1.0)
	mi.mesh = pm
	var centers := [
		Vector4(L.sacred_tree.x, 0, L.sacred_tree.z, 2.6), Vector4(-15, 0, -56, 2.2), Vector4(-12, 0, -58, 1.4),
		Vector4(-17.5, 0, -52, 1.6), Vector4(17, 0, -68, 2.0), Vector4(L.bell.x, 0, L.bell.z, 3.0)]
	mi.material_override = shader_mat("gravel", {"albedo_tex": tex("gravel_albedo"), "normal_tex": tex("gravel_normal"), "centers": centers})
	mi.position = Vector3((pl[0] + pl[1]) / 2.0, 12.02, (pl[2] + pl[3]) / 2.0)
	add_child(mi)


func _fallen_petals() -> void:
	var raw := FileAccess.get_file_as_bytes("res://showcase/data/petals.bin").to_float32_array()
	var q := QuadMesh.new()
	q.size = Vector2(0.06, 0.045)
	q.orientation = PlaneMesh.FACE_Y
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex("petal")
	m.albedo_color = Color(1.0, 0.86, 0.9)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.6
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = q
	mm.instance_count = raw.size() / 5
	for k in mm.instance_count:
		var i := k * 5
		var b := Basis(Vector3.UP, raw[i + 3]).rotated(Vector3(1, 0, 0), raw[i + 4] * 0.4).scaled(Vector3.ONE * (0.8 + raw[i + 4] * 0.5))
		mm.set_instance_transform(k, Transform3D(b, Vector3(raw[i], raw[i + 1], raw[i + 2])))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = m
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = 40.0
	add_child(mmi)


# ------------------------------------------------------------------ life & air
func _petals(tree: Node3D) -> void:
	var p := GPUParticles3D.new()
	p.amount = 24
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.visibility_aabb = AABB(Vector3(-8, -8, -8), Vector3(16, 16, 16))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 3.0
	pm.gravity = Vector3(0.25, -0.35, 0.1)
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.3
	pm.angular_velocity_min = -180
	pm.angular_velocity_max = 180
	pm.angle_max = 360
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.2
	pm.turbulence_noise_scale = 3.0
	pm.scale_min = 0.6
	pm.scale_max = 1.1
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.05, 0.04)
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex("petal")
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.backlight_enabled = true
	m.backlight = Color(1.0, 0.7, 0.75)
	q.material = m
	p.draw_pass_1 = q
	p.position = Vector3(0, 4.0, 0)
	tree.add_child(p)


func _motes(center: Vector3, extents: Vector3, amount: int, col: Color, size: float, energy: float, gravity: float) -> void:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = 12.0
	p.preprocess = 12.0
	p.position = center
	p.visibility_aabb = AABB(-extents * 1.5, extents * 3.0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = extents
	pm.gravity = Vector3(0, gravity, 0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	pm.turbulence_noise_speed_random = 0.5
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0))
	curve.add_point(Vector2(0.2, 1))
	curve.add_point(Vector2(0.8, 1))
	curve.add_point(Vector2(1, 0))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.scale_curve = ct
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	var g := GradientTexture2D.new()
	var gr := Gradient.new()
	gr.set_color(0, Color(1, 1, 1, 1))
	gr.set_color(1, Color(1, 1, 1, 0))
	g.gradient = gr
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.5)
	g.fill_to = Vector2(0.5, 0.0)
	m.albedo_texture = g
	q.material = m
	p.draw_pass_1 = q
	add_child(p)


func _atmosphere() -> void:
	# sunlit pollen drifting through the stair and courtyard
	_motes(Vector3(0, 8, -24), Vector3(10, 6, 22), 260, Color(1.0, 0.85, 0.6, 0.8), 0.035, 2.0, 0.01)
	_motes(Vector3(0, 14, -55), Vector3(16, 3, 14), 160, Color(1.0, 0.85, 0.6, 0.8), 0.035, 2.0, 0.01)
	# early fireflies over the pond
	_motes(Vector3(0, 0.8, 22), Vector3(12, 0.8, 7), 50, Color(0.75, 1.0, 0.45, 1.0), 0.05, 5.0, 0.0)
	# low mist pooled in the valley below the overlook
	var mist := FogVolume.new()
	mist.size = Vector3(160, 22, 160)
	mist.position = Vector3(-110, -24, -60)
	var fm := FogMaterial.new()
	fm.density = 0.018
	fm.albedo = Color(0.95, 0.8, 0.8)
	fm.height_falloff = 0.15
	fm.edge_fade = 0.4
	mist.material = fm
	add_child(mist)


func _spawn_player() -> void:
	player = PLAYER.new()
	add_child(player)
	go_view(0)


func go_view(i: int) -> void:
	var v: Array = VIEWS[i]
	player.set_view(v[0], v[1])


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_7:
			go_view(event.keycode - KEY_1)
		elif event.keycode == KEY_P or event.keycode == KEY_F12:
			var img := get_viewport().get_texture().get_image()
			var path := "user://shot_%d.png" % Time.get_ticks_msec()
			img.save_png(path)
			print("saved ", ProjectSettings.globalize_path(path))
