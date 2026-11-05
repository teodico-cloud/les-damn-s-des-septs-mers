extends SceneTree
## Fabrique le thème commun de l'interface (refonte, direction validée par Téo le 05/11 : « gravure marine »).
## Usage (après `godot --headless --path . --import`) :
##   godot --headless --path . -s "$PWD/tools/ui/fabriquer_theme.gd"
## Écrit res://assets/ui/theme_damnes.tres (thème du projet : gui/theme/custom). Les textures viennent de
## tools/ui/matieres.py (mêmes marges que MARGES là-bas). Ne pas typer avec les classes du jeu (pièges).

const DOSSIER := "res://assets/ui/"
const SORTIE := "res://assets/ui/theme_damnes.tres"

# palette (la même que tools/ui/matieres.py)
const CHARBON := Color("15120f")
const PARCHEMIN := Color("d9c79f")
const ENCRE := Color("2b1d13")
const OR := Color("b08a42")
const OR_CLAIR := Color("deba70")
const OR_SOMBRE := Color("6e5326")
const ROUGE := Color("8b1e1a")
const VERT_DE_GRIS := Color("5f8f86")
const GRIS := Color("8a8074")


func _initialize() -> void:
	var t := Theme.new()
	var texte: Font = load(DOSSIER + "polices/AlegreyaSans-Regular.ttf")
	var gras: Font = load(DOSSIER + "polices/AlegreyaSans-Bold.ttf")
	var titre: Font = load(DOSSIER + "polices/IMFellEnglishSC-Regular.ttf")
	t.default_font = texte
	t.default_font_size = 26

	# ---------------------------------------------------------------- boutons : planche cerclée de fer
	for etat in ["normal", "hover", "focus"]:
		t.set_stylebox(etat, "Button", _boite("bouton", 34, 12, 40, 8))
	t.set_stylebox("pressed", "Button", _boite("bouton_appuye", 34, 12, 40, 8, 3))
	t.set_stylebox("hover_pressed", "Button", _boite("bouton_appuye", 34, 12, 40, 8, 3))
	t.set_stylebox("disabled", "Button", _boite("bouton_desactive", 34, 12, 40, 8))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())   # (au doigt : pas de cadre de focus)
	t.set_font("font", "Button", titre)
	t.set_font_size("font_size", "Button", 30)
	t.set_color("font_color", "Button", OR_CLAIR)
	t.set_color("font_hover_color", "Button", OR_CLAIR)
	t.set_color("font_focus_color", "Button", OR_CLAIR)
	t.set_color("font_pressed_color", "Button", OR)
	t.set_color("font_hover_pressed_color", "Button", OR)
	t.set_color("font_disabled_color", "Button", GRIS)
	t.set_color("font_outline_color", "Button", Color(0.05, 0.03, 0.02))
	t.set_constant("outline_size", "Button", 4)

	_variation(t, "BoutonPrincipal", "Button")
	t.set_font_size("font_size", "BoutonPrincipal", 38)
	_variation(t, "BoutonPetit", "Button")
	t.set_font_size("font_size", "BoutonPetit", 24)
	for etat in ["normal", "hover", "focus"]:
		t.set_stylebox(etat, "BoutonPetit", _boite("bouton", 34, 12, 30, 4))
	t.set_stylebox("pressed", "BoutonPetit", _boite("bouton_appuye", 34, 12, 30, 4, 2))
	t.set_stylebox("disabled", "BoutonPetit", _boite("bouton_desactive", 34, 12, 30, 4))
	# onglets : cuir cousu ; l'onglet choisi est une planche
	_variation(t, "BoutonOnglet", "Button")
	for etat in ["normal", "hover", "focus"]:
		t.set_stylebox(etat, "BoutonOnglet", _boite("onglet", 20, 16, 24, 6))
	t.set_stylebox("pressed", "BoutonOnglet", _boite("bouton_appuye", 34, 12, 30, 6, 2))
	t.set_color("font_color", "BoutonOnglet", PARCHEMIN)
	t.set_font_size("font_size", "BoutonOnglet", 26)
	_variation(t, "BoutonOngletActif", "Button")
	for etat in ["normal", "hover", "focus", "pressed"]:
		t.set_stylebox(etat, "BoutonOngletActif", _boite("bouton", 34, 12, 30, 6))
	t.set_font_size("font_size", "BoutonOngletActif", 26)

	# ---------------------------------------------------------------- textes
	t.set_color("font_color", "Label", PARCHEMIN)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.75))
	t.set_constant("shadow_offset_x", "Label", 0)
	t.set_constant("shadow_offset_y", "Label", 2)
	t.set_color("font_outline_color", "Label", Color(0.04, 0.03, 0.02))
	_variation(t, "LabelTitre", "Label")
	t.set_font("font", "LabelTitre", titre)
	t.set_font_size("font_size", "LabelTitre", 44)
	t.set_color("font_color", "LabelTitre", OR_CLAIR)
	_variation(t, "LabelSousTitre", "Label")
	t.set_font("font", "LabelSousTitre", titre)
	t.set_font_size("font_size", "LabelSousTitre", 30)
	t.set_color("font_color", "LabelSousTitre", OR)
	_variation(t, "LabelGras", "Label")
	t.set_font("font", "LabelGras", gras)
	# à l'encre, sur le parchemin : pas d'ombre noire, un très léger relief clair dessous
	for v in ["LabelEncre", "LabelEncreGras", "LabelEncreTitre", "LabelEncreDiscret"]:
		_variation(t, v, "Label")
		t.set_color("font_color", v, ENCRE)
		t.set_color("font_shadow_color", v, Color(1.0, 0.96, 0.85, 0.35))
		t.set_constant("shadow_offset_y", v, 1)
	t.set_font("font", "LabelEncreGras", gras)
	t.set_font("font", "LabelEncreTitre", titre)
	t.set_font_size("font_size", "LabelEncreTitre", 36)
	t.set_color("font_color", "LabelEncreDiscret", Color(ENCRE, 0.72))
	t.set_font_size("font_size", "LabelEncreDiscret", 22)

	# ---------------------------------------------------------------- panneaux
	_variation(t, "PanelParchemin", "PanelContainer")
	t.set_stylebox("panel", "PanelParchemin", _boite("panneau", 72, 72, 58, 52))
	_variation(t, "PanelCuir", "PanelContainer")
	t.set_stylebox("panel", "PanelCuir", _boite("cuir", 24, 24, 26, 20))
	_variation(t, "PanelPlaque", "PanelContainer")
	t.set_stylebox("panel", "PanelPlaque", _boite("plaque", 28, 22, 40, 8))

	# affiches (avis de recrutement : le choix du héros), boutons de parchemin écrits à l'encre
	_variation(t, "BoutonAffiche", "Button")
	for etat in ["normal", "hover", "focus"]:
		t.set_stylebox(etat, "BoutonAffiche", _boite("affiche", 48, 48, 40, 34))
	t.set_stylebox("pressed", "BoutonAffiche", _boite("affiche_appuye", 48, 48, 40, 34, 3))
	t.set_stylebox("focus", "BoutonAffiche", StyleBoxEmpty.new())
	t.set_color("font_color", "BoutonAffiche", ENCRE)

	# ---------------------------------------------------------------- barres de défilement : une lanière de cuir
	var poignee := StyleBoxFlat.new()
	poignee.bg_color = OR_SOMBRE
	poignee.border_color = Color(0.08, 0.05, 0.03)
	poignee.set_border_width_all(2)
	poignee.content_margin_left = 6
	poignee.content_margin_right = 6
	var rail := StyleBoxFlat.new()
	rail.bg_color = Color(0.1, 0.07, 0.05, 0.55)
	rail.content_margin_left = 6
	rail.content_margin_right = 6
	for etat in ["grabber", "grabber_highlight", "grabber_pressed"]:
		t.set_stylebox(etat, "VScrollBar", poignee)
	t.set_stylebox("scroll", "VScrollBar", rail)

	# ---------------------------------------------------------------- champs de saisie (code de secours)
	var champ := _boite("cuir", 24, 24, 20, 8)
	t.set_stylebox("normal", "LineEdit", champ)
	t.set_stylebox("focus", "LineEdit", champ)
	t.set_color("font_color", "LineEdit", PARCHEMIN)
	t.set_font_size("font_size", "LineEdit", 30)

	var err := ResourceSaver.save(t, SORTIE)
	if err != OK:
		push_error("thème : impossible d'écrire " + SORTIE)
		quit(1)
		return
	print("Thème : ", SORTIE)
	quit()


func _variation(t: Theme, nom: String, base: String) -> void:
	t.set_type_variation(nom, base)


## Texture « 9 cases » : `mx`, `my` = marges (coins et bords fixes) ; `cx`, `cy` = marges du contenu.
func _boite(nom: String, mx: int, my: int, cx: int, cy: int, decale := 0) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = load(DOSSIER + "matieres/" + nom + ".png")
	s.texture_margin_left = mx
	s.texture_margin_right = mx
	s.texture_margin_top = my
	s.texture_margin_bottom = my
	s.content_margin_left = cx
	s.content_margin_right = cx
	s.content_margin_top = cy + decale       # (appuyé : le texte descend un peu, comme enfoncé)
	s.content_margin_bottom = cy - decale
	return s
