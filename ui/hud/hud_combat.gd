class_name HudCombat
extends CanvasLayer
## Interface de combat : joystick flottant à gauche, boutons d'action à droite, barre de vie,
## bouton Menu. Gère plusieurs doigts à la fois et traduit tout en CommandesHeros.
## Au clavier (ordinateur) : ZQSD/WASD ou flèches, J attaque, K esquive, L parade, I fente.
## Expédition : nom de la salle en haut, fondu au noir entre deux salles, Menu à confirmer (on ne
## perd pas une expédition d'un doigt maladroit), écran de fin avec le bilan.

signal menu_demande

const COULEUR_OS := Color("e2d6ba")

var heros: Heros
var heros_partenaire: Heros    ## coop (sinon nul)
var regles: Node               ## coop, hôte : ReglesCoop (compte à rebours quand les deux sont à terre)
var camera: CameraCombat
var joystick: JoystickFlottant
var bouton_attaque: BoutonAction
var bouton_esquive: BoutonAction
var bouton_competence_1: BoutonAction
var bouton_competence_2: BoutonAction
var barre_vie: Control
var label_mort: Label
var label_ips: Label
var _minuterie_ips := 0.0
var label_message: Label
var label_partenaire: Label
var label_alerte: Label
var _les_deux_a_terre_depuis := -1.0
var bouton_menu: Button
var _boutons: Array[BoutonAction] = []
var _actions := {}   ## BoutonAction -> nom d'action
var _doigt_menu := -1      ## doigt posé sur le bouton Menu
var _menu_demande := false
var mode_expedition := false
var label_salle: Label
var voile: ColorRect           ## fondu au noir entre deux salles
var panneau_fin: Control
var _premier_appui_menu := -100.0   ## expédition : heure du 1er appui sur Menu (on attend le 2e)


func _ready() -> void:
	_actions_clavier()
	var racine := Control.new()
	racine.set_anchors_preset(Control.PRESET_FULL_RECT)
	racine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(racine)

	joystick = JoystickFlottant.new()
	racine.add_child(joystick)

	var noms: Dictionary = heros.noms_boutons()
	var icones: Dictionary = heros.icones_boutons()
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

	# images par seconde (APK de test : pour juger la fluidité avec la horde)
	label_ips = Label.new()
	label_ips.add_theme_font_size_override("font_size", 20)
	label_ips.add_theme_color_override("font_color", Color(COULEUR_OS, 0.7))
	label_ips.add_theme_color_override("font_outline_color", Color.BLACK)
	label_ips.add_theme_constant_override("outline_size", 6)
	label_ips.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	label_ips.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	label_ips.position = Vector2(-120, 98)
	label_ips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	racine.add_child(label_ips)

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

	label_partenaire = label_mort.duplicate() as Label
	label_partenaire.add_theme_color_override("font_color", Color("6cffa0"))
	label_partenaire.add_theme_font_size_override("font_size", 30)
	label_partenaire.set_anchors_preset(Control.PRESET_CENTER_TOP)
	label_partenaire.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label_partenaire.position.y = 80
	label_partenaire.text = "Ton partenaire est à terre : reste près de lui pour le relever !"
	racine.add_child(label_partenaire)

	label_alerte = label_partenaire.duplicate() as Label
	label_alerte.add_theme_color_override("font_color", Color(1.0, 0.75, 0.3))
	label_alerte.position.y = 130
	label_alerte.visible = false
	racine.add_child(label_alerte)

	label_message = label_mort.duplicate() as Label
	label_message.add_theme_color_override("font_color", Color("e2d6ba"))
	label_message.add_theme_font_size_override("font_size", 36)
	label_message.position.y -= 160
	racine.add_child(label_message)

	label_salle = Label.new()
	label_salle.add_theme_font_size_override("font_size", 30)
	label_salle.add_theme_color_override("font_color", Color("e0b04a"))
	label_salle.add_theme_color_override("font_outline_color", Color.BLACK)
	label_salle.add_theme_constant_override("outline_size", 8)
	label_salle.set_anchors_preset(Control.PRESET_CENTER_TOP)
	label_salle.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label_salle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_salle.position.y = 22
	label_salle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	racine.add_child(label_salle)

	voile = ColorRect.new()
	voile.color = Color(0, 0, 0, 0)
	voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	voile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	racine.add_child(voile)


func _bouton(parent: Control, texte: String, rayon: float, rec: Recharge, decalage: Vector2, action: StringName) -> BoutonAction:
	var b := BoutonAction.new()
	b.configurer(texte, rayon, rec)
	b.icone = heros.icones_boutons().get(action) as Texture2D
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


## Alerte qui reste affichée tant qu'elle n'est pas retirée (texte vide) : connexion instable…
func alerte(texte: String) -> void:
	label_alerte.text = texte
	label_alerte.visible = texte != ""


## Message au centre de l'écran pendant `duree` secondes (partenaire parti…).
func afficher_message(texte: String, duree: float) -> void:
	label_message.text = texte
	label_message.visible = true
	get_tree().create_timer(duree).timeout.connect(func(): if is_instance_valid(label_message): label_message.visible = false)


func _demander_menu() -> void:
	if _menu_demande:
		return   # une seule fois, même si le clic et le toucher arrivent tous les deux
	if mode_expedition and panneau_fin == null:
		# expédition en cours : un premier appui demande confirmation (un doigt maladroit ne la perd pas)
		var depuis := Time.get_ticks_msec() / 1000.0 - _premier_appui_menu
		if depuis < 0.2:
			return   # le clic et le toucher d'un même appui arrivent ensemble : pas une confirmation
		if depuis > 2.5:
			_premier_appui_menu = Time.get_ticks_msec() / 1000.0
			afficher_message("Appuie encore sur Menu pour abandonner l'expédition", 2.5)
			return
	_menu_demande = true
	menu_demande.emit()


## Nom de la salle en cours (expédition).
func afficher_salle(texte: String) -> void:
	label_salle.text = texte


## Fondu au noir (vers_noir) ou retour à l'image, en `duree` secondes réelles.
func fondu(vers_noir: bool, duree: float) -> void:
	var t := voile.create_tween()
	t.set_ignore_time_scale(true)
	t.tween_property(voile, "color:a", 1.0 if vers_noir else 0.0, duree)


## Écran de fin d'expédition : titre, lignes du bilan, bouton de retour au menu.
func afficher_resultats(reussite: bool, lignes: Array) -> void:
	if panneau_fin:
		return
	relacher_tout()
	label_mort.visible = false
	label_message.visible = false
	var fond := ColorRect.new()
	fond.color = Color(0.02, 0.03, 0.04, 0.0)
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fond)
	panneau_fin = fond
	var colonne := VBoxContainer.new()
	colonne.set_anchors_preset(Control.PRESET_CENTER)
	colonne.grow_horizontal = Control.GROW_DIRECTION_BOTH
	colonne.grow_vertical = Control.GROW_DIRECTION_BOTH
	colonne.alignment = BoxContainer.ALIGNMENT_CENTER
	colonne.add_theme_constant_override("separation", 14)
	fond.add_child(colonne)
	var titre := Label.new()
	titre.text = "Expédition réussie !" if reussite else "Expédition perdue…"
	titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titre.add_theme_font_size_override("font_size", 64)
	titre.add_theme_color_override("font_color", Color("6cffa0") if reussite else Color(1.0, 0.45, 0.4))
	titre.add_theme_color_override("font_outline_color", Color.BLACK)
	titre.add_theme_constant_override("outline_size", 12)
	colonne.add_child(titre)
	for l in lignes:
		var ligne := Label.new()
		ligne.text = String(l)
		ligne.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ligne.add_theme_font_size_override("font_size", 30)
		ligne.add_theme_color_override("font_color", COULEUR_OS)
		colonne.add_child(ligne)
	var espace := Control.new()
	espace.custom_minimum_size = Vector2(0, 16)
	colonne.add_child(espace)
	var b := Button.new()
	b.text = "Retour au menu"
	b.custom_minimum_size = Vector2(420, 90)
	b.add_theme_font_size_override("font_size", 34)
	b.add_theme_color_override("font_color", COULEUR_OS)
	for etat in ["normal", "hover", "pressed", "focus"]:
		var st := StyleBoxFlat.new()
		st.bg_color = Color("3a2a20") if etat != "pressed" else Color("24190f")
		st.border_color = Color("ac8036")
		st.set_border_width_all(4)
		st.set_corner_radius_all(14)
		b.add_theme_stylebox_override(etat, st)
	b.pressed.connect(func():
		_menu_demande = true
		menu_demande.emit())
	var centre := CenterContainer.new()
	centre.add_child(b)
	colonne.add_child(centre)
	var t := fond.create_tween()
	t.set_ignore_time_scale(true)
	t.tween_property(fond, "color:a", 0.82, 0.6)


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


func _process(delta: float) -> void:
	_minuterie_ips -= delta
	if _minuterie_ips <= 0.0 and label_ips:
		_minuterie_ips = 0.5
		label_ips.text = "%d i/s" % Engine.get_frames_per_second()
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

	_textes_a_terre()


## Textes quand un héros est à terre (solo : compte à rebours ; coop : réanimation ou retour au départ).
func _textes_a_terre() -> void:
	var moi_a_terre := not heros.est_vivant()
	var coop := heros_partenaire != null and is_instance_valid(heros_partenaire)
	var lui_a_terre := coop and not heros_partenaire.est_vivant()
	label_partenaire.visible = coop and lui_a_terre and not moi_a_terre
	label_mort.visible = moi_a_terre
	if not moi_a_terre:
		_les_deux_a_terre_depuis = -1.0
		return
	if panneau_fin:
		label_mort.visible = false
		return
	if not coop:
		if mode_expedition:
			label_mort.text = "Vous êtes tombé…"
		else:
			label_mort.text = "Vous êtes tombé…\nRetour dans %d s" % ceili(heros.temps_avant_reapparition())
	elif not lui_a_terre:
		_les_deux_a_terre_depuis = -1.0
		label_mort.text = "Tu es à terre !\nTon partenaire peut te relever (%d %%)" % roundi(heros.progres_reanimation * 100.0)
	else:
		var t := Time.get_ticks_msec() / 1000.0
		if _les_deux_a_terre_depuis < 0.0:
			_les_deux_a_terre_depuis = t
		if mode_expedition:
			label_mort.text = "Vous êtes tombés…"
			return
		var reste: float = regles.temps_avant_retour if regles else heros.EQ.coop_delai_retour - (t - _les_deux_a_terre_depuis)
		label_mort.text = "Vous êtes tombés…\nRetour au départ dans %d s" % maxi(ceili(reste), 0)


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
