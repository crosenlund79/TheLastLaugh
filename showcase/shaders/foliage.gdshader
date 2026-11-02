// Leaf / blossom cards: alpha-to-coverage edges, crown-shaped normals (from Blender),
// baked canopy AO (vertex colour), translucent backlight and layered wind.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec3 backlight_col : source_color = vec3(1.0, 0.75, 0.8);
uniform float translucency = 0.7;
uniform float wind = 0.12;
uniform float var_amount = 0.12;
uniform float ao_strength = 1.0;
uniform float roughness = 0.75;

varying vec3 wpos;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = clamp(VERTEX.y * 0.12, 0.0, 1.5);
	float t = TIME;
	float gust = sin(t * 0.37 + w.x * 0.05) * 0.5 + 0.5;
	vec3 sway = vec3(sin(t * 1.21 + w.x * 0.31 + w.z * 0.17), 0.0, cos(t * 0.93 + w.z * 0.29)) * wind * h * (0.6 + gust);
	VERTEX += (inverse(mat3(MODEL_MATRIX)) * sway);
	VERTEX += NORMAL * sin(t * 3.7 + dot(w, vec3(2.3, 1.7, 3.1))) * 0.025 * wind * 8.0;
	wpos = w;
}

void fragment() {
	vec4 c = texture(albedo_tex, UV);
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ALPHA_ANTIALIASING_EDGE = 0.25;
	ALPHA_TEXTURE_COORDINATE = UV * vec2(textureSize(albedo_tex, 0));
	if (!FRONT_FACING) { NORMAL = -NORMAL; }  // keep the crown-shaped normals on both sides
	float v = fract(sin(dot(floor(wpos * 0.7), vec3(12.9898, 78.233, 37.719))) * 43758.5453);
	float ao = mix(1.0, COLOR.r, ao_strength);
	ALBEDO = c.rgb * tint.rgb * (1.0 + (v - 0.5) * var_amount * 2.0) * ao;
	ROUGHNESS = roughness;
	SPECULAR = 0.25;
	BACKLIGHT = backlight_col * translucency * ao;
	AO = ao;
	AO_LIGHT_AFFECT = 0.3;
}
