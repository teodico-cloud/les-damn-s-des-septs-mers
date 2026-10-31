extends Node3D
## Choix du héros avant l'arène : les deux héros debout dans une salle, une carte sous chacun.
## Toucher une carte choisit ce héros et ouvre l'arène. (En coop, le héros déjà pris sera grisé.)

const SCENE_MENU := "res://ui/screens/demarrage.tscn"
const SCENE_COOP := "res://ui/screens/coop.tscn"
const DECOR := "res://assets/models/decor/"
const COULEUR_OS := Color("e2d6ba")
const COULEUR_OR := Color("ac8036")
const HEROS := {
	&"bretteur": {
		"modele": "res://assets/models/heroes/Bretteur.glb",
		"nom": "Le Bretteur",
		"role": "Corps-à-corps · 100 PV",
		"competences": "Combo de 3 coups · Roulade\nParade-riposte · Fente",
		"x": -1.5,
	},
	&"occultiste": {
		"modele": "res://assets/models/heroes/Occultiste.glb",
		"nom": "L'Occultiste",
		"role": "À distance · 80 PV",
		"competences": "Projectile maudit · Téléportation\nMarque maudite · Chaînes spectrales",
		"x": 1.5,
	},
}

var cartes := {}          ## archétype -> Button
var choix_malediction: ChoixMalediction   ## expédition en solo : niveau de malédiction
var changer_de_scene := true   ## faux dans les tests


func _ready() -> void:
	get_tree().set_quit_on_go_back(false)
	_monde()
	_interface()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		retour_menu()


## Choix fait : en solo on entre dans l'arène ou l'expédition (Partie.destination) ; si l'on héberge une partie à deux, on revient à
## l'écran de coop qui attend le partenaire (il prendra l'autre héros).
func choisir(archetype: StringName) -> void:
	Partie.heros_local = archetype
	if changer_de_scene:
		get_tree().change_scene_to_file(SCENE_COOP if Partie.mode == Partie.Mode.HOTE else Partie.scene_destination())


func retour_menu() -> void:
	Partie.revenir_en_solo()
	if changer_de_scene:
		get_tree().change_scene_to_file(SCENE_MENU)


# ---------------------------------------------------------------- monde
func _monde() -> void:
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.02, 0.03, 0.05)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.3, 0.4, 0.55)
	e.ambient_light_energy = 0.4
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	e.glow_intensity = 0.9
	we.environment = e
	add_child(we)

	for x in [-8, -4, 0, 4, 8]:
		for z in [-4, 0, 4]:
			_objet("floor_tile_large", Vector3(x, 0, z))
	for x in [-8, -4, 0, 4, 8]:
		_objet("wall_arched" if x == 0 else "wall", Vector3(x, 0, -5.5))
	for x in [-2.6, 2.6]:
		_objet("torch_mounted", Vector3(x, 2.0, -5.1))
		var l := OmniLight3D.new()
		l.position = Vector3(x, 2.6, -4.6)
		l.light_color = Color(1.0, 0.55, 0.2)
		l.light_energy = 2.2
		l.omni_range = 7.0
		add_child(l)
	var appoint := OmniLight3D.new()
	appoint.position = Vector3(0, 3.0, 3.5)
	appoint.light_color = Color(1.0, 0.8, 0.6)
	appoint.light_energy = 1.5
	appoint.omni_range = 9.0
	add_child(appoint)

	var camera := Camera3D.new()
	camera.fov = 40.0
	add_child(camera)
	if Partie.destination == &"expedition" and Partie.mode == Partie.Mode.SOLO:
		# le choix de la malédiction occupe le haut de l'écran : les héros, un peu plus loin, en dessous
		camera.look_at_from_position(Vector3(0, 2.3, 8.6), Vector3(0, 1.45, 0), Vector3.UP)
	else:
		camera.look_at_from_position(Vector3(0, 2.3, 6.2), Vector3(0, 0.75, 0), Vector3.UP)
	camera.current = true

	for cle in HEROS:
		var n: Node3D = load(HEROS[cle]["modele"]).instantiate()
		n.position = Vector3(HEROS[cle]["x"], 0, -0.6)
		add_child(n)
		n.rotation.y = -0.18 * signf(HEROS[cle]["x"])   # légèrement tournés l'un vers l'autre
		var anim: AnimationPlayer = n.find_child("AnimationPlayer", true, false)
		anim.get_animation("Idle").loop_mode = Animation.LOOP_LINEAR
		anim.play("Idle")


func _objet(nom: String, pos: Vector3) -> void:
	var n: Node3D = load(DECOR + nom + ".glb").instantiate()
	n.position = pos
	add_child(n)


# ---------------------------------------------------------------- interface
func _interface() -> void:
	var couche := CanvasLayer.new()
	add_child(couche)
	var racine := Control.new()
	racine.set_anchors_preset(Control.PRESET_FULL_RECT)
	racine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	couche.add_child(racine)

	var titre := Label.new()
	titre.text = "Choisis ton héros"
	titre.add_theme_font_size_override("font_size", 46)
	titre.add_theme_color_override("font_color", COULEUR_OS)
	titre.add_theme_color_override("font_outline_color", Color.BLACK)
	titre.add_theme_constant_override("outline_size", 10)
	titre.set_anchors_preset(Control.PRESET_CENTER_TOP)
	titre.grow_horizontal = Control.GROW_DIRECTION_BOTH
	titre.position.y = 18
	racine.add_child(titre)

	var rangee := HBoxContainer.new()
	rangee.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	rangee.grow_horizontal = Control.GROW_DIRECTION_BOTH
	rangee.grow_vertical = Control.GROW_DIRECTION_BEGIN
	rangee.position.y = -24
	rangee.add_theme_constant_override("separation", 120)
	racine.add_child(rangee)
	for cle in HEROS:
		var carte := _carte(HEROS[cle])
		carte.pressed.connect(choisir.bind(cle))
		rangee.add_child(carte)
		cartes[cle] = carte

	var retour := Button.new()
	retour.text = "Retour"
	retour.custom_minimum_size = Vector2(170, 76)
	retour.add_theme_font_size_override("font_size", 28)
	retour.add_theme_color_override("font_color", COULEUR_OS)
	for etat in ["normal", "hover", "pressed", "focus"]:
		retour.add_theme_stylebox_override(etat, _style(etat == "pressed"))
	retour.position = Vector2(24, 18)
	retour.pressed.connect(retour_menu)
	racine.add_child(retour)

	# expédition en solo : la malédiction se choisit ici (à deux, l'hôte la choisit sur l'écran de coop)
	if Partie.destination == &"expedition" and Partie.mode == Partie.Mode.SOLO:
		choix_malediction = ChoixMalediction.new()
		choix_malediction.set_anchors_preset(Control.PRESET_CENTER_TOP)
		choix_malediction.grow_horizontal = Control.GROW_DIRECTION_BOTH
		choix_malediction.position.y = 84
		racine.add_child(choix_malediction)


func _carte(info: Dictionary) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(470, 210)
	for etat in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(etat, _style(etat == "pressed"))
	var colonne := VBoxContainer.new()
	colonne.set_anchors_preset(Control.PRESET_FULL_RECT)
	colonne.alignment = BoxContainer.ALIGNMENT_CENTER
	colonne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(colonne)
	for ligne in [[info["nom"], 40, COULEUR_OS], [info["role"], 26, Color("6cffa0")], [info["competences"], 24, Color(COULEUR_OS, 0.85)]]:
		var l := Label.new()
		l.text = ligne[0]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", ligne[1])
		l.add_theme_color_override("font_color", ligne[2])
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		colonne.add_child(l)
	return b


func _style(enfonce: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.1, 0.07, 0.05, 0.92) if enfonce else Color(0.16, 0.11, 0.08, 0.82)
	s.border_color = COULEUR_OR
	s.set_border_width_all(3)
	s.set_corner_radius_all(12)
	return s
