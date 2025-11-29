shader_type spatial;
uniform sampler2D albedo: source_color;
uniform sampler2D normal: source_color;

void fragment() {
	ALBEDO = texture(albedo, UV).rgb;
	NORMAL_MAP = texture(normal, UV).rgb;
}