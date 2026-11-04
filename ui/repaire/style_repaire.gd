class_name StyleRepaire
extends RefCounted
## Couleurs et boutons du repaire et de ses lieux (mêmes teintes que l'écran titre et l'Équipement :
## bois sombre, liseré d'or, lettres couleur d'os).

const COULEUR_OS := Color("e2d6ba")
const COULEUR_OR := Color("ac8036")
const OR_VIF := Color("e0b04a")
const VERT := Color("6cffa0")
const ROUGE := Color("ff7a6a")


static func style(enfonce := false, fond := Color(0.16, 0.11, 0.08, 0.92), bord := COULEUR_OR) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fond.darkened(0.35) if enfonce else fond
	s.border_color = bord
	s.set_border_width_all(3)
	s.set_corner_radius_all(12)
	s.set_content_margin_all(12)
	return s


static func bouton(texte: String, taille := Vector2(260, 72), police := 28, couleur := COULEUR_OS) -> Button:
	var b := Button.new()
	b.text = texte
	b.custom_minimum_size = taille
	b.add_theme_font_size_override("font_size", police)
	for etat in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(etat, couleur)
	b.add_theme_color_override("font_disabled_color", Color(couleur, 0.4))
	for etat in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(etat, style(etat == "pressed", Color(0.16, 0.11, 0.08, 0.92) if etat != "disabled" else Color(0.1, 0.08, 0.07, 0.7)))
	return b


static func texte(t: String, taille := 24, couleur := COULEUR_OS) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", couleur)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	return l
