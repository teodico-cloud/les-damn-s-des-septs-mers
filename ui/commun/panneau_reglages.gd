class_name PanneauReglages
extends PanneauRepaire
## Écran Réglages (jalon 6, refonte de l'interface ; choix de Téo : la qualité graphique seulement, ce qui marche
## déjà — les volumes viendront avec les sons). Le même parchemin cloué que les lieux du repaire ; on l'ouvre depuis
## l'écran titre et depuis le carnet du repaire. Le choix s'applique tout de suite et reste d'une partie à l'autre
## (service Reglages, fichier à part de la sauvegarde).

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
	["Bords lissés", "non", "non", "oui"],
	["Finesse de l'image", "75 %", "100 %", "100 %"],
]

var boutons_qualite := {}       ## qualité (0 économie, 1 normale, 2 belle) -> Button
var label_description: Label


func _init() -> void:
	titre = "Réglages"
	marge_x = 190.0   # (un parchemin plus petit que les lieux : il y a moins à y écrire)
	marge_haut = 86.0
	marge_bas = 80.0


func _remplir() -> void:
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


func _choisir(q: int) -> void:
	Reglages.choisir_qualite(q)
	rafraichir()
