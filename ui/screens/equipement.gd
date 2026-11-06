extends Node3D
## Écran Équipement (jalon 4 ; jalon 5 : ouvert depuis l'entrepôt du repaire) : un onglet par héros, debout à
## gauche avec l'arme qu'il porte en main ; ses 3 emplacements (arme, deux reliques) ; les objets des
## coffres qui vont à l'emplacement choisi ; la fiche de l'objet touché, avec la comparaison ▲▼ avec
## ce qu'il porte (annexe retenue par Téo) et le bouton Équiper. Tout est enregistré aussitôt.
## Refonte de l'interface (05/11) : les emplacements et ce que donne l'équipement sur une laniere de cuir ; les
## coffres sur un parchemin (noms à l'encre, couleur de leur rareté) ; la fiche de l'objet sur un cuir cousu,
## comme dans la planche de direction artistique ; onglets des héros en cuir (choisi : une planche).

const SCENE_MENU := "res://game/repaire/repaire.tscn"   ## (jalon 5 : ouvert depuis l'entrepôt du repaire)
const DECOR := "res://assets/models/decor/"
const COULEUR_OS := Color("d9c79f")    ## parchemin (texte clair, sur le cuir)
const COULEUR_OR := Color("deba70")
const VERT := Color("9fd49a")
const ROUGE := Color("ff8f74")
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
	Partie.lieu_repaire = &"entrepot"   # (on revient devant l'entrepôt)
	if changer_de_scene:
		get_tree().change_scene_to_file(SCENE_MENU)


# ---------------------------------------------------------------- actions
func montrer_heros(h: StringName) -> void:
	heros_affiche = h
	for cle in onglets:
		onglets[cle].button_pressed = cle == h
		onglets[cle].theme_type_variation = &"BoutonOngletActif" if cle == h else &"BoutonOnglet"
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
		Sons.jouer(&"fer")   # (l'arme ou l'objet pris en main)
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
		var couleur := Butin.couleur(o) if not o.is_empty() else Color(COULEUR_OS, 0.5)
		for etat in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(etat, couleur)
		b.button_pressed = e == emplacement
		# l'emplacement choisi : une planche ; les autres : une laniere de cuir
		b.theme_type_variation = &"BoutonOngletActif" if e == emplacement else &"BoutonOnglet"
	# ce que donne tout l'équipement porté
	var lignes := []
	var total := Equipement.bonus(portes.values())
	for cle in Equipement._ordonner(total.keys()):
		lignes.append("◆  " + Equipement.texte(cle, total[cle]))
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
	elif Sauvegarde.emplacement_du_meme_unique(heros_affiche, o, emplacement) != "":
		etiquette = "   (en double)"
	b.text = Butin.nom(o) + etiquette
	b.add_theme_font_override("font", load("res://assets/ui/polices/AlegreyaSans-Bold.ttf"))
	b.add_theme_font_size_override("font_size", 25)
	for etat in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(etat, StyleRepaire.encre(Butin.couleur(o)))
	b.add_theme_constant_override("outline_size", 0)
	var choisi: bool = o.get("id") == selection.get("id", "")
	for etat in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(etat, _ligne_style(choisi or etat == "pressed"))
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
	var nom := _texte(fiche, Butin.nom(selection), 34, Butin.couleur(selection))
	nom.add_theme_font_override("font", load("res://assets/ui/polices/IMFellEnglishSC-Regular.ttf"))
	var genre := "Arme" if def.get("type") == "arme" else "Relique"
	_texte(fiche, "%s · %s" % [genre, Butin.NOMS_RARETES[clampi(int(selection.get("rarete", 0)), 0, 4)]], 20, Color(COULEUR_OS, 0.7))
	for l in Equipement.textes(selection):
		_texte(fiche, l[0], 22, COULEUR_OS if l[1] else ROUGE)
	var est_porte: bool = not porte.is_empty() and porte["id"] == selection["id"]
	if not est_porte:
		var portes := Sauvegarde.portes(heros_affiche)
		var avant := Equipement.bonus(portes.values())   # (ce que donne l'équipement porté maintenant)
		# (un objet déjà porté à l'autre emplacement de relique y serait retiré : la comparaison en tient compte)
		var ou := Sauvegarde.ou_est_porte(selection["id"])
		if not ou.is_empty() and ou[0] == heros_affiche:
			portes[ou[1]] = {}
		# (objet unique : l'exemplaire que porte déjà ce héros serait retiré)
		var double := Sauvegarde.emplacement_du_meme_unique(heros_affiche, selection, emplacement)
		if double != "":
			portes[double] = {}
			_texte(fiche, "Objet unique : un seul par héros. L'exemplaire porté sera retiré.", 20, Color(COULEUR_OS, 0.7))
		var comparaison := Equipement.comparer(avant, Equipement.avec(portes, emplacement, selection))
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

	var retour := _bouton("Retour", Vector2(150, 60), 24)
	retour.theme_type_variation = &"BoutonPetit"
	retour.position = Vector2(22, 18)
	retour.pressed.connect(retour_menu)
	racine.add_child(retour)

	var plaque := PanelContainer.new()
	plaque.theme_type_variation = &"PanelPlaque"
	plaque.position = Vector2(186, 16)
	plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var titre := Label.new()
	titre.text = "Équipement"
	titre.theme_type_variation = &"LabelTitre"
	titre.add_theme_font_size_override("font_size", 34)
	plaque.add_child(titre)
	racine.add_child(plaque)

	# la bourse, en haut à droite
	var bourse := PanelContainer.new()
	bourse.theme_type_variation = &"PanelCuir"
	bourse.anchor_left = 1.0
	bourse.anchor_right = 1.0
	bourse.offset_left = -22
	bourse.offset_right = -22
	bourse.offset_top = 16
	bourse.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	bourse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	racine.add_child(bourse)
	var ligne_bourse := HBoxContainer.new()
	ligne_bourse.add_theme_constant_override("separation", 8)
	bourse.add_child(ligne_bourse)
	var piece := TextureRect.new()
	piece.texture = load("res://assets/ui/icones/doublon.svg")
	piece.custom_minimum_size = Vector2(34, 34)
	piece.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	piece.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ligne_bourse.add_child(piece)
	label_doublons = Label.new()
	label_doublons.theme_type_variation = &"LabelGras"
	label_doublons.add_theme_font_size_override("font_size", 26)
	label_doublons.add_theme_color_override("font_color", COULEUR_OR)
	ligne_bourse.add_child(label_doublons)

	# onglets des héros (sous ses pieds)
	var rangee := HBoxContainer.new()
	rangee.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	rangee.grow_vertical = Control.GROW_DIRECTION_BEGIN
	rangee.offset_left = 22
	rangee.offset_top = -78
	rangee.offset_bottom = -16
	rangee.add_theme_constant_override("separation", 10)
	racine.add_child(rangee)
	var groupe := ButtonGroup.new()
	for h in NOMS_HEROS:
		var b := _bouton(NOMS_HEROS[h], Vector2(190, 60), 24)
		b.theme_type_variation = &"BoutonOnglet"
		b.toggle_mode = true
		b.button_group = groupe
		b.pressed.connect(montrer_heros.bind(h))
		rangee.add_child(b)
		onglets[h] = b

	# emplacements et ce que donne l'équipement : une laniere de cuir, au milieu
	var laniere := PanelContainer.new()
	laniere.theme_type_variation = &"PanelCuir"
	laniere.position = Vector2(400, 96)
	laniere.custom_minimum_size = Vector2(372, 0)
	racine.add_child(laniere)
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 6)
	laniere.add_child(colonne)
	var groupe_e := ButtonGroup.new()
	for e in Equipement.EMPLACEMENTS:
		if e != "relique_2":
			_section(colonne, "Arme" if e == "arme" else "Reliques")
		var b := _bouton("", Vector2(320, 60), 24)
		b.theme_type_variation = &"BoutonOnglet"
		b.toggle_mode = true
		b.button_group = groupe_e
		b.clip_text = true
		b.add_theme_font_override("font", load("res://assets/ui/polices/AlegreyaSans-Bold.ttf"))
		b.pressed.connect(choisir_emplacement.bind(e))
		colonne.add_child(b)
		boutons_emplacements[e] = b
	var espace := Control.new()
	espace.custom_minimum_size = Vector2(0, 4)
	colonne.add_child(espace)
	_section(colonne, "Ce que donne l'équipement")
	label_resume = _texte(colonne, "", 21, COULEUR_OS)
	label_resume.custom_minimum_size = Vector2(320, 0)

	# objets des coffres (à droite, en haut, sur parchemin) et fiche (en dessous, sur cuir)
	var droite := Control.new()
	droite.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	droite.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	droite.offset_left = -486
	droite.offset_right = -22
	droite.offset_top = 96
	droite.offset_bottom = -14
	droite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	racine.add_child(droite)
	var cadre_liste := PanelContainer.new()
	cadre_liste.theme_type_variation = &"PanelParchemin"
	cadre_liste.add_theme_stylebox_override("panel", _parchemin_serre())
	cadre_liste.position = Vector2(0, 0)
	cadre_liste.size = Vector2(464, 300)
	droite.add_child(cadre_liste)
	var dans_liste := VBoxContainer.new()
	dans_liste.add_theme_constant_override("separation", 2)
	cadre_liste.add_child(dans_liste)
	var titre_coffres := Label.new()
	titre_coffres.text = "Vos coffres"
	titre_coffres.theme_type_variation = &"LabelEncreTitre"
	titre_coffres.add_theme_font_size_override("font_size", 26)
	dans_liste.add_child(titre_coffres)
	var defile := ScrollContainer.new()
	defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	defile.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dans_liste.add_child(defile)
	liste = VBoxContainer.new()
	liste.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	liste.add_theme_constant_override("separation", 2)
	defile.add_child(liste)
	label_vide = Label.new()
	label_vide.text = "Rien dans vos coffres pour cette place.\nRapportez du butin d'une expédition !"
	label_vide.theme_type_variation = &"LabelEncre"
	label_vide.add_theme_font_size_override("font_size", 22)
	label_vide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label_vide.position = Vector2(30, 92)
	label_vide.size = Vector2(404, 120)
	label_vide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	droite.add_child(label_vide)

	var cadre_fiche := PanelContainer.new()
	cadre_fiche.theme_type_variation = &"PanelCuir"
	cadre_fiche.position = Vector2(0, 310)
	cadre_fiche.size = Vector2(464, 300)
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
	bouton_retirer = _bouton("Retirer", Vector2(160, 60), 24)
	bouton_retirer.theme_type_variation = &"BoutonPetit"
	bouton_retirer.pressed.connect(retirer)
	boutons.add_child(bouton_retirer)
	bouton_equiper = _bouton("Équiper", Vector2(200, 64), 30)
	bouton_equiper.pressed.connect(equiper_selection)
	boutons.add_child(bouton_equiper)
	EffetsUI.voile(racine)


## Petit titre de section, gravé à l'or (sur le cuir).
func _section(parent: Control, texte: String) -> void:
	var l := Label.new()
	l.text = texte
	l.theme_type_variation = &"LabelSousTitre"
	l.add_theme_font_size_override("font_size", 22)
	parent.add_child(l)


func _bouton(texte: String, taille: Vector2, police: int) -> Button:
	var b := Button.new()
	b.text = texte
	b.custom_minimum_size = taille
	b.add_theme_font_size_override("font_size", police)
	EffetsUI.animer_bouton(b)
	return b


## Une ligne des coffres sur le parchemin : rien autour ; choisie, un lavis et un filet d'encre.
func _ligne_style(choisi: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.35, 0.22, 0.1, 0.18) if choisi else Color(0, 0, 0, 0)
	s.border_color = Color("6e5326", 0.8)
	s.border_width_left = 4 if choisi else 0
	s.content_margin_left = 12
	s.content_margin_right = 8
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	return s


## Le parchemin des coffres : une feuille clouée, sans cadre de bois (la place est comptée).
func _parchemin_serre() -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = load("res://assets/ui/matieres/affiche.png")
	s.set_texture_margin_all(48)
	s.content_margin_left = 30
	s.content_margin_right = 26
	s.content_margin_top = 40
	s.content_margin_bottom = 22
	return s
