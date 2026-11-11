shader_type spatial;
render_mode unshaded, cull_front;
// Contour à l'encre : la silhouette gonflée le long des normales, dont on ne voit que l'envers.
// La largeur est donnée en mètres dans le monde : on divise par l'échelle du modèle, car les
// squelettes sortent de l'atelier 3D en centimètres (nœud parent à l'échelle 0,01).

uniform vec4 color : source_color = vec4(0.11, 0.11, 0.11, 1.0);
uniform float width = 0.012;
// Recul de la coque derrière le modèle (mètres, vers le fond de l'image) : là où les normales
// sont cassées (cheveux frisés, plis du visage), la coque gonflée ne perce plus la surface.
// On ne garde ainsi que le trait de la silhouette.
uniform float depth_push = 0.06;

void vertex() {
	float model_scale = max(length(MODEL_MATRIX[0].xyz), 0.0001);
	VERTEX += normalize(NORMAL) * width / model_scale;
	vec4 view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	view.z -= depth_push;  // caméra orthographique : le fond est vers -Z
	POSITION = PROJECTION_MATRIX * view;
}

void fragment() {
	ALBEDO = color.rgb;
}
