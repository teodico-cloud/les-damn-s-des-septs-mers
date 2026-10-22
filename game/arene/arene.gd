extends Node3D
## Arène d'entraînement (jalon 1) : le Bretteur contre des Matelots squelettes qui reviennent
## sans fin, dans une salle de forteresse. Construit tout par code : salle, héros, ennemis,
## caméra, effets, interface.

const SCENE_MENU := "res://ui/screens/demarrage.tscn"
const DECOR := "res://assets/models/decor/"
const ECHELLE_DECOR := 0.8   ## les meubles KayKit paraissaient trop grands à côté des héros allongés
const DEMI_COTE := 6.4       ## la salle va de -6,4 à +6,4 m

var heros: Heros
var camera: CameraCombat
var effets: EffetsCombat
var generateur: GenerateurEnnemis
var hud: HudCombat
var torches: Array[OmniLight3D] = []
var _temps := 0.0


func _ready() -> void:
	get_tree().set_quit_on_go_back(false)
	_ambiance()
	_salle()
	heros = Heros.creer(Partie.heros_local)
	heros.position = Vector3(0, 0, 1.5)
	add_child(heros)
	heros.rotation.y = PI * 0.25

	camera = CameraCombat.new()
	camera.cible = heros
	add_child(camera)
	camera.current = true

	var appoint := OmniLight3D.new()   # éclaire le héros côté caméra, le suit
	appoint.light_color = Color(1.0, 0.8, 0.6)
	appoint.light_energy = 1.3
	appoint.omni_range = 8.0
	appoint.position = Vector3(1.6, 3.2, 1.6)
	heros.add_child(appoint)

	effets = EffetsCombat.new()
	effets.camera = camera
	add_child(effets)

	generateur = GenerateurEnnemis.new()
	generateur.demi_cote = DEMI_COTE - 1.4
	add_child(generateur)

	hud = HudCombat.new()
	hud.heros = heros
	hud.camera = camera
	hud.menu_demande.connect(retour_menu)
	add_child(hud)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		retour_menu()


func retour_menu() -> void:
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(SCENE_MENU)


func _process(delta: float) -> void:
	_temps += delta
	for i in torches.size():
		torches[i].light_energy = 2.2 + 0.35 * sin(_temps * 9.0 + i * 2.1) + 0.2 * sin(_temps * 23.0 + i)


# ---------------------------------------------------------------- décor
func _ambiance() -> void:
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.02, 0.03, 0.05)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.3, 0.4, 0.55)
	e.ambient_light_energy = 0.45
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.fog_enabled = true
	e.fog_light_color = Color(0.05, 0.08, 0.11)
	e.fog_density = 0.012
	e.glow_enabled = true
	e.glow_intensity = 0.9
	e.glow_bloom = 0.08
	we.environment = e
	add_child(we)
	var lune := DirectionalLight3D.new()
	lune.rotation_degrees = Vector3(-55, -30, 0)
	lune.light_color = Color(0.55, 0.65, 1.0)
	lune.light_energy = 0.4
	lune.shadow_enabled = true
	lune.directional_shadow_max_distance = 30.0
	add_child(lune)


func _objet(nom: String, pos: Vector3, rot_y := 0.0) -> Node3D:
	var n: Node3D = load(DECOR + nom + ".glb").instantiate()
	n.position = pos
	n.rotation_degrees.y = rot_y
	n.scale = Vector3.ONE * ECHELLE_DECOR
	add_child(n)
	return n


func _obstacle(centre: Vector3, taille: Vector3) -> void:
	var corps := StaticBody3D.new()
	corps.collision_layer = Combat.COUCHE_MONDE
	corps.collision_mask = 0
	var forme := CollisionShape3D.new()
	var boite := BoxShape3D.new()
	boite.size = taille
	forme.shape = boite
	corps.position = centre
	corps.add_child(forme)
	add_child(corps)


func _salle() -> void:
	var pas := 4.0 * ECHELLE_DECOR
	var dalles := ["floor_tile_large", "floor_tile_large_rocks"]
	# 4 × 4 dalles de jeu, plus 2 rangées hors jeu côté caméra pour ne pas voir le vide
	for ix in 6:
		for iz in 6:
			var x := -DEMI_COTE + pas * (ix + 0.5)
			var z := -DEMI_COTE + pas * (iz + 0.5)
			_objet(dalles[(ix * 7 + iz * 3) & 1], Vector3(x, 0, z))
	for i in 4:
		var c := -DEMI_COTE + pas * (i + 0.5)
		_objet("wall_arched" if i == 1 else "wall", Vector3(c, 0, -DEMI_COTE - 0.4))
		_objet("wall", Vector3(-DEMI_COTE - 0.4, 0, c), 90)
	_objet("pillar", Vector3(-DEMI_COTE - 0.2, 0, -DEMI_COTE - 0.2))

	# sol et limites de la salle (les côtés vers la caméra n'ont pas de mur visible)
	_obstacle(Vector3(0, -0.1, 0), Vector3(DEMI_COTE * 2 + 2, 0.2, DEMI_COTE * 2 + 2))
	_obstacle(Vector3(0, 1.5, -DEMI_COTE - 0.2), Vector3(DEMI_COTE * 2 + 2, 3, 0.4))
	_obstacle(Vector3(0, 1.5, DEMI_COTE + 0.2), Vector3(DEMI_COTE * 2 + 2, 3, 0.4))
	_obstacle(Vector3(-DEMI_COTE - 0.2, 1.5, 0), Vector3(0.4, 3, DEMI_COTE * 2 + 2))
	_obstacle(Vector3(DEMI_COTE + 0.2, 1.5, 0), Vector3(0.4, 3, DEMI_COTE * 2 + 2))

	# meubles dans les coins du fond, avec leur volume
	_objet("barrel_large", Vector3(-5.3, 0, -5.3))
	_obstacle(Vector3(-5.3, 0.8, -5.3), Vector3(1.4, 1.6, 1.4))
	_objet("crates_stacked", Vector3(5.1, 0, -5.2), 20)
	_obstacle(Vector3(5.1, 0.9, -5.2), Vector3(1.8, 1.8, 1.8))
	_objet("keg_decorated", Vector3(3.2, 0, -5.6))
	_obstacle(Vector3(3.2, 0.7, -5.6), Vector3(1.2, 1.4, 1.0))
	_objet("chest_gold", Vector3(-5.6, 0, 1.2), 90)
	_obstacle(Vector3(-5.6, 0.6, 1.2), Vector3(1.3, 1.2, 1.5))
	_objet("coin_stack_large", Vector3(-5.5, 0, 2.6))

	# torches du mur du fond et du mur de gauche
	for p in [Vector3(-2.4, 1.8, -DEMI_COTE), Vector3(2.4, 1.8, -DEMI_COTE)]:
		_objet("torch_mounted", p)
		_torche(p + Vector3(0, 0.55, 0.45), torches.is_empty())
	_objet("torch_mounted", Vector3(-DEMI_COTE, 1.8, -2.0), 90)
	_torche(Vector3(-DEMI_COTE + 0.45, 2.35, -2.0), false)

	var tresor := OmniLight3D.new()   # lueur maudite du coffre
	tresor.position = Vector3(-5.0, 1.2, 1.6)
	tresor.light_color = Color(0.3, 1.0, 0.55)
	tresor.light_energy = 1.6
	tresor.omni_range = 4.0
	add_child(tresor)


func _torche(pos: Vector3, ombre: bool) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = Color(1.0, 0.55, 0.2)
	l.light_energy = 2.4
	l.omni_range = 8.0
	l.shadow_enabled = ombre
	l.omni_shadow_mode = OmniLight3D.SHADOW_DUAL_PARABOLOID
	add_child(l)
	torches.append(l)
