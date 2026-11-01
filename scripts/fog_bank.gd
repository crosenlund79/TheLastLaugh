extends Node3D
## A slowly drifting bank of purple fog. Wanders between random points; never seeks anyone.

var radius := 7.0
var speed := 1.1
var target := Vector3.ZERO
var _t := 0.0
var _light: OmniLight3D
var _fm: FogMaterial


func _ready() -> void:
	_t = randf() * 10.0
	var fv := FogVolume.new()
	fv.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
	fv.size = Vector3(radius * 2.3, 5.0, radius * 2.3)
	fv.position.y = 1.2
	_fm = FogMaterial.new()
	_fm.density = 0.9
	_fm.albedo = Color(0.6, 0.25, 0.85)
	_fm.emission = Color(0.22, 0.03, 0.35)
	_fm.height_falloff = 0.25
	_fm.edge_fade = 0.6
	fv.material = _fm
	add_child(fv)

	# billboard puffs so the bank reads clearly even without volumetrics
	var parts := GPUParticles3D.new()
	parts.amount = 46
	parts.lifetime = 7.0
	parts.preprocess = 7.0
	parts.local_coords = true
	parts.visibility_aabb = AABB(Vector3(-radius * 1.5, -2, -radius * 1.5), Vector3(radius * 3, 8, radius * 3))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(radius * 0.85, 0.8, radius * 0.85)
	pm.gravity = Vector3(0, 0.05, 0)
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.3
	pm.scale_min = 0.7
	pm.scale_max = 1.6
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0))
	grad.set_color(1, Color(1, 1, 1, 0))
	grad.add_point(0.3, Color(1, 1, 1, 1))
	grad.add_point(0.7, Color(1, 1, 1, 1))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	parts.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(4.5, 3.5)
	var qm := StandardMaterial3D.new()
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.vertex_color_use_as_albedo = true
	qm.albedo_color = Color(0.62, 0.3, 0.9, 0.28)
	qm.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var soft := GradientTexture2D.new()
	var sg := Gradient.new()
	sg.set_color(0, Color(1, 1, 1, 1))
	sg.set_color(1, Color(1, 1, 1, 0))
	soft.gradient = sg
	soft.fill = GradientTexture2D.FILL_RADIAL
	soft.fill_from = Vector2(0.5, 0.5)
	soft.fill_to = Vector2(0.5, 0.0)
	soft.width = 64
	soft.height = 64
	qm.albedo_texture = soft
	quad.material = qm
	parts.draw_pass_1 = quad
	parts.position.y = 1.0
	add_child(parts)

	_light = OmniLight3D.new()
	_light.light_color = Color(0.7, 0.3, 1.0)
	_light.light_energy = 1.6
	_light.omni_range = radius * 1.8
	_light.position.y = 2.0
	add_child(_light)


func _process(delta: float) -> void:
	_t += delta
	var to := target - global_position
	to.y = 0
	if to.length() < 2.0:
		target = Vector3(randf_range(-34, 34), 0, randf_range(-34, 34))
	else:
		var drift := Vector3(sin(_t * 0.31), 0, cos(_t * 0.23)) * 0.3
		global_position += (to.normalized() + drift) * speed * delta
	_light.light_energy = 1.4 + sin(_t * 1.7) * 0.4
	_fm.density = 0.8 + sin(_t * 0.9) * 0.15


func contains(p: Vector3) -> bool:
	var d := p - global_position
	return p.y < global_position.y + 4.5 and Vector2(d.x, d.z).length() < radius
