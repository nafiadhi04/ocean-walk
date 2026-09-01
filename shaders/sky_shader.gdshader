shader_type sky;

// ============================================================
// sky_shader.gdshader - DREAMY / OTHERWORLDLY
// Langit ungu gelap ke magenta vivid, awan bercahaya lavender
// ============================================================

uniform float time : hint_range(0.0, 10000.0) = 0.0;
// Zenith sangat gelap - hampir hitam keunguan
uniform vec4 sky_color_zenith  : source_color = vec4(0.04, 0.01, 0.12, 1.0);
// Horizon vivid magenta/pink uncanny
uniform vec4 sky_color_horizon : source_color = vec4(0.62, 0.08, 0.55, 1.0);
// Awan lavender bercahaya
uniform vec4 cloud_color_light  : source_color = vec4(0.78, 0.60, 1.00, 1.0);
uniform vec4 cloud_color_shadow : source_color = vec4(0.28, 0.12, 0.45, 1.0);
uniform float cloud_speed   : hint_range(0.0, 0.05) = 0.006;
uniform float cloud_scale   : hint_range(0.5, 8.0)  = 1.4;
uniform float cloud_density : hint_range(0.0, 1.0)  = 0.45;
uniform float cloud_softness: hint_range(0.0, 1.0)  = 0.65;

// === HASH & NOISE ===
// Hash yang lebih baik - tidak menghasilkan pola diagonal
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(443.897, 441.423, 437.195));
	p3 += dot(p3, p3.yzx + 19.19);
	return fract((p3.x + p3.y) * p3.z);
}

float smoothnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	// Quintic interpolation - jauh lebih smooth dari cubic
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	return mix(
		mix(hash(i),               hash(i + vec2(1,0)), u.x),
		mix(hash(i + vec2(0,1)),   hash(i + vec2(1,1)), u.x),
		u.y
	);
}

float fbm(vec2 p) {
	float val = 0.0;
	float amp = 0.5;
	float freq = 1.0;
	for (int i = 0; i < 3; i++) {
		val += smoothnoise(p * freq) * amp;
		amp  *= 0.5;
		freq *= 2.1;
	}
	return val;
}

float get_clouds(vec2 uv) {
	vec2 drift = vec2(time * cloud_speed, time * cloud_speed * 0.4);
	// Domain warping - sample offset dulu sebelum sample utama
	// Ini menghilangkan pola grid/radial artifact
	vec2 warp = vec2(
		fbm(uv * cloud_scale * 0.8 + drift + vec2(1.7, 9.2)),
		fbm(uv * cloud_scale * 0.8 + drift + vec2(8.3, 2.8))
	);
	float n = fbm(uv * cloud_scale + drift + warp * 0.5);
	return smoothstep(cloud_density - cloud_softness, cloud_density + cloud_softness, n);
}

void sky() {
	vec3 dir = EYEDIR;

	// Gradient langit - zenith hitam keunguan ke horizon magenta
	float horizon_factor = clamp(1.0 - dir.y, 0.0, 1.0);
	horizon_factor = pow(horizon_factor, 0.5);
	vec3 sky = mix(sky_color_zenith.rgb, sky_color_horizon.rgb, horizon_factor);

	// Pita cahaya tipis di horizon - natural
	float horizon_glow = pow(clamp(1.0 - abs(dir.y) / 0.18, 0.0, 1.0), 2.0);
	sky += vec3(0.55, 0.72, 0.95) * horizon_glow * 0.3;

	// Awan - kembali ke perspective projection tapi dengan domain warping
	if (dir.y > 0.01) {
		vec2 cloud_uv = dir.xz / (dir.y + 0.3);
		float cloud = get_clouds(cloud_uv);

		float cloud_light = clamp(dir.y * 0.4 + 0.65, 0.0, 1.0);
		vec3 cloud_col = mix(cloud_color_shadow.rgb, cloud_color_light.rgb, cloud_light);

		float fade = clamp((dir.y - 0.01) / 0.30, 0.0, 1.0);
		cloud *= fade;

		sky = mix(sky, cloud_col, cloud * 0.88);
	}

	COLOR = sky;
}
