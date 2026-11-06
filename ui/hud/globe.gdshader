// Globe de la jauge façon Diablo (06/11, choix de Téo) : une boule de verre sombre où monte un liquide (Fureur rouge
// sang du Bretteur, Âmes vertes de l'Occultiste), avec une vague à la surface, des remous, l'ombre du bord et un
// reflet. Voir GlobeJauge.
shader_type canvas_item;

uniform float niveau : hint_range(0.0, 1.0) = 0.5;
uniform vec4 couleur : source_color = vec4(0.78, 0.08, 0.06, 1.0);
uniform float eclat = 0.0;   // un éclair bref quand la compétence redevient possible

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	float y = 1.0 - UV.y;   // 0 en bas, 1 en haut
	vec3 fond = mix(vec3(0.06, 0.04, 0.035), vec3(0.012, 0.008, 0.008), d);
	float vague = 0.0;
	if (niveau > 0.002 && niveau < 0.998) {
		vague = 0.02 * sin(UV.x * 9.0 + TIME * 2.2) + 0.012 * sin(UV.x * 17.0 - TIME * 3.1);
	}
	float surface = niveau + vague;
	float dans = step(y, surface);
	float remous = 0.5 + 0.5 * sin(p.x * 6.0 + TIME * 0.9 + sin(p.y * 5.0 - TIME * 1.3) * 1.8);
	vec3 liquide = couleur.rgb * (0.6 + 0.4 * remous) * mix(0.55, 1.2, smoothstep(surface - 0.4, surface, y));
	float ligne = smoothstep(0.035, 0.0, abs(y - surface)) * dans;
	liquide += mix(couleur.rgb, vec3(1.0), 0.35) * ligne * 0.7;
	vec3 c = mix(fond, liquide, dans);
	c *= mix(1.0, 0.3, smoothstep(0.5, 1.0, d));                 // la boule : plus sombre sur les bords
	float reflet = smoothstep(0.45, 0.0, length((p - vec2(-0.3, -0.45)) * vec2(1.0, 1.6)));
	c += vec3(1.0, 0.95, 0.85) * reflet * 0.3;
	c += couleur.rgb * eclat * 0.7;
	COLOR = vec4(c, smoothstep(1.0, 0.965, d));
}
