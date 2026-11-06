// Matière réaliste posée sur les décors KayKit (06/11, identité visuelle façon Diablo IV, étape 3 ; textures Poly Haven,
// CC0). Les UV KayKit renvoient à une palette de cases de couleur : inutilisables pour une texture qui se répète.
// Ici la texture est posée « en mètres du monde » : vue de dessus pour les faces à plat, de face pour les faces
// debout (un seul tirage par carte, contrairement à la projection sur trois axes qui en fait trois : moins cher pour
// le téléphone). Deux façons :
//  - pleine (sols, murs) : la texture remplace la couleur KayKit ;
//  - grain (bois, métal) : la couleur KayKit est gardée, la matière y ajoute ses veines, sa saleté et son relief.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D tex_couleur : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_relief : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_rugosite : hint_roughness_r, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_palette : source_color, filter_nearest_mipmap, repeat_enable;
uniform bool grain = false;
uniform vec4 teinte : source_color = vec4(1.0);
uniform float taille = 2.4;          // mètres couverts par une répétition de la texture
uniform float force_relief = 1.4;

varying vec3 pos_monde;
varying vec3 normale_monde;

void vertex() {
	pos_monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	normale_monde = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = normalize(normale_monde);
	vec3 a = abs(n);
	vec2 uv;
	vec3 t;   // sens où u augmente
	vec3 b;   // sens du « haut » de l'image (convention OpenGL des reliefs Poly Haven)
	if (a.y >= a.x && a.y >= a.z) {
		uv = pos_monde.xz;
		t = vec3(1.0, 0.0, 0.0);
		b = vec3(0.0, 0.0, -1.0);
	} else if (a.x >= a.z) {
		uv = vec2(pos_monde.z, -pos_monde.y);
		t = vec3(0.0, 0.0, 1.0);
		b = vec3(0.0, 1.0, 0.0);
	} else {
		uv = vec2(pos_monde.x, -pos_monde.y);
		t = vec3(1.0, 0.0, 0.0);
		b = vec3(0.0, 1.0, 0.0);
	}
	uv /= taille;
	// (le relief est importé compressé sur deux canaux, rouge et vert : le troisième est recalculé)
	vec3 r;
	r.xy = texture(tex_relief, uv).rg * 2.0 - 1.0;
	r.z = sqrt(max(0.0, 1.0 - dot(r.xy, r.xy)));
	r.xy *= force_relief;
	vec3 nw = normalize(t * r.x + b * r.y + n * r.z);
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	ROUGHNESS = texture(tex_rugosite, uv).r;
	vec3 c = texture(tex_couleur, uv).rgb;
	if (grain) {
		ALBEDO = texture(tex_palette, UV).rgb * c * teinte.rgb;
	} else {
		ALBEDO = c * teinte.rgb;
	}
}
