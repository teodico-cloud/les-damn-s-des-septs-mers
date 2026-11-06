// Brume au ras du sol (06/11, sons et ambiance du jalon 6, choix de Téo) : une nappe transparente qui roule
// lentement, éclairée par les torches et la lumière des héros (éclairage par sommet : peu coûteux sur téléphone).
// Deux nappes l'une au-dessus de l'autre donnent l'épaisseur. Voir Ambiance.brume().
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled, vertex_lighting, specular_disabled;

uniform vec3 couleur : source_color = vec3(0.62, 0.68, 0.7);
uniform float opacite = 0.3;
uniform float echelle = 0.11;           // bruit : tours par mètre
uniform vec2 vent = vec2(0.018, 0.007); // dérive (tours par seconde)
uniform float bord = 0.14;              // part du bord de la nappe où elle s'efface
uniform vec2 centre = vec2(0.0);        // la nappe entière (en mètres du monde ; elle est faite de plusieurs
uniform vec2 demi = vec2(7.0);          // morceaux : chacun reçoit les lumières qui l'entourent)
uniform sampler2D bruit : repeat_enable, filter_linear_mipmap;

varying vec2 sol;

void vertex() {
	sol = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 uv = sol * echelle;
	float a = texture(bruit, uv + TIME * vent).r;
	float b = texture(bruit, uv * 1.9 + vec2(0.37, 0.71) - TIME * vent * 1.6).r;
	float n = smoothstep(0.36, 0.82, a * 0.65 + b * 0.35);
	vec2 reste = (demi - abs(sol - centre)) / (2.0 * demi);   // 0 au bord de la nappe, 0,5 au milieu
	float d = min(reste.x, reste.y);
	ALBEDO = couleur;
	ROUGHNESS = 1.0;
	ALPHA = n * opacite * smoothstep(0.0, bord, d);
}
