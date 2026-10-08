shader_type canvas_item;
// Нуар-фильтр поверх 3D-картинки: почти чёрно-белый кадр, но красное
// (кровь, огонь, бочки) остаётся цветным. Плюс контраст, виньетка и зерно плёнки.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float saturation : hint_range(0.0, 1.0) = 0.12;
uniform float red_keep : hint_range(0.0, 1.0) = 1.0;
uniform float contrast : hint_range(0.5, 2.0) = 1.25;
uniform float pivot : hint_range(0.0, 1.0) = 0.3;  // тёмное темнеет меньше, светлое ярче
uniform float brightness : hint_range(0.5, 1.5) = 1.18;
uniform float lift : hint_range(0.0, 0.2) = 0.03;  // приподнять самые тёмные места, чтобы не было «дыр»
uniform float vignette : hint_range(0.0, 2.0) = 0.9;
uniform float grain : hint_range(0.0, 0.2) = 0.035;
uniform vec3 tint : source_color = vec3(0.94, 0.97, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 c = texture(screen_texture, SCREEN_UV).rgb;
	float luma = dot(c, vec3(0.299, 0.587, 0.114));
	float redness = smoothstep(0.3, 0.6, (c.r - max(c.g, c.b)) / max(c.r, 0.02)) * smoothstep(0.03, 0.12, c.r);
	vec3 col = mix(vec3(luma) * tint, c, mix(saturation, 1.0, redness * red_keep));
	col = (col - pivot) * contrast + pivot;
	col *= brightness;
	col = col * (1.0 - lift) + lift;
	vec2 d = UV - 0.5;
	col *= clamp(1.0 - dot(d, d) * vignette * 1.6, 0.0, 1.0);
	col += (hash(floor(UV * 480.0) + fract(TIME) * 61.0) - 0.5) * grain;
	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
