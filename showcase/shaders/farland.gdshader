// Distant hills: lumpy cedar-forest canopy (world-space noise relief) with bare rock on
// steep slopes. Seen only through aerial perspective, so it trades texture for form.
shader_type spatial;
render_mode diffuse_burley;

uniform vec3 canopy_dark : source_color = vec3(0.04, 0.07, 0.04);
uniform vec3 canopy_lit : source_color = vec3(0.12, 0.18, 0.08);
uniform vec3 rock : source_color = vec3(0.24, 0.22, 0.21);
uniform vec3 sun_dir = vec3(-0.6, 0.3, 0.74);

varying vec3 wpos;
varying vec3 wnrm;

float h2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1, 0)), f.x), mix(h2(i + vec2(0, 1)), h2(i + vec2(1, 1)), f.x), f.y);
}
float crowns(vec2 p) { return vn(p * 0.35) * 0.6 + vn(p * 0.9) * 0.3 + vn(p * 2.1) * 0.1; }

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float c = crowns(wpos.xz);
	float e = 0.6;
	vec2 g = vec2(crowns(wpos.xz + vec2(e, 0.0)) - c, crowns(wpos.xz + vec2(0.0, e)) - c) / e;
	vec3 n = normalize(wnrm + vec3(-g.x, 0.0, -g.y) * 6.0);
	float slope = 1.0 - clamp(wnrm.y, 0.0, 1.0);
	float rocky = smoothstep(0.45, 0.65, slope + (c - 0.5) * 0.3);
	vec3 col = mix(canopy_dark, canopy_lit, smoothstep(0.35, 0.75, c));
	col = mix(col, rock, rocky);
	ALBEDO = col;
	NORMAL = normalize((VIEW_MATRIX * vec4(mix(n, wnrm, rocky), 0.0)).xyz);
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}
