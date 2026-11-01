extends Node3D
## A slowly drifting bank of purple fog. Wanders between random points; never seeks anyone.
## Visual layers: wispy volumetric core (3D-noise density), a low ground-creeping skirt,
## billowing billboard puffs, rising corruption motes, a pulsing inner glow and a drone.

static var _noise3d: NoiseTexture3D
static var _soft: GradientTexture2D

var radius := 7.0
var speed := 1.1
var target := Vector3.ZERO
var _t := 0.0
var _light: OmniLight3D
var _core: FogMaterial
var _skirt: FogMaterial
var _drone: AudioStreamPlayer3D


func _ready() -> void:
	_t = randf() * 10.0
	if _noise3d == null:
		_noise3d = NoiseTexture3D.new()
		_noise3d.width = 48
		_noise3d.height = 48
		_noise3d.depth = 48
		_noise3d.seamless = true
		var n := FastNoiseLite.new()
		n.frequency = 0.06
		n.fractal_octaves = 3
		_noise3d.noise = n
		_soft = GradientTexture2D.new()
		var sg := Gradient.new()
		sg.set_color(0, Color(1, 1, 1, 1))
		sg.set_color(1, Color(1, 1, 1, 0))
		_soft.gradient = sg
		_soft.fill = GradientTexture2D.FILL_RADIAL
		_soft.fill_from = Vector2(0.5, 0.5)
		_soft.fill_to = Vector2(0.5, 0.0)
		_soft.width = 64
		_soft.height = 64

	var core := FogVolume.new()
	core.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
	core.size = Vector3(radius * 2.3, 6.0, radius * 2.3)
	core.position.y = 1.6
	_core = FogMaterial.new()
	_core.density = 1.2
	_core.albedo = Color(0.62, 0.28, 0.9)
	_core.emission = Color(0.25, 0.04, 0.4)
	_core.height_falloff = 0.2
	_core.edge_fade = 0.7
	_core.density_texture = _noise3d
	core.material = _core
	add_child(core)

	var skirt := FogVolume.new()
	skirt.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
	skirt.size = Vector3(radius * 3.2, 1.6, radius * 3.2)
	skirt.position.y = 0.2
	_skirt = FogMaterial.new()
	_skirt.density = 0.7
	_skirt.albedo = Color(0.5, 0.2, 0.75)
	_skirt.emission = Color(0.12, 0.02, 0.2)
	_skirt.edge_fade = 0.9
	_skirt.density_texture = _noise3d
	skirt.material = _skirt
	add_child(skirt)

	# billowing puffs (keeps the bank readable even without volumetrics)
	_puffs(46, Vector3(radius * 0.85, 0.9, radius * 0.85), Vector2(4.8, 3.6), Color(0.62, 0.3, 0.9, 0.3), 1.1, BaseMaterial3D.BILLBOARD_PARTICLES)
	# low ground-creeping roll at the edge
	_puffs(30, Vector3(radius * 1.25, 0.15, radius * 1.25), Vector2(6.0, 1.6), Color(0.5, 0.22, 0.8, 0.35), 0.35, BaseMaterial3D.BILLBOARD_FIXED_Y)
	_motes()

	_light = OmniLight3D.new()
	_light.light_color = Color(0.7, 0.3, 1.0)
	_light.light_energy = 2.0
	_light.omni_range = radius * 2.0
	_light.position.y = 2.0
	add_child(_light)

	_drone = AudioStreamPlayer3D.new()
	_drone.stream = Sfx.sounds.get("fog_drone")
	_drone.bus = "SFX"
	_drone.unit_size = 9.0
	_drone.max_distance = 45.0
	_drone.volume_db = -4.0
	_drone.pitch_scale = randf_range(0.85, 1.1)
	_drone.position.y = 1.5
	add_child(_drone)
	if _drone.stream:
		_drone.play()


func _puffs(amount: int, extents: Vector3, size: Vector2, col: Color, y: float, bb: int) -> void:
	var parts := GPUParticles3D.new()
	parts.amount = amount
	parts.lifetime = 7.0
	parts.preprocess = 7.0
	parts.local_coords = true
	parts.visibility_aabb = AABB(Vector3(-radius * 2, -2, -radius * 2), Vector3(radius * 4, 9, radius * 4))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = extents
	pm.gravity = Vector3(0, 0.04, 0)
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.35
	pm.scale_min = 0.7
	pm.scale_max = 1.7
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	pm.angular_velocity_min = -8.0
	pm.angular_velocity_max = 8.0
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0))
	grad.set_color(1, Color(1, 1, 1, 0))
	grad.add_point(0.3, Color(1, 1, 1, 1))
	grad.add_point(0.7, Color(0.85, 0.8, 1, 1))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	parts.process_material = pm
	var quad := QuadMesh.new()
	quad.size = size
	var qm := StandardMaterial3D.new()
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = bb
	qm.vertex_color_use_as_albedo = true
	qm.albedo_color = col
	qm.albedo_texture = _soft
	qm.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	quad.material = qm
	parts.draw_pass_1 = quad
	parts.position.y = y
	add_child(parts)


func _motes() -> void:
	var parts := GPUParticles3D.new()
	parts.amount = 40
	parts.lifetime = 4.0
	parts.preprocess = 4.0
	parts.local_coords = true
	parts.visibility_aabb = AABB(Vector3(-radius * 2, -2, -radius * 2), Vector3(radius * 4, 10, radius * 4))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(radius, 0.5, radius)
	pm.gravity = Vector3(0, 0.6, 0)
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 0.2
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 2.0
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	parts.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.08, 0.08)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = Color(0.9, 0.5, 1.0)
	m.emission_enabled = true
	m.emission = Color(0.9, 0.4, 1.0)
	m.emission_energy_multiplier = 4.0
	q.material = m
	parts.draw_pass_1 = q
	add_child(parts)


func _process(delta: float) -> void:
	_t += delta
	var to := target - global_position
	to.y = 0
	if to.length() < 2.0:
		target = Vector3(randf_range(-34, 34), 0, randf_range(-34, 34))
	else:
		var drift := Vector3(sin(_t * 0.31), 0, cos(_t * 0.23)) * 0.3
		global_position += (to.normalized() + drift) * speed * delta
	_light.light_energy = 1.7 + sin(_t * 1.7) * 0.5 + (randf() * 0.6 if randf() < 0.03 else 0.0)
	_core.density = 1.1 + sin(_t * 0.9) * 0.2
	_skirt.density = 0.65 + sin(_t * 0.6 + 1.0) * 0.15


func contains(p: Vector3) -> bool:
	var d := p - global_position
	return p.y < global_position.y + 4.5 and Vector2(d.x, d.z).length() < radius
