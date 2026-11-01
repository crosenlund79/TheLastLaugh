class_name Build
extends RefCounted
## Helpers for assembling stylized low-poly geometry in code, plus procedural textures.

static var _mats := {}
static var _tex := {}


# ------------------------------------------------------------------ textures
## Subtle grey detail noise multiplied onto every opaque material (breaks up flat colour).
static func detail_tex() -> Texture2D:
	if _tex.has("detail"):
		return _tex["detail"]
	var nt := NoiseTexture2D.new()
	nt.width = 256
	nt.height = 256
	nt.seamless = true
	var n := FastNoiseLite.new()
	n.frequency = 0.03
	n.fractal_octaves = 4
	nt.noise = n
	var g := Gradient.new()
	g.set_color(0, Color(0.72, 0.72, 0.72))
	g.set_color(1, Color(1, 1, 1))
	nt.color_ramp = g
	_tex["detail"] = nt
	return nt


static func detail_normal() -> Texture2D:
	if _tex.has("detail_n"):
		return _tex["detail_n"]
	var nt := NoiseTexture2D.new()
	nt.width = 256
	nt.height = 256
	nt.seamless = true
	nt.as_normal_map = true
	nt.bump_strength = 3.0
	var n := FastNoiseLite.new()
	n.frequency = 0.05
	nt.noise = n
	_tex["detail_n"] = nt
	return nt


static func noise_tex(key: String, c0: Color, c1: Color, freq: float, w: int = 256, h: int = 256) -> Texture2D:
	if _tex.has(key):
		return _tex[key]
	var nt := NoiseTexture2D.new()
	nt.width = w
	nt.height = h
	nt.seamless = true
	var n := FastNoiseLite.new()
	n.frequency = freq
	n.fractal_octaves = 5
	nt.noise = n
	var g := Gradient.new()
	g.set_color(0, c0)
	g.set_color(1, c1)
	nt.color_ramp = g
	_tex[key] = nt
	return nt


## Vertical stripes (wraps nicely around cylinders/cones for tents and awnings).
static func stripe_tex(a: Color, b: Color, count: int = 8) -> Texture2D:
	var key := "stripe_%s_%s_%d" % [a.to_html(), b.to_html(), count]
	if _tex.has(key):
		return _tex[key]
	var img := Image.create(count * 8, 8, false, Image.FORMAT_RGB8)
	for x in count * 8:
		var c := a if (x / 8) % 2 == 0 else b
		for y in 8:
			img.set_pixel(x, y, c)
	var t := ImageTexture.create_from_image(img)
	_tex[key] = t
	return t


## Costume patterns: 0 stripes, 1 polka dots, 2 checker, 3 diamonds, 4 plain.
static func pattern_tex(base: Color, accent: Color, kind: int) -> Texture2D:
	var key := "pat_%s_%s_%d" % [base.to_html(), accent.to_html(), kind]
	if _tex.has(key):
		return _tex[key]
	var s := 32
	var img := Image.create(s, s, false, Image.FORMAT_RGB8)
	for x in s:
		for y in s:
			var on := false
			match kind:
				0: on = (x / 4) % 2 == 0
				1: on = Vector2(x % 16 - 8, y % 16 - 8).length() < 4.0
				2: on = ((x / 8) + (y / 8)) % 2 == 0
				3: on = absf(x % 16 - 8) + absf(y % 16 - 8) < 6
			img.set_pixel(x, y, accent if on else base)
	var t := ImageTexture.create_from_image(img)
	_tex[key] = t
	return t


static func brick_tex(key: String, brick: Color, mortar: Color) -> Texture2D:
	if _tex.has(key):
		return _tex[key]
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		for x in 64:
			var row := y / 8
			var off := 8 if row % 2 == 1 else 0
			var m := y % 8 == 0 or (x + off) % 16 == 0
			var v := 0.85 + 0.15 * sin(float(x * 7 + y * 13 + row * 31))
			img.set_pixel(x, y, mortar if m else brick * v)
	var t := ImageTexture.create_from_image(img)
	_tex[key] = t
	return t


# ------------------------------------------------------------------ materials
static func mat(color: Color, emission: float = 0.0, unshaded: bool = false) -> StandardMaterial3D:
	var key := "%s_%s_%s" % [color.to_html(), emission, unshaded]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.8
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	elif emission == 0.0 and not unshaded:
		m.albedo_texture = detail_tex()
		m.normal_enabled = true
		m.normal_texture = detail_normal()
		m.normal_scale = 0.35
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(0.6, 0.6, 0.6)
	_mats[key] = m
	return m


static func tex_mat(key: String, tex: Texture2D, tint: Color = Color.WHITE, scale: float = 1.0, triplanar: bool = true, rough: float = 0.85) -> StandardMaterial3D:
	var k := "tex_" + key
	if _mats.has(k):
		return _mats[k]
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.albedo_color = tint
	m.roughness = rough
	m.uv1_triplanar = triplanar
	m.uv1_scale = Vector3(scale, scale, scale)
	m.normal_enabled = true
	m.normal_texture = detail_normal()
	m.normal_scale = 0.5
	_mats[k] = m
	return m


static func stripe_mat(a: Color, b: Color, count: int = 8, emission: float = 0.0) -> StandardMaterial3D:
	var k := "stripes_%s_%s_%d_%s" % [a.to_html(), b.to_html(), count, emission]
	if _mats.has(k):
		return _mats[k]
	var m := StandardMaterial3D.new()
	m.albedo_texture = stripe_tex(a, b, count)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	m.roughness = 0.7
	if emission > 0.0:
		m.emission_enabled = true
		m.emission_texture = m.albedo_texture
		m.emission_energy_multiplier = emission
	_mats[k] = m
	return m


static func unique_mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.55
	m.rim_enabled = true
	m.rim = 0.35
	m.rim_tint = 0.6
	return m


# ------------------------------------------------------------------ geometry
static func mesh(parent: Node, m: Mesh, pos: Vector3, material: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = material
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func _body(parent: Node, pos: Vector3, rot: Vector3, shape: Shape3D) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation = rot
	parent.add_child(body)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	return body


static func box(parent: Node, size: Vector3, pos: Vector3, color: Color, collide: bool = true, emission: float = 0.0, rot: Vector3 = Vector3.ZERO) -> Node3D:
	return boxm(parent, size, pos, mat(color, emission), collide, rot)


static func boxm(parent: Node, size: Vector3, pos: Vector3, material: Material, collide: bool = true, rot: Vector3 = Vector3.ZERO) -> Node3D:
	var bm := BoxMesh.new()
	bm.size = size
	if collide:
		var sh := BoxShape3D.new()
		sh.size = size
		var body := _body(parent, pos, rot, sh)
		mesh(body, bm, Vector3.ZERO, material)
		return body
	return mesh(parent, bm, pos, material, rot)


static func cyl(parent: Node, r_top: float, r_bot: float, h: float, pos: Vector3, color: Color, collide: bool = false, segs: int = 8, emission: float = 0.0, rot: Vector3 = Vector3.ZERO) -> Node3D:
	return cylm(parent, r_top, r_bot, h, pos, mat(color, emission), collide, segs, rot)


static func cylm(parent: Node, r_top: float, r_bot: float, h: float, pos: Vector3, material: Material, collide: bool = false, segs: int = 8, rot: Vector3 = Vector3.ZERO) -> Node3D:
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = h
	cm.radial_segments = segs
	cm.rings = 1
	if collide:
		var sh := CylinderShape3D.new()
		sh.radius = maxf(r_top, r_bot)
		sh.height = h
		var body := _body(parent, pos, rot, sh)
		mesh(body, cm, Vector3.ZERO, material)
		return body
	return mesh(parent, cm, pos, material, rot)


static func sphere(parent: Node, r: float, pos: Vector3, material: Material, segs: int = 8) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = segs
	sm.rings = maxi(3, segs / 2)
	return mesh(parent, sm, pos, material)


static func torus(parent: Node, inner: float, outer: float, pos: Vector3, material: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var tm := TorusMesh.new()
	tm.inner_radius = inner
	tm.outer_radius = outer
	tm.rings = 10
	tm.ring_segments = 5
	return mesh(parent, tm, pos, material, rot)


static func label(parent: Node, text: String, pos: Vector3, color: Color, size: int = 96, rot_y: float = 0.0, billboard: bool = false) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.01
	l.modulate = color
	l.outline_size = 12
	l.outline_modulate = Color(0, 0, 0, 0.8)
	l.position = pos
	l.rotation.y = rot_y
	l.shaded = false
	if billboard:
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(l)
	return l


static func omni(parent: Node, pos: Vector3, color: Color, energy: float = 2.0, rng: float = 10.0) -> OmniLight3D:
	var o := OmniLight3D.new()
	o.position = pos
	o.light_color = color
	o.light_energy = energy
	o.omni_range = rng
	o.omni_attenuation = 1.2
	parent.add_child(o)
	return o


## Many small identical meshes in one draw call per colour (bulbs, flags, popcorn...).
static func multi(parent: Node, m: Mesh, xforms: Array, material: Material) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = m
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = material
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)
	return mmi


## Light bulbs at the given points, cycling through colours.
static func bulbs(parent: Node, points: Array, colors: Array, r: float = 0.07, energy: float = 5.0) -> void:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 6
	sm.rings = 3
	var groups := []
	for c in colors:
		groups.append([])
	for i in points.size():
		groups[i % colors.size()].append(Transform3D(Basis(), points[i]))
	for k in colors.size():
		if not groups[k].is_empty():
			var mmi := multi(parent, sm, groups[k], mat(colors[k], energy))
			mmi.add_to_group("bulbs")


## Rectangle of marquee bulbs around a sign (local XY plane at z).
static func marquee(parent: Node, center: Vector3, w: float, h: float, spacing: float = 0.28, colors: Array = [Color(1, 0.85, 0.4), Color(1, 0.3, 0.3)]) -> void:
	var pts := []
	var nx := int(w / spacing)
	var ny := int(h / spacing)
	for i in nx + 1:
		var x := -w / 2 + i * spacing
		pts.append(center + Vector3(x, h / 2, 0))
		pts.append(center + Vector3(x, -h / 2, 0))
	for j in range(1, ny):
		var y := -h / 2 + j * spacing
		pts.append(center + Vector3(-w / 2, y, 0))
		pts.append(center + Vector3(w / 2, y, 0))
	bulbs(parent, pts, colors, 0.06, 4.0)
