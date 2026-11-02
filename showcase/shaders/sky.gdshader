// Golden-hour sky: graded dome, sun disc + bloom halo, lit cirrus and drifting cumulus.
shader_type sky;


uniform vec3 zenith : source_color = vec3(0.16, 0.24, 0.48);
uniform vec3 upper : source_color = vec3(0.42, 0.42, 0.62);
uniform vec3 horizon_warm : source_color = vec3(1.0, 0.62, 0.34);
uniform vec3 horizon_cool : source_color = vec3(0.86, 0.58, 0.62);
uniform vec3 ground : source_color = vec3(0.22, 0.2, 0.24);
uniform vec3 sun_col : source_color = vec3(1.0, 0.82, 0.55);
uniform float cloud_amount = 0.55;

float h2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1, 0)), f.x), mix(h2(i + vec2(0, 1)), h2(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 6; i++) { v += vn(p) * a; p = p * 2.03 + vec2(1.7, 9.2); a *= 0.5; }
	return v;
}

void sky() {
	vec3 d = EYEDIR;
	vec3 sd = LIGHT0_DIRECTION;
	float el = d.y;
	float sun_dot = max(dot(d, sd), 0.0);
	float az = max(dot(normalize(d.xz + 1e-4), normalize(sd.xz + 1e-4)), 0.0);
	vec3 hz = mix(horizon_cool, horizon_warm, pow(az, 1.5));
	vec3 col;
	if (el >= 0.0) {
		col = mix(hz, upper, smoothstep(0.0, 0.25, el));
		col = mix(col, zenith, smoothstep(0.2, 0.9, el));
	} else {
		col = mix(hz * 0.85, ground, smoothstep(0.0, 0.25, -el));
	}
	// atmospheric glow around the sun
	col += sun_col * (pow(sun_dot, 8.0) * 0.55 + pow(sun_dot, 64.0) * 0.8);
	{
		// clouds on a curved plane
		if (el > 0.005) {
			vec2 cp = d.xz / (el + 0.12) * 1.4 + vec2(TIME * 0.004, TIME * 0.0015);
			float c = fbm(cp * 1.2);
			float cir = fbm(vec2(cp.x * 0.5, cp.y * 3.0) + 4.0);
			float cov = smoothstep(1.0 - cloud_amount, 1.05 - cloud_amount * 0.4, c);
			float wisps = smoothstep(0.55, 0.85, cir) * 0.45 * smoothstep(0.03, 0.2, el);
			float shade = fbm(cp * 1.2 + sd.xz * 0.08);
			vec3 lit = mix(vec3(0.62, 0.5, 0.6), sun_col * 1.25, clamp((c - shade) * 4.0 + 0.5, 0.0, 1.0));
			lit = mix(lit, sun_col * 1.6, pow(sun_dot, 6.0) * 0.6);
			float fade = smoothstep(0.0, 0.08, el) * (1.0 - smoothstep(0.55, 0.95, el) * 0.5);
			col = mix(col, lit, (cov * 0.85 + wisps) * fade);
		}
	}
	// the sun itself (only on the full-res pass for crisp edges)
	float disc = smoothstep(0.99955, 0.99975, sun_dot);
	col += sun_col * disc * 14.0;
	COLOR = col;
}
