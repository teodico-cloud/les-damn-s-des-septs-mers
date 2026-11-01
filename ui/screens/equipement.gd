extends Node3D
## Écran Équipement (jalon 4, ouvert depuis l'écran titre, choix de Téo) : un onglet par héros, debout à
## gauche avec l'arme qu'il porte en main ; ses 3 emplacements (arme, deux reliques) ; les objets des
## coffres qui vont à l'emplacement choisi ; la fiche de l'objet touché, avec la comparaison ▲▼ avec
## ce qu'il porte (annexe retenue par Téo) et le bouton Équiper. Tout est enregistré aussitôt.

const SCENE_MENU := "res://ui/screens/demarrage.tscn"
const DECOR := "res://assets/models/decor/"
const COULEUR_OS := Color("e2d6ba")
const COULEUR_OR := Color("ac8036")
const VERT := Color("6cffa0")
const ROUGE := Color(1.0, 0.45, 0.4)
const NOMS_HEROS := {&"bretteur": "Le Bretteur", &"occultiste": "L'Occultiste"}

var heros_affiche: StringName = &"bretteur"
var emplacement := "arme"          ## emplacement choisi
var selection := {}                ## objet dont la fiche est ouverte
var changer_de_scene := true       ## faux dans les tests

var onglets := {}                  ## héros -> Button
var boutons_emplacements := {}     ## emplacement -> Button
var liste: VBoxContainer
var label_vide: Label
var label_doublons: Label
var label_resume: Label
var fiche: VBoxContainer
var bouton_equiper: Button
var bouton_retirer: Button
var _modele: Node3D                ## le héros debout (un vrai Heros, figé, pour l'arme en main)
var _socle: Node3D


func _ready() -> void:
	get_tree().set_quit_on_go_back(false)
	_monde()
	_interface()
	montrer_heros(Partie.heros_local if Partie.heros_local in NOMS_HEROS else &"bretteur")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		retour_menu()


func retour_menu() -> void:
	if changer_de_scene:
		get_tree().change_scene_to_file(SCENE_MENU)


# ---------------------------------------------------------------- actions
func montrer_heros(h: StringName) -> void:
	heros_affiche = h
	for cle in onglets:
		onglets[cle].button_pressed = cle == h
	choisir_emplacement("arme")
	_poser_modele()


func choisir_emplacement(e: String) -> void:
	emplacement = e
	selection = Sauvegarde.porte(heros_affiche, e)
	_rafraichir()


func choisir_objet(objet: Dictionary) -> void:
	selection = objet
	_rafraichir()


func equiper_selection() -> void:
	if selection.is_empty():
		return
	if Sauvegarde.equiper(heros_affiche, emplacement, selection["id"]):
		_poser_modele()
	_rafraichir()


func retirer() -> void:
	Sauvegarde.retirer(heros_affiche, emplacement)
	_poser_modele()
	_rafraichir()


## Les objets des coffres qui vont à l'emplacement choisi, les plus rares d'abord.
func objets_possibles() -> Array:
	var r := Sauvegarde.objets().filter(func(o): return Equipement.convient(o, heros_affiche, emplacement))
	r.sort_custom(func(a, b):
		if int(a["rarete"]) != int(b["rarete"]):
			return int(a["rarete"]) > int(b["rarete"])
		return Butin.nom(a) < Butin.nom(b))
	return r


# ---------------------------------------------------------------- affichage
func _rafraichir() -> void:
	label_doublons.text = "%d doublons" % Sauvegarde.doublons()
	var portes := Sauvegarde.portes(heros_affiche)
	for e in boutons_emplacements:
		var b: Button = boutons_emplacements[e]
		var o: Dictionary = portes[e]
		b.text = Butin.nom(o) if not o.is_empty() else "— vide —"
		b.add_theme_color_override("font_color", Butin.couleur(o) if not o.is_empty() else Color(COULEUR_OS, 0.5))
		b.add_theme_color_override("font_hover_color", Butin.couleur(o) if not o.is_empty() else Color(COULEUR_OS, 0.5))
		b.add_theme_color_override("font_pressed_color", Butin.couleur(o) if not o.is_empty() else Color(COULEUR_OS, 0.5))
		b.button_pressed = e == emplacement
	# ce que donne tout l'équipement porté
	var lignes := []
	var total := Equipement.bonus(portes.values())
	for cle in Equipement._ordonner(total.keys()):
		lignes.append("· " + Equipement.texte(cle, total[cle]))
	label_resume.text = "\n".join(lignes) if not lignes.is_empty() else "Aucun objet porté."
	# la liste
	for c in liste.get_children():
		liste.remove_child(c)
		c.queue_free()
	var possibles := objets_possibles()
	label_vide.visible = possibles.is_empty()
	for o in possibles:
		liste.add_child(_ligne_objet(o))
	_remplir_fiche()


func _ligne_objet(o: Dictionary) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 58)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = true
	var ou := Sauvegarde.ou_est_porte(o["id"])
	var etiquette := ""
	if not ou.is_empty():
		if ou[0] == heros_affiche and ou[1] == emplacement:
			etiquette = "   (porté)"
		elif ou[0] == heros_affiche:
			etiquette = "   (autre relique)"
		else:
			etiquette = "   (porté par %s)" % NOMS_HEROS[ou[0]].to_lower()
	b.text = "  " + Butin.nom(o) + etiquette
	b.add_theme_font_size_override("font_size", 24)
	for etat in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(etat, Butin.couleur(o))
	for etat in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(etat, _style(etat == "pressed" or o.get("id") == selection.get("id", "")))
	b.pressed.connect(choisir_objet.bind(o))
	return b


func _remplir_fiche() -> void:
	for c in fiche.get_children():
		fiche.remove_child(c)
		c.queue_free()
	var porte := Sauvegarde.porte(heros_affiche, emplacement)
	if selection.is_empty():
		_texte(fiche, "Touchez un objet de la liste pour voir sa fiche." if not objets_possibles().is_empty() else "", 22, Color(COULEUR_OS, 0.7))
		bouton_equiper.visible = false
		bouton_retirer.visible = not porte.is_empty()
		return
	var def := Butin.definition(selection)
	_texte(fiche, Butin.nom(selection), 32, Butin.couleur(selection))
	var genre := "Arme" if def.get("type") == "arme" else "Relique"
	_texte(fiche, "%s · %s" % [genre, Butin.NOMS_RARETES[clampi(int(selection.get("rarete", 0)), 0, 4)]], 20, Color(COULEUR_OS, 0.7))
	for l in Equipement.textes(selection):
		_texte(fiche, l[0], 22, COULEUR_OS if l[1] else ROUGE)
	var est_porte: bool = not porte.is_empty() and porte["id"] == selection["id"]
	if not est_porte:
		var portes := Sauvegarde.portes(heros_affiche)
		# (un objet déjà porté à l'autre emplacement de relique y serait retiré : la comparaison en tient compte)
		var ou := Sauvegarde.ou_est_porte(selection["id"])
		if not ou.is_empty() and ou[0] == heros_affiche:
			portes[ou[1]] = {}
		var comparaison := Equipement.comparer(Equipement.bonus(portes.values()), Equipement.avec(portes, emplacement, selection))
		if not comparaison.is_empty():
			_texte(fiche, "Si vous l'équipez :" if porte.is_empty() else "À la place de « %s » :" % Butin.nom(porte), 20, Color(COULEUR_OS, 0.7))
			for l in comparaison:
				_texte(fiche, l[0], 22, VERT if l[1] else ROUGE)
	bouton_equiper.visible = not est_porte
	bouton_retirer.visible = est_porte


func _texte(parent: Control, texte: String, taille: int, couleur: Color) -> Label:
	var l := Label.new()
	l.text = texte
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", couleur)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	parent.add_child(l)
	return l


## Le héros affiché debout à gauche, équipé (l'arme qu'il porte est dans sa main).
func _poser_modele() -> void:
	if _modele:
		_modele.queue_free()
	_modele = Heros.creer(heros_affiche)
	_modele.equiper(Sauvegarde.equipes(heros_affiche))
	_modele.position = Vector3(0, 0, 0)
	_socle.add_child(_modele)
	_modele.set_physics_process(false)   # (posé là pour être regardé : ni pesanteur, ni règles)
	_modele.rotation.y = 0.35
	_modele.anim.play("Idle")


# ---------------------------------------------------------------- monde
func _monde() -> void:
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.02, 0.03, 0.05)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.3, 0.4, 0.55)
	e.ambient_light_energy = 0.45
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	e.glow_intensity = 0.9
	we.environment = e
	add_child(we)
	for x in [-4, 0, 4]:
		for z in [-4, 0, 4]:
			_objet("floor_tile_large", Vector3(x, 0, z))
	for x in [-4, 0, 4]:
		_objet("wall", Vector3(x, 0, -5.5))
	_objet("torch_mounted", Vector3(-1.6, 2.0, -5.1))
	var torche := OmniLight3D.new()
	torche.position = Vector3(-1.6, 2.6, -4.6)
	torche.light_color = Color(1.0, 0.55, 0.2)
	torche.light_energy = 2.2
	torche.omni_range = 7.0
	add_child(torche)
	var appoint := OmniLight3D.new()
	appoint.position = Vector3(0.6, 2.6, 3.0)
	appoint.light_color = Color(1.0, 0.8, 0.6)
	appoint.light_energy = 1.4
	appoint.omni_range = 8.0
	add_child(appoint)
	_socle = Node3D.new()
	_socle.position = Vector3(0, 0, 0)
	add_child(_socle)
	var camera := Camera3D.new()
	camera.fov = 40.0
	add_child(camera)
	# le héros à gauche de l'écran (le reste : l'interface)
	camera.look_at_from_position(Vector3(2.2, 1.35, 5.4), Vector3(2.2, 1.05, 0), Vector3.UP)
	camera.current = true


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

	var retour := _bouton("Retour", Vector2(170, 70), 28)
	retour.position = Vector2(24, 18)
	retour.pressed.connect(retour_menu)
	racine.add_child(retour)

	var titre := _texte(racine, "Équipement", 46, COULEUR_OS)
	titre.autowrap_mode = TextServer.AUTOWRAP_OFF
	titre.add_theme_constant_override("outline_size", 10)
	titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titre.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_KEEP_SIZE)
	titre.grow_horizontal = Control.GROW_DIRECTION_BOTH
	titre.offset_left = -200
	titre.offset_right = 200
	titre.offset_top = 18

	label_doublons = _texte(racine, "", 30, Color("e0b04a"))
	label_doublons.autowrap_mode = TextServer.AUTOWRAP_OFF
	label_doublons.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label_doublons.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	label_doublons.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	label_doublons.offset_left = -400
	label_doublons.offset_right = -24
	label_doublons.offset_top = 30

	# onglets des héros (sous ses pieds)
	var rangee := HBoxContainer.new()
	rangee.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	rangee.grow_vertical = Control.GROW_DIRECTION_BEGIN
	rangee.offset_left = 24
	rangee.offset_top = -80
	rangee.offset_bottom = -16
	rangee.add_theme_constant_override("separation", 10)
	racine.add_child(rangee)
	var groupe := ButtonGroup.new()
	for h in NOMS_HEROS:
		var b := _bouton(NOMS_HEROS[h], Vector2(190, 60), 24)
		b.toggle_mode = true
		b.button_group = groupe
		b.pressed.connect(montrer_heros.bind(h))
		rangee.add_child(b)
		onglets[h] = b

	# emplacements
	var colonne := VBoxContainer.new()
	colonne.position = Vector2(430, 104)
	colonne.custom_minimum_size = Vector2(330, 0)
	colonne.add_theme_constant_override("separation", 8)
	racine.add_child(colonne)
	var groupe_e := ButtonGroup.new()
	for e in Equipement.EMPLACEMENTS:
		if e != "relique_2":
			_texte(colonne, "ARME" if e == "arme" else "RELIQUES", 20, Color(COULEUR_OS, 0.7))
		var b := _bouton("", Vector2(330, 64), 24)
		b.toggle_mode = true
		b.button_group = groupe_e
		b.clip_text = true
		b.pressed.connect(choisir_emplacement.bind(e))
		colonne.add_child(b)
		boutons_emplacements[e] = b
	var espace := Control.new()
	espace.custom_minimum_size = Vector2(0, 6)
	colonne.add_child(espace)
	_texte(colonne, "CE QUE DONNE L'ÉQUIPEMENT", 20, Color(COULEUR_OS, 0.7))
	label_resume = _texte(colonne, "", 20, COULEUR_OS)
	label_resume.custom_minimum_size = Vector2(330, 0)

	# objets des coffres (à droite, en haut) et fiche (en dessous)
	var droite := Control.new()
	droite.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	droite.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	droite.offset_left = -486
	droite.offset_right = -24
	droite.offset_top = 104
	droite.offset_bottom = -16
	droite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	racine.add_child(droite)
	var cadre_liste := PanelContainer.new()
	cadre_liste.add_theme_stylebox_override("panel", _style(false))
	cadre_liste.position = Vector2(0, 0)
	cadre_liste.size = Vector2(462, 250)
	droite.add_child(cadre_liste)
	var defile := ScrollContainer.new()
	defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cadre_liste.add_child(defile)
	liste = VBoxContainer.new()
	liste.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	liste.add_theme_constant_override("separation", 6)
	defile.add_child(liste)
	label_vide = _texte(droite, "Rien dans vos coffres pour cette place.\nRapportez du butin d'une expédition !", 22, Color(COULEUR_OS, 0.75))
	label_vide.position = Vector2(20, 70)
	label_vide.size = Vector2(422, 120)
	label_vide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var cadre_fiche := PanelContainer.new()
	cadre_fiche.add_theme_stylebox_override("panel", _style(false))
	cadre_fiche.position = Vector2(0, 262)
	cadre_fiche.size = Vector2(462, 338)
	droite.add_child(cadre_fiche)
	var dans_fiche := VBoxContainer.new()
	dans_fiche.add_theme_constant_override("separation", 4)
	cadre_fiche.add_child(dans_fiche)
	var defile_fiche := ScrollContainer.new()
	defile_fiche.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	defile_fiche.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dans_fiche.add_child(defile_fiche)
	fiche = VBoxContainer.new()
	fiche.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fiche.add_theme_constant_override("separation", 2)
	defile_fiche.add_child(fiche)
	var boutons := HBoxContainer.new()
	boutons.alignment = BoxContainer.ALIGNMENT_END
	boutons.add_theme_constant_override("separation", 10)
	dans_fiche.add_child(boutons)
	bouton_retirer = _bouton("Retirer", Vector2(160, 62), 26)
	bouton_retirer.pressed.connect(retirer)
	boutons.add_child(bouton_retirer)
	bouton_equiper = _bouton("Équiper", Vector2(190, 62), 28)
	bouton_equiper.add_theme_color_override("font_color", VERT)
	bouton_equiper.pressed.connect(equiper_selection)
	boutons.add_child(bouton_equiper)


func _bouton(texte: String, taille: Vector2, police: int) -> Button:
	var b := Button.new()
	b.text = texte
	b.custom_minimum_size = taille
	b.add_theme_font_size_override("font_size", police)
	b.add_theme_color_override("font_color", COULEUR_OS)
	for etat in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(etat, _style(etat == "pressed"))
	return b


func _style(enfonce: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.3, 0.2, 0.12, 0.95) if enfonce else Color(0.16, 0.11, 0.08, 0.85)
	s.border_color = Color("e0b04a") if enfonce else COULEUR_OR
	s.set_border_width_all(3)
	s.set_corner_radius_all(12)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s
