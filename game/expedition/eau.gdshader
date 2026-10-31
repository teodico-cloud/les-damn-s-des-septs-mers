// Eau du quai : des vagues qui grossissent pendant le départ de la chaloupe (« houle » de 0 à 1),
// creux sombres, crêtes plus claires et un peu d'écume. Léger : trois sinus, normale calculée d'après eux.
shader_type spatial;

uniform float houle = 0.0;
uniform vec4 couleur : source_color = vec4(0.05, 0.2, 0.24, 1.0);
uniform vec4 ecume : source_color = vec4(0.55, 0.75, 0.72, 1.0);

varying float hauteur;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float a = 0.06 + 0.3 * houle;
	float p1 = w.x * 1.3 + TIME * 1.7;
	float p2 = w.z * 0.9 - TIME * 1.2;
	float p3 = (w.x + w.z) * 2.1 + TIME * 2.6;
	hauteur = 0.6 * sin(p1) + 0.4 * sin(p2) + 0.35 * houle * sin(p3);
	VERTEX.y += hauteur * a;
	float dx = 0.6 * 1.3 * cos(p1) + 0.35 * houle * 2.1 * cos(p3);
	float dz = 0.4 * 0.9 * cos(p2) + 0.35 * houle * 2.1 * cos(p3);
	NORMAL = normalize(vec3(-a * dx, 1.0, -a * dz));
}

void fragment() {
	float t = clamp(hauteur * 0.5 + 0.5, 0.0, 1.0);
	vec3 fond = mix(couleur.rgb * 0.55, couleur.rgb * 1.9, t);
	float e = smoothstep(0.55, 1.05, hauteur) * (0.35 + 0.65 * houle);
	ALBEDO = mix(fond, ecume.rgb, e);
	METALLIC = 0.4;
	ROUGHNESS = 0.18;
	EMISSION = fond * 0.45 + ecume.rgb * e * 0.3;
}
