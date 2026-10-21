extends Node3D
## Vitrine des héros (jalon 0) : les deux héros dans une salle de forteresse, ambiance sombre.
## Toucher l'écran : les héros enchaînent leurs actions. Glisser : tourner la caméra.
## Sert aussi de test de performance sur téléphone (compteur d'images par seconde).

const SCENE_MENU := "res://ui/screens/demarrage.tscn"
const HEROS := {
	"bretteur": {
		"modele": "res://assets/models/heroes/Bretteur.glb",
		"nom": "Le Bretteur",
		"pos": Vector3(-1.4, 0, 0.8),
		"actions": [
			["1H_Melee_Attack_Slice_Diagonal", "Taille"],
			["1H_Melee_Attack_Chop", "Coup de sabre"],
			["Block", "Parade"],
			["Dodge_Forward", "Esquive"],
		],
	},
	"occultiste": {
		"modele": "res://assets/models/heroes/Occultiste.glb",
		"nom": "L'Occultiste",
		"pos": Vector3(1.4, 0, 0.8),
		"actions": [
			["Spellcast_Shoot", "Projectile maudit"],
			["Spellcast_Raise", "Chaînes spectrales"],
			["Spellcast_Long", "Marque maudite"],
			["Dodge_Backward", "Esquive"],
		],
	},
}
const DECOR := "res://assets/models/decor/"
const CIBLE_CAMERA := Vector3(0, 1.2, 0.5)
const DECALAGE_CAMERA := Vector3(2.6, 4.1, 7.5)
const SEUIL_GLISSER := 18.0

var joueurs := {}        # clé -> {"noeud": Node3D, "anim": AnimationPlayer}
var index_action := -1
var camera: Camera3D
var lacet := 0.0
var torches: Array[OmniLight3D] = []
var temps := 0.0
var label_fps: Label
var label_action: Label
var appui_pos := Vector2.ZERO
var appui_actif := false
var doigt := -1
var a_glisse := false
var compteur_fps := 0.0


func _ready() -> void:
	get_tree().set_quit_on_go_back(false)
	_environnement()
	_salle()
	_heros()
	_camera()
	_interface()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		retour_menu()


# ---------------------------------------------------------------- monde
func _environnement() -> void:
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.02, 0.03, 0.05)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.3, 0.4, 0.55)
	e.ambient_light_energy = 0.4
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.fog_enabled = true
	e.fog_light_color = Color(0.05, 0.08, 0.11)
	e.fog_density = 0.015
	e.glow_enabled = true
	e.glow_intensity = 1.0
	e.glow_bloom = 0.1
	we.environment = e
	add_child(we)

	var lune := DirectionalLight3D.new()
	lune.rotation_degrees = Vector3(-55, -30, 0)
	lune.light_color = Color(0.55, 0.65, 1.0)
	lune.light_energy = 0.35
	lune.shadow_enabled = true
	add_child(lune)


func _objet(nom: String, pos: Vector3, rot_y := 0.0) -> Node3D:
	var n: Node3D = load(DECOR + nom + ".glb").instantiate()
	n.position = pos
	n.rotation_degrees.y = rot_y
	add_child(n)
	return n


func _salle() -> void:
	var dalles := ["floor_tile_large", "floor_tile_large_rocks"]
	for x in range(-1, 2):
		for z in range(-1, 2):
			_objet(dalles[(x * 7 + z * 3) & 1], Vector3(x * 4, 0, z * 4))
	for i in range(-1, 2):
		_objet("wall_arched" if i == 0 else "wall", Vector3(i * 4, 0, -6.5))
		_objet("wall", Vector3(-6.5, 0, i * 4), 90)
	_objet("pillar", Vector3(-5.8, 0, -5.8))
	_objet("barrel_large", Vector3(-4.6, 0, -4.4))
	_objet("crates_stacked", Vector3(-4.8, 0, 2.6), 25)
	_objet("keg_decorated", Vector3(4.6, 0, -5.0))
	_objet("chest_gold", Vector3(3.8, 0, -3.0), -30)
	_objet("coin_stack_large", Vector3(4.9, 0, -2.0))

	for p in [Vector3(-2.5, 2.2, -6.0), Vector3(2.5, 2.2, -6.0)]:
		_objet("torch_mounted", p)
		var l := OmniLight3D.new()
		l.position = p + Vector3(0, 0.7, 0.5)
		l.light_color = Color(1.0, 0.55, 0.2)
		l.light_energy = 2.5
		l.omni_range = 8.0
		l.shadow_enabled = torches.is_empty()  # une seule ombre de torche : plus léger sur téléphone
		add_child(l)
		torches.append(l)

	# Lumière d'appoint côté caméra : sans elle, les héros sont à contre-jour (torches au fond).
	var appoint := OmniLight3D.new()
	appoint.position = Vector3(0.5, 3.2, 5.0)
	appoint.light_color = Color(1.0, 0.78, 0.55)
	appoint.light_energy = 1.4
	appoint.omni_range = 9.0
	add_child(appoint)

	var tresor := OmniLight3D.new()
	tresor.position = Vector3(3.8, 1.3, -3.0)
	tresor.light_color = Color(0.3, 1.0, 0.55)
	tresor.light_energy = 1.8
	tresor.omni_range = 4.5
	add_child(tresor)


func _heros() -> void:
	for cle in HEROS:
		var info: Dictionary = HEROS[cle]
		var n: Node3D = load(info["modele"]).instantiate()
		n.position = info["pos"]
		add_child(n)
		var vers_camera := CIBLE_CAMERA + DECALAGE_CAMERA
		n.look_at(Vector3(vers_camera.x, 0, vers_camera.z), Vector3.UP, true)
		var anim: AnimationPlayer = n.find_child("AnimationPlayer", true, false)
		var idle := anim.get_animation("Idle")
		idle.loop_mode = Animation.LOOP_LINEAR
		anim.animation_finished.connect(_fin_animation.bind(anim))
		anim.play("Idle")
		joueurs[cle] = {"noeud": n, "anim": anim}

		var etiquette := Label3D.new()
		etiquette.text = info["nom"]
		etiquette.position = info["pos"] + Vector3(0, 2.85, 0)
		etiquette.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		etiquette.font_size = 48
		etiquette.pixel_size = 0.006
		etiquette.outline_size = 14
		etiquette.modulate = Color("e2d6ba")
		add_child(etiquette)

	# La lanterne de l'Occultiste éclaire réellement autour de lui
	var lanterne := (joueurs["occultiste"]["noeud"] as Node3D).find_child("Occultiste_Lanterne", true, false)
	if lanterne:
		var l := OmniLight3D.new()
		l.position = Vector3(0, -0.3, 0)
		l.light_color = Color(0.35, 1.0, 0.6)
		l.light_energy = 1.2
		l.omni_range = 3.0
		lanterne.add_child(l)


func _camera() -> void:
	camera = Camera3D.new()
	camera.fov = 38.0
	add_child(camera)
	_placer_camera()


func _placer_camera() -> void:
	var offset := Basis(Vector3.UP, lacet) * DECALAGE_CAMERA
	camera.look_at_from_position(CIBLE_CAMERA + offset, CIBLE_CAMERA, Vector3.UP)


# ---------------------------------------------------------------- actions
func action_suivante() -> void:
	index_action += 1
	var textes: Array[String] = []
	for cle in joueurs:
		var actions: Array = HEROS[cle]["actions"]
		var a: Array = actions[index_action % actions.size()]
		var anim: AnimationPlayer = joueurs[cle]["anim"]
		anim.play(a[0], 0.15)
		textes.append("%s : %s" % [HEROS[cle]["nom"], a[1]])
	label_action.text = "   ·   ".join(textes)


func _fin_animation(nom: StringName, anim: AnimationPlayer) -> void:
	if nom != &"Idle":
		anim.play("Idle", 0.2)


func retour_menu() -> void:
	get_tree().change_scene_to_file(SCENE_MENU)


# ---------------------------------------------------------------- interface
func _interface() -> void:
	var couche := CanvasLayer.new()
	add_child(couche)
	var racine := Control.new()
	racine.set_anchors_preset(Control.PRESET_FULL_RECT)
	racine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	couche.add_child(racine)

	label_fps = _label(26, Color("6cffa0"))
	label_fps.position = Vector2(24, 18)
	racine.add_child(label_fps)

	var retour := Button.new()
	retour.text = "Retour"
	retour.custom_minimum_size = Vector2(200, 84)
	retour.add_theme_font_size_override("font_size", 30)
	retour.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	retour.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	retour.position = Vector2(-224, 18)
	retour.pressed.connect(retour_menu)
	racine.add_child(retour)

	label_action = _label(30, Color("e2d6ba"))
	label_action.text = "Touchez l'écran pour lancer une action  ·  Glissez pour tourner la caméra"
	label_action.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	label_action.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label_action.grow_vertical = Control.GROW_DIRECTION_BEGIN
	label_action.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_action.position.y -= 28
	racine.add_child(label_action)


func _label(taille: int, couleur: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", couleur)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _unhandled_input(event: InputEvent) -> void:
	# Seul le premier doigt posé compte ; un toucher annulé par le système (geste retour,
	# barre d'état) ne déclenche pas d'action.
	if event is InputEventScreenTouch:
		if event.pressed:
			if not appui_actif:
				appui_actif = true
				doigt = event.index
				a_glisse = false
				appui_pos = event.position
		elif appui_actif and event.index == doigt:
			appui_actif = false
			if not a_glisse and not event.canceled:
				action_suivante()
	elif event is InputEventScreenDrag and appui_actif and event.index == doigt:
		if event.position.distance_to(appui_pos) > SEUIL_GLISSER:
			a_glisse = true
		if a_glisse:
			lacet -= event.relative.x * 0.006
			_placer_camera()


func _process(delta: float) -> void:
	temps += delta
	for i in torches.size():
		torches[i].light_energy = 2.3 + 0.35 * sin(temps * 9.0 + i * 2.1) + 0.2 * sin(temps * 23.0 + i)
	compteur_fps -= delta
	if compteur_fps <= 0.0:
		compteur_fps = 0.5
		label_fps.text = "%d images/s  ·  %s" % [Engine.get_frames_per_second(), RenderingServer.get_video_adapter_name()]
