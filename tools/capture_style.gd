extends SceneTree
## Planche d'essai de l'identité visuelle (06/11, demande de Téo : « moins cartoon, façon Diablo IV »).
## Une salle d'expédition, le Bretteur et la horde, image figée ; puis, l'un après l'autre (cumulés) :
##   0_actuel      le jeu tel quel
##   1_lumiere     lumière et étalonnage : ombre, couleurs ternes, brume, torches chaudes, bords sombres
##   2_textures    + sols, murs, bois et métal en textures réalistes (Poly Haven, CC0)
##   3_personnages + héros et squelettes moins « jouets »
## Rien n'est changé dans le jeu : tout est appliqué ici, le temps des captures.
## Textures : build/style/textures/<nom>_<diff|nor_gl|rough|grain>.png (converties depuis third_party/polyhaven ;
## « grain » : la couleur en gris ramenée autour de 0,82, multipliée à la palette KayKit).
## Usage : xvfb-run -a godot --path . --rendering-method gl_compatibility --rendering-driver opengl3
##         --resolution 1280x720 -s <chemin absolu>/tools/capture_style.gd -- <dossier> [graine]
## Ne pas typer avec les classes du jeu (voir CLAUDE.md, pièges).

const TEXTURES := "res://build/style/textures/"

var dossier := ""
var partie
var e   # l'expédition


func _initialize() -> void:
	_go()


func _images(n: int) -> void:
	for i in n:
		await physics_frame


func _capture(nom: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(dossier)
	var chemin := dossier.path_join(nom)
	if root.get_texture().get_image().save_png(chemin) != OK:
		push_error("capture impossible : " + chemin)
		quit(1)
	print("Capture : ", chemin)


func _go() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	dossier = args[0] if args.size() > 0 else "build/apercus/style"
	partie = root.get_node("Partie")
	partie.heros_local = &"bretteur"
	partie.debug_depart = &""
	seed(int(args[1]) if args.size() > 1 else 3)   # (la graine choisit la salle : 7 = réfectoire au plancher)
	e = load("res://game/expedition/expedition.tscn").instantiate()
	root.add_child(e)
	await _images(5)
	e.hud.menu_demande.disconnect(e.retour_menu)
	e.heros.sante.rendre_invulnerable(1000.0)
	await _images(170)
	# le héros face à la horde
	var proche = null
	for s in e.generateur.get_children():
		if s.is_in_group(&"ennemis") and (proche == null or s.global_position.distance_to(e.heros.global_position)
				< proche.global_position.distance_to(e.heros.global_position)):
			proche = s
	if proche:
		e.heros.look_at(Vector3(proche.global_position.x, e.heros.global_position.y, proche.global_position.z), Vector3.UP, true)
	await _images(2)
	paused = true   # (image figée : la même scène pour toutes les étapes ; l'arrêt sur image des coups remettrait
	await process_frame   #  le temps en marche, d'où la pause plutôt que Engine.time_scale)
	await process_frame
	await _capture("0_actuel.png")
	_lumiere()
	await _capture("1_lumiere.png")
	_textures()
	await _capture("2_textures.png")
	_personnages()
	await _capture("3_personnages.png")
	quit()


# ---------------------------------------------------------------- (a) lumière et étalonnage
func _lumiere() -> void:
	for we in e.find_children("*", "WorldEnvironment", true, false):
		var env: Environment = we.environment
		env.background_color = Color(0.008, 0.01, 0.012)
		env.ambient_light_color = Color(0.36, 0.4, 0.44)
		env.ambient_light_energy = 0.5
		env.tonemap_mode = Environment.TONE_MAPPER_AGX
		env.tonemap_exposure = 1.6
		env.fog_light_color = Color(0.035, 0.05, 0.05)
		env.fog_density = 0.022
		env.adjustment_enabled = true
		env.adjustment_brightness = 0.95
		env.adjustment_contrast = 1.14
		env.adjustment_saturation = 0.6
		env.glow_intensity = 1.1
	for l in e.find_children("*", "DirectionalLight3D", true, false):
		l.light_color = Color(0.55, 0.62, 0.8)
		l.light_energy *= 0.7
	for l in e.find_children("*", "OmniLight3D", true, false):
		if l.light_color.r > l.light_color.g:   # (les torches, pas les lueurs vertes)
			l.light_color = Color(1.0, 0.52, 0.22)
			l.omni_attenuation = 1.25
			l.omni_range *= 1.15
	# la lumière du héros (comme dans Diablo : un halo qui le suit et éclaire autour de lui), un peu côté caméra
	var vers_camera: Vector3 = e.camera.global_transform.basis.z
	vers_camera.y = 0.0
	var halo := OmniLight3D.new()
	halo.light_color = Color(1.0, 0.86, 0.68)
	halo.light_energy = 2.2
	halo.omni_range = 6.5
	halo.omni_attenuation = 1.1
	e.add_child(halo)
	halo.global_position = e.heros.global_position + Vector3(0, 2.4, 0) + vers_camera.normalized() * 1.1
	# KayKit : la matière partagée du donjon, assombrie (sols et murs trop clairs)
	var donjon: StandardMaterial3D = load("res://assets/materials/kaykit_dungeon.tres")
	donjon.albedo_color = Color(0.6, 0.58, 0.56)
	var couche := CanvasLayer.new()
	couche.layer = -1   # (sur la 3D, sous l'interface)
	couche.add_child(load("res://ui/commun/effets_ui.gd").vignette())
	e.add_child(couche)


# ---------------------------------------------------------------- (b) textures réalistes
const SOL := ["floor_tile_large", "floor_tile_large_rocks", "floor_dirt_large", "floor_tile_small_weeds_A",
		"stairs"]
const MUR := ["wall", "wall_arched", "wall_broken", "wall_corner", "wall_cracked", "wall_doorway", "wall_gated",
		"column", "pillar", "pillar_decorated", "rubble_half", "rubble_large"]
const BOIS := ["barrel_large", "barrel_small", "barrel_small_stack", "box_large", "box_stacked", "crates_stacked",
		"chair", "stool", "table_long_broken", "table_medium", "table_medium_broken", "shelf_large", "shelves",
		"trunk_large_A", "trunk_large_B", "keg_decorated", "barrier", "barrier_column", "floor_wood_large",
		"floor_wood_large_dark", "wall_scaffold"]
const METAL := ["chest", "chest_gold", "sword_shield", "sword_shield_broken", "torch_mounted", "keyring_hanging",
		"floor_tile_big_grate", "floor_tile_big_spikes"]

var _cache := {}


func _tex(nom: String) -> Texture2D:
	if not _cache.has(nom):
		var img := Image.load_from_file(ProjectSettings.globalize_path(TEXTURES + nom + ".png"))
		img.generate_mipmaps()
		_cache[nom] = ImageTexture.create_from_image(img)
	return _cache[nom]


## Une matière qui remplace la couleur KayKit (sols, murs) : projetée sur les trois axes du monde (les UV KayKit
## renvoient à une palette de cases de couleur, inutilisables pour une texture qui se répète).
func _matiere_pleine(nom: String, echelle: float, teinte: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = _tex(nom + "_diff")
	m.albedo_color = teinte
	m.normal_enabled = true
	m.normal_texture = _tex(nom + "_nor_gl")
	m.normal_scale = 1.4
	m.roughness_texture = _tex(nom + "_rough")
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_triplanar_sharpness = 4.0
	m.uv1_scale = Vector3.ONE * echelle
	return m


## Une matière qui garde la couleur KayKit (palette) et lui ajoute le grain et le relief d'une vraie matière.
func _matiere_grain(base: StandardMaterial3D, nom: String, echelle: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = base.albedo_texture
	m.albedo_color = Color(0.85, 0.82, 0.78)
	m.roughness = 0.8
	m.detail_enabled = true
	m.detail_uv_layer = BaseMaterial3D.DETAIL_UV_2
	m.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	m.detail_albedo = _tex(nom + "_grain")
	m.detail_normal = _tex(nom + "_nor_gl")
	m.uv2_triplanar = true
	m.uv2_world_triplanar = true
	m.uv2_triplanar_sharpness = 4.0
	m.uv2_scale = Vector3.ONE * echelle
	return m


func _textures() -> void:
	var donjon: StandardMaterial3D = load("res://assets/materials/kaykit_dungeon.tres")
	var sol := _matiere_pleine("cobblestone_floor_001", 0.42, Color(0.75, 0.72, 0.68))
	var mur := _matiere_pleine("stone_brick_wall_001", 0.38, Color(0.8, 0.78, 0.74))
	var bois := _matiere_grain(donjon, "weathered_brown_planks", 0.7)
	var metal := _matiere_grain(donjon, "rust_coarse_01", 0.9)
	var compte := {}
	for mi in e.find_children("*", "MeshInstance3D", true, false):
		var racine = mi
		while racine and not String(racine.scene_file_path).contains("/decor/"):
			racine = racine.get_parent()
		if racine == null:
			continue
		var nom: String = String(racine.scene_file_path).get_file().get_basename().get_basename()
		var m: Material = null
		if nom in SOL:
			m = sol
		elif nom in MUR:
			m = mur
		elif nom in BOIS:
			m = bois
		elif nom in METAL:
			m = metal
		if m:
			mi.material_override = m
			compte[nom] = compte.get(nom, 0) + 1
	print("Textures posées : ", compte)


# ---------------------------------------------------------------- (c) personnages
func _personnages() -> void:
	var os_script = load("res://tools/capture_style_os.gd")
	# squelettes : crâne plus petit, os jaunis et sales, yeux d'un vert maudit
	var mat: StandardMaterial3D = load("res://assets/materials/kaykit_squelette.tres")
	mat.albedo_color = Color(0.66, 0.6, 0.5)
	mat.roughness = 0.85
	mat.detail_enabled = true
	mat.detail_uv_layer = BaseMaterial3D.DETAIL_UV_2
	mat.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	mat.detail_albedo = _tex("stone_brick_wall_001_grain")
	mat.uv2_triplanar = true
	mat.uv2_scale = Vector3.ONE * 2.5
	var n := 0
	for s in e.generateur.get_children():
		for sk in s.find_children("*", "Skeleton3D", true, false):
			var m = os_script.new()
			m.echelles = {"head": Vector3.ONE * 0.64}
			sk.add_child(m)
			sk.process_mode = Node.PROCESS_MODE_ALWAYS   # (jeu en pause : le squelette applique quand même l'échelle)
			n += 1
		for mi in s.find_children("*", "MeshInstance3D", true, false):
			if String(mi.name).ends_with("_Eyes"):
				var yeux := StandardMaterial3D.new()
				yeux.albedo_color = Color(0.3, 1.0, 0.55)
				yeux.emission_enabled = true
				yeux.emission = Color(0.3, 1.0, 0.55)
				yeux.emission_energy_multiplier = 4.0
				mi.material_override = yeux
	# le héros : tête un peu plus petite (le tricorne suit)
	for sk in e.heros.find_children("*", "Skeleton3D", true, false):
		var m = os_script.new()
		m.echelles = {"head": Vector3.ONE * 0.8}
		sk.add_child(m)
		sk.process_mode = Node.PROCESS_MODE_ALWAYS
	print("Squelettes retouchés : ", n)
