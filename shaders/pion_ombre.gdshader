shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
// Ombre portée d'un pion en carton : sa silhouette couchée sur le sol.

uniform sampler2D atlas : filter_linear_mipmap, repeat_disable;
uniform float frames = 5.0;
uniform float frame = 0.0;
uniform float flip = 0.0;
uniform float strength = 0.3;

void fragment() {
	vec2 uv = UV;
	if (flip > 0.5) {
		uv.x = 1.0 - uv.x;
	}
	float a = texture(atlas, vec2((frame + clamp(uv.x, 0.002, 0.998)) / frames, uv.y)).a;
	ALBEDO = vec3(0.06, 0.04, 0.12);
	// L'ombre s'estompe en s'éloignant des pieds.
	ALPHA = a * strength * mix(0.45, 1.0, uv.y);
}
