class_name HudCombat
extends CanvasLayer
## Interface de combat : joystick flottant à gauche, boutons d'action à droite, barre de vie,
## bouton Menu. Gère plusieurs doigts à la fois et traduit tout en CommandesHeros.
## Au clavier (ordinateur) : ZQSD/WASD ou flèches, J attaque, K esquive, L parade, I fente.

signal menu_demande

const COULEUR_OS := Color("e2d6ba")

var heros: Heros
var camera: CameraCombat
var joystick: JoystickFlottant
var bouton_attaque: BoutonAction
var bouton_esquive: BoutonAction
var bouton_competence_1: BoutonAction
var bouton_competence_2: BoutonAction
var barre_vie: Control
var label_mort: Label
var label_message: Label
var bouton_menu: Button
var _boutons: Array[BoutonAction] = []
var _actions := {}   ## BoutonAction -> nom d'action
var _doigt_menu := -1      ## doigt posé sur le bouton Menu
var _menu_demande := false


func _ready() -> void:
	_actions_clavier()
	var racine := Control.new()
	racine.set_anchors_preset(Control.PRESET_FULL_RECT)
	racine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(racine)

	joystick = JoystickFlottant.new()
	racine.add_child(joystick)

	var noms: Dictionary = heros.noms_boutons()
	bouton_attaque = _bouton(racine, noms[&"attaque"], 96.0, null, Vector2(-170, -170), &"attaque")
	bouton_esquive = _bouton(racine, noms[&"esquive"], 62.0, heros.recharge_esquive, Vector2(-345, -105), &"esquive")
	bouton_competence_1 = _bouton(racine, noms[&"competence_1"], 62.0, heros.recharge_competence_1, Vector2(-330, -285), &"competence_1")
	bouton_competence_2 = _bouton(racine, noms[&"competence_2"], 62.0, heros.recharge_competence_2, Vector2(-170, -365), &"competence_2")

	barre_vie = Control.new()
	barre_vie.position = Vector2(24, 20)
	barre_vie.size = Vector2(380, 38)
	barre_vie.mouse_filter = Control.MOUSE_FILTER_IGNORE
	barre_vie.draw.connect(_dessiner_vie)
	racine.add_child(barre_vie)
	heros.sante.change.connect(func(_pv, _max): barre_vie.queue_redraw())

	bouton_menu = Button.new()
	bouton_menu.text = "Menu"
	bouton_menu.custom_minimum_size = Vector2(170, 76)
	bouton_menu.add_theme_font_size_override("font_size", 28)
	bouton_menu.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	bouton_menu.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	bouton_menu.position = Vector2(-194, 18)
	for etat in ["normal", "hover", "pressed", "focus"]:
		var st := StyleBoxFlat.new()
		st.bg_color = Color(0.16, 0.11, 0.08, 0.8) if etat != "pressed" else Color(0.1, 0.07, 0.05, 0.9)
		st.border_color = Color("ac8036")
		st.set_border_width_all(3)
		st.set_corner_radius_all(10)
		bouton_menu.add_theme_stylebox_override(etat, st)
	bouton_menu.add_theme_color_override("font_color", COULEUR_OS)
	bouton_menu.pressed.connect(_demander_menu)   # clic souris (ordinateur) ou 1er doigt
	racine.add_child(bouton_menu)

	label_mort = Label.new()
	label_mort.add_theme_font_size_override("font_size", 46)
	label_mort.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
	label_mort.add_theme_color_override("font_outline_color", Color.BLACK)
	label_mort.add_theme_constant_override("outline_size", 12)
	label_mort.set_anchors_preset(Control.PRESET_CENTER)
	label_mort.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label_mort.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_mort.visible = false
	label_mort.mouse_filter = Control.MOUSE_FILTER_IGNORE
	racine.add_child(label_mort)

	label_message = label_mort.duplicate() as Label
	label_message.add_theme_color_override("font_color", Color("e2d6ba"))
	label_message.add_theme_font_size_override("font_size", 36)
	label_message.position.y -= 160
	racine.add_child(label_message)


func _bouton(parent: Control, texte: String, rayon: float, rec: Recharge, decalage: Vector2, action: StringName) -> BoutonAction:
	var b := BoutonAction.new()
	b.configurer(texte, rayon, rec)
	b.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	b.position = decalage - Vector2(rayon, rayon)
	parent.add_child(b)
	# ancré en bas à droite : la position est relative à ce coin
	b.anchor_left = 1.0
	b.anchor_top = 1.0
	b.anchor_right = 1.0
	b.anchor_bottom = 1.0
	b.offset_left = decalage.x - rayon
	b.offset_top = decalage.y - rayon
	b.offset_right = decalage.x + rayon
	b.offset_bottom = decalage.y + rayon
	_boutons.append(b)
	_actions[b] = action
	return b


func _actions_clavier() -> void:
	var touches := {
		&"deplacer_gauche": [KEY_A, KEY_Q, KEY_LEFT],
		&"deplacer_droite": [KEY_D, KEY_RIGHT],
		&"deplacer_haut": [KEY_W, KEY_Z, KEY_UP],
		&"deplacer_bas": [KEY_S, KEY_DOWN],
		&"attaque": [KEY_J, KEY_SPACE],
		&"esquive": [KEY_K, KEY_SHIFT],
		&"competence_1": [KEY_L],
		&"competence_2": [KEY_I],
	}
	for action in touches:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for k in touches[action]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(action, e)


# ---------------------------------------------------------------- toucher (plusieurs doigts)
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			# le Menu est géré ici aussi : Godot ne transforme en clic que le 1er doigt posé, et le
			# pouce gauche est souvent déjà sur le joystick
			if bouton_menu.get_global_rect().has_point(event.position):
				_doigt_menu = event.index
				return
			for b in _boutons:
				if b.doigt == -1 and b.contient(event.position):
					b.doigt = event.index
					b.appuye = true
					_demander(_actions[b])
					get_viewport().set_input_as_handled()
					return
			if not joystick.actif and event.position.x < get_viewport().get_visible_rect().size.x * 0.5:
				joystick.commencer(event.index, event.position)
				get_viewport().set_input_as_handled()
		else:
			if _doigt_menu == event.index:
				_doigt_menu = -1
				if not event.canceled and bouton_menu.get_global_rect().has_point(event.position):
					_demander_menu()
			for b in _boutons:
				if b.doigt == event.index:
					b.doigt = -1
					b.appuye = false
			if joystick.actif and joystick.doigt == event.index:
				joystick.relacher()
	elif event is InputEventScreenDrag:
		if joystick.actif and joystick.doigt == event.index:
			joystick.deplacer(event.position)
			get_viewport().set_input_as_handled()


## Message au centre de l'écran pendant `duree` secondes (partenaire parti…).
func afficher_message(texte: String, duree: float) -> void:
	label_message.text = texte
	label_message.visible = true
	get_tree().create_timer(duree).timeout.connect(func(): if is_instance_valid(label_message): label_message.visible = false)


func _demander_menu() -> void:
	if not _menu_demande:   # une seule fois, même si le clic et le toucher arrivent tous les deux
		_menu_demande = true
		menu_demande.emit()


## Si l'appli passe en arrière-plan (appel, notification…), Android n'envoie pas toujours la levée
## des doigts : on relâche tout pour ne pas retrouver une attaque bloquée ou un joystick collé.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		relacher_tout()


func relacher_tout() -> void:
	for b in _boutons:
		b.doigt = -1
		b.appuye = false
	_doigt_menu = -1
	if joystick:
		joystick.relacher()


func _demander(action: StringName) -> void:
	if heros:
		heros.commandes.demander(action, heros.horloge)


func _process(_delta: float) -> void:
	if heros == null:
		return
	# garder l'attaque enfoncée enchaîne le combo
	if bouton_attaque.appuye:
		_demander(&"attaque")
	for action in [&"attaque", &"esquive", &"competence_1", &"competence_2"]:
		if Input.is_action_just_pressed(action):
			_demander(action)
	var v := joystick.valeur
	var clavier := Input.get_vector(&"deplacer_gauche", &"deplacer_droite", &"deplacer_haut", &"deplacer_bas")
	if clavier.length() > v.length():
		v = clavier
	heros.commandes.deplacement = camera.joystick_vers_monde(v) if camera else Vector3(v.x, 0, v.y)

	label_mort.visible = not heros.est_vivant()
	if label_mort.visible:
		label_mort.text = "Vous êtes tombé…\nRetour dans %d s" % ceili(heros.temps_avant_reapparition())


func _dessiner_vie() -> void:
	var s := heros.sante
	var r := Rect2(Vector2.ZERO, barre_vie.size)
	var fond := StyleBoxFlat.new()
	fond.bg_color = Color(0.05, 0.05, 0.06, 0.7)
	fond.border_color = Color("ac8036")
	fond.set_border_width_all(3)
	fond.set_corner_radius_all(8)
	barre_vie.draw_style_box(fond, r)
	var f: float = clampf(s.pv / s.pv_max, 0.0, 1.0)
	if f > 0.0:
		var plein := StyleBoxFlat.new()
		plein.bg_color = Color(0.72, 0.12, 0.12).lerp(Color(0.85, 0.25, 0.2), f)
		plein.set_corner_radius_all(6)
		barre_vie.draw_style_box(plein, Rect2(Vector2(4, 4), Vector2((r.size.x - 8) * f, r.size.y - 8)))
	var police := ThemeDB.fallback_font
	var txt := "PV %d / %d" % [ceili(s.pv), int(s.pv_max)]
	barre_vie.draw_string_outline(police, Vector2(14, 27), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, 6, Color.BLACK)
	barre_vie.draw_string(police, Vector2(14, 27), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, COULEUR_OS)
