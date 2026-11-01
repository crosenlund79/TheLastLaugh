extends Node3D
## Small animated prop behaviours: spinners, gallery ducks, bobbing, flickering lights, blinkers.
## Rides slow down and lights die off as GameState.dread rises.

@export var kind := "spin"  # spin, duck, flicker, bob, blink
@export var axis := Vector3.UP
@export var speed := 0.3
@export var amp := 1.0
var _t := 0.0
var _base := Vector3.ZERO
var _light: Light3D
var _base_energy := 1.0
var _death_at := 2.0  # dread level at which this light gives out for good


func _ready() -> void:
	_base = position
	_t = randf() * 10.0
	_death_at = randf_range(0.45, 1.6)
	if kind == "flicker":
		for c in get_children():
			if c is Light3D:
				_light = c
				_base_energy = c.light_energy


func _process(delta: float) -> void:
	_t += delta
	var dread := GameState.dread
	match kind:
		"spin":
			rotate(axis.normalized(), speed * delta * (1.0 - Music.distortion * 0.5) * (1.0 - dread * 0.75))
		"duck":
			position.x = _base.x + sin(_t * speed) * amp
		"bob":
			position.y = _base.y + sin(_t * speed) * amp
		"blink":
			visible = fmod(_t, 1.2) < 0.25
		"flicker":
			if _light:
				var target := _base_energy * (1.0 - dread * 0.35)
				if dread > _death_at:
					target = _base_energy * 0.04
				elif randf() < 0.02 + Music.distortion * 0.12 + dread * 0.08:
					target *= randf_range(0.05, 0.6)
				_light.light_energy = lerpf(_light.light_energy, target, 0.35)
