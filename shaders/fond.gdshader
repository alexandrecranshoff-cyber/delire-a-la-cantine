shader_type spatial;
render_mode unshaded, cull_disabled;

// Fond autour du plateau : violet de nuit qui s'assombrit loin de la salle, avec une trame
// de points façon impression BD, pour ne pas poser le jeu sur un aplat uni.
uniform vec3 center = vec3(0.0);
uniform vec2 half_size = vec2(20.0, 14.0);
uniform vec4 near_color : source_color = vec4(0.33, 0.26, 0.42, 1.0);
uniform vec4 far_color : source_color = vec4(0.13, 0.1, 0.18, 1.0);
uniform vec4 dot_color : source_color = vec4(0.45, 0.36, 0.55, 1.0);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 d = abs(world_pos.xz - center.xz) - half_size;
	float dist = length(max(d, vec2(0.0)));
	float t = smoothstep(0.0, 22.0, dist);
	vec3 col = mix(near_color.rgb, far_color.rgb, t);
	// Trame décalée : un point tous les 0,6 unité, plus petit en s'éloignant.
	vec2 g = world_pos.xz / 0.6;
	g.x += 0.5 * mod(floor(g.y), 2.0);
	float r = length(fract(g) - 0.5);
	float dots = 1.0 - smoothstep(0.17 * (1.0 - t) , 0.17 * (1.0 - t) + 0.05, r);
	col = mix(col, dot_color.rgb, dots * 0.35 * (1.0 - t));
	ALBEDO = col;
}
