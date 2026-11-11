shader_type spatial;
render_mode unshaded, cull_back;
// Personnage 3D façon BD : la texture porte déjà le trait et les couleurs, on ajoute un ombrage
// en deux tons (lumière venant des fenêtres), la teinte d'état et l'éclair quand il est touché.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 sun_dir = vec3(0.45, 0.8, 0.4);     // vers la lumière, dans le repère du monde
uniform vec4 shade_color : source_color = vec4(0.74, 0.72, 0.86, 1.0);
uniform vec4 tint : source_color = vec4(1.0);
uniform float tint_amount = 0.0;
uniform float flash = 0.0;
uniform float saturation = 1.18;                 // un peu plus vif que le décor, pour ressortir
uniform float dim = 0.0;                          // assombri (a déjà tout dépensé)

varying vec3 world_normal;

void vertex() {
	world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	vec3 col = texture(albedo_tex, UV).rgb;
	float lit = smoothstep(-0.04, 0.06, dot(normalize(world_normal), normalize(sun_dir)));
	col *= mix(shade_color.rgb, vec3(1.0), lit);
	col = mix(vec3(dot(col, vec3(0.299, 0.587, 0.114))), col, saturation);
	float grey = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, tint.rgb * (0.35 + grey * 0.9), tint_amount);
	col = mix(col, vec3(1.0), flash);
	col = mix(col, col * 0.62, dim);
	ALBEDO = col;
}
