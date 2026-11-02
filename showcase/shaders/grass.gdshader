// Grass clumps (MultiMesh). UV.y = 0 root .. 1 tip; INSTANCE_CUSTOM.r = tint seed.
shader_type spatial;
render_mode cull_disabled, diffuse_burley;

uniform vec3 root_col : source_color = vec3(0.05, 0.08, 0.02);
uniform vec3 mid_col : source_color = vec3(0.20, 0.30, 0.07);
uniform vec3 tip_col : source_color = vec3(0.40, 0.52, 0.14);
uniform vec3 dry_col : source_color = vec3(0.62, 0.52, 0.25);
uniform float wind = 0.22;

varying float h;
varying float seed;

void vertex() {
	h = UV.y;
	seed = INSTANCE_CUSTOM.r;
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME;
	float gust = sin(t * 0.6 + w.x * 0.08 - w.z * 0.05) * 0.5 + 0.5;
	vec2 bend = vec2(sin(t * 1.7 + w.x * 0.45 + w.z * 0.3), cos(t * 1.3 + w.z * 0.5)) * (0.35 + gust * 0.65);
	VERTEX.xz += vec2(bend.x, bend.y * 0.5) * wind * h * h;
}

void fragment() {
	vec3 tipc = mix(tip_col, dry_col, smoothstep(0.75, 1.0, seed) * 0.6);
	vec3 col = mix(root_col, mid_col, smoothstep(0.0, 0.45, h));
	col = mix(col, tipc, smoothstep(0.4, 1.0, h));
	col *= 0.85 + seed * 0.3;
	ALBEDO = col;
	ROUGHNESS = 0.62;
	SPECULAR = 0.35;
	// soften shading: lean blade normals toward the sky
	vec3 up = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	if (!FRONT_FACING) { NORMAL = -NORMAL; }
	NORMAL = normalize(mix(NORMAL, up, 0.55));
	BACKLIGHT = tipc * 0.55 * h;
	AO = mix(0.35, 1.0, h);
	AO_LIGHT_AFFECT = 0.5;
}
