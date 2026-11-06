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
	return l


## Brume au ras du sol (06/11, choix de Téo avec les sons) : deux nappes transparentes qui roulent lentement, de
## `taille` mètres, éclairées par les torches. Les annonces au sol (zones rouges et dorées) restent dessinées par-dessus
## (priorité de rendu plus basse) : la brume ne cache jamais un danger. Masquée en qualité Économie (Reglages).
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
	for i in NAPPES.size():
		var n: Array = NAPPES[i]
		var cle := "nappe_%d" % i
		if not _ressources.has(cle):
			var m := ShaderMaterial.new()
			m.shader = SHADER_BRUME
			m.render_priority = -2
			m.set_shader_parameter("bruit", _ressources["bruit"])
			m.set_shader_parameter("opacite", n[1])
			m.set_shader_parameter("echelle", n[2])
			m.set_shader_parameter("vent", n[3])
			_ressources[cle] = m
		var plan := PlaneMesh.new()
		plan.size = taille
		plan.subdivide_width = int(taille.x / 0.6)    # (éclairée sommet par sommet : il en faut assez)
		plan.subdivide_depth = int(taille.y / 0.6)
		var nappe := MeshInstance3D.new()
		nappe.name = "Nappe%d" % i
		nappe.mesh = plan
		nappe.material_override = _ressources[cle]
		nappe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		nappe.position.y = n[0]
		racine.add_child(nappe)
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
