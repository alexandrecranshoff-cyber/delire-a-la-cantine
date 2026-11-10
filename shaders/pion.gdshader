shader_type spatial;
render_mode unshaded, cull_disabled;
// Pion en carton : une vue de la planche (5 vues côte à côte), détourée,
// avec un liseré de la couleur de la bande et un trait d'encre autour.

uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform float frames = 5.0;
uniform float frame = 0.0;
uniform float flip = 0.0;
uniform float aspect = 0.5;          // largeur / hauteur d'une vue
uniform vec4 border_color : source_color = vec4(1.0);
uniform float border = 0.016;        // épaisseur du liseré, en fraction de la hauteur
uniform vec4 tint : source_color = vec4(1.0);
uniform float tint_amount = 0.0;
uniform float flash = 0.0;
uniform float dim = 0.0;             // assombri (a déjà tout dépensé)

float alpha_at(vec2 uv) {
	uv = clamp(uv, vec2(0.002), vec2(0.998));
	return texture(atlas, vec2((frame + uv.x) / frames, uv.y)).a;
}

void fragment() {
	vec2 uv = UV;
	if (flip > 0.5) {
		uv.x = 1.0 - uv.x;
	}
	vec4 c = texture(atlas, vec2((frame + clamp(uv.x, 0.002, 0.998)) / frames, uv.y));
	vec3 col = c.rgb;
	if (c.a < 0.5) {
		float near = 0.0;
		float far = 0.0;
		for (int i = 0; i < 8; i++) {
			float a = float(i) * 0.7853982;
			vec2 dir = vec2(cos(a) / aspect, sin(a));
			near = max(near, alpha_at(uv + dir * border));
			far = max(far, alpha_at(uv + dir * border * 1.45));
		}
		if (near >= 0.5) {
			col = border_color.rgb;
		} else if (far >= 0.5) {
			col = vec3(0.11);
		} else {
			discard;
		}
	} else {
		float grey = dot(col, vec3(0.299, 0.587, 0.114));
		col = mix(col, tint.rgb * (0.35 + grey * 0.9), tint_amount);
	}
	col = mix(col, vec3(1.0), flash);
	col = mix(col, col * 0.62, dim);
	ALBEDO = col;
}
