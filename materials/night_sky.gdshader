shader_type sky;
// Ночное небо города: тёмный градиент с засветкой у горизонта, звёзды и луна.

uniform vec3 top_color : source_color = vec3(0.01, 0.014, 0.035);
uniform vec3 horizon_color : source_color = vec3(0.09, 0.09, 0.13);
uniform vec3 ground_color : source_color = vec3(0.015, 0.015, 0.02);
uniform vec3 moon_direction = vec3(-0.4, 0.55, -0.73);
uniform vec3 moon_color : source_color = vec3(0.95, 0.95, 0.88);
uniform float star_density : hint_range(0.0, 0.05) = 0.006;

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	vec3 col = mix(horizon_color, top_color, smoothstep(0.0, 0.55, dir.y));
	if (dir.y < 0.0) {
		col = mix(horizon_color, ground_color, smoothstep(0.0, 0.15, -dir.y));
	}
	vec3 cell = floor(dir * 240.0);
	float star = step(1.0 - star_density, hash(cell)) * smoothstep(0.05, 0.3, dir.y);
	col += vec3(star) * (0.4 + 0.6 * hash(cell + 13.0));
	float moon = dot(dir, normalize(moon_direction));
	col += moon_color * smoothstep(0.99935, 0.9996, moon);
	col += vec3(0.1, 0.12, 0.18) * pow(max(moon, 0.0), 80.0);
	COLOR = col;
}
