// Raked courtyard gravel (karesansui): straight combed lines that ripple around stones.
shader_type spatial;
render_mode diffuse_burley;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic;
uniform vec4 centers[6];   // xyz = centre, w = radius of ring zone

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float coord = wpos.z;
	float ringw = 0.0;
	for (int i = 0; i < 6; i++) {
		float dd = length(wpos.xz - centers[i].xz);
		float zone = 1.0 - smoothstep(centers[i].w, centers[i].w + 0.6, dd);
		if (zone > ringw) { ringw = zone; coord = mix(coord, dd, zone); }
	}
	float rake = sin(coord * 3.14159 * 2.0 / 0.17);
	vec2 uv = wpos.xz * 0.9;
	vec3 a = texture(albedo_tex, uv).rgb;
	vec3 n = texture(normal_tex, uv).rgb;
	a *= 0.86 + rake * 0.1;
	ALBEDO = a * 1.05;
	vec3 grad = vec3(0.0);
	NORMAL_MAP = normalize(n * 2.0 - 1.0 + vec3(0.0, cos(coord * 3.14159 * 2.0 / 0.17) * 0.6, 0.0)) * 0.5 + 0.5;
	ROUGHNESS = 0.9;
}
