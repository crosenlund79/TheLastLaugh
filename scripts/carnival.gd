class_name Carnival
extends RefCounted
## Builds the night carnival out of stylized geometry and procedural textures.
## Returns key locations (doors, safe-house slots, duty points, patrol routes...).

const PROPS := preload("res://scripts/props.gd")
const INTERACT := preload("res://scripts/interactables.gd")
const TV := preload("res://scripts/news_tv.gd")

const HALF := 42.0
const STRIPES := [Color(0.9, 0.12, 0.18), Color(0.97, 0.93, 0.85), Color(0.55, 0.18, 0.7), Color(0.1, 0.55, 0.7), Color(1.0, 0.62, 0.1)]
const BULB_COLS := [Color(1, 0.82, 0.45), Color(1, 0.3, 0.45), Color(0.45, 0.8, 1), Color(0.6, 1, 0.45), Color(0.9, 0.5, 1)]


# ---------------------------------------------------------------- shared materials
static func wood() -> StandardMaterial3D:
	return Build.tex_mat("wood", Build.noise_tex("wood", Color(0.3, 0.18, 0.1), Color(0.6, 0.42, 0.24), 0.03, 256, 24), Color.WHITE, 0.45)


static func dark_wood() -> StandardMaterial3D:
	return Build.tex_mat("dwood", Build.noise_tex("wood", Color(0.3, 0.18, 0.1), Color(0.6, 0.42, 0.24), 0.03, 256, 24), Color(0.55, 0.45, 0.5), 0.45)


static func metal() -> StandardMaterial3D:
	var m := Build.tex_mat("metal", Build.noise_tex("metal", Color(0.3, 0.32, 0.36), Color(0.5, 0.52, 0.56), 0.08), Color.WHITE, 0.6, true, 0.45)
	m.metallic = 0.6
	return m


static func concrete() -> StandardMaterial3D:
	return Build.tex_mat("conc", Build.noise_tex("conc", Color(0.32, 0.33, 0.33), Color(0.52, 0.53, 0.5), 0.1), Color.WHITE, 0.35)


static func brick(tint: Color = Color.WHITE) -> StandardMaterial3D:
	return Build.tex_mat("brick_" + tint.to_html(), Build.brick_tex("brick", Color(0.55, 0.25, 0.2), Color(0.3, 0.27, 0.25)), tint, 0.5)


static func build(root: Node3D) -> Dictionary:
	var info := {}
	_ground(root)
	_fence(root)
	info["gate"] = _gate(root)
	_avenue_lights(root)
	_stall(root, Vector3(-9, 0, 22), -PI / 2, "POPCORN", Color(0.95, 0.78, 0.2))
	_stall(root, Vector3(9, 0, 22), PI / 2, "COTTON CANDY", Color(1.0, 0.45, 0.75))
	_stall(root, Vector3(-9, 0, -16), -PI / 2, "HOOPLA", Color(0.3, 0.85, 0.4))
	_stall(root, Vector3(9, 0, -16), PI / 2, "FORTUNES", Color(0.6, 0.3, 0.95))
	_stall(root, Vector3(-16, 0, 30), -PI / 2, "TICKETS", Color(0.95, 0.3, 0.2))
	_stall(root, Vector3(-17, 0, -6), -PI / 2, "DUCK POND", Color(0.2, 0.6, 0.95))
	info["gallery"] = _shooting_gallery(root, Vector3(-27, 0, 10))
	info["shed"] = _shed(root, Vector3(30, 0, -26))
	info["office"] = _security_office(root, Vector3(33, 0, 31))
	info["guard_post"] = _guard_booth(root, Vector3(14, 0, 33))
	_carousel(root, Vector3(0, 0, -2))
	_ferris_wheel(root, Vector3(10, 0, -35))
	_big_top(root, Vector3(25, 0, 6))
	_fun_house(root, Vector3(-27, 0, -29))
	_tent(root, Vector3(-19, 0, -16), 3.5, STRIPES[2])
	_tent(root, Vector3(19, 0, -15), 3.0, STRIPES[3])
	_tent(root, Vector3(-17, 0, 18), 3.0, STRIPES[4])
	_tent(root, Vector3(25, 0, 24), 3.5, STRIPES[0])
	_tent(root, Vector3(-32, 0, 30), 3.0, STRIPES[3])
	_strength_tester(root, Vector3(13, 0, 12))
	_bunting(root)
	_clutter(root)
	_storytelling(root)
	_cameras(root)
	info["worker_duty"] = [
		[Vector3(-22, 0, -22), Vector3(-31, 0, -21), Vector3(-14, 0, -28)],
		[Vector3(-4, 0, 7), Vector3(5, 0, -12), Vector3(-5, 0, 17)],
		[Vector3(18, 0, -6), Vector3(23, 0, -19), Vector3(16, 0, 15)],
	]
	info["guard_routes"] = [
		[Vector3(9, 0, 30), Vector3(-9, 0, 30), Vector3(-11, 0, 19), Vector3(10, 0, 18)],
		[Vector3(-21, 0, 3), Vector3(-35, 0, 0), Vector3(-35, 0, -14), Vector3(-22, 0, -11)],
		[Vector3(36, 0, 0), Vector3(36, 0, -15), Vector3(21, 0, -23), Vector3(17, 0, -3)],
	]
	return info


# ---------------------------------------------------------------- ground & fence
static func _ground(root: Node3D) -> void:
	var grass := Build.tex_mat("grass", Build.noise_tex("grass", Color(0.05, 0.09, 0.05), Color(0.13, 0.2, 0.09), 0.05), Color.WHITE, 0.08)
	Build.boxm(root, Vector3(160, 1, 160), Vector3(0, -0.5, 0), grass)
	var dirt := Build.tex_mat("dirt", Build.noise_tex("dirt", Color(0.17, 0.12, 0.09), Color(0.33, 0.25, 0.18), 0.09), Color.WHITE, 0.15)
	Build.boxm(root, Vector3(9, 0.04, 74), Vector3(0, 0.02, -3), dirt, false)
	Build.boxm(root, Vector3(70, 0.04, 7), Vector3(0, 0.021, 8), dirt, false)
	Build.boxm(root, Vector3(70, 0.04, 6), Vector3(0, 0.021, -24), dirt, false)
	# brick entrance plaza
	Build.boxm(root, Vector3(26, 0.05, 12), Vector3(0, 0.025, 36), brick(Color(0.8, 0.75, 0.8)), false)
	# road outside the gate
	Build.boxm(root, Vector3(10, 0.05, 40), Vector3(0, 0.02, 62), concrete(), false)


static func _fence(root: Node3D) -> void:
	var h := 3.6
	var c2 := Color(0.85, 0.65, 0.2)
	var w := dark_wood()
	Build.boxm(root, Vector3(HALF * 2, h, 0.5), Vector3(0, h / 2, -HALF), w)
	Build.boxm(root, Vector3(0.5, h, HALF * 2), Vector3(HALF, h / 2, 0), w)
	Build.boxm(root, Vector3(0.5, h, HALF * 2), Vector3(-HALF, h / 2, 0), w)
	Build.boxm(root, Vector3(HALF - 4, h, 0.5), Vector3(-(HALF + 4) / 2, h / 2, HALF), w)
	Build.boxm(root, Vector3(HALF - 4, h, 0.5), Vector3((HALF + 4) / 2, h / 2, HALF), w)
	var i := 0
	var caps := []
	for x in range(-42, 43, 6):
		for z in [-HALF, HALF]:
			if z == HALF and absf(x) < 5:
				continue
			Build.cyl(root, 0.2, 0.25, h + 0.6, Vector3(x, (h + 0.6) / 2, z), c2 if i % 2 == 0 else Color(0.5, 0.1, 0.18))
			caps.append(Vector3(x, h + 0.75, z))
			i += 1
	for z in range(-36, 37, 6):
		for x in [-HALF, HALF]:
			Build.cyl(root, 0.2, 0.25, h + 0.6, Vector3(x, (h + 0.6) / 2, z), c2 if i % 2 == 0 else Color(0.5, 0.1, 0.18))
			caps.append(Vector3(x, h + 0.75, z))
			i += 1
	Build.bulbs(root, caps, BULB_COLS, 0.14, 4.0)
	# tree silhouettes and distant hills outside
	var trunk := Build.mat(Color(0.05, 0.04, 0.03))
	var pines := []
	for k in 60:
		var a := randf() * TAU
		var r := randf_range(48, 80)
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		if p.z > 40 and absf(p.x) < 10:
			continue
		var th := randf_range(7, 14)
		pines.append(Transform3D(Basis().scaled(Vector3(randf_range(2, 3.5), th, randf_range(2, 3.5))), p + Vector3(0, th / 2 + 1.5, 0)))
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 1.0
	cone.height = 1.0
	cone.radial_segments = 6
	Build.multi(root, cone, pines, Build.mat(Color(0.025, 0.045, 0.035)))
	var stump := CylinderMesh.new()
	stump.top_radius = 0.3
	stump.bottom_radius = 0.35
	stump.height = 2.0
	stump.radial_segments = 5
	var stumps := []
	for t in pines:
		stumps.append(Transform3D(Basis(), Vector3(t.origin.x, 1.0, t.origin.z)))
	Build.multi(root, stump, stumps, trunk)


# ---------------------------------------------------------------- entrance
static func _gate(root: Node3D) -> Node3D:
	var g := Node3D.new()
	g.position = Vector3(0, 0, HALF)
	root.add_child(g)
	var red := Build.stripe_mat(Color(0.75, 0.1, 0.18), Color(0.95, 0.88, 0.75), 6)
	Build.boxm(g, Vector3(1.2, 7, 1.2), Vector3(-4.6, 3.5, 0), red)
	Build.boxm(g, Vector3(1.2, 7, 1.2), Vector3(4.6, 3.5, 0), red)
	Build.sphere(g, 0.8, Vector3(-4.6, 7.6, 0), Build.mat(Color(1, 0.75, 0.2), 0.6), 10)
	Build.sphere(g, 0.8, Vector3(4.6, 7.6, 0), Build.mat(Color(1, 0.75, 0.2), 0.6), 10)
	Build.box(g, Vector3(10.4, 1.6, 0.8), Vector3(0, 7.2, 0), Color(0.18, 0.06, 0.3), false)
	Build.label(g, "THE LAST LAUGH", Vector3(0, 7.2, -0.45), Color(1, 0.82, 0.3), 110, PI)
	Build.label(g, "HAPPY HOLLOW CARNIVAL", Vector3(0, 7.2, 0.45), Color(1, 0.82, 0.3), 70)
	Build.marquee(g, Vector3(0, 7.2, -0.45), 10.0, 1.5, 0.3)
	var gate := INTERACT.new()
	gate.kind = "gate"
	gate.collision_layer = 16
	g.add_child(gate)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(8, 4, 0.4)
	cs.shape = sh
	cs.position = Vector3(0, 2, 0)
	gate.add_child(cs)
	var iron := metal()
	for side in [-1, 1]:
		var pivot := Node3D.new()
		pivot.position = Vector3(side * 4.0, 0, 0)
		gate.add_child(pivot)
		for b in 6:
			Build.boxm(pivot, Vector3(0.1, 3.8, 0.1), Vector3(-side * (0.35 + b * 0.65), 1.9, 0), iron, false)
			Build.sphere(pivot, 0.09, Vector3(-side * (0.35 + b * 0.65), 3.85, 0), Build.mat(Color(0.8, 0.65, 0.2)), 5)
		Build.boxm(pivot, Vector3(4, 0.15, 0.15), Vector3(-side * 2, 0.6, 0), iron, false)
		Build.boxm(pivot, Vector3(4, 0.15, 0.15), Vector3(-side * 2, 3.2, 0), iron, false)
		gate.door_pivots.append(pivot)
	Build.box(gate, Vector3(0.4, 0.5, 0.3), Vector3(0, 1.6, -0.15), Color(0.8, 0.7, 0.2), false, 0.5)
	var o := Build.omni(g, Vector3(0, 6, -3), Color(1, 0.65, 0.35), 3.0, 14)
	o.shadow_enabled = true
	var tv := TV.new()
	tv.position = Vector3(6.5, 1.8, -1.5)
	tv.rotation.y = PI * 0.85
	g.add_child(tv)
	Build.box(g, Vector3(0.2, 1.2, 0.2), Vector3(6.5, 0.6, -1.3), Color(0.2, 0.2, 0.2), false)
	# fog advisory sign: the first hint that tonight is going wrong
	var sign := Node3D.new()
	sign.position = Vector3(-7, 0, -3)
	sign.rotation.y = PI * 0.15
	g.add_child(sign)
	Build.boxm(sign, Vector3(0.15, 2.2, 0.15), Vector3(-1.1, 1.1, 0), wood(), false)
	Build.boxm(sign, Vector3(0.15, 2.2, 0.15), Vector3(1.1, 1.1, 0), wood(), false)
	Build.box(sign, Vector3(2.6, 1.2, 0.08), Vector3(0, 1.8, 0), Color(0.95, 0.85, 0.2), false)
	var tl := Build.label(sign, "NOTICE\nPARK MAY CLOSE EARLY\nFOG ADVISORY IN EFFECT", Vector3(0, 1.8, -0.05), Color(0.1, 0.05, 0.05), 22, PI)
	tl.outline_size = 0
	GameState.light_points.append(g.global_position + Vector3(0, 0, -3))
	return gate


static func _avenue_lights(root: Node3D) -> void:
	var idx := 0
	var string_pts := []
	for z in range(34, -32, -13):
		for x in [-5.5, 5.5]:
			var post := Node3D.new()
			post.position = Vector3(x, 0, z)
			root.add_child(post)
			Build.cylm(post, 0.1, 0.16, 4.5, Vector3(0, 2.25, 0), metal(), true, 8)
			Build.cyl(post, 0.25, 0.25, 0.2, Vector3(0, 0.1, 0), Color(0.15, 0.12, 0.15), false, 8)
			Build.cyl(post, 0.35, 0.12, 0.25, Vector3(0, 4.85, 0), Color(0.12, 0.1, 0.12), false, 8)
			Build.sphere(post, 0.28, Vector3(0, 4.6, 0), Build.mat(BULB_COLS[idx % 4], 5.0), 10)
			var flick := PROPS.new()
			flick.kind = "flicker"
			flick.position = Vector3(0, 4.3, 0)
			post.add_child(flick)
			var o := Build.omni(flick, Vector3.ZERO, BULB_COLS[idx % 4], 2.4, 12)
			o.shadow_enabled = idx % 3 == 0
			GameState.light_points.append(post.position)
			idx += 1
		var n := 16
		for k in n + 1:
			var u := float(k) / n
			string_pts.append(Vector3(lerpf(-5.5, 5.5, u), 4.4 - sin(u * PI) * 0.9, z - 6.5 * u))
	Build.bulbs(root, string_pts, BULB_COLS, 0.09, 5.0)


static func _bunting(root: Node3D) -> void:
	var pm := PrismMesh.new()
	pm.size = Vector3(0.35, 0.45, 0.02)
	var groups := [[], [], [], [], []]
	for z in range(34, -32, -13):
		for side in [-5.5, 5.5]:
			# along the avenue between consecutive posts
			for k in 12:
				var u := float(k) / 12.0
				var p := Vector3(side, 3.7 - sin(u * PI) * 0.6, z - 13.0 * u)
				groups[k % 5].append(Transform3D(Basis(Vector3.UP, PI / 2).rotated(Vector3.RIGHT, PI), p))
	for c in 5:
		Build.multi(root, pm, groups[c], Build.mat(STRIPES[c]))


# ---------------------------------------------------------------- attractions
static func _stall(root: Node3D, pos: Vector3, rot: float, title: String, col: Color) -> void:
	var s := Node3D.new()
	s.position = pos
	s.rotation.y = rot
	root.add_child(s)
	Build.boxm(s, Vector3(4, 1.1, 1), Vector3(0, 0.55, 0), wood())
	Build.box(s, Vector3(4.1, 0.12, 1.15), Vector3(0, 1.12, 0), col, false)
	Build.box(s, Vector3(4, 2.8, 0.2), Vector3(0, 1.4, 1.8), col.darkened(0.55))
	for x in [-1.9, 1.9]:
		Build.cylm(s, 0.07, 0.07, 2.9, Vector3(x, 1.45, -0.3), Build.stripe_mat(Color(0.95, 0.95, 0.9), col, 4), false, 6)
	Build.boxm(s, Vector3(4.2, 0.08, 2.8), Vector3(0, 3.0, 0.7), Build.stripe_mat(col, Color(0.97, 0.94, 0.86), 10), false, Vector3(-0.25, 0, 0))
	var scallop := []
	for k in 11:
		scallop.append(Vector3(-2.0 + k * 0.4, 2.62, -0.62))
	Build.bulbs(s, scallop, [col.lightened(0.3), Color(1, 0.9, 0.6)], 0.07, 4.0)
	Build.box(s, Vector3(3.2, 0.7, 0.08), Vector3(0, 3.55, -0.35), Color(0.12, 0.05, 0.15), false)
	Build.label(s, title, Vector3(0, 3.55, -0.4), col.lightened(0.35), 60, PI)
	Build.marquee(s, Vector3(0, 3.55, -0.42), 3.2, 0.7, 0.32, [Color(1, 0.85, 0.45)])
	var o := Build.omni(s, Vector3(0, 2.4, -0.6), col.lightened(0.2), 2.0, 7)
	o.shadow_enabled = false
	for k in 4:
		Build.sphere(s, 0.18, Vector3(-1.2 + k * 0.8, 1.35, 0), Build.mat(STRIPES[k + 1], 0.5), 8)
	# prizes hanging at the back
	for k in 5:
		Build.sphere(s, 0.22, Vector3(-1.6 + k * 0.8, 2.1, 1.6), Build.mat(Color.from_hsv(randf(), 0.6, 0.9)), 8)
	GameState.light_points.append(pos)


static func _shooting_gallery(root: Node3D, pos: Vector3) -> Dictionary:
	var s := Node3D.new()
	s.position = pos
	s.rotation.y = -PI / 2
	root.add_child(s)
	var wallm := Build.stripe_mat(Color(0.35, 0.08, 0.12), Color(0.25, 0.05, 0.1), 12)
	Build.boxm(s, Vector3(8, 4, 0.3), Vector3(0, 2, 3.0), wallm)
	Build.boxm(s, Vector3(0.3, 4, 3.2), Vector3(-4, 2, 1.5), wallm)
	Build.boxm(s, Vector3(0.3, 4, 3.2), Vector3(4, 2, 1.5), wallm)
	Build.boxm(s, Vector3(8, 1.1, 0.8), Vector3(0, 0.55, -0.3), wood())
	Build.box(s, Vector3(8.1, 0.1, 0.9), Vector3(0, 1.12, -0.3), Color(0.8, 0.15, 0.15), false)
	Build.boxm(s, Vector3(8.4, 0.3, 4), Vector3(0, 4.1, 1.2), Build.stripe_mat(Color(0.97, 0.85, 0.3), Color(0.85, 0.15, 0.2), 10), false)
	Build.box(s, Vector3(7.4, 1.0, 0.1), Vector3(0, 4.75, -0.85), Color(0.12, 0.05, 0.18), false)
	Build.label(s, "SHOOTING GALLERY", Vector3(0, 4.75, -0.92), Color(1, 0.9, 0.3), 90, PI)
	Build.marquee(s, Vector3(0, 4.75, -0.95), 7.4, 1.0, 0.3)
	Build.label(s, "WIN A PRIZE!", Vector3(0, 3.2, 2.8), Color(1, 0.5, 0.5), 50, PI)
	for row in 2:
		var d := PROPS.new()
		d.kind = "duck"
		d.speed = 0.8 + row * 0.5
		d.amp = 2.5
		d.position = Vector3(0, 1.6 + row * 0.8, 2.6)
		s.add_child(d)
		for k in 3:
			Build.sphere(d, 0.18, Vector3(-1.5 + k * 1.5, 0, 0), Build.mat(Color(1, 0.85, 0.1), 0.4), 8)
			Build.sphere(d, 0.11, Vector3(-1.38 + k * 1.5, 0.2, 0), Build.mat(Color(1, 0.85, 0.1), 0.4), 6)
			Build.box(d, Vector3(0.12, 0.05, 0.06), Vector3(-1.25 + k * 1.5, 0.2, 0), Color(1, 0.4, 0.1), false)
	var o := Build.omni(s, Vector3(0, 3, 0.5), Color(1, 0.8, 0.5), 3.0, 10)
	o.shadow_enabled = true
	GameState.light_points.append(pos)
	var to_world := func(local: Vector3) -> Vector3: return s.position + local.rotated(Vector3.UP, s.rotation.y)
	return {
		"pistol": to_world.call(Vector3(0.6, 1.25, -0.3)),
		"ammo": [to_world.call(Vector3(-1.5, 1.25, -0.3)), to_world.call(Vector3(2.5, 1.25, -0.3))],
	}


# ---------------------------------------------------------------- safe houses
## Builds a walled room with a door gap on its west wall (door faces -x). Returns the door.
static func _room(s: Node3D, w: float, d: float, h: float, wall: Material, profession: String, door_col: Color) -> Node:
	Build.boxm(s, Vector3(w, h, 0.3), Vector3(0, h / 2, -d / 2), wall)
	Build.boxm(s, Vector3(w, h, 0.3), Vector3(0, h / 2, d / 2), wall)
	Build.boxm(s, Vector3(0.3, h, d), Vector3(w / 2, h / 2, 0), wall)
	var side := (d - 2.0) / 2.0
	Build.boxm(s, Vector3(0.3, h, side), Vector3(-w / 2, h / 2, -1.0 - side / 2), wall)
	Build.boxm(s, Vector3(0.3, h, side), Vector3(-w / 2, h / 2, 1.0 + side / 2), wall)
	Build.boxm(s, Vector3(0.3, h - 2.4, 2.0), Vector3(-w / 2, h - (h - 2.4) / 2, 0), wall, false)
	Build.boxm(s, Vector3(w + 0.6, 0.3, d + 0.6), Vector3(0, h + 0.15, 0), metal())
	Build.boxm(s, Vector3(w - 0.3, 0.04, d - 0.3), Vector3(0, 0.02, 0), concrete(), false)
	var door := INTERACT.new()
	door.position = Vector3(-w / 2, 0, 0)
	s.add_child(door)
	door.setup_safe_door(profession, Vector3.RIGHT.rotated(Vector3.UP, s.rotation.y))
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.25, 2.4, 2.0)
	cs.shape = sh
	cs.position = Vector3(0, 1.2, 0)
	door.add_child(cs)
	var pivot := Node3D.new()
	pivot.position = Vector3(0, 0, -1)
	door.add_child(pivot)
	Build.box(pivot, Vector3(0.12, 2.35, 1.96), Vector3(0, 1.18, 1), door_col, false)
	Build.box(pivot, Vector3(0.16, 0.5, 1.6), Vector3(0, 1.8, 1), door_col.darkened(0.3), false)
	Build.box(pivot, Vector3(0.22, 0.12, 0.12), Vector3(-0.1, 1.1, 1.75), Color(0.8, 0.7, 0.2), false, 0.6)
	door.door_pivots.append(pivot)
	# "secured" indicator light above the door
	Build.sphere(s, 0.1, Vector3(-w / 2 - 0.2, 2.65, 0), Build.mat(Color(0.2, 1, 0.3), 5.0), 6)
	return door


static func _slots(s: Node3D, locals: Array) -> Array:
	var out := []
	for l in locals:
		out.append(s.position + (l as Vector3).rotated(Vector3.UP, s.rotation.y))
	return out


static func _shed(root: Node3D, pos: Vector3) -> Dictionary:
	var s := Node3D.new()
	s.position = pos
	root.add_child(s)
	var w := 7.0
	var d := 6.0
	var h := 3.2
	var door := _room(s, w, d, h, brick(Color(0.75, 0.8, 0.75)), "worker", Color(0.6, 0.35, 0.12))
	Build.box(s, Vector3(0.1, 0.8, 3.6), Vector3(-w / 2 - 0.2, h + 0.6, 0), Color(0.15, 0.15, 0.1), false)
	Build.label(s, "MAINTENANCE", Vector3(-w / 2 - 0.27, h + 0.75, 0), Color(1, 0.8, 0.2), 52, -PI / 2)
	Build.label(s, "STAFF ONLY", Vector3(-w / 2 - 0.27, h + 0.42, 0), Color(1, 0.4, 0.3), 30, -PI / 2)
	# hazard stripes either side of the door
	for z in [-1.25, 1.25]:
		Build.boxm(s, Vector3(0.05, 2.4, 0.3), Vector3(-w / 2 - 0.17, 1.2, z), Build.stripe_mat(Color(1, 0.8, 0.1), Color(0.1, 0.1, 0.1), 6), false, Vector3(0, 0, 0.0))
	# interior
	Build.boxm(s, Vector3(1.2, 0.9, 2.5), Vector3(2.6, 0.45, 0), wood())
	Build.boxm(s, Vector3(2.5, 1.8, 0.6), Vector3(1.5, 0.9, 2.6), metal())
	Build.box(s, Vector3(0.5, 0.3, 0.3), Vector3(2.8, 1.05, -0.9), Color(0.8, 0.15, 0.1), false)  # toolbox
	Build.boxm(s, Vector3(0.1, 1.6, 2.4), Vector3(3.3, 1.8, -1.2), Build.mat(Color(0.35, 0.28, 0.2)), false)  # pegboard
	for k in 5:
		Build.box(s, Vector3(0.05, 0.4, 0.06), Vector3(3.22, 1.9, -2.1 + k * 0.45), Color(0.6, 0.6, 0.65), false)
	var lamp := PROPS.new()
	lamp.kind = "flicker"
	lamp.position = Vector3(0, 2.8, 0)
	s.add_child(lamp)
	Build.omni(lamp, Vector3.ZERO, Color(0.95, 0.95, 0.75), 1.8, 7)
	var o := Build.omni(s, Vector3(-w / 2 - 1, 3, 0), Color(1, 0.55, 0.2), 1.6, 7)
	o.shadow_enabled = false
	var tv := TV.new()
	tv.position = Vector3(0.6, 1.8, -d / 2 + 0.4)
	s.add_child(tv)
	_maintenance_yard(root, pos)
	return {
		"door": door,
		"door_pos": pos + Vector3(-w / 2 - 1.2, 0, 0),
		"shotgun": pos + Vector3(2.6, 1.05, -0.2),
		"gate_key": pos + Vector3(2.6, 1.05, 0.8),
		"ammo": pos + Vector3(1.5, 1.95, 2.6),
		"slots": _slots(s, [Vector3(-1.6, 0, -1.8), Vector3(-1.8, 0, 1.5), Vector3(0.6, 0, -1.2)]),
	}


static func _maintenance_yard(root: Node3D, shed: Vector3) -> void:
	var y := Node3D.new()
	y.position = shed
	root.add_child(y)
	# generator with exhaust
	Build.boxm(y, Vector3(2.0, 1.4, 1.2), Vector3(6.5, 0.7, 6.0), Build.mat(Color(0.25, 0.4, 0.25)))
	Build.cylm(y, 0.08, 0.08, 1.0, Vector3(7.2, 1.9, 6.0), metal(), false, 6)
	Build.box(y, Vector3(0.6, 0.3, 0.05), Vector3(6.2, 1.0, 5.38), Color(1, 0.8, 0.1), false, 0.5)
	# cable spools, barrels, pallets
	Build.cylm(y, 0.7, 0.7, 0.6, Vector3(-6.0, 0.7, 5.0), wood(), true, 10, Vector3(PI / 2, 0, 0))
	Build.cylm(y, 0.55, 0.55, 0.5, Vector3(-7.4, 0.55, 3.8), wood(), true, 10, Vector3(PI / 2, 0.4, 0))
	var hz := Build.stripe_mat(Color(1, 0.75, 0.1), Color(0.12, 0.12, 0.12), 8)
	for k in 3:
		Build.cylm(y, 0.4, 0.4, 1.1, Vector3(5.8 + k * 0.85, 0.55, -4.2), hz, true, 8)
	Build.boxm(y, Vector3(1.4, 0.2, 1.2), Vector3(-6.5, 0.1, -5.0), wood())
	Build.boxm(y, Vector3(1.0, 0.8, 1.0), Vector3(-6.5, 0.6, -5.0), wood())
	# floodlight on a pole lighting the yard
	Build.cylm(y, 0.08, 0.1, 6.0, Vector3(-5.0, 3.0, -4.0), metal(), true, 6)
	Build.box(y, Vector3(0.6, 0.4, 0.3), Vector3(-4.7, 6.0, -3.7), Color(0.9, 0.9, 0.8), false, 3.0)
	var sp := SpotLight3D.new()
	sp.position = Vector3(-4.6, 5.9, -3.6)
	sp.light_color = Color(0.9, 1.0, 0.85)
	sp.light_energy = 3.0
	sp.spot_range = 16.0
	sp.spot_angle = 50.0
	sp.shadow_enabled = true
	y.add_child(sp)
	sp.look_at(y.global_position + Vector3(-7, 0, 1), Vector3.UP)
	var wsign := Build.label(y, "DANGER\nHIGH VOLTAGE", Vector3(6.5, 1.0, 5.36), Color(0.05, 0.05, 0.05), 18, PI)
	wsign.outline_size = 0
	Build.label(y, "MAINTENANCE YARD", Vector3(-5.0, 4.2, -3.85), Color(1, 0.85, 0.3), 40, -PI / 2)
	GameState.light_points.append(shed + Vector3(-6, 0, -1))


static func _security_office(root: Node3D, pos: Vector3) -> Dictionary:
	var s := Node3D.new()
	s.position = pos
	root.add_child(s)
	var w := 8.0
	var d := 6.0
	var h := 3.3
	var wall := Build.tex_mat("office", Build.noise_tex("conc", Color(0.32, 0.33, 0.33), Color(0.52, 0.53, 0.5), 0.1), Color(0.6, 0.7, 0.95), 0.35)
	var door := _room(s, w, d, h, wall, "guard", Color(0.2, 0.28, 0.45))
	# armoured glass window strip (solid to bodies, see-through)
	Build.box(s, Vector3(3.0, 0.9, 0.32), Vector3(0.5, 1.8, -d / 2), Color(0.5, 0.8, 1.0, 0.3), true)
	Build.box(s, Vector3(0.12, 1.0, 3.6), Vector3(-w / 2 - 0.2, h + 0.65, 0), Color(0.05, 0.08, 0.2), false)
	Build.label(s, "SECURITY", Vector3(-w / 2 - 0.27, h + 0.65, 0), Color(0.55, 0.8, 1), 70, -PI / 2)
	var mh := Node3D.new()
	mh.position = Vector3(-w / 2 - 0.29, h + 0.65, 0)
	mh.rotation.y = -PI / 2
	s.add_child(mh)
	Build.marquee(mh, Vector3.ZERO, 3.6, 1.0, 0.36, [Color(0.5, 0.75, 1)])
	# desk with CCTV monitor wall
	Build.boxm(s, Vector3(1.0, 0.9, 3.0), Vector3(3.1, 0.45, 0), wood())
	for k in 3:
		for r in 2:
			Build.box(s, Vector3(0.1, 0.55, 0.8), Vector3(3.75, 1.4 + r * 0.6, -0.9 + k * 0.9), Color(0.08, 0.08, 0.1), false)
			var scr := Build.box(s, Vector3(0.02, 0.45, 0.7), Vector3(3.69, 1.4 + r * 0.6, -0.9 + k * 0.9), Color(0.3, 0.6, 0.45), false, 1.8)
			scr.set_meta("monitor", true)
	Build.boxm(s, Vector3(2.8, 2.0, 0.5), Vector3(1.0, 1.0, -2.6), metal())  # lockers
	for k in 4:
		Build.box(s, Vector3(0.04, 1.8, 0.02), Vector3(-0.35 + k * 0.7, 1.0, -2.34), Color(0.15, 0.15, 0.18), false)
	var lamp := PROPS.new()
	lamp.kind = "flicker"
	lamp.position = Vector3(0, 2.9, 0)
	s.add_child(lamp)
	Build.omni(lamp, Vector3.ZERO, Color(0.75, 0.85, 1.0), 1.8, 8)
	var mon := Build.omni(s, Vector3(3.2, 1.6, 0), Color(0.3, 0.8, 0.5), 0.8, 3.5)
	mon.shadow_enabled = false
	# radio mast with blinking red beacon
	Build.cylm(s, 0.05, 0.08, 5.0, Vector3(2.5, h + 2.5, 2.0), metal(), false, 5)
	var beacon := PROPS.new()
	beacon.kind = "blink"
	beacon.position = Vector3(2.5, h + 5.1, 2.0)
	s.add_child(beacon)
	Build.sphere(beacon, 0.15, Vector3.ZERO, Build.mat(Color(1, 0.1, 0.1), 6.0), 6)
	var o := Build.omni(s, Vector3(-w / 2 - 1.2, 3.0, 0), Color(0.7, 0.85, 1.0), 2.0, 9)
	o.shadow_enabled = true
	GameState.light_points.append(pos + Vector3(-w / 2 - 1, 0, 0))
	return {
		"door": door,
		"door_pos": pos + Vector3(-w / 2 - 1.2, 0, 0),
		"slots": _slots(s, [Vector3(-1.8, 0, -1.4), Vector3(-1.8, 0, 1.6), Vector3(1.0, 0, 1.7)]),
		"ammo": pos + Vector3(1.0, 2.15, -2.6),
	}


static func _guard_booth(root: Node3D, pos: Vector3) -> Vector3:
	var s := Node3D.new()
	s.position = pos
	root.add_child(s)
	var c := Color(0.15, 0.2, 0.35)
	Build.box(s, Vector3(3, 2.6, 0.2), Vector3(0, 1.3, 1.5), c)
	Build.box(s, Vector3(0.2, 2.6, 3), Vector3(1.5, 1.3, 0), c)
	Build.box(s, Vector3(0.2, 1.0, 3), Vector3(-1.5, 0.5, 0), c)
	Build.boxm(s, Vector3(3.4, 0.2, 3.4), Vector3(0, 2.7, 0), metal(), false)
	Build.label(s, "CHECKPOINT", Vector3(-1.65, 2.2, 0), Color(0.6, 0.8, 1), 40, -PI / 2)
	var hz := Build.stripe_mat(Color(0.95, 0.5, 0.1), Color(0.95, 0.95, 0.95), 6)
	for k in 4:
		Build.boxm(s, Vector3(2, 0.9, 0.3), Vector3(-4, 0.45, -3 + k * 2.2), hz)
	var o := Build.omni(s, Vector3(0, 2.4, 0), Color(0.7, 0.8, 1.0), 2.0, 8)
	o.shadow_enabled = false
	Build.box(s, Vector3(0.6, 0.4, 0.4), Vector3(0.9, 1.4, 1.1), Color(0.1, 0.12, 0.2), false)
	GameState.light_points.append(pos)
	return pos + Vector3(-0.3, 0, -0.3)


static func _carousel(root: Node3D, pos: Vector3) -> void:
	var s := Node3D.new()
	s.position = pos
	root.add_child(s)
	Build.cylm(s, 7, 7.2, 0.6, Vector3(0, 0.3, 0), Build.stripe_mat(Color(0.5, 0.1, 0.25), Color(0.85, 0.7, 0.3), 16), true, 24)
	Build.cylm(s, 0.6, 0.6, 5, Vector3(0, 2.8, 0), Build.stripe_mat(Color(0.95, 0.85, 0.4), Color(0.9, 0.2, 0.3), 6), true, 12)
	var spin := PROPS.new()
	spin.kind = "spin"
	spin.speed = 0.35
	spin.position = Vector3(0, 0.6, 0)
	s.add_child(spin)
	Build.cylm(spin, 0.0, 7.6, 2.2, Vector3(0, 5.6, 0), Build.stripe_mat(Color(0.9, 0.15, 0.25), Color(0.98, 0.94, 0.85), 12), false, 24)
	Build.cylm(spin, 7.6, 7.6, 0.6, Vector3(0, 4.3, 0), Build.stripe_mat(Color(0.97, 0.85, 0.3), Color(0.6, 0.2, 0.7), 24), false, 24)
	Build.sphere(spin, 0.5, Vector3(0, 6.9, 0), Build.mat(Color(1, 0.8, 0.2), 1.5), 10)
	var rim := []
	for k in 10:
		var a := TAU * k / 10.0
		var p := Vector3(cos(a) * 5.2, 0, sin(a) * 5.2)
		Build.cylm(spin, 0.05, 0.05, 4.0, p + Vector3(0, 2.2, 0), Build.stripe_mat(Color(0.95, 0.9, 0.6), Color(0.85, 0.65, 0.2), 4), false, 6)
		var horse := PROPS.new()
		horse.kind = "bob"
		horse.speed = 2.0
		horse.amp = 0.25
		horse.position = p + Vector3(0, 1.3, 0)
		horse.rotation.y = -a
		spin.add_child(horse)
		var hc: Color = [Color(0.97, 0.95, 0.9), Color(0.35, 0.22, 0.15), Color(0.65, 0.35, 0.8)][k % 3]
		var hm := Build.mat(hc)
		Build.mesh(horse, _capsule_mesh(0.25, 1.3), Vector3.ZERO, hm, Vector3(PI / 2, 0, 0))
		Build.mesh(horse, _capsule_mesh(0.13, 0.6), Vector3(0, 0.35, -0.6), hm, Vector3(0.6, 0, 0))
		Build.mesh(horse, _capsule_mesh(0.12, 0.4), Vector3(0, 0.6, -0.85), hm, Vector3(PI / 2 - 0.2, 0, 0))
		Build.box(horse, Vector3(0.06, 0.4, 0.5), Vector3(0, 0.6, -0.5), STRIPES[k % 5], false)  # mane
		Build.box(horse, Vector3(0.45, 0.06, 0.35), Vector3(0, 0.26, 0.05), Color(0.8, 0.15, 0.2), false)  # saddle
		for lx in [-0.12, 0.12]:
			for lz in [-0.4, 0.4]:
				Build.mesh(horse, _capsule_mesh(0.05, 0.6), Vector3(lx, -0.45, lz), hm, Vector3(0.4 if lz < 0 else -0.4, 0, 0))
		for j in 3:
			var a2 := TAU * (k * 3 + j) / 30.0
			rim.append(Vector3(cos(a2) * 7.62, 3.7, sin(a2) * 7.62))
	Build.bulbs(spin, rim, BULB_COLS, 0.1, 5.0)
	var o := Build.omni(s, Vector3(0, 3.5, 0), Color(1, 0.75, 0.45), 4.0, 16)
	o.shadow_enabled = true
	Build.label(s, "CAROUSEL", Vector3(0, 1.2, 7.4), Color(1, 0.85, 0.4), 64)
	GameState.light_points.append(pos)


static func _capsule_mesh(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = maxf(h, r * 2.01)
	c.radial_segments = 8
	c.rings = 2
	return c


static func _ferris_wheel(root: Node3D, pos: Vector3) -> void:
	var s := Node3D.new()
	s.position = pos
	root.add_child(s)
	var r := 10.0
	var hub_h := 12.0
	var steel := metal()
	for side in [-1.2, 1.2]:
		for lean in [-1, 1]:
			Build.boxm(s, Vector3(0.4, 13, 0.4), Vector3(lean * 3.2, 6.2, side), steel, true, Vector3(0, 0, lean * 0.27))
	Build.boxm(s, Vector3(6, 0.4, 4), Vector3(0, 0.2, 3.5), wood())  # boarding platform
	Build.label(s, "SKY WHEEL", Vector3(0, 1.5, 5.6), Color(0.5, 0.9, 1), 70)
	var wheel := PROPS.new()
	wheel.kind = "spin"
	wheel.axis = Vector3(0, 0, 1)
	wheel.speed = 0.12
	wheel.position = Vector3(0, hub_h, 0)
	s.add_child(wheel)
	Build.cyl(wheel, 0.8, 0.8, 2.6, Vector3.ZERO, Color(0.85, 0.7, 0.3), false, 12, 0.0, Vector3(PI / 2, 0, 0))
	var n := 12
	var lights := []
	for k in n:
		var a := TAU * k / n
		var dir := Vector3(cos(a), sin(a), 0)
		Build.boxm(wheel, Vector3(0.15, r, 0.15), dir * r / 2, steel, false, Vector3(0, 0, a - PI / 2))
		var a2 := TAU * (k + 0.5) / n
		var chord := 2.0 * r * sin(PI / n)
		for zz in [-1.0, 1.0]:
			Build.box(wheel, Vector3(0.2, chord, 0.2), Vector3(cos(a2), sin(a2), 0) * r * cos(PI / n) + Vector3(0, 0, zz), Color(0.9, 0.3, 0.4), false, 0.0, Vector3(0, 0, a2))
		for j in 4:
			var a3 := TAU * (k * 4 + j) / (n * 4)
			lights.append(Vector3(cos(a3), sin(a3), 0) * r + Vector3(0, 0, 1.2))
			lights.append(Vector3(cos(a3), sin(a3), 0) * r * 0.5 + Vector3(0, 0, 1.2))
		var car := PROPS.new()
		car.kind = "spin"
		car.axis = Vector3(0, 0, 1)
		car.speed = -0.12
		car.position = dir * r
		wheel.add_child(car)
		Build.cylm(car, 0.75, 0.6, 1.0, Vector3(0, -1.0, 0), Build.stripe_mat(STRIPES[k % 5], Color(0.97, 0.94, 0.85), 6), false, 10)
		Build.cyl(car, 0.0, 0.85, 0.4, Vector3(0, -0.2, 0), STRIPES[(k + 2) % 5], false, 10)
		Build.boxm(car, Vector3(0.1, 0.8, 0.1), Vector3(0, -0.4, 0), steel, false)
	Build.bulbs(wheel, lights, BULB_COLS, 0.11, 6.0)


static func _big_top(root: Node3D, pos: Vector3) -> void:
	var s := Node3D.new()
	s.position = pos
	root.add_child(s)
	Build.cylm(s, 8, 8, 4, Vector3(0, 2, 0), Build.stripe_mat(Color(0.88, 0.12, 0.2), Color(0.97, 0.93, 0.85), 16), true, 24)
	Build.cylm(s, 0.4, 8.6, 5, Vector3(0, 6.5, 0), Build.stripe_mat(Color(0.97, 0.93, 0.85), Color(0.88, 0.12, 0.2), 16), false, 24)
	Build.cyl(s, 0.05, 0.05, 2, Vector3(0, 9.8, 0), Color(0.9, 0.9, 0.9), false, 4)
	Build.box(s, Vector3(1, 0.6, 0.05), Vector3(0.5, 10.5, 0), Color(0.6, 0.1, 0.8), false, 1.0)
	# entrance arch facing the avenue (-x)
	Build.box(s, Vector3(0.6, 3.6, 3.4), Vector3(-8.1, 1.8, 0), Color(0.08, 0.02, 0.05), false)
	Build.box(s, Vector3(0.3, 0.8, 4.4), Vector3(-8.3, 4.3, 0), Color(0.15, 0.04, 0.25), false)
	Build.label(s, "BIG TOP", Vector3(-8.5, 4.3, 0), Color(1, 0.9, 0.4), 90, -PI / 2)
	var m := []
	for k in 24:
		var a := TAU * k / 24.0
		m.append(Vector3(cos(a) * 8.65, 4.05, sin(a) * 8.65))
	Build.bulbs(s, m, BULB_COLS, 0.1, 5.0)
	var o := Build.omni(s, Vector3(-9.5, 4, 0), Color(1, 0.45, 0.45), 2.4, 10)
	o.shadow_enabled = false


static func _fun_house(root: Node3D, pos: Vector3) -> void:
	var s := Node3D.new()
	s.position = pos
	root.add_child(s)
	Build.boxm(s, Vector3(10, 6, 7), Vector3(0, 3, 0), Build.stripe_mat(Color(0.35, 0.12, 0.45), Color(0.25, 0.08, 0.35), 10))
	Build.boxm(s, Vector3(10.4, 0.6, 7.4), Vector3(0, 6.3, 0), Build.stripe_mat(Color(0.95, 0.55, 0.1), Color(0.95, 0.85, 0.3), 12), false)
	Build.sphere(s, 2.2, Vector3(0, 4, 3.4), Build.mat(Color(0.96, 0.93, 0.88)), 16)
	Build.sphere(s, 0.6, Vector3(0, 4, 5.4), Build.mat(Color(1, 0.1, 0.1), 1.5), 12)
	Build.sphere(s, 0.35, Vector3(-0.8, 4.8, 5.1), Build.mat(Color(0.1, 0.1, 0.1)), 8)
	Build.sphere(s, 0.35, Vector3(0.8, 4.8, 5.1), Build.mat(Color(0.1, 0.1, 0.1)), 8)
	for k in 7:
		var u := (k - 3) / 3.0
		Build.sphere(s, 0.22, Vector3(u * 1.3, 3.0 + u * u * 0.5, 5.15 - absf(u) * 0.35), Build.mat(Color(0.85, 0.05, 0.1), 0.5), 6)
	Build.label(s, "FUN HOUSE", Vector3(0, 6.9, 3.8), Color(0.4, 1, 0.5), 110)
	Build.marquee(s, Vector3(0, 6.9, 3.75), 6.0, 1.0, 0.3, [Color(0.4, 1, 0.5), Color(1, 0.9, 0.4)])
	Build.box(s, Vector3(2.2, 2.8, 0.1), Vector3(-3.4, 1.4, 3.52), Color(0.03, 0.01, 0.03), false)
	var o := Build.omni(s, Vector3(0, 2, 6), Color(0.5, 1, 0.45), 2.2, 9)
	o.shadow_enabled = false
	Build.boxm(s, Vector3(1.2, 1.2, 1.2), Vector3(-4, 0.6, -5.5), wood())
	Build.boxm(s, Vector3(1.2, 1.2, 1.2), Vector3(-1.5, 0.6, -6.0), wood())
	Build.boxm(s, Vector3(1.0, 1.0, 1.0), Vector3(-1.5, 1.7, -6.0), wood())


static func _tent(root: Node3D, pos: Vector3, r: float, col: Color) -> void:
	var s := Node3D.new()
	s.position = pos
	root.add_child(s)
	Build.cylm(s, r, r, 2.2, Vector3(0, 1.1, 0), Build.stripe_mat(col, Color(0.97, 0.93, 0.85), 10), true, 16)
	Build.cylm(s, 0.1, r + 0.4, 2.4, Vector3(0, 3.4, 0), Build.stripe_mat(Color(0.97, 0.93, 0.85), col, 10), false, 16)
	Build.box(s, Vector3(0.6, 0.35, 0.05), Vector3(0.3, 4.9, 0), col.lightened(0.3), false, 0.5)
	Build.cyl(s, 0.03, 0.03, 0.8, Vector3(0, 4.8, 0), Color(0.8, 0.8, 0.8), false, 4)
	var m := []
	for k in 16:
		var a := TAU * k / 16.0
		m.append(Vector3(cos(a) * (r + 0.42), 2.2, sin(a) * (r + 0.42)))
	Build.bulbs(s, m, [Color(1, 0.85, 0.5), col.lightened(0.3)], 0.07, 4.0)


static func _strength_tester(root: Node3D, pos: Vector3) -> void:
	var s := Node3D.new()
	s.position = pos
	root.add_child(s)
	Build.boxm(s, Vector3(1.2, 0.4, 1.2), Vector3(0, 0.2, 0), wood())
	Build.box(s, Vector3(0.4, 7, 0.3), Vector3(0, 3.7, 0), Color(0.95, 0.93, 0.88))
	for k in 6:
		Build.box(s, Vector3(0.45, 0.25, 0.32), Vector3(0, 1.5 + k * 1.0, -0.02), Color.from_hsv(k / 7.0, 0.9, 1), false, 1.5)
	Build.sphere(s, 0.4, Vector3(0, 7.4, 0), Build.mat(Color(1, 0.9, 0.2), 3.0), 10)
	var tl := Build.label(s, "TEST YOUR STRENGTH", Vector3(-0.4, 4, 0), Color(1, 1, 1), 40, -PI / 2)
	tl.rotation.z = PI / 2


# ---------------------------------------------------------------- dressing
static func _clutter(root: Node3D) -> void:
	var spots := [
		Vector3(-4, 0, 14), Vector3(4.5, 0, 4), Vector3(-12, 0, 6), Vector3(14, 0, -6),
		Vector3(-6, 0, -26), Vector3(20, 0, -27), Vector3(-22, 0, 2), Vector3(33, 0, -12),
		Vector3(-34, 0, -12), Vector3(-36, 0, 18), Vector3(6, 0, 30),
		Vector3(-24, 0, 24), Vector3(26, 0, -37), Vector3(-12, 0, -34), Vector3(37, 0, 14),
	]
	var barrel := Build.stripe_mat(Color(0.55, 0.15, 0.15), Color(0.35, 0.1, 0.1), 8)
	var barrel2 := Build.stripe_mat(Color(0.15, 0.3, 0.55), Color(0.1, 0.2, 0.4), 8)
	for i in spots.size():
		var p: Vector3 = spots[i]
		if i % 3 == 0:
			Build.cylm(root, 0.45, 0.45, 1.1, p + Vector3(0, 0.55, 0), barrel, true, 10)
			Build.cylm(root, 0.45, 0.45, 1.1, p + Vector3(1.0, 0.55, 0.3), barrel2, true, 10)
		elif i % 3 == 1:
			Build.boxm(root, Vector3(1.3, 1.3, 1.3), p + Vector3(0, 0.65, 0), wood(), true, Vector3(0, randf() * 3, 0))
			Build.boxm(root, Vector3(1.0, 0.9, 1.0), p + Vector3(1.4, 0.45, 0.2), wood())
		else:
			Build.box(root, Vector3(2.2, 1.0, 1.0), p + Vector3(0, 0.5, 0), Color(0.78, 0.68, 0.3), true, 0.0, Vector3(0, randf() * 3, 0))
	# benches & bins along the avenue
	for z in [28.0, 14.0, -9.0, -22.0]:
		for side in [-1.0, 1.0]:
			var b := Node3D.new()
			b.position = Vector3(side * 7.3, 0, z)
			b.rotation.y = PI / 2 * side
			root.add_child(b)
			Build.boxm(b, Vector3(2.0, 0.12, 0.5), Vector3(0, 0.5, 0), wood())
			Build.boxm(b, Vector3(2.0, 0.5, 0.1), Vector3(0, 0.8, 0.25), wood(), false)
			Build.boxm(b, Vector3(0.1, 0.5, 0.5), Vector3(-0.9, 0.25, 0), metal(), false)
			Build.boxm(b, Vector3(0.1, 0.5, 0.5), Vector3(0.9, 0.25, 0), metal(), false)
			Build.cylm(root, 0.3, 0.26, 0.9, Vector3(side * 7.3, 0.45, z + 1.8), Build.stripe_mat(Color(0.2, 0.55, 0.3), Color(0.15, 0.4, 0.2), 6), true, 10)
	# balloon bunches
	for p in [Vector3(-5, 0, 34), Vector3(7, 0, 8), Vector3(-8, 0, -8), Vector3(16, 0, 26)]:
		Build.cyl(root, 0.05, 0.05, 1.2, p + Vector3(0, 0.6, 0), Color(0.3, 0.3, 0.3), false, 4)
		for k in 6:
			var bb := PROPS.new()
			bb.kind = "bob"
			bb.speed = randf_range(1, 2)
			bb.amp = 0.12
			bb.position = p + Vector3(randf_range(-0.5, 0.5), 2.4 + randf_range(0, 0.8), randf_range(-0.5, 0.5))
			root.add_child(bb)
			var bm := StandardMaterial3D.new()
			bm.albedo_color = STRIPES[k % 5]
			bm.roughness = 0.2
			bm.metallic_specular = 1.0
			bm.rim_enabled = true
			Build.sphere(bb, 0.32, Vector3.ZERO, bm, 12)


static func _storytelling(root: Node3D) -> void:
	# popcorn spilled in front of the popcorn stall
	var pop := []
	for k in 70:
		pop.append(Transform3D(Basis(), Vector3(-6.5 + randf_range(-1.2, 1.2), 0.05, 22 + randf_range(-1.5, 1.5))))
	var pm := SphereMesh.new()
	pm.radius = 0.05
	pm.height = 0.08
	pm.radial_segments = 4
	pm.rings = 2
	Build.multi(root, pm, pop, Build.mat(Color(1, 0.92, 0.6)))
	Build.box(root, Vector3(0.3, 0.4, 0.2), Vector3(-6.2, 0.1, 22.4), Color(0.9, 0.15, 0.15), false, 0.0, Vector3(1.4, 0.3, 0))
	# a lost teddy bear by the carousel
	var bear := Node3D.new()
	bear.position = Vector3(5.8, 0, 6.5)
	bear.rotation = Vector3(0, 0.6, -0.4)
	root.add_child(bear)
	var fur := Build.mat(Color(0.6, 0.38, 0.2))
	Build.sphere(bear, 0.28, Vector3(0, 0.28, 0), fur, 8)
	Build.sphere(bear, 0.2, Vector3(0, 0.66, 0), fur, 8)
	Build.sphere(bear, 0.08, Vector3(-0.15, 0.82, 0), fur, 6)
	Build.sphere(bear, 0.08, Vector3(0.15, 0.82, 0), fur, 6)
	Build.box(bear, Vector3(0.3, 0.08, 0.08), Vector3(0, 0.5, -0.18), Color(0.9, 0.1, 0.4), false)
	# "MISSING" poster boards: performers have been vanishing all week
	var names := ["BOBO", "MISS GIGGLES", "TINY TIM-TIM"]
	var spots := [Vector3(-7.5, 0, 31), Vector3(7.5, 0, -3), Vector3(-14, 0, -24)]
	for i in 3:
		var b := Node3D.new()
		b.position = spots[i]
		b.rotation.y = -PI / 2 if spots[i].x < 0 else PI / 2
		root.add_child(b)
		Build.boxm(b, Vector3(0.12, 2.4, 0.12), Vector3(0, 1.2, 0), wood(), false)
		Build.box(b, Vector3(1.0, 1.3, 0.04), Vector3(0, 1.75, -0.08), Color(0.92, 0.88, 0.75), false)
		var l := Build.label(b, "MISSING\n%s\nLAST SEEN\nNEAR THE FOG" % names[i], Vector3(0, 1.75, -0.11), Color(0.15, 0.05, 0.05), 16, PI)
		l.outline_size = 0
	# an overturned cotton-candy cart on the east path
	var cart := Node3D.new()
	cart.position = Vector3(21, 0.45, 8.5)
	cart.rotation = Vector3(0, 0.4, 1.45)
	root.add_child(cart)
	Build.box(cart, Vector3(1.4, 0.8, 0.9), Vector3.ZERO, Color(1, 0.6, 0.8), false)
	Build.sphere(cart, 0.4, Vector3(0.9, 0.2, 0), Build.mat(Color(1, 0.75, 0.9)), 8)
	# a ticket booth at the entrance plaza
	var tb := Node3D.new()
	tb.position = Vector3(-6.5, 0, 37.5)
	root.add_child(tb)
	Build.boxm(tb, Vector3(1.8, 1.2, 1.6), Vector3(0, 0.6, 0), Build.stripe_mat(Color(0.9, 0.2, 0.25), Color(0.97, 0.93, 0.85), 6))
	Build.box(tb, Vector3(1.8, 1.0, 0.1), Vector3(0, 1.7, 0.75), Color(0.6, 0.85, 1, 0.3), false)
	Build.cylm(tb, 0.0, 1.4, 1.0, Vector3(0, 2.7, 0), Build.stripe_mat(Color(0.97, 0.85, 0.3), Color(0.9, 0.2, 0.25), 8), false, 8)
	Build.label(tb, "ADMIT ONE", Vector3(0, 1.0, -0.82), Color(1, 0.9, 0.5), 30, PI)


static func _cameras(root: Node3D) -> void:
	for p in [Vector3(-9, 0, 33), Vector3(-30, 0, 0), Vector3(30, 0, -14), Vector3(10, 0, -24), Vector3(27, 0, 34)]:
		var c := Node3D.new()
		c.position = p
		root.add_child(c)
		Build.cylm(c, 0.06, 0.08, 4.0, Vector3(0, 2.0, 0), metal(), false, 6)
		Build.box(c, Vector3(0.25, 0.25, 0.5), Vector3(0, 4.05, -0.2), Color(0.85, 0.85, 0.8), false)
		var led := PROPS.new()
		led.kind = "blink"
		led.position = Vector3(0.09, 4.12, -0.46)
		c.add_child(led)
		Build.sphere(led, 0.035, Vector3.ZERO, Build.mat(Color(1, 0.1, 0.1), 6.0), 4)
