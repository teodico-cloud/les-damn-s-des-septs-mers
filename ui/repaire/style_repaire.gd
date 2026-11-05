class_name StyleRepaire
extends RefCounted
## Les lieux du repaire (refonte de l'interface, 05/11, direction « gravure marine » validée par Téo) sont des
## parchemins cloués sur du bois : on y écrit **à l'encre**. Ces couleurs sont celles de l'encre (elles gardent
## leurs anciens noms, employés par tous les lieux) ; les boutons, les cadres et les polices viennent du thème
## commun (assets/ui/theme_damnes.tres).

const COULEUR_OS := Color("2b1d13")     ## encre : le texte courant
const COULEUR_OR := Color("6e5326")     ## or sombre : filets, détails
const OR_VIF := Color("7a4f12")         ## encre brun-or : titres de ligne, ce qu'on peut faire
const VERT := Color("2f6b3a")           ## encre verte : réussi, au plus haut
const ROUGE := Color("8b1e1a")          ## encre rouge : ce qui manque, attention
const ROUGE_BOUTON := Color("ff8f74")   ## texte d'un bouton « attention » (sur le bois)


## Une couleur pensée pour un fond sombre (rareté, matériau), rendue lisible sur le parchemin.
static func encre(c: Color) -> Color:
	if c.get_luminance() < 0.4:
		return c
	return Color(c.darkened(0.55), c.a)


## Un bouton du thème (planche cerclée de fer). `couleur` ROUGE : un bouton « attention ».
static func bouton(texte: String, taille := Vector2(260, 72), police := 28, couleur := COULEUR_OS) -> Button:
	var b := Button.new()
	b.text = texte
	b.custom_minimum_size = taille
	b.theme_type_variation = &"BoutonPetit" if taille.y < 70 else &""
	b.add_theme_font_size_override("font_size", police)
	if couleur == ROUGE:
		for etat in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(etat, ROUGE_BOUTON)
	EffetsUI.animer_bouton(b)
	return b


## Un texte à l'encre sur le parchemin.
static func texte(t: String, taille := 24, couleur := COULEUR_OS) -> Label:
	var l := Label.new()
	l.text = t
	l.theme_type_variation = &"LabelEncre"
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", encre(couleur))
	return l


## Un titre gravé (police des titres), à l'encre.
static func titre(t: String, taille := 32, couleur := COULEUR_OS) -> Label:
	var l := texte(t, taille, couleur)
	l.theme_type_variation = &"LabelEncreTitre"
	return l


## Séparateur dessiné à l'encre (un trait qui s'amincit, un losange rouge au milieu).
static func separateur(largeur := 0.0) -> TextureRect:
	var r := TextureRect.new()
	r.texture = load("res://assets/ui/matieres/trait_encre.png")
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.custom_minimum_size = Vector2(largeur, 14)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL if largeur <= 0.0 else Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Une zone à part sur le parchemin (une ligne de la forge, un encart) : un léger lavis plus sombre, des filets.
static func cadre() -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.35, 0.22, 0.1, 0.09)
	s.border_color = Color(COULEUR_OR, 0.55)
	s.border_width_top = 1
	s.border_width_bottom = 2
	s.content_margin_left = 14
	s.content_margin_right = 10
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", s)
	return p


## (Ancien style des cadres : désormais un lavis sur le parchemin, voir `cadre`.)
static func style(_enfonce := false, _fond := Color(), _bord := Color()) -> StyleBox:
	return cadre().get_theme_stylebox("panel")
