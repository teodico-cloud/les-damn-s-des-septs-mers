class_name Ambiance
extends RefCounted
## La lumière du jeu, façon Diablo IV (06/11 : choisie par Téo sur la planche d'essai, tools/capture_style.gd) :
## presque tout dans l'ombre, couleurs ternes, brume, torches orangées qui font des taches de lumière, une lumière
## qui suit chaque héros (HaloHeros) et les bords de l'écran assombris (EffetsUI.vignette, dans les HUD).
## Partagée par l'arène, les salles d'expédition et le repaire.

const TORCHE := Color(1.0, 0.52, 0.22)
const LUNE := Color(0.55, 0.62, 0.8)
const SHADER_BRUME := preload("res://game/commun/brume.gdshader")
## Nappes de brume : [hauteur (m), opacité, échelle du bruit, vent]
const NAPPES := [[0.16, 0.34, 0.11, Vector2(0.018, 0.007)], [0.55, 0.2, 0.08, Vector2(-0.011, 0.014)]]
const MORCEAU_BRUME := 6.0

static var _ressources := {}


## L'environnement : fond presque noir, lumière ambiante faible et grise, étalonnage terne et contrasté (AgX).
static func environnement(densite_brume := 0.022) -> WorldEnvironment:
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.008, 0.01, 0.012)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.36, 0.4, 0.44)
	e.ambient_light_energy = 0.5
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.tonemap_exposure = 1.6
	e.fog_enabled = true
	e.fog_light_color = Color(0.035, 0.05, 0.05)
	e.fog_density = densite_brume
	e.glow_enabled = true
	e.glow_intensity = 1.1
	e.glow_bloom = 0.08
	e.adjustment_enabled = true
	e.adjustment_brightness = 0.95
	e.adjustment_contrast = 1.14
	e.adjustment_saturation = 0.6
	we.environment = e
	return we


## La lune : froide et faible (elle dessine les ombres sans éclairer la salle).
static func lune(energie: float, portee_ombres: float) -> DirectionalLight3D:
	var l := DirectionalLight3D.new()
	l.rotation_degrees = Vector3(-55, -30, 0)
	l.light_color = LUNE
	l.light_energy = energie
	l.shadow_enabled = true
	l.directional_shadow_max_distance = portee_ombres
	return l


## Une torche : orangée, qui s'éteint vite en s'éloignant (des taches de lumière, pas une salle éclairée).
static func torche(pos: Vector3, ombre: bool) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = TORCHE
	l.light_energy = 2.4
	l.omni_range = 9.2
	l.omni_attenuation = 1.25
	l.shadow_enabled = ombre
	l.omni_shadow_mode = OmniLight3D.SHADOW_DUAL_PARABOLOID
	l.add_child(flamme())   # (10/11 : le panier de la torche KayKit n'a pas de flamme ; la lumière vacille déjà)
	return l


## La flamme d'une torche (10/11, choix de Téo : « pas et torches ») : une quinzaine de petites taches de feu qui
## montent du panier, jaunes en bas, rouges puis éteintes en haut ; leur mélange les unes aux autres fait danser la
## flamme. Mélange normal et couleurs franches : en mélange additif, les taches s'empilaient en une boule blanche (vu en
## capture). Coût : 16 particules par torche.
static func flamme() -> CPUParticles3D:
	if not _ressources.has("flamme"):
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.55, 0.8, 1.0])   # (bord net : une langue de feu, pas un nuage)
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.3), Color(1, 1, 1, 0)])
		var rond := GradientTexture2D.new()
		rond.gradient = g
		rond.fill = GradientTexture2D.FILL_RADIAL
		rond.fill_from = Vector2(0.5, 0.5)
		rond.fill_to = Vector2(0.5, 0.0)
		rond.width = 32
		rond.height = 32
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat.vertex_color_use_as_albedo = true
		mat.albedo_texture = rond
		mat.billboard_keep_scale = true   # (sinon la taille de chaque particule est ignorée : une boule de 60 cm)
		mat.albedo_color = Color(1.5, 1.5, 1.5)   # (un peu « au-delà du blanc », sans plus : l'étalonnage la blanchirait)
		mat.disable_receive_shadows = true
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		var q := QuadMesh.new()
		q.size = Vector2(0.65, 1.0)   # (des langues de feu, plus hautes que larges)
		q.material = mat
		_ressources["flamme"] = q
		var vie := Gradient.new()   # (jaune au pied, orange, rouge sombre, puis plus rien)
		vie.offsets = PackedFloat32Array([0.0, 0.12, 0.45, 0.8, 1.0])
		vie.colors = PackedColorArray([Color(1.0, 0.62, 0.14, 0.0), Color(1.0, 0.45, 0.06, 0.9), Color(0.95, 0.22, 0.02, 0.75),
				Color(0.5, 0.06, 0.01, 0.35), Color(0.2, 0.03, 0.01, 0.0)])
		_ressources["vie_flamme"] = vie
		var taille := Curve.new()   # (la tache grossit un instant, puis rétrécit en montant)
		taille.add_point(Vector2(0.0, 0.55))
		taille.add_point(Vector2(0.25, 1.0))
		taille.add_point(Vector2(1.0, 0.1))
		_ressources["taille_flamme"] = taille
	var p := CPUParticles3D.new()
	p.name = "Flamme"
	p.mesh = _ressources["flamme"]
	p.amount = 16
	p.lifetime = 0.55
	p.preprocess = 0.55
	p.position = Vector3(0, -0.1, 0)   # (au fond du panier : la lumière est posée à son bord)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.06
	p.direction = Vector3.UP
	p.spread = 12.0
	p.initial_velocity_min = 0.35
	p.initial_velocity_max = 0.55
	p.gravity = Vector3(0, 0.6, 0)   # (l'air chaud monte)
	p.scale_amount_min = 0.13
	p.scale_amount_max = 0.2
	p.scale_amount_curve = _ressources["taille_flamme"]
	p.color_ramp = _ressources["vie_flamme"]
	p.angle_min = -12.0
	p.angle_max = 12.0
	return p


## Brume au ras du sol (06/11, choix de Téo avec les sons) : deux nappes transparentes qui roulent lentement, de
## `taille` mètres, éclairées par les torches. Les annonces au sol (zones rouges et dorées) restent dessinées par-dessus
## (priorité de rendu plus basse) : la brume ne cache jamais un danger. Masquée en qualité Économie (Reglages).
## Chaque nappe est faite de morceaux d'au plus MORCEAU_BRUME mètres : sur téléphone, un objet ne reçoit que 8
## lumières ; d'un seul tenant, la brume en aurait ignoré une partie (torches, halos ; relecture du jalon 6).
static func brume(taille: Vector2, centre := Vector3.ZERO) -> Node3D:
	var racine := Node3D.new()
	racine.name = "Brume"
	racine.position = centre
	racine.add_to_group(&"brume")
	if not _ressources.has("bruit"):
		var bruit := FastNoiseLite.new()
		bruit.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		bruit.frequency = 0.012
		bruit.fractal_octaves = 3
		var t := NoiseTexture2D.new()
		t.width = 256
		t.height = 256
		t.seamless = true
		t.generate_mipmaps = true
		t.noise = bruit
		_ressources["bruit"] = t
	var nx := maxi(1, ceili(taille.x / MORCEAU_BRUME))
	var nz := maxi(1, ceili(taille.y / MORCEAU_BRUME))
	var morceau := Vector2(taille.x / nx, taille.y / nz)
	var plan := PlaneMesh.new()
	plan.size = morceau
	plan.subdivide_width = int(morceau.x / 0.6)    # (éclairée sommet par sommet : il en faut assez)
	plan.subdivide_depth = int(morceau.y / 0.6)
	for i in NAPPES.size():
		var n: Array = NAPPES[i]
		var m := ShaderMaterial.new()   # (une par brume : elle connaît la taille de sa nappe)
		m.shader = SHADER_BRUME
		m.render_priority = -2
		m.set_shader_parameter("bruit", _ressources["bruit"])
		m.set_shader_parameter("opacite", n[1])
		m.set_shader_parameter("echelle", n[2])
		m.set_shader_parameter("vent", n[3])
		m.set_shader_parameter("centre", Vector2(centre.x, centre.z))
		m.set_shader_parameter("demi", taille / 2.0)
		var couche := Node3D.new()
		couche.name = "Nappe%d" % i
		couche.position.y = n[0]
		racine.add_child(couche)
		for ix in nx:
			for iz in nz:
				var piece := MeshInstance3D.new()
				piece.mesh = plan
				piece.material_override = m
				piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				piece.position = Vector3(-taille.x / 2.0 + morceau.x * (ix + 0.5), 0, -taille.y / 2.0 + morceau.y * (iz + 0.5))
				couche.add_child(piece)
	return racine


## La poussière d'une torche (accrochée au mur) : un peu devant elle, vers `centre` (le milieu de la salle), et en
## dessous, là où sa lumière tombe.
static func poussiere_torche(l: OmniLight3D, centre := Vector3.ZERO) -> void:
	var p := poussiere(Vector3(1.2, 0.9, 1.2), 18)
	var vers := Vector3(centre.x - l.position.x, 0.0, centre.z - l.position.z)
	p.position = (vers.normalized() if vers.length() > 0.1 else Vector3.ZERO) * 1.1 + Vector3(0, -0.6, 0)
	l.add_child(p)


## Poussière dans la lumière (06/11) : de petites poussières qui flottent ; éclairées comme le reste, elles ne se voient
## que dans la lumière (autour d'une torche, d'un héros). `boite` : la zone où elles naissent ; `monde` : elles restent
## où elles sont nées quand leur parent bouge (celles du héros). Moins nombreuses en qualité Économie (Reglages).
static func poussiere(boite: Vector3, nombre: int, monde := false) -> CPUParticles3D:
	if not _ressources.has("grain"):
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
		var rond := GradientTexture2D.new()
		rond.gradient = g
		rond.fill = GradientTexture2D.FILL_RADIAL
		rond.fill_from = Vector2(0.5, 0.5)
		rond.fill_to = Vector2(0.5, 0.0)
		rond.width = 32
		rond.height = 32
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat.vertex_color_use_as_albedo = true
		mat.albedo_texture = rond
		mat.albedo_color = Color(1.0, 0.93, 0.8)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
		mat.roughness = 1.0
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		var q := QuadMesh.new()
		q.size = Vector2(0.07, 0.07)
		q.material = mat
		_ressources["grain"] = q
		var vie := Gradient.new()   # (chaque grain apparaît, flotte, puis s'efface)
		vie.offsets = PackedFloat32Array([0.0, 0.2, 0.75, 1.0])
		vie.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.7), Color(1, 1, 1, 0)])
		_ressources["vie_grain"] = vie
	var p := CPUParticles3D.new()
	p.name = "Poussiere"
	p.add_to_group(&"poussiere")
	p.set_meta(&"nombre_voulu", nombre)
	p.mesh = _ressources["grain"]
	p.amount = nombre
	p.lifetime = 7.0
	p.preprocess = 7.0          # (déjà là à l'entrée dans la salle)
	p.local_coords = not monde
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = boite
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.02
	p.initial_velocity_max = 0.09
	p.gravity = Vector3(0, -0.012, 0)
	p.tangential_accel_min = -0.03
	p.tangential_accel_max = 0.03
	p.damping_min = 0.0
	p.damping_max = 0.02
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	p.color_ramp = _ressources["vie_grain"]
	return p
