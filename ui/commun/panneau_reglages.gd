class_name PanneauReglages
extends PanneauRepaire
## Écran Réglages (jalon 6, refonte de l'interface ; choix de Téo : la qualité graphique, puis les volumes avec les
## sons). Le même parchemin cloué que les lieux du repaire ; on l'ouvre depuis l'écran titre et depuis le carnet du
## repaire. Le choix s'applique tout de suite et reste d'une partie à l'autre (service Reglages, fichier à part de
## la sauvegarde).

## (dans l'ordre de Reglages.Qualite : économie, normale, belle)
const NOMS := ["Économie", "Normale", "Belle"]
const DESCRIPTIONS := [
	"Pour jouer longtemps : le téléphone chauffe moins et la batterie dure plus.",
	"Le jeu tel qu'il a été réglé.",
	"Pour les téléphones puissants : peut coûter quelques images par seconde.",
]
## Ce que change chaque niveau : [nom, économie, normale, belle]
const DETAILS := [
	["Ombres", "non", "oui", "oui, plus douces"],
	["Halo des lumières", "non", "oui", "oui"],
	["Brume et poussière", "sans brume, peu de poussière", "oui", "oui"],
	["Bords lissés", "non", "non", "oui"],
	["Finesse de l'image", "75 %", "100 %", "100 %"],
]

## Volumes : [canal de Reglages, nom, ce qu'il règle]
const VOLUMES := [
	["general", "Général", "tout le jeu"],
	["effets", "Effets", "combat, butin, boutons"],
	["ambiances", "Ambiances", "mer, vent, torches, musiques de fin"],
]

var boutons_qualite := {}       ## qualité (0 économie, 1 normale, 2 belle) -> Button
var label_description: Label
var curseurs := {}              ## canal -> HSlider
var _dernier_essai := 0         ## (ms) dernier son d'essai joué en réglant les effets


func _init() -> void:
	titre = "Réglages"
	marge_x = 190.0   # (un parchemin plus petit que les lieux : il y a moins à y écrire)
	marge_haut = 86.0
	marge_bas = 80.0


func _remplir() -> void:
	# (les sons d'abord : c'est ce qu'on vient régler le plus souvent ; les boutons de qualité restent visibles
	#  dessous sans faire défiler, leurs détails en faisant défiler)
	_remplir_volumes()
	boutons_qualite.clear()
	contenu.add_child(StyleRepaire.titre("Qualité graphique", 34))
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override("separation", 14)
	contenu.add_child(ligne)
	for q in NOMS.size():
		var b := Button.new()
		b.text = NOMS[q]
		b.custom_minimum_size = Vector2(230, 64)
		b.theme_type_variation = &"BoutonOngletActif" if q == Reglages.qualite else &"BoutonOnglet"
		b.pressed.connect(_choisir.bind(q))
		EffetsUI.animer_bouton(b)
		ligne.add_child(b)
		boutons_qualite[q] = b

	var cadre_choix := StyleRepaire.cadre()
	contenu.add_child(cadre_choix)
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 4)
	cadre_choix.add_child(colonne)
	label_description = StyleRepaire.texte(DESCRIPTIONS[Reglages.qualite], 26)
	label_description.theme_type_variation = &"LabelEncreGras"
	label_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	colonne.add_child(label_description)
	for d in DETAILS:
		var valeur: String = d[1 + int(Reglages.qualite)]
		var couleur := StyleRepaire.ROUGE if valeur == "non" else StyleRepaire.COULEUR_OS
		var l := StyleRepaire.texte("◆  %s : %s" % [d[0], valeur], 24, couleur)
		colonne.add_child(l)

	var note := StyleRepaire.texte("Le changement se voit tout de suite. En combat, le compteur « i/s » sous le bouton "
			+ "Menu dit si le jeu reste fluide.", 22)
	note.theme_type_variation = &"LabelEncreDiscret"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	contenu.add_child(note)
	contenu.add_child(StyleRepaire.separateur(420))
	var version := StyleRepaire.texte("Les Damnés des Sept Mers · version %s"
			% ProjectSettings.get_setting("application/config/version", "?"), 20)
	version.theme_type_variation = &"LabelEncreDiscret"
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	contenu.add_child(version)


## Trois curseurs (Général, Effets, Ambiances), de 0 à 100 %.
func _remplir_volumes() -> void:
	curseurs.clear()
	contenu.add_child(StyleRepaire.titre("Sons", 34))
	var cadre_sons := StyleRepaire.cadre()
	contenu.add_child(cadre_sons)
	var grille := GridContainer.new()
	grille.columns = 3
	grille.add_theme_constant_override("h_separation", 22)
	grille.add_theme_constant_override("v_separation", 8)
	cadre_sons.add_child(grille)
	for v in VOLUMES:
		var noms := VBoxContainer.new()
		noms.add_theme_constant_override("separation", -4)
		noms.custom_minimum_size.x = 250
		var nom := StyleRepaire.texte(v[1], 26)
		nom.theme_type_variation = &"LabelEncreGras"
		noms.add_child(nom)
		var detail := StyleRepaire.texte(v[2], 19)
		detail.theme_type_variation = &"LabelEncreDiscret"
		noms.add_child(detail)
		grille.add_child(noms)
		var c := HSlider.new()
		c.min_value = 0
		c.max_value = 100
		c.step = 5
		c.value = roundf(Reglages.volume(v[0]) * 100.0)
		c.custom_minimum_size = Vector2(380, 52)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_habiller_curseur(c)
		grille.add_child(c)
		var pct := StyleRepaire.texte("%d %%" % c.value, 24)
		pct.custom_minimum_size.x = 80
		pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grille.add_child(pct)
		c.value_changed.connect(_volume.bind(v[0], pct))
		curseurs[v[0]] = c


func _volume(valeur: float, canal: String, pct: Label) -> void:
	Reglages.choisir_volume(canal, valeur / 100.0)
	pct.text = "%d %%" % valeur
	# on entend le niveau choisi : les ambiances jouent déjà ; pour les effets, un coup d'essai (pas à chaque cran)
	if canal == "effets" and Time.get_ticks_msec() - _dernier_essai > 250:
		_dernier_essai = Time.get_ticks_msec()
		Sons.jouer(&"coup")


## Le curseur aux couleurs du parchemin : une rainure d'encre, la part réglée en or sombre, un doublon à saisir.
static func _habiller_curseur(c: HSlider) -> void:
	var rainure := StyleBoxFlat.new()
	rainure.bg_color = Color(StyleRepaire.COULEUR_OS, 0.28)
	rainure.set_corner_radius_all(5)
	rainure.content_margin_top = 5
	rainure.content_margin_bottom = 5
	var rempli := rainure.duplicate() as StyleBoxFlat
	rempli.bg_color = Color(StyleRepaire.COULEUR_OR, 0.95)
	c.add_theme_stylebox_override("slider", rainure)
	c.add_theme_stylebox_override("grabber_area", rempli)
	c.add_theme_stylebox_override("grabber_area_highlight", rempli)
	c.add_theme_icon_override("grabber", _poignee(false))
	c.add_theme_icon_override("grabber_highlight", _poignee(true))


static var _poignees := {}


static func _poignee(claire: bool) -> Texture2D:
	if not _poignees.has(claire):
		var g := Gradient.new()
		var or_ := Color("e0b04a") if claire else Color("c99a3c")
		g.offsets = PackedFloat32Array([0.0, 0.55, 0.78, 0.86, 1.0])
		g.colors = PackedColorArray([or_.lightened(0.25), or_, or_.darkened(0.45), Color(StyleRepaire.COULEUR_OS, 0.9),
				Color(StyleRepaire.COULEUR_OS, 0.0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(0.5, 0.0)
		t.width = 44
		t.height = 44
		_poignees[claire] = t
	return _poignees[claire]


func _choisir(q: int) -> void:
	Reglages.choisir_qualite(q)
	rafraichir()
