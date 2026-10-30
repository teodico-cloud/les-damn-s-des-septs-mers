extends Control
## Écran titre : nom du jeu, expédition et combat d'entraînement (via le choix du héros), jeu à deux,
## vitrine, version ; « Mode test » (APK de test) : santé infinie, salle de départ de l'expédition.

const SCENE_VITRINE := "res://game/vitrine/vitrine.tscn"
const SCENE_CHOIX := "res://ui/screens/choix_heros.tscn"
const SCENE_COOP := "res://ui/screens/coop.tscn"
const COULEUR_OS := Color("e2d6ba")
const COULEUR_OR := Color("ac8036")

var bouton_vitrine: Button
var bouton_expedition: Button
var bouton_combat: Button
var bouton_coop: Button
var bouton_test: Button
var panneau_test: VBoxContainer
var bouton_sante: Button
var bouton_depart: Button
var label_test: Label
const DEPARTS: Array[StringName] = [&"", &"tresor", &"bosco", &"chaloupe"]
const NOMS_DEPARTS := {&"": "salle 1", &"tresor": "trésor", &"bosco": "antre du Bosco", &"chaloupe": "chaloupe"}


func _ready() -> void:
	get_tree().set_quit_on_go_back(true)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_construire()


func _construire() -> void:
	var fond := TextureRect.new()
	var degrade := Gradient.new()
	degrade.set_color(0, Color("1c3a32"))
	degrade.set_color(1, Color("070c10"))
	var tex := GradientTexture2D.new()
	tex.gradient = degrade
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.4)
	tex.fill_to = Vector2(1.1, 1.1)
	fond.texture = tex
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	fond.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(fond)

	var colonne := VBoxContainer.new()
	colonne.set_anchors_preset(Control.PRESET_CENTER)
	colonne.grow_horizontal = Control.GROW_DIRECTION_BOTH
	colonne.grow_vertical = Control.GROW_DIRECTION_BOTH
	colonne.alignment = BoxContainer.ALIGNMENT_CENTER
	colonne.add_theme_constant_override("separation", 20)
	add_child(colonne)

	var titre := Label.new()
	titre.text = "Les Damnés des Sept Mers"
	titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titre.add_theme_font_size_override("font_size", 72)
	titre.add_theme_color_override("font_color", COULEUR_OS)
	titre.add_theme_color_override("font_outline_color", Color("0b1418"))
	titre.add_theme_constant_override("outline_size", 12)
	colonne.add_child(titre)

	var sous_titre := Label.new()
	sous_titre.text = "Prototype — jalon 3"
	sous_titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sous_titre.add_theme_font_size_override("font_size", 30)
	sous_titre.add_theme_color_override("font_color", Color("6cffa0"))
	colonne.add_child(sous_titre)

	var espace := Control.new()
	espace.custom_minimum_size = Vector2(0, 10)
	colonne.add_child(espace)

	bouton_expedition = _bouton("Expédition")
	bouton_expedition.pressed.connect(_ouvrir_expedition)
	var centre_exp := CenterContainer.new()
	centre_exp.add_child(bouton_expedition)
	colonne.add_child(centre_exp)

	bouton_combat = _bouton("Combat d'entraînement")
	bouton_combat.pressed.connect(_ouvrir_arene)
	var centre_combat := CenterContainer.new()
	centre_combat.add_child(bouton_combat)
	colonne.add_child(centre_combat)

	bouton_coop = _bouton("Jouer à deux")
	bouton_coop.pressed.connect(_ouvrir_coop)
	var centre_coop := CenterContainer.new()
	centre_coop.add_child(bouton_coop)
	colonne.add_child(centre_coop)

	bouton_vitrine = _bouton("Voir les héros")
	bouton_vitrine.custom_minimum_size = Vector2(500, 80)
	bouton_vitrine.add_theme_font_size_override("font_size", 32)
	bouton_vitrine.pressed.connect(_ouvrir_vitrine)
	var centre := CenterContainer.new()
	centre.add_child(bouton_vitrine)
	colonne.add_child(centre)

	var version := Label.new()
	version.text = "version %s" % ProjectSettings.get_setting("application/config/version", "?")
	version.add_theme_font_size_override("font_size", 22)
	version.add_theme_color_override("font_color", Color(COULEUR_OS, 0.6))
	version.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	version.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	version.grow_vertical = Control.GROW_DIRECTION_BEGIN
	version.position -= Vector2(24, 16)
	add_child(version)
	_mode_test()


## Mode test (prévu dans la conception) : essayer un point précis en 30 secondes.
func _mode_test() -> void:
	bouton_test = _bouton("Mode test")
	bouton_test.custom_minimum_size = Vector2(220, 64)
	bouton_test.add_theme_font_size_override("font_size", 24)
	bouton_test.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bouton_test.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bouton_test.position += Vector2(24, -16)
	bouton_test.pressed.connect(func(): panneau_test.visible = not panneau_test.visible)
	add_child(bouton_test)
	panneau_test = VBoxContainer.new()
	panneau_test.add_theme_constant_override("separation", 12)
	panneau_test.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	panneau_test.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panneau_test.position += Vector2(24, -96)
	panneau_test.visible = false
	add_child(panneau_test)
	bouton_sante = _bouton("")
	bouton_depart = _bouton("")
	for b in [bouton_sante, bouton_depart]:
		b.custom_minimum_size = Vector2(440, 64)
		b.add_theme_font_size_override("font_size", 24)
		panneau_test.add_child(b)
	bouton_sante.pressed.connect(func():
		Partie.debug_sante_infinie = not Partie.debug_sante_infinie
		_textes_test())
	bouton_depart.pressed.connect(func():
		Partie.debug_depart = DEPARTS[(DEPARTS.find(Partie.debug_depart) + 1) % DEPARTS.size()]
		_textes_test())
	label_test = Label.new()
	label_test.add_theme_font_size_override("font_size", 24)
	label_test.add_theme_color_override("font_color", Color(1.0, 0.75, 0.3))
	label_test.set_anchors_preset(Control.PRESET_TOP_LEFT)
	label_test.position = Vector2(24, 16)
	add_child(label_test)
	_textes_test()


func _textes_test() -> void:
	bouton_sante.text = "Santé infinie : %s" % ("oui" if Partie.debug_sante_infinie else "non")
	bouton_depart.text = "Expédition : départ %s" % NOMS_DEPARTS.get(Partie.debug_depart, "?")
	var actif := Partie.debug_sante_infinie or Partie.debug_depart != &""
	label_test.text = "MODE TEST actif" if actif else ""


func _bouton(texte: String) -> Button:
	var b := Button.new()
	b.text = texte
	b.custom_minimum_size = Vector2(500, 96)
	b.add_theme_font_size_override("font_size", 38)
	b.add_theme_color_override("font_color", COULEUR_OS)
	for etat in ["normal", "hover", "pressed", "focus"]:
		var s := StyleBoxFlat.new()
		s.bg_color = {"normal": Color("3a2a20"), "hover": Color("4a3628"), "pressed": Color("24190f"), "focus": Color("3a2a20")}[etat]
		s.border_color = COULEUR_OR
		s.set_border_width_all(4)
		s.set_corner_radius_all(14)
		b.add_theme_stylebox_override(etat, s)
	return b


func _ouvrir_expedition() -> void:
	Reseau.quitter()
	Partie.revenir_en_solo()
	Partie.destination = &"expedition"
	get_tree().change_scene_to_file(SCENE_CHOIX)


func _ouvrir_arene() -> void:
	Reseau.quitter()
	Partie.revenir_en_solo()
	Partie.destination = &"arene"
	get_tree().change_scene_to_file(SCENE_CHOIX)


func _ouvrir_coop() -> void:
	Partie.mode = Partie.Mode.SOLO
	get_tree().change_scene_to_file(SCENE_COOP)


func _ouvrir_vitrine() -> void:
	get_tree().change_scene_to_file(SCENE_VITRINE)
