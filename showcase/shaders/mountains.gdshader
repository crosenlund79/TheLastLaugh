// Distant ranges: hand-graded aerial perspective (fog disabled for full control).
shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled;

uniform vec3 near_col : source_color = vec3(0.32, 0.30, 0.42);
uniform vec3 far_col : source_color = vec3(0.86, 0.66, 0.66);
uniform vec3 sun_side : source_color = vec3(1.0, 0.74, 0.5);
uniform vec3 sun_dir = vec3(-0.8, 0.15, -0.55);

varying float layer;
varying vec3 wpos;

void vertex() {
	layer = COLOR.r;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float haze = mix(0.45, 0.88, layer);
	float hgt = clamp((wpos.y + 60.0) / 500.0, 0.0, 1.0);
	vec2 dir = normalize(wpos.xz);
	float toward = max(dot(dir, normalize(sun_dir.xz)), 0.0);
	vec3 far = mix(far_col, sun_side, pow(toward, 3.0) * 0.8);
	vec3 c = mix(near_col, far, haze);
	c = mix(far, c, smoothstep(0.0, 0.5, hgt));  // valley mist at the base
	ALBEDO = c;
}
