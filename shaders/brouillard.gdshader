shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
// Brouillard de guerre façon BD : un voile violet tramé de points, à bords adoucis.
// La texture de visibilité a un texel par case : rouge = case cachée au sol, vert = table cachée.

uniform sampler2D hidden_map : filter_linear, repeat_disable;
uniform int channel = 0;                                    // 0 : sol, 1 : dessus des tables
uniform vec4 fog_color : source_color = vec4(0.09, 0.06, 0.16, 1.0);
uniform float opacity = 0.62;
uniform float dot_scale = 3.0;                              // points par mètre

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec4 m = texture(hidden_map, UV);
	float raw = channel == 0 ? m.r : m.g;
	float hidden = smoothstep(0.3, 0.7, raw);
	if (hidden < 0.01) {
		discard;
	}
	// Trame de points en quinconce, fixée au sol pour ne pas « nager » quand la caméra bouge.
	vec2 p = world_pos.xz * dot_scale;
	p.x += step(1.0, mod(floor(p.y), 2.0)) * 0.5;
	float d = length(fract(p) - 0.5);
	float dots = 1.0 - smoothstep(0.26, 0.32, d);
	ALBEDO = fog_color.rgb * (1.0 - dots * 0.45);
	ALPHA = hidden * (opacity + dots * 0.18);
}
