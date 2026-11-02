// World-space triplanar stone with moss settling on up-facing surfaces (and in crevices).
shader_type spatial;
render_mode diffuse_burley;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D rough_tex : hint_default_white, filter_linear_mipmap_anisotropic;
uniform sampler2D moss_tex : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 tint : source_color = vec4(1.0);
uniform float scale = 0.6;
uniform float moss_amount = 0.5;
uniform float moss_height = 99.0;   // moss fades out above this world height
uniform bool object_space = false;
uniform float cell = 0.0;          // > 0: tonal variation per cell (e.g. individual stair treads)

varying vec3 ppos;
varying vec3 pnrm;
varying vec3 wnrm;

void vertex() {
	if (object_space) {
		ppos = VERTEX;
		pnrm = NORMAL;
	} else {
		ppos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		pnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	}
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec4 tri(sampler2D t, vec3 p, vec3 w) {
	return texture(t, p.zy) * w.x + texture(t, p.xz) * w.y + texture(t, p.xy) * w.z;
}

void fragment() {
	vec3 bw = pow(abs(pnrm), vec3(4.0));
	bw /= (bw.x + bw.y + bw.z);
	vec3 p = ppos * scale;
	vec3 a = tri(albedo_tex, p, bw).rgb * tint.rgb;
	vec3 n = tri(normal_tex, p, bw).rgb;
	float r = tri(rough_tex, p, bw).r;
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float lum = dot(a, vec3(0.33));
	float up = smoothstep(0.35, 0.95, wnrm.y);
	float mvar = texture(moss_tex, wp.xz * 0.11).g * 2.0;
	float moss = clamp(up * moss_amount * 1.6 * mvar + (0.45 - lum) * moss_amount * 0.6, 0.0, 1.0);
	moss *= 1.0 - smoothstep(moss_height - 0.5, moss_height + 0.5, wp.y);
	moss = smoothstep(0.35, 0.65, moss);
	vec3 m = texture(moss_tex, wp.xz * 0.9).rgb;
	if (cell > 0.0) {
		float hv = fract(sin(dot(floor(wp.xz / cell), vec2(12.9898, 78.233))) * 43758.5453);
		a *= 0.82 + hv * 0.3;
		// treads are worn smooth and pale along the walking line, darker toward the edges
		float walk = smoothstep(1.4, 0.3, abs(wp.x));
		a = mix(a * 0.88, a * 1.06, walk * up);
		moss *= 1.0 - walk * 0.7;
		moss = max(moss, smoothstep(1.2, 1.65, abs(wp.x)) * up * 0.8);
	}
	ALBEDO = mix(a, m, moss);
	NORMAL_MAP = mix(n, vec3(0.5, 0.5, 1.0), moss * 0.6);
	ROUGHNESS = mix(r, 0.95, moss);
	SPECULAR = 0.4;
}
