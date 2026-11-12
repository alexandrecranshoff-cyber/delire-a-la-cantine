shader_type spatial;
render_mode unshaded, cull_back;
// Personnage 3D façon BD : la texture porte déjà le trait et les couleurs, on ajoute un ombrage
// en deux tons (lumière venant des fenêtres), la teinte d'état et l'éclair quand il est touché.
// Les habits du haut sont repeints à la couleur de la bande, et les taches de nourriture sont
// peintes sur le tissu même : elles suivent les plis, l'ombrage et les gestes du personnage.

const int MAX_STAINS = 20;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 sun_dir = vec3(0.45, 0.8, 0.4);     // vers la lumière, dans le repère du monde
uniform vec4 shade_color : source_color = vec4(0.74, 0.72, 0.86, 1.0);
uniform vec4 tint : source_color = vec4(1.0);
uniform float tint_amount = 0.0;
uniform float flash = 0.0;
uniform float saturation = 1.18;                 // un peu plus vif que le décor, pour ressortir
uniform float dim = 0.0;                          // assombri (a déjà tout dépensé)

// Habits de la bande : masque (blanc = habit), couleur, et luminosité moyenne de l'habit d'origine.
uniform sampler2D cloth_mask : filter_linear_mipmap, repeat_disable, hint_default_black;
uniform vec4 cloth_color : source_color = vec4(1.0);
uniform float cloth_amount = 0.0;
uniform float cloth_ref = 0.4;

// Taches, dans le repère du modèle au repos : centre et rayon (0 = pas de tache), couleur et
// opacité, normale de la surface touchée et graine du contour.
uniform vec4 stain_pos[MAX_STAINS];
uniform vec4 stain_col[MAX_STAINS];
uniform vec4 stain_nrm[MAX_STAINS];

varying vec3 world_normal;
varying vec3 rest_pos;
varying vec3 rest_nrm;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
	// Position et normale au repos, posées sur le maillage au chargement (GameAssets) : la tache
	// reste au même endroit du vêtement quand le personnage bouge.
	rest_pos = CUSTOM0.xyz;
	rest_nrm = CUSTOM1.xyz;
}

void fragment() {
	vec3 col = texture(albedo_tex, UV).rgb;

	// Habits : on garde les plis et les rayures (la luminosité) et on prend la teinte de la bande.
	float cloth = texture(cloth_mask, UV).r * cloth_amount;
	if (cloth > 0.001) {
		float lum = dot(col, vec3(0.299, 0.587, 0.114));
		float k = lum / cloth_ref;
		vec3 dyed = cloth_color.rgb * min(k, 1.0) + (vec3(1.0) - cloth_color.rgb) * clamp(k - 1.0, 0.0, 1.0) * 0.55;
		col = mix(col, dyed, cloth);
	}

	// Taches : contour irrégulier, bord plus foncé, coulure, quelques reflets mouillés.
	float wet = 0.0;
	for (int i = 0; i < MAX_STAINS; i++) {
		vec4 sp = stain_pos[i];
		if (sp.w <= 0.0) {
			continue;
		}
		vec3 rel = rest_pos - sp.xyz;
		// La nourriture coule un peu vers le bas : la tache s'étire sous son centre.
		rel.y *= rel.y < 0.0 ? 0.62 : 1.0;
		float d = length(rel) / sp.w;
		if (d > 1.6) {
			continue;
		}
		vec4 sn = stain_nrm[i];
		vec3 q = rest_pos * 34.0 + sn.w * 13.7;
		float n = noise(q) * 0.65 + noise(q * 2.3) * 0.35;
		float edge = d + (n - 0.5) * 0.7;
		float facing = smoothstep(-0.15, 0.3, dot(normalize(rest_nrm), sn.xyz));
		float cover = (1.0 - smoothstep(0.86, 0.98, edge)) * facing;
		if (cover <= 0.0) {
			continue;
		}
		vec4 sc = stain_col[i];
		float rim = smoothstep(0.62, 0.9, edge);
		// Grumeaux : petites variations claires et sombres dans la matière.
		float lumps = noise(q * 3.1) - 0.5;
		vec3 paint = sc.rgb * (1.0 - 0.38 * rim) * (1.0 + lumps * 0.22);
		col = mix(col, paint, cover * sc.a);
		// Reflet de BD : un petit éclat ovale au-dessus du centre des grosses taches.
		if (sp.w > 0.05) {
			vec3 g = rest_pos - (sp.xyz + vec3(0.18, 0.32, 0.0) * sp.w);
			float dg = length(g * vec3(1.0, 1.6, 1.0)) / (0.2 * sp.w);
			wet = max(wet, cover * sc.a * (1.0 - smoothstep(0.6, 1.0, dg)));
		}
	}

	float lit = smoothstep(-0.04, 0.06, dot(normalize(world_normal), normalize(sun_dir)));
	col *= mix(shade_color.rgb, vec3(1.0), lit);
	// Reflet de BD : un éclat blanc là où la tache regarde la lumière.
	col = mix(col, vec3(1.0), wet * lit * 0.75);
	col = mix(vec3(dot(col, vec3(0.299, 0.587, 0.114))), col, saturation);
	float grey = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, tint.rgb * (0.35 + grey * 0.9), tint_amount);
	col = mix(col, vec3(1.0), flash);
	col = mix(col, col * 0.62, dim);
	ALBEDO = col;
}
