shader_type canvas_item;

uniform sampler2D color_gradient;
uniform sampler2D effect_texture;
uniform vec2 effect_texture_size;

void fragment() {
	float value = texture(effect_texture, UV).r;
	vec3 albedo = texture(color_gradient,vec2(clamp(value, 0.01, 0.99), 0.0)).rgb;
	COLOR.rgb = albedo;
}
