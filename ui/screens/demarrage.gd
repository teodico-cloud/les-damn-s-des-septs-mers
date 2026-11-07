extends Control
## Écran titre (refonte de l'interface, 05/11, direction « gravure marine » validée par Téo) : derrière, le navire
## des damnés amarré au ponton, de nuit (DecorMenu) ; à gauche, le titre gravé à l'or sur une rose des vents, et
## le menu en planches cerclées de fer clouées le long d'une corde, un peu de travers comme posées à la main.
## En haut à droite, la bourse (doublons, objets des coffres) ; en bas à droite, la version et le Mode test.
## « Réglages » (jalon 6) ouvre l'écran Réglages par-dessus (PanneauReglages).
## Mode test (APK de test) : santé infinie, salle de départ de l'expédition, malédiction, héros Meshy, coffres de test (des
## objets pour essayer l'équipement tout de suite), ressources de test (doublons et matériaux pour les achats).

const SCENE_VITRINE := "res://game/vitrine/vitrine.tscn"
const SCENE_CHOIX := "res://ui/screens/choix_heros.tscn"
const SCENE_COOP := "res://ui/screens/coop.tscn"
const SCENE_REPAIRE := "res://game/repaire/repaire.tscn"
const MATIERES := "res://assets/ui/matieres/"
const ROUGE_TITRE := Color("c9503f")

var decor: DecorMenu
var voile: ColorRect
var bouton_vitrine: Button
var bouton_repaire: Button
var bouton_combat: Button
var bouton_coop: Button
var bouton_reglages: Button
var panneau_reglages: Control   ## l'écran Réglages ouvert par-dessus (null sinon)
var label_doublons: Label
var bouton_test: Button
var panneau_test: PanelContainer
var bouton_sante: Button
var bouton_depart: Button
var bouton_coque: Button
var bouton_meshy: Button   ## Mode test (07/11) : les héros Meshy de Téo
var label_test: Label
var changer_de_scene := true   ## faux dans les tests : `scene_demandee` dit où l'on serait allé
var scene_demandee := ""
const DEPARTS: Array[StringName] = [&"", &"tresor", &"bosco", &"chaloupe"]
const NOMS_DEPARTS := {&"": "salle 1", &"tresor": "trésor", &"bosco": "antre du Bosco", &"chaloupe": "chaloupe"}


func _ready() -> void:
	get_tree().set_quit_on_go_back(true)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_construire()


func _construire() -> void:
	decor = DecorMenu.new()
	decor.name = "Decor"
	add_child(decor)
	_lune()
	# l'ombre à gauche, où se posent le titre et le menu ; et en bas, sous la version
	add_child(_degrade(Vector2(0, 0.5), Vector2(1, 0.5), [Color(0.03, 0.025, 0.02, 0.94), Color(0.03, 0.025, 0.02, 0.7),
			Color(0.03, 0.025, 0.02, 0.0)], [0.0, 0.33, 0.68]))
	add_child(_degrade(Vector2(0.5, 1), Vector2(0.5, 0), [Color(0, 0, 0, 0.6), Color(0, 0, 0, 0)], [0.0, 0.25]))
	_titre()
	_menu()
	_bourse()
	_pied()
	_mode_test()
	voile = EffetsUI.voile(self)


## Une lune voilée dans la brume, en haut à droite (au-dessus des mâts, sous la bourse).
func _lune() -> void:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0.85, 0.9, 1.0, 0.5), Color(0.7, 0.8, 1.0, 0.16), Color(0.5, 0.6, 0.8, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 0.12, 1.0])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	var halo := TextureRect.new()
	halo.texture = tex
	halo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	halo.size = Vector2(560, 560)
	halo.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	halo.position = Vector2(-560, -150)
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(halo)


func _titre() -> void:
	var rose := TextureRect.new()
	rose.texture = load(MATIERES + "rose_des_vents.png")
	rose.position = Vector2(-40, -36)
	rose.size = Vector2(320, 320)
	rose.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rose.modulate = Color(1, 1, 1, 0.16)
	rose.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rose)
	var bloc := Control.new()
	bloc.position = Vector2(64, 40)
	bloc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bloc)
	var t1 := Label.new()
	t1.text = "Les Damnés"
	t1.theme_type_variation = &"LabelTitre"
	t1.add_theme_font_size_override("font_size", 96)
	t1.add_theme_constant_override("outline_size", 10)
	t1.add_theme_constant_override("shadow_offset_y", 5)
	bloc.add_child(t1)
	var t2 := Label.new()
	t2.text = "des Sept Mers"
	t2.add_theme_font_override("font", load("res://assets/ui/polices/IMFellEnglish-Regular.ttf"))
	t2.add_theme_font_size_override("font_size", 56)
	t2.add_theme_color_override("font_color", ROUGE_TITRE)
	t2.add_theme_constant_override("outline_size", 8)
	t2.position = Vector2(150, 102)
	bloc.add_child(t2)
	var corde := _texture_repetee("cordage.png", Vector2(470, 14))
	corde.position = Vector2(4, 182)
	bloc.add_child(corde)
	EffetsUI.entree(bloc, 0.15, Vector2(0, -16), 0.8)


## Les planches du menu, clouées le long d'une corde verticale, un peu de travers (posées à la main).
func _menu() -> void:
	var corde := _texture_repetee("cordage.png", Vector2(560, 14))
	corde.rotation = PI / 2.0
	corde.position = Vector2(76, 226)
	add_child(corde)
	var y := 270.0
	bouton_repaire = _planche("Le repaire", &"BoutonPrincipal", Vector2(480, 100), Vector2(54, y), -0.8, 0.35)
	bouton_repaire.pressed.connect(_ouvrir_repaire)
	bouton_coop = _planche("Jouer à deux", &"", Vector2(430, 84), Vector2(78, y + 118), 0.6, 0.43)
	bouton_coop.pressed.connect(_ouvrir_coop)
	bouton_combat = _planche("Combat d'entraînement", &"", Vector2(430, 84), Vector2(62, y + 218), -0.4, 0.51)
	bouton_combat.pressed.connect(_ouvrir_arene)
	bouton_vitrine = _planche("Voir les héros", &"BoutonPetit", Vector2(300, 68), Vector2(86, y + 318), 0.9, 0.59)
	bouton_vitrine.pressed.connect(_ouvrir_vitrine)
	bouton_reglages = _planche("Réglages", &"BoutonPetit", Vector2(220, 68), Vector2(398, y + 322), -0.7, 0.65)
	bouton_reglages.pressed.connect(ouvrir_reglages)


func _planche(texte: String, variation: StringName, taille: Vector2, pos: Vector2, degres: float, delai: float) -> Button:
	var b := Button.new()
	b.text = texte
	b.theme_type_variation = variation
	b.custom_minimum_size = taille
	b.size = taille
	b.position = pos
	b.rotation_degrees = degres
	add_child(b)
	EffetsUI.animer_bouton(b)
	EffetsUI.entree(b, delai, Vector2(-60, 0))
	return b


## La bourse, en haut à droite : une étiquette de cuir avec la pièce maudite.
func _bourse() -> void:
	var p := PanelContainer.new()
	p.theme_type_variation = &"PanelCuir"
	_coller_a_droite(p, 28, 22)
	add_child(p)
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override("separation", 10)
	p.add_child(ligne)
	var piece := TextureRect.new()
	piece.texture = load("res://assets/ui/icones/doublon.svg")
	piece.custom_minimum_size = Vector2(38, 38)
	piece.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	piece.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ligne.add_child(piece)
	label_doublons = Label.new()
	label_doublons.theme_type_variation = &"LabelGras"
	label_doublons.add_theme_font_size_override("font_size", 26)
	label_doublons.add_theme_color_override("font_color", Color("deba70"))
	ligne.add_child(label_doublons)
	_textes_doublons()
	EffetsUI.apparition(p, 0.5)


func _pied() -> void:
	var version := Label.new()
	version.text = "version %s" % ProjectSettings.get_setting("application/config/version", "?")
	version.add_theme_font_size_override("font_size", 20)
	version.add_theme_color_override("font_color", Color("d9c79f", 0.5))
	version.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	version.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	version.grow_vertical = Control.GROW_DIRECTION_BEGIN
	version.position -= Vector2(28, 14)
	add_child(version)


## Mode test (prévu dans la conception) : essayer un point précis en 30 secondes. Une petite étiquette en bas à
## droite ; ses réglages sur un cuir, au-dessus.
func _mode_test() -> void:
	bouton_test = Button.new()
	bouton_test.text = "Mode test"
	bouton_test.theme_type_variation = &"BoutonOnglet"
	bouton_test.add_theme_font_size_override("font_size", 22)
	bouton_test.custom_minimum_size = Vector2(170, 52)
	bouton_test.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	bouton_test.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	bouton_test.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bouton_test.position += Vector2(-28, -46)
	bouton_test.pressed.connect(func(): panneau_test.visible = not panneau_test.visible)
	add_child(bouton_test)
	EffetsUI.animer_bouton(bouton_test)
	panneau_test = PanelContainer.new()
	panneau_test.theme_type_variation = &"PanelCuir"
	panneau_test.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	panneau_test.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panneau_test.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panneau_test.position += Vector2(-28, -112)
	panneau_test.visible = false
	add_child(panneau_test)
	var liste := VBoxContainer.new()
	liste.add_theme_constant_override("separation", 8)
	panneau_test.add_child(liste)
	bouton_sante = Button.new()
	bouton_depart = Button.new()
	bouton_coque = Button.new()
	bouton_meshy = Button.new()
	var bouton_coffres := Button.new()
	bouton_coffres.text = "Coffres de test"
	bouton_coffres.pressed.connect(remplir_coffres_de_test)
	var bouton_ressources := Button.new()
	bouton_ressources.text = "Ressources de test"
	bouton_ressources.pressed.connect(remplir_ressources_de_test)
	for b in [bouton_sante, bouton_depart, bouton_coque, bouton_meshy, bouton_coffres, bouton_ressources]:
		b.theme_type_variation = &"BoutonPetit"
		b.custom_minimum_size = Vector2(360, 60)
		liste.add_child(b)
	bouton_sante.pressed.connect(func():
		Partie.debug_sante_infinie = not Partie.debug_sante_infinie
		_textes_test())
	bouton_depart.pressed.connect(func():
		Partie.debug_depart = DEPARTS[(DEPARTS.find(Partie.debug_depart) + 1) % DEPARTS.size()]
		_textes_test())
	bouton_coque.pressed.connect(func():
		Partie.debug_tout_debloque = not Partie.debug_tout_debloque
		_textes_test())
	bouton_meshy.pressed.connect(func():
		Partie.debug_heros_meshy = not Partie.debug_heros_meshy
		_textes_test())
	label_test = Label.new()
	label_test.theme_type_variation = &"LabelGras"
	label_test.add_theme_font_size_override("font_size", 22)
	label_test.add_theme_color_override("font_color", Color("e0603f"))
	label_test.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	label_test.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	label_test.grow_vertical = Control.GROW_DIRECTION_BEGIN
	label_test.position += Vector2(-212, -58)
	add_child(label_test)
	_textes_test()


func _textes_doublons() -> void:
	var n: int = Sauvegarde.doublons()
	var objets: int = Sauvegarde.objets().size()
	label_doublons.text = "%d doublons · %d objet%s" % [n, objets, "s" if objets > 1 else ""]


## Mode test : un objet de chaque sorte dans les coffres (les cinq uniques compris), pour essayer
## l'équipement et ses effets sans attendre la chance. Les identifiants « test_… » ne s'ajoutent qu'une fois.
func remplir_coffres_de_test() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var nouveaux := []
	for cle in Butin.BASES:
		nouveaux.append({"id": "test_" + cle, "base": cle, "rarete": Butin.Rarete.EPIQUE,
				"effets": Butin.tirer_effets_plus(rng, Butin.Rarete.EPIQUE)})
	for cle in Butin.UNIQUES:
		nouveaux.append({"id": "test_" + cle, "base": cle, "rarete": Butin.UNIQUES[cle]["rarete"], "effets": {}})
	Sauvegarde.encaisser("coffres_de_test_%d" % Time.get_ticks_usec(), nouveaux, 0, {"test": true})
	_textes_doublons()


## Mode test (jalon 5) : 1 000 doublons et l'entrepôt rempli jusqu'au plafond, pour essayer les achats.
func remplir_ressources_de_test() -> void:
	var matieres := {}
	for m in Butin.MATIERES:
		matieres[m] = Sauvegarde.plafond(m) - Sauvegarde.ressource(m)
	Sauvegarde.encaisser("ressources_de_test_%d" % Time.get_ticks_usec(), [], 1000, {"test": true}, matieres)
	_textes_doublons()


func _textes_test() -> void:
	bouton_sante.text = "Santé infinie : %s" % ("oui" if Partie.debug_sante_infinie else "non")
	bouton_depart.text = "Départ : %s" % NOMS_DEPARTS.get(Partie.debug_depart, "?")
	bouton_coque.text = "Malédiction : %s" % ("toutes" if Partie.debug_tout_debloque else "selon la coque")
	bouton_meshy.text = "Héros Meshy : %s" % ("oui" if Partie.debug_heros_meshy else "non")
	var actif := Partie.debug_sante_infinie or Partie.debug_depart != &"" or Partie.debug_tout_debloque \
			or Partie.debug_heros_meshy
	label_test.text = "Mode test actif" if actif else ""


# ---------------------------------------------------------------- navigation
func _aller(scene: String) -> void:
	scene_demandee = scene
	if not changer_de_scene:
		return
	EffetsUI.fondu_puis(voile, func(): get_tree().change_scene_to_file(scene))


func _ouvrir_repaire() -> void:
	Reseau.quitter()
	Partie.revenir_en_solo()
	Partie.lieu_repaire = &""
	_aller(SCENE_REPAIRE)


func _ouvrir_arene() -> void:
	Reseau.quitter()
	Partie.revenir_en_solo()
	Partie.destination = &"arene"
	_aller(SCENE_CHOIX)


func _ouvrir_coop() -> void:
	Partie.mode = Partie.Mode.SOLO
	_aller(SCENE_COOP)


func _ouvrir_vitrine() -> void:
	_aller(SCENE_VITRINE)


## Les réglages (jalon 6), par-dessus l'écran titre ; le retour d'Android les referme au lieu de quitter le jeu.
func ouvrir_reglages() -> void:
	if panneau_reglages:
		return
	panneau_reglages = PanneauReglages.new()
	panneau_reglages.ferme.connect(fermer_reglages)
	add_child(panneau_reglages)
	Sons.jouer(&"parchemin")
	var ombre := ColorRect.new()   # (le menu s'assombrit derrière le parchemin, comme le repaire derrière un lieu)
	ombre.color = Color(0.02, 0.015, 0.01, 0.62)
	ombre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ombre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panneau_reglages.add_child(ombre)
	panneau_reglages.move_child(ombre, 0)
	move_child(voile, -1)   # (le fondu reste au-dessus de tout)
	get_tree().set_quit_on_go_back(false)


func fermer_reglages() -> void:
	if panneau_reglages == null:
		return
	Sons.jouer(&"parchemin_ferme")
	panneau_reglages.queue_free()
	panneau_reglages = null
	# (plus tard : Godot décide de quitter après avoir prévenu les nœuds du retour qui ferme ce panneau)
	get_tree().set_quit_on_go_back.call_deferred(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and panneau_reglages:
		fermer_reglages()


# ---------------------------------------------------------------- petits outils
## Accroché en haut à droite, à `droite` px du bord : il grandit vers la gauche (sa taille vient de son contenu).
func _coller_a_droite(n: Control, droite: float, haut: float) -> void:
	n.anchor_left = 1.0
	n.anchor_right = 1.0
	n.offset_left = -droite
	n.offset_right = -droite
	n.offset_top = haut
	n.grow_horizontal = Control.GROW_DIRECTION_BEGIN


func _degrade(de: Vector2, vers: Vector2, couleurs: Array, positions: Array) -> TextureRect:
	var g := Gradient.new()
	g.colors = PackedColorArray(couleurs)
	g.offsets = PackedFloat32Array(positions)
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = de
	tex.fill_to = vers
	var r := TextureRect.new()
	r.texture = tex
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _texture_repetee(nom: String, taille: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = load(MATIERES + nom)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_TILE
	r.size = taille
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r
