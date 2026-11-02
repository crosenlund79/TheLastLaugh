// Vermilion / black urushi lacquer: object-space triplanar texture, per-instance tonal
// variation (no two torii identical), and soot/grime creeping up from the base.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D rough_tex : hint_default_white, filter_linear_mipmap_anisotropic;
uniform vec4 tint : source_color = vec4(1.0);
uniform float scale = 0.9;
uniform float rough_bias = 0.0;
uniform float grime_height = 0.9;
uniform float variation = 0.14;
uniform float use_texture = 1.0;

varying vec3 opos;
varying vec3 onrm;

void vertex() {
	opos = VERTEX;
	onrm = NORMAL;
}

vec4 tri(sampler2D t, vec3 p, vec3 w) {
	return texture(t, p.zy) * w.x + texture(t, p.xz) * w.y + texture(t, p.xy) * w.z;
}

void fragment() {
	vec3 bw = pow(abs(onrm), vec3(4.0));
	bw /= (bw.x + bw.y + bw.z);
	vec3 p = opos * scale;
	vec3 a = mix(vec3(1.0), tri(albedo_tex, p, bw).rgb, use_texture) * tint.rgb;
	vec3 n = tri(normal_tex, p, bw).rgb;
	float r = tri(rough_tex, p, bw).r;
	float h = fract(sin(dot(floor(NODE_POSITION_WORLD * 3.0), vec3(12.9898, 78.233, 37.719))) * 43758.5453);
	a *= 1.0 + (h - 0.5) * variation * 2.0;
	a = mix(a, a * vec3(1.06, 0.92, 0.88), h * 0.5);               // some faded more than others
	float grime = 1.0 - smoothstep(0.0, grime_height, opos.y);
	a = mix(a, a * vec3(0.38, 0.33, 0.30), grime * 0.7);
	ALBEDO = a;
	NORMAL_MAP = n;
	ROUGHNESS = clamp(r + rough_bias + grime * 0.25 + (h - 0.5) * 0.15, 0.05, 1.0);
	SPECULAR = 0.5;
}
