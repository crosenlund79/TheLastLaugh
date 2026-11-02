// Still shrine pond: a dark, glossy mirror (opaque so screen-space reflections apply),
// with slow layered ripples and a faint green body colour.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap;
uniform vec3 body : source_color = vec3(0.025, 0.045, 0.04);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv1 = wpos.xz * 0.16 + vec2(TIME * 0.010, TIME * 0.006);
	vec2 uv2 = wpos.xz * 0.37 - vec2(TIME * 0.008, -TIME * 0.012);
	vec3 n = normalize((texture(normal_tex, uv1).rgb * 2.0 - 1.0) + (texture(normal_tex, uv2).rgb * 2.0 - 1.0));
	NORMAL_MAP = n * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.18;
	ALBEDO = body;
	ROUGHNESS = 0.035;
	METALLIC = 0.0;
	SPECULAR = 0.55;
}
