class_name Carnival
extends RefCounted
## Builds the night carnival out of simple geometry. Returns key locations.

const PROPS := preload("res://scripts/props.gd")
const INTERACT := preload("res://scripts/interactables.gd")
const TV := preload("res://scripts/news_tv.gd")

const HALF := 42.0
const STRIPES := [Color(0.85, 0.1, 0.15), Color(0.95, 0.9, 0.8), Color(0.5, 0.15, 0.6), Color(0.1, 0.5, 0.6), Color(0.95, 0.6, 0.1)]


static func build(root: Node3D) -> Dictionary:
	var info := {}
	_ground(root)
	_fence(root)
	info["gate"] = _gate(root)
	_avenue_lights(root)
	_stall(root, Vector3(-9, 0, 22), PI / 2, "POPCORN", Color(0.9, 0.75, 0.2))
	_stall(root, Vector3(9, 0, 22), -PI / 2, "COTTON CANDY", Color(1.0, 0.45, 0.75))
	_stall(root, Vector3(-9, 0, -16), PI / 2, "HOOPLA", Color(0.3, 0.8, 0.4))
	_stall(root, Vector3(9, 0, -16), -PI / 2, "FORTUNES", Color(0.6, 0.3, 0.9))
	_stall(root, Vector3(-16, 0, 30), PI / 2, "TICKETS", Color(0.95, 0.3, 0.2))
	_stall(root, Vector3(-17, 0, -6), PI / 2, "DUCK POND", Color(0.2, 0.6, 0.95))
	info["gallery"] = _shooting_gallery(root, Vector3(-27, 0, 10))
	info["shed"] = _shed(root, Vector3(30, 0, -26))
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
	_clutter(root)
	info["worker_hide"] = Vector3(-30, 0, -37.5)
	return info


static func _ground(root: Node3D) -> void:
	Build.box(root, Vector3(160, 1, 160), Vector3(0, -0.5, 0), Color(0.08, 0.1, 0.07))
	# dirt paths
	Build.box(root, Vector3(9, 0.04, 80), Vector3(0, 0.02, 0), Color(0.22, 0.17, 0.13), false)
	Build.box(root, Vector3(70, 0.04, 7), Vector3(0, 0.02, 8), Color(0.22, 0.17, 0.13), false)
	Build.box(root, Vector3(70, 0.04, 6), Vector3(0, 0.02, -24), Color(0.22, 0.17, 0.13), false)
	# road outside the gate
	Build.box(root, Vector3(10, 0.05, 40), Vector3(0, 0.02, 62), Color(0.1, 0.1, 0.11), false)


static func _fence(root: Node3D) -> void:
	var h := 3.6
	var c1 := Color(0.3, 0.12, 0.18)
	var c2 := Color(0.6, 0.5, 0.2)
	# north, east, west full; south with a gate gap at |x| < 4
	Build.box(root, Vector3(HALF * 2, h, 0.5), Vector3(0, h / 2, -HALF), c1)
	Build.box(root, Vector3(0.5, h, HALF * 2), Vector3(HALF, h / 2, 0), c1)
	Build.box(root, Vector3(0.5, h, HALF * 2), Vector3(-HALF, h / 2, 0), c1)
	Build.box(root, Vector3(HALF - 4, h, 0.5), Vector3(-(HALF + 4) / 2, h / 2, HALF), c1)
	Build.box(root, Vector3(HALF - 4, h, 0.5), Vector3((HALF + 4) / 2, h / 2, HALF), c1)
	# striped posts
	var i := 0
	for x in range(-42, 43, 6):
		for z in [-HALF, HALF]:
			if z == HALF and absf(x) < 5:
				continue
			Build.cyl(root, 0.2, 0.25, h + 0.6, Vector3(x, (h + 0.6) / 2, z), c2 if i % 2 == 0 else c1)
			i += 1
	for z in range(-42, 43, 6):
		for x in [-HALF, HALF]:
			Build.cyl(root, 0.2, 0.25, h + 0.6, Vector3(x, (h + 0.6) / 2, z), c2 if i % 2 == 0 else c1)
			i += 1
	# dark tree silhouettes outside
	for k in 40:
		var a := randf() * TAU
		var r := randf_range(50, 75)
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		if p.z > 40 and absf(p.x) < 10:
			continue
		var th := randf_range(6, 12)
		Build.cyl(root, 0.0, randf_range(2, 3.5), th, p + Vector3(0, th / 2 + 1.5, 0), Color(0.03, 0.05, 0.04), false, 6)
		Build.cyl(root, 0.3, 0.3, 2, p + Vector3(0, 1, 0), Color(0.05, 0.04, 0.03), false, 5)


static func _gate(root: Node3D) -> Node3D:
	var g := Node3D.new()
	g.position = Vector3(0, 0, HALF)
	root.add_child(g)
	Build.box(g, Vector3(1.2, 7, 1.2), Vector3(-4.6, 3.5, 0), Color(0.5, 0.1, 0.15))
	Build.box(g, Vector3(1.2, 7, 1.2), Vector3(4.6, 3.5, 0), Color(0.5, 0.1, 0.15))
	Build.box(g, Vector3(10.4, 1.4, 0.8), Vector3(0, 7.2, 0), Color(0.15, 0.05, 0.25), false)
	Build.label(g, "THE LAST LAUGH", Vector3(0, 7.2, -0.45), Color(1, 0.8, 0.3), 110, PI)
	Build.label(g, "HAPPY HOLLOW CARNIVAL", Vector3(0, 7.2, 0.45), Color(1, 0.8, 0.3), 70)
	for k in 11:
		var x := -5.0 + k
		Build.sphere(g, 0.12, Vector3(x, 8.0, -0.3), Build.mat(Color(1, 0.7, 0.3) if k % 2 == 0 else Color(1, 0.2, 0.3), 4.0), 6)
	var gate := INTERACT.new()
	gate.kind = "gate"
	g.add_child(gate)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(8, 4, 0.4)
	cs.shape = sh
	cs.position = Vector3(0, 2, 0)
	gate.add_child(cs)
	for side in [-1, 1]:
		var pivot := Node3D.new()
		pivot.position = Vector3(side * 4.0, 0, 0)
		gate.add_child(pivot)
		for b in 6:
			Build.box(pivot, Vector3(0.12, 3.8, 0.12), Vector3(-side * (0.35 + b * 0.65), 1.9, 0), Color(0.15, 0.15, 0.17), false)
		Build.box(pivot, Vector3(4, 0.15, 0.15), Vector3(-side * 2, 0.6, 0), Color(0.15, 0.15, 0.17), false)
		Build.box(pivot, Vector3(4, 0.15, 0.15), Vector3(-side * 2, 3.2, 0), Color(0.15, 0.15, 0.17), false)
		gate.door_pivots.append(pivot)
	Build.box(gate, Vector3(0.4, 0.5, 0.3), Vector3(0, 1.6, -0.15), Color(0.8, 0.7, 0.2), false, 0.5)
	Build.omni(g, Vector3(0, 6, -3), Color(1, 0.6, 0.3), 3.0, 14)
	var tv := TV.new()
	tv.position = Vector3(6.5, 1.8, -1.5)
	tv.rotation.y = PI * 0.85
	g.add_child(tv)
	Build.box(g, Vector3(0.2, 1.2, 0.2), Vector3(6.5, 0.6, -1.3), Color(0.2, 0.2, 0.2), false)
	GameState.light_points.append(g.global_position + Vector3(0, 0, -3))
	return gate


static func _avenue_lights(root: Node3D) -> void:
	var cols := [Color(1, 0.75, 0.4), Color(1, 0.35, 0.5), Color(0.5, 0.6, 1), Color(0.7, 1, 0.5)]
	var idx := 0
	for z in range(34, -32, -13):
		for x in [-5.5, 5.5]:
			var post := Node3D.new()
			post.position = Vector3(x, 0, z)
			root.add_child(post)
			Build.cyl(post, 0.1, 0.14, 4.5, Vector3(0, 2.25, 0), Color(0.15, 0.12, 0.15), true, 6)
			Build.sphere(post, 0.3, Vector3(0, 4.6, 0), Build.mat(cols[idx % 4], 5.0))
			var flick := PROPS.new()
			flick.kind = "flicker"
			flick.position = Vector3(0, 4.3, 0)
			post.add_child(flick)
			Build.omni(flick, Vector3.ZERO, cols[idx % 4], 2.2, 11)
			GameState.light_points.append(post.position)
			idx += 1
		# string lights across the avenue
		var n := 14
		for k in n + 1:
			var u := float(k) / n
			var p := Vector3(lerpf(-5.5, 5.5, u), 4.4 - sin(u * PI) * 0.9, z - 6.5 * u)
			Build.sphere(root, 0.09, p, Build.mat(STRIPES[k % STRIPES.size()], 5.0), 4)


static func _stall(root: Node3D, pos: Vector3, rot: float, title: String, col: Color) -> void:
	var s := Node3D.new()
	s.position = pos
	s.rotation.y = rot
	root.add_child(s)
	Build.box(s, Vector3(4, 1.1, 1), Vector3(0, 0.55, 0), col.darkened(0.3))
	Build.box(s, Vector3(4, 2.8, 0.2), Vector3(0, 1.4, 1.8), col.darkened(0.6))
	for x in [-1.9, 1.9]:
		Build.box(s, Vector3(0.15, 2.9, 0.15), Vector3(x, 1.45, -0.3), Color(0.9, 0.9, 0.85), false)
	for k in 5:
		Build.box(s, Vector3(0.8, 0.12, 2.6), Vector3(-1.6 + k * 0.8, 3.0, 0.7), STRIPES[k % 2], false, 0.0, Vector3(-0.25, 0, 0))
	Build.label(s, title, Vector3(0, 3.5, -0.3), col.lightened(0.3), 64, PI)
	var o := Build.omni(s, Vector3(0, 2.4, -0.6), col.lightened(0.2), 1.8, 7)
	o.shadow_enabled = false
	for k in 4:
		Build.sphere(s, 0.18, Vector3(-1.2 + k * 0.8, 1.3, 0), Build.mat(STRIPES[k + 1], 0.5), 6)
	GameState.light_points.append(pos)


static func _shooting_gallery(root: Node3D, pos: Vector3) -> Dictionary:
	var s := Node3D.new()
	s.position = pos
	s.rotation.y = -PI / 2  # opens toward +x (the avenue)
	root.add_child(s)
	Build.box(s, Vector3(8, 4, 0.3), Vector3(0, 2, 3.0), Color(0.25, 0.08, 0.1))
	Build.box(s, Vector3(0.3, 4, 3.2), Vector3(-4, 2, 1.5), Color(0.25, 0.08, 0.1))
	Build.box(s, Vector3(0.3, 4, 3.2), Vector3(4, 2, 1.5), Color(0.25, 0.08, 0.1))
	Build.box(s, Vector3(8, 1.1, 0.8), Vector3(0, 0.55, -0.3), Color(0.6, 0.15, 0.15))
	Build.box(s, Vector3(8.4, 0.3, 4), Vector3(0, 4.1, 1.2), Color(0.95, 0.85, 0.3), false)
	for k in 8:
		Build.box(s, Vector3(1, 0.5, 0.1), Vector3(-3.5 + k, 3.75, -0.85), STRIPES[k % 2], false)
	Build.label(s, "SHOOTING GALLERY", Vector3(0, 4.7, -0.85), Color(1, 0.9, 0.3), 90, PI)
	Build.label(s, "WIN A PRIZE!", Vector3(0, 3.2, 2.8), Color(1, 0.5, 0.5), 50, PI)
	# moving duck targets
	for row in 2:
		var d := PROPS.new()
		d.kind = "duck"
		d.speed = 0.8 + row * 0.5
		d.amp = 2.5
		d.position = Vector3(0, 1.6 + row * 0.8, 2.6)
		s.add_child(d)
		for k in 3:
			Build.box(d, Vector3(0.3, 0.3, 0.1), Vector3(-1.5 + k * 1.5, 0, 0), Color(1, 0.85, 0.1), false, 0.4)
			Build.box(d, Vector3(0.15, 0.12, 0.08), Vector3(-1.3 + k * 1.5, 0.18, 0), Color(1, 0.4, 0.1), false)
	var o := Build.omni(s, Vector3(0, 3, 0.5), Color(1, 0.8, 0.5), 3.0, 10)
	o.shadow_enabled = false
	GameState.light_points.append(pos)
	var to_world := func(local: Vector3) -> Vector3: return s.position + local.rotated(Vector3.UP, s.rotation.y)
	return {
		"pistol": to_world.call(Vector3(0.6, 1.25, -0.3)),
		"ammo": [to_world.call(Vector3(-1.5, 1.25, -0.3)), to_world.call(Vector3(2.5, 1.25, -0.3))],
	}


static func _shed(root: Node3D, pos: Vector3) -> Dictionary:
	var s := Node3D.new()
	s.position = pos
	root.add_child(s)
	var wall := Color(0.3, 0.32, 0.28)
	var w := 7.0
	var d := 6.0
	var h := 3.2
	Build.box(s, Vector3(w, h, 0.3), Vector3(0, h / 2, -d / 2), wall)
	Build.box(s, Vector3(w, h, 0.3), Vector3(0, h / 2, d / 2), wall)
	Build.box(s, Vector3(0.3, h, d), Vector3(w / 2, h / 2, 0), wall)
	# west wall with door gap (z in -1..1)
	Build.box(s, Vector3(0.3, h, 2), Vector3(-w / 2, h / 2, -2), wall)
	Build.box(s, Vector3(0.3, h, 2), Vector3(-w / 2, h / 2, 2), wall)
	Build.box(s, Vector3(0.3, 0.9, 2), Vector3(-w / 2, h - 0.45, 0), wall)
	Build.box(s, Vector3(w + 0.6, 0.3, d + 0.6), Vector3(0, h + 0.15, 0), Color(0.2, 0.2, 0.22))
	Build.label(s, "MAINTENANCE - STAFF ONLY", Vector3(-w / 2 - 0.2, h + 0.6, 0), Color(1, 0.8, 0.2), 48, -PI / 2)
	var door := INTERACT.new()
	door.kind = "shed_door"
	door.position = Vector3(-w / 2, 0, 0)
	s.add_child(door)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.25, 2.3, 2)
	cs.shape = sh
	cs.position = Vector3(0, 1.15, 0)
	door.add_child(cs)
	var pivot := Node3D.new()
	pivot.position = Vector3(0, 0, -1)
	door.add_child(pivot)
	Build.box(pivot, Vector3(0.12, 2.3, 2), Vector3(0, 1.15, 1), Color(0.55, 0.35, 0.15), false)
	Build.box(pivot, Vector3(0.2, 0.15, 0.15), Vector3(-0.1, 1.1, 1.7), Color(0.8, 0.7, 0.2), false, 0.5)
	door.door_pivots.append(pivot)
	# interior
	Build.box(s, Vector3(1.2, 0.9, 2.5), Vector3(2.6, 0.45, 0), Color(0.4, 0.3, 0.2))
	Build.box(s, Vector3(2.5, 1.8, 0.6), Vector3(1.5, 0.9, 2.6), Color(0.25, 0.3, 0.35))
	var lamp := PROPS.new()
	lamp.kind = "flicker"
	lamp.position = Vector3(0, 2.8, 0)
	s.add_child(lamp)
	Build.omni(lamp, Vector3.ZERO, Color(0.9, 0.95, 0.7), 1.8, 7)
	var o := Build.omni(s, Vector3(-w / 2 - 1, 3, 0), Color(1, 0.5, 0.2), 1.5, 6)
	o.shadow_enabled = false
	var tv := TV.new()
	tv.position = Vector3(0.6, 1.8, -d / 2 + 0.4)
	s.add_child(tv)
	return {
		"door": door,
		"door_pos": pos + Vector3(-w / 2 - 1.2, 0, 0),
		"shotgun": pos + Vector3(2.6, 1.05, -0.6),
		"gate_key": pos + Vector3(2.6, 1.05, 0.7),
		"ammo": pos + Vector3(1.5, 1.95, 2.6),
	}


static func _guard_booth(root: Node3D, pos: Vector3) -> Vector3:
	var s := Node3D.new()
	s.position = pos
	root.add_child(s)
	var c := Color(0.15, 0.2, 0.35)
	Build.box(s, Vector3(3, 2.6, 0.2), Vector3(0, 1.3, 1.5), c)
	Build.box(s, Vector3(0.2, 2.6, 3), Vector3(1.5, 1.3, 0), c)
	Build.box(s, Vector3(0.2, 1.0, 3), Vector3(-1.5, 0.5, 0), c)
	Build.box(s, Vector3(3.4, 0.2, 3.4), Vector3(0, 2.7, 0), Color(0.1, 0.1, 0.12), false)
	Build.label(s, "SECURITY", Vector3(-1.65, 2.2, 0), Color(0.6, 0.8, 1), 50, -PI / 2)
	for k in 4:
		Build.box(s, Vector3(2, 0.9, 0.3), Vector3(-4, 0.45, -3 + k * 2.2), Color(0.9, 0.5, 0.1) if k % 2 == 0 else Color(0.9, 0.9, 0.9))
	var o := Build.omni(s, Vector3(0, 2.4, 0), Color(0.7, 0.8, 1.0), 2.0, 8)
	o.shadow_enabled = false
	Build.box(s, Vector3(0.6, 0.4, 0.4), Vector3(0.9, 1.4, 1.1), Color(0.1, 0.12, 0.2), false)
	GameState.light_points.append(pos)
	return pos + Vector3(-0.3, 0, -0.3)


static func _carousel(root: Node3D, pos: Vector3) -> void:
	var s := Node3D.new()
	s.position = pos
	root.add_child(s)
	Build.cyl(s, 7, 7.2, 0.6, Vector3(0, 0.3, 0), Color(0.4, 0.1, 0.2), true, 16)
	Build.cyl(s, 0.6, 0.6, 5, Vector3(0, 2.8, 0), Color(0.9, 0.8, 0.4), true, 8)
	var spin := PROPS.new()
	spin.kind = "spin"
	spin.speed = 0.35
	spin.position = Vector3(0, 0.6, 0)
	s.add_child(spin)
	Build.cyl(spin, 0.0, 7.6, 2.2, Vector3(0, 5.6, 0), Color(0.85, 0.15, 0.25), false, 16)
	Build.cyl(spin, 7.6, 7.6, 0.6, Vector3(0, 4.3, 0), Color(0.95, 0.85, 0.3), false, 16)
	for k in 10:
		var a := TAU * k / 10.0
		var p := Vector3(cos(a) * 5.2, 0, sin(a) * 5.2)
		Build.cyl(spin, 0.05, 0.05, 4.0, p + Vector3(0, 2.2, 0), Color(0.9, 0.85, 0.6), false, 4)
		var horse := Node3D.new()
		horse.position = p + Vector3(0, 1.2 + (k % 2) * 0.4, 0)
		horse.rotation.y = -a
		spin.add_child(horse)
		var hc: Color = [Color(0.95, 0.95, 0.9), Color(0.3, 0.2, 0.15), Color(0.6, 0.3, 0.7)][k % 3]
		Build.box(horse, Vector3(0.4, 0.5, 1.3), Vector3.ZERO, hc, false)
		Build.box(horse, Vector3(0.3, 0.7, 0.35), Vector3(0, 0.45, -0.65), hc, false, 0.0, Vector3(0.4, 0, 0))
		Build.box(horse, Vector3(0.12, 0.6, 0.12), Vector3(0, -0.5, 0.45), hc, false)
		Build.box(horse, Vector3(0.12, 0.6, 0.12), Vector3(0, -0.5, -0.45), hc, false)
		Build.sphere(spin, 0.12, Vector3(cos(a) * 7.5, 4.0, sin(a) * 7.5), Build.mat(STRIPES[k % 5], 5.0), 4)
	var o := Build.omni(s, Vector3(0, 3.5, 0), Color(1, 0.7, 0.4), 4.0, 16)
	o.shadow_enabled = true
	GameState.light_points.append(pos)


static func _ferris_wheel(root: Node3D, pos: Vector3) -> void:
	var s := Node3D.new()
	s.position = pos
	root.add_child(s)
	var r := 10.0
	var hub_h := 12.0
	for side in [-1.2, 1.2]:
		for lean in [-1, 1]:
			Build.box(s, Vector3(0.4, 13, 0.4), Vector3(lean * 3.2, 6.2, side), Color(0.35, 0.35, 0.4), true, 0.0, Vector3(0, 0, lean * 0.27))
	var wheel := PROPS.new()
	wheel.kind = "spin"
	wheel.axis = Vector3(0, 0, 1)
	wheel.speed = 0.12
	wheel.position = Vector3(0, hub_h, 0)
	s.add_child(wheel)
	Build.cyl(wheel, 0.8, 0.8, 2.6, Vector3.ZERO, Color(0.8, 0.7, 0.3), false, 8, 0.0, Vector3(PI / 2, 0, 0))
	var n := 12
	for k in n:
		var a := TAU * k / n
		var dir := Vector3(cos(a), sin(a), 0)
		Build.box(wheel, Vector3(0.15, r, 0.15), dir * r / 2, Color(0.8, 0.8, 0.85), false, 0.0, Vector3(0, 0, a - PI / 2))
		var a2 := TAU * (k + 0.5) / n
		var chord := 2.0 * r * sin(PI / n)
		for zz in [-1.0, 1.0]:
			Build.box(wheel, Vector3(0.2, chord, 0.2), Vector3(cos(a2), sin(a2), 0) * r * cos(PI / n) + Vector3(0, 0, zz), Color(0.9, 0.3, 0.4), false, 0.0, Vector3(0, 0, a2))
		Build.sphere(wheel, 0.15, dir * r + Vector3(0, 0, 1.2), Build.mat(STRIPES[k % 5], 6.0), 4)
		var car := PROPS.new()
		car.kind = "spin"
		car.axis = Vector3(0, 0, 1)
		car.speed = -0.12
		car.position = dir * r
		wheel.add_child(car)
		Build.box(car, Vector3(1.4, 1.0, 1.4), Vector3(0, -1.0, 0), STRIPES[k % 5], false)
		Build.box(car, Vector3(0.1, 0.8, 0.1), Vector3(0, -0.4, 0), Color(0.7, 0.7, 0.7), false)


static func _big_top(root: Node3D, pos: Vector3) -> void:
	var s := Node3D.new()
	s.position = pos
	root.add_child(s)
	Build.cyl(s, 8, 8, 4, Vector3(0, 2, 0), Color(0.85, 0.15, 0.2), true, 12)
	Build.cyl(s, 0.4, 8.6, 5, Vector3(0, 6.5, 0), Color(0.95, 0.9, 0.8), false, 12)
	for k in 12:
		var a := TAU * (k + 0.5) / 12.0
		Build.box(s, Vector3(0.6, 4.02, 0.1), Vector3(cos(a) * 7.98, 2, sin(a) * 7.98), Color(0.95, 0.9, 0.8), false, 0.0, Vector3(0, -a + PI / 2, 0))
	Build.cyl(s, 0.05, 0.05, 2, Vector3(0, 9.8, 0), Color(0.9, 0.9, 0.9), false, 4)
	Build.box(s, Vector3(1, 0.6, 0.05), Vector3(0.5, 10.5, 0), Color(0.6, 0.1, 0.8), false, 1.0)
	Build.label(s, "BIG TOP", Vector3(-8.2, 5, 0), Color(1, 0.9, 0.4), 120, -PI / 2)
	var o := Build.omni(s, Vector3(-9, 4, 0), Color(1, 0.4, 0.4), 2.0, 9)
	o.shadow_enabled = false


static func _fun_house(root: Node3D, pos: Vector3) -> void:
	var s := Node3D.new()
	s.position = pos
	root.add_child(s)
	Build.box(s, Vector3(10, 6, 7), Vector3(0, 3, 0), Color(0.3, 0.1, 0.4))
	Build.box(s, Vector3(10.4, 0.6, 7.4), Vector3(0, 6.3, 0), Color(0.9, 0.5, 0.1), false)
	# giant clown face on the front (+z)
	Build.sphere(s, 2.2, Vector3(0, 4, 3.4), Build.mat(Color(0.95, 0.92, 0.88)), 10)
	Build.sphere(s, 0.6, Vector3(0, 4, 5.4), Build.mat(Color(1, 0.1, 0.1), 1.5), 8)
	Build.sphere(s, 0.35, Vector3(-0.8, 4.8, 5.1), Build.mat(Color(0.1, 0.1, 0.1)), 6)
	Build.sphere(s, 0.35, Vector3(0.8, 4.8, 5.1), Build.mat(Color(0.1, 0.1, 0.1)), 6)
	Build.box(s, Vector3(2.2, 0.4, 0.5), Vector3(0, 3.0, 5.2), Color(0.8, 0.0, 0.1), false, 0.5)
	Build.label(s, "FUN HOUSE", Vector3(0, 6.9, 3.8), Color(0.4, 1, 0.5), 110)
	var o := Build.omni(s, Vector3(0, 2, 6), Color(0.5, 1, 0.4), 2.0, 9)
	o.shadow_enabled = false
	# crates behind it - the worker's hiding nook
	Build.box(s, Vector3(1.2, 1.2, 1.2), Vector3(-4, 0.6, -5.5), Color(0.4, 0.3, 0.15))
	Build.box(s, Vector3(1.2, 1.2, 1.2), Vector3(-1.5, 0.6, -6.0), Color(0.4, 0.3, 0.15))
	Build.box(s, Vector3(1.0, 1.0, 1.0), Vector3(-1.5, 1.7, -6.0), Color(0.45, 0.32, 0.15))


static func _tent(root: Node3D, pos: Vector3, r: float, col: Color) -> void:
	var s := Node3D.new()
	s.position = pos
	root.add_child(s)
	Build.cyl(s, r, r, 2.2, Vector3(0, 1.1, 0), col, true, 8)
	Build.cyl(s, 0.1, r + 0.4, 2.4, Vector3(0, 3.4, 0), Color(0.95, 0.9, 0.8), false, 8)
	Build.box(s, Vector3(0.6, 0.35, 0.05), Vector3(0.3, 4.9, 0), col.lightened(0.3), false, 0.5)
	Build.cyl(s, 0.03, 0.03, 0.8, Vector3(0, 4.8, 0), Color(0.8, 0.8, 0.8), false, 4)


static func _strength_tester(root: Node3D, pos: Vector3) -> void:
	var s := Node3D.new()
	s.position = pos
	root.add_child(s)
	Build.box(s, Vector3(1.2, 0.4, 1.2), Vector3(0, 0.2, 0), Color(0.5, 0.2, 0.1))
	Build.box(s, Vector3(0.4, 7, 0.3), Vector3(0, 3.7, 0), Color(0.9, 0.9, 0.85))
	for k in 6:
		Build.box(s, Vector3(0.45, 0.25, 0.32), Vector3(0, 1.5 + k * 1.0, -0.02), Color.from_hsv(k / 7.0, 0.9, 1), false, 1.5)
	Build.sphere(s, 0.4, Vector3(0, 7.4, 0), Build.mat(Color(1, 0.9, 0.2), 3.0))
	var tl := Build.label(s, "TEST YOUR STRENGTH", Vector3(-0.4, 4, 0), Color(1, 1, 1), 40, -PI / 2)
	tl.rotation.z = PI / 2


static func _clutter(root: Node3D) -> void:
	var spots := [
		Vector3(-4, 0, 14), Vector3(4.5, 0, 4), Vector3(-12, 0, 6), Vector3(14, 0, -6),
		Vector3(-6, 0, -26), Vector3(20, 0, -24), Vector3(-22, 0, 2), Vector3(32, 0, -12),
		Vector3(-34, 0, -12), Vector3(-36, 0, 18), Vector3(34, 0, 32), Vector3(6, 0, 30),
		Vector3(-24, 0, 24), Vector3(26, 0, -36), Vector3(-12, 0, -34), Vector3(36, 0, 14),
	]
	for i in spots.size():
		var p: Vector3 = spots[i]
		if i % 3 == 0:
			Build.cyl(root, 0.45, 0.45, 1.1, p + Vector3(0, 0.55, 0), Color(0.5, 0.15, 0.15), true, 8)
			Build.cyl(root, 0.45, 0.45, 1.1, p + Vector3(1.0, 0.55, 0.3), Color(0.15, 0.3, 0.5), true, 8)
		elif i % 3 == 1:
			Build.box(root, Vector3(1.3, 1.3, 1.3), p + Vector3(0, 0.65, 0), Color(0.42, 0.3, 0.16), true, 0.0, Vector3(0, randf() * 3, 0))
			Build.box(root, Vector3(1.0, 0.9, 1.0), p + Vector3(1.4, 0.45, 0.2), Color(0.45, 0.33, 0.18))
		else:
			Build.box(root, Vector3(2.2, 1.0, 1.0), p + Vector3(0, 0.5, 0), Color(0.75, 0.65, 0.3), true, 0.0, Vector3(0, randf() * 3, 0))
	# balloon bunches
	for p in [Vector3(-5, 0, 34), Vector3(7, 0, 8), Vector3(-8, 0, -8), Vector3(16, 0, 26)]:
		Build.cyl(root, 0.05, 0.05, 1.2, p + Vector3(0, 0.6, 0), Color(0.3, 0.3, 0.3), false, 4)
		for k in 6:
			var b := PROPS.new()
			b.kind = "bob"
			b.speed = randf_range(1, 2)
			b.amp = 0.12
			b.position = p + Vector3(randf_range(-0.5, 0.5), 2.4 + randf_range(0, 0.8), randf_range(-0.5, 0.5))
			root.add_child(b)
			Build.sphere(b, 0.32, Vector3.ZERO, Build.mat(STRIPES[k % 5], 0.6), 8)
