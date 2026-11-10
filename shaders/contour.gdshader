shader_type spatial;
render_mode unshaded, cull_front;
// Contour à l'encre : la silhouette gonflée le long des normales, dont on ne voit que l'envers.

uniform vec4 color : source_color = vec4(0.11, 0.11, 0.11, 1.0);
uniform float width = 0.012;

void vertex() {
	VERTEX += NORMAL * width;
}

void fragment() {
	ALBEDO = color.rgb;
}
