shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_disabled;

// ============================================================
// ocean_shader.gdshader - DREAMY / OTHERWORLDLY
// Bioluminescent ocean dengan warna vivid dan pulse emission
// ============================================================

uniform float time : hint_range(0.0, 1000.0) = 0.0;
uniform float wave_amplitude : hint_range(0.0, 0.5) = 0.055;

// Warna air dreamy - ungu teal bioluminescent
uniform vec4 water_color_shallow : source_color = vec4(0.02, 0.28, 0.38, 0.95);
uniform vec4 water_color_deep    : source_color = vec4(0.04, 0.02, 0.22, 0.99);
uniform vec4 water_color_scatter : source_color = vec4(0.00, 0.55, 0.62, 1.0);

// Warna emission bioluminescent
uniform vec4 emission_color : source_color = vec4(0.00, 0.75, 0.85, 1.0);
uniform float emission_strength : hint_range(0.0, 1.0) = 0.18;

uniform float fresnel_power : hint_range(1.0, 10.0) = 4.5;

// Warna langit untuk refleksi - vivid magenta ke ungu
uniform vec4 sky_color_horizon : source_color = vec4(0.55, 0.08, 0.45, 1.0);
uniform vec4 sky_color_zenith  : source_color = vec4(0.05, 0.02, 0.18, 1.0);

// === VERTEX WAVES ===
float get_height(vec2 pos) {
	float t = time;
	float h  = sin(pos.x * 0.22 + t * 0.30) * cos(pos.y * 0.18 + t * 0.25);
	h += sin(pos.x * 0.35 + pos.y * 0.28 + t * 0.20) * 0.45;
	h += cos(pos.x * 0.12 + t * 0.18) * sin(pos.y * 0.14 + t * 0.22) * 0.22;
	h += sin(pos.x * 0.55 + pos.y * 0.48 + t * 0.38) * 0.12;
	return h * wave_amplitude;
}

vec3 get_normal(vec2 pos) {
	float eps = 0.4;
	float dx = get_height(pos + vec2(eps, 0.0)) - get_height(pos - vec2(eps, 0.0));
	float dz = get_height(pos + vec2(0.0, eps)) - get_height(pos - vec2(0.0, eps));
	return normalize(vec3(-dx, 2.0 * eps, -dz));
}

float cheap_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float fast_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(cheap_hash(i),              cheap_hash(i + vec2(1, 0)), u.x),
		mix(cheap_hash(i + vec2(0, 1)), cheap_hash(i + vec2(1, 1)), u.x),
		u.y
	);
}

// === VARYING ===
varying vec3 v_world_pos;
varying float v_wave_height;
varying vec3 v_wave_normal;
varying vec3 v_view_dir;

void vertex() {
	vec2 world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;

	float h = get_height(world_xz);
	VERTEX.y += h;
	v_wave_height = h;

	v_wave_normal = get_normal(world_xz);
	NORMAL   = v_wave_normal;
	TANGENT  = normalize(cross(vec3(0, 1, 0), NORMAL));
	BINORMAL = normalize(cross(NORMAL, TANGENT));

	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_view_dir  = normalize(CAMERA_POSITION_WORLD - v_world_pos);
}

void fragment() {
	vec2 xz = v_world_pos.xz;

	// Noise untuk variasi warna
	vec2 uv1 = xz * 0.06 + vec2(time * 0.006, time * 0.004);
	float n1 = fast_noise(uv1);

	// Noise kedua lebih besar untuk pola bioluminescent
	vec2 uv2 = xz * 0.025 + vec2(time * 0.003, -time * 0.002);
	float n2 = fast_noise(uv2);

	vec3 N = normalize(v_wave_normal);
	NORMAL = N;

	// Fresnel dramatis
	float NdotV  = max(dot(N, v_view_dir), 0.0);
	float fresnel = 0.04 + 0.96 * pow(1.0 - NdotV, fresnel_power);

	// Warna air vivid
	float wave_f  = clamp((v_wave_height / max(wave_amplitude, 0.001) + 1.0) * 0.5, 0.0, 1.0);
	float depth_v = clamp(n1 * 0.5 + 0.5, 0.0, 1.0);
	vec4 base_col = mix(water_color_deep, water_color_shallow, depth_v * 0.5 + wave_f * 0.4);
	base_col      = mix(base_col, water_color_scatter, n2 * 0.25);

	// Refleksi langit magenta/ungu
	float sky_l  = clamp(1.0 - v_view_dir.y, 0.0, 1.0);
	vec4 sky_ref = mix(sky_color_zenith, sky_color_horizon, sky_l);

	vec4 final_col = mix(base_col, sky_ref, clamp(fresnel * 0.75, 0.0, 1.0));

	// Pulse bioluminescent - efek "bernapas" lambat
	float pulse = sin(time * 0.4 + n2 * 6.28) * 0.5 + 0.5;
	float bio_emit = (wave_f * 0.6 + n2 * 0.4) * emission_strength;
	bio_emit *= (0.7 + pulse * 0.3);

	ALBEDO    = final_col.rgb;
	ALPHA     = mix(0.90, 0.99, fresnel);
	ROUGHNESS = 0.35;
	METALLIC  = 0.0;
	SPECULAR  = 0.0;
	EMISSION  = emission_color.rgb * bio_emit;
}
