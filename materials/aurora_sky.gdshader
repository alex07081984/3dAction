shader_type sky;
// Ночное небо Аляски: звёзды, луна и северное сияние — колышущиеся полосы у горизонта.

uniform vec3 top_color : source_color = vec3(0.01, 0.015, 0.035);
uniform vec3 horizon_color : source_color = vec3(0.08, 0.09, 0.12);
uniform vec3 ground_color : source_color = vec3(0.6, 0.62, 0.68);
uniform vec3 aurora_color : source_color = vec3(0.25, 1.0, 0.55);
uniform vec3 moon_direction = vec3(0.4, 0.5, -0.76);
uniform float star_density : hint_range(0.0, 0.05) = 0.007;

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	vec3 col = mix(horizon_color, top_color, smoothstep(0.0, 0.55, dir.y));
	if (dir.y < 0.0) {
		col = mix(horizon_color, ground_color * 0.2, smoothstep(0.0, 0.2, -dir.y));
	}
	vec3 cell = floor(dir * 240.0);
	col += vec3(step(1.0 - star_density, hash(cell)) * smoothstep(0.05, 0.3, dir.y)) * (0.4 + 0.6 * hash(cell + 13.0));
	float angle = atan(dir.x, dir.z);
	float band = sin(angle * 3.0 + TIME * 0.05) * 0.08 + sin(angle * 7.0 - TIME * 0.11) * 0.04 + 0.32;
	float curtain = exp(-pow((dir.y - band) * 9.0, 2.0)) * (0.55 + 0.45 * sin(angle * 23.0 + TIME * 0.3));
	col += aurora_color * curtain * smoothstep(0.05, 0.2, dir.y) * 0.45;
	float moon = dot(dir, normalize(moon_direction));
	col += vec3(0.95, 0.95, 0.88) * smoothstep(0.99935, 0.9996, moon);
	col += vec3(0.1, 0.12, 0.18) * pow(max(moon, 0.0), 80.0);
	COLOR = col;
}
