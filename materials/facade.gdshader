shader_type spatial;
// Фасад дома ночью: штукатурка с окнами по мировым координатам (трипланарно),
// часть окон светится. Свой шейдер, потому что в рендере Compatibility
// стандартный материал не умеет трипланарную текстуру свечения.

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D lit_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform float scale = 0.1;  // одна текстура — 10 м стены
uniform vec4 window_light : source_color = vec4(1.0, 0.86, 0.62, 1.0);
uniform float light_energy = 1.6;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.85;

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec3 triplanar(sampler2D tex, vec3 p, vec3 w) {
	return texture(tex, vec2(p.z, -p.y)).rgb * w.x
			+ texture(tex, p.xz).rgb * w.y
			+ texture(tex, vec2(p.x, -p.y)).rgb * w.z;
}

void fragment() {
	vec3 w = pow(abs(world_normal), vec3(4.0));
	w /= w.x + w.y + w.z;
	vec3 p = world_position * scale;
	ALBEDO = albedo.rgb * triplanar(albedo_texture, p, w);
	ROUGHNESS = roughness_value;
	EMISSION = window_light.rgb * triplanar(lit_texture, p, w) * light_energy;
}
