// Terrain: grass / moss / dirt / cliff blended by baked vertex weights (COLOR) and slope,
// with two-scale sampling to hide tiling.
shader_type spatial;
render_mode diffuse_burley;

uniform sampler2D grass_a : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D grass_n : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D moss_a : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D moss_n : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D dirt_a : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D dirt_n : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D cliff_a : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D cliff_n : hint_normal, filter_linear_mipmap_anisotropic;
uniform float scale = 0.22;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec4 two_scale(sampler2D t, vec2 uv) {
	return mix(texture(t, uv), texture(t, uv * 0.193 + 0.37), 0.4);
}

void fragment() {
	vec2 uv = wpos.xz * scale;
	vec3 g = two_scale(grass_a, uv).rgb;
	vec3 m = two_scale(moss_a, uv * 1.3).rgb;
	vec3 d = two_scale(dirt_a, uv * 1.4).rgb;
	// cliff: triplanar on the two vertical axes
	vec3 bw = pow(abs(wnrm), vec3(4.0));
	bw /= (bw.x + bw.y + bw.z);
	vec3 c = texture(cliff_a, wpos.zy * 0.12).rgb * bw.x + texture(cliff_a, wpos.xz * 0.12).rgb * bw.y + texture(cliff_a, wpos.xy * 0.12).rgb * bw.z;
	float slope = 1.0 - clamp(wnrm.y, 0.0, 1.0);
	float rock = clamp(COLOR.b + smoothstep(0.32, 0.5, slope), 0.0, 1.0);
	float path = COLOR.r;
	float moss = COLOR.g * (1.0 - rock);
	// break up blend edges with texture luminance (height-ish blend)
	float hn = dot(g, vec3(0.33)) * 2.0;
	path = smoothstep(0.25, 0.75, path + (hn - 0.4) * 0.35);
	moss = smoothstep(0.2, 0.8, moss + (hn - 0.4) * 0.3);
	vec3 col = mix(g, m, moss);
	col = mix(col, d, path);
	col = mix(col, c, rock);
	vec3 n1 = texture(grass_n, uv).rgb;
	vec3 n2 = texture(moss_n, uv * 1.3).rgb;
	vec3 n3 = texture(dirt_n, uv * 1.4).rgb;
	vec3 n4 = texture(cliff_n, wpos.xy * 0.12).rgb;
	vec3 nn = mix(mix(mix(n1, n2, moss), n3, path), n4, rock);
	ALBEDO = col;
	NORMAL_MAP = nn;
	NORMAL_MAP_DEPTH = 1.0;
	ROUGHNESS = mix(0.92, 0.8, path);
	SPECULAR = 0.3;
}
