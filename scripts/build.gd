class_name Build
extends RefCounted
## Tiny helpers for assembling low-poly placeholder geometry in code.

static var _mats := {}


static func mat(color: Color, emission: float = 0.0, unshaded: bool = false) -> StandardMaterial3D:
	var key := "%s_%s_%s" % [color.to_html(), emission, unshaded]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats[key] = m
	return m


static func unique_mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.8
	return m


static func mesh(parent: Node, m: Mesh, pos: Vector3, material: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = material
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func box(parent: Node, size: Vector3, pos: Vector3, color: Color, collide: bool = true, emission: float = 0.0, rot: Vector3 = Vector3.ZERO) -> Node3D:
	var bm := BoxMesh.new()
	bm.size = size
	if collide:
		var body := StaticBody3D.new()
		body.position = pos
		body.rotation = rot
		parent.add_child(body)
		mesh(body, bm, Vector3.ZERO, mat(color, emission))
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		body.add_child(cs)
		return body
	return mesh(parent, bm, pos, mat(color, emission), rot)


static func cyl(parent: Node, r_top: float, r_bot: float, h: float, pos: Vector3, color: Color, collide: bool = false, segs: int = 8, emission: float = 0.0, rot: Vector3 = Vector3.ZERO) -> Node3D:
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = h
	cm.radial_segments = segs
	cm.rings = 1
	if collide:
		var body := StaticBody3D.new()
		body.position = pos
		body.rotation = rot
		parent.add_child(body)
		mesh(body, cm, Vector3.ZERO, mat(color, emission))
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = maxf(r_top, r_bot)
		sh.height = h
		cs.shape = sh
		body.add_child(cs)
		return body
	return mesh(parent, cm, pos, mat(color, emission), rot)


static func sphere(parent: Node, r: float, pos: Vector3, material: Material, segs: int = 8) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = segs
	sm.rings = maxi(3, segs / 2)
	return mesh(parent, sm, pos, material)


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
