class_name PanneauCredits
extends PanneauRepaire
## « Crédits » (jalon 6, écrans restants ; choix de Téo du 08/11 : ouvert depuis l'écran titre seulement). Qui a fait
## quoi (voir aussi assets/CREDITS.md), puis ce que les licences demandent d'afficher : la licence MIT de Godot
## (obligatoire dans le jeu), les composants du moteur et leurs licences (affichés sur demande : environ 80 000
## caractères de textes de licences, trop pour les mettre en page à chaque ouverture).

## [ce que c'est, de qui, licence]
const SOURCES := [
	["Personnages, ennemis, décors et armes", "KayKit, de Kay Lousberg (kaylousberg.com)", "CC0"],
	["Héros Meshy (à l'essai), sabre, bâton et lanterne", "Faits par Téo sur Meshy (meshy.ai)", ""],
	["Textures des décors", "Poly Haven (polyhaven.com)", "CC0"],
	["Sons", "Kenney (kenney.nl) ; les autres sons ont été fabriqués pour le jeu", "CC0"],
	["Polices", "Alegreya Sans (The Alegreya Sans Project Authors, 2013) et IM Fell English (Igino Marini, 2010)",
		"SIL Open Font License 1.1"],
]

var bouton_licences: Button
var licences_visibles := false
var _colonne_licences: VBoxContainer


func _init() -> void:
	titre = "Crédits"
	marge_x = 150.0
	marge_haut = 86.0
	marge_bas = 40.0


func _remplir() -> void:
	var nom := StyleRepaire.titre("Les Damnés des Sept Mers", 40)
	nom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	contenu.add_child(nom)
	var qui := StyleRepaire.texte("Un jeu de Téo · programmé avec Claude (Anthropic)", 24, StyleRepaire.OR_VIF)
	qui.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	contenu.add_child(qui)
	var version := StyleRepaire.texte("version %s" % ProjectSettings.get_setting("application/config/version", "?"), 20)
	version.theme_type_variation = &"LabelEncreDiscret"
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	contenu.add_child(version)
	contenu.add_child(StyleRepaire.separateur(420))

	var cadre_sources := StyleRepaire.cadre()
	contenu.add_child(cadre_sources)
	var liste := VBoxContainer.new()
	liste.add_theme_constant_override("separation", 8)
	cadre_sources.add_child(liste)
	for s in SOURCES:
		var quoi := StyleRepaire.texte(s[0], 24, StyleRepaire.OR_VIF)
		quoi.theme_type_variation = &"LabelEncreGras"
		liste.add_child(quoi)
		var de := StyleRepaire.texte(s[1] + ("  ·  licence %s" % s[2] if s[2] != "" else ""), 21)
		de.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		liste.add_child(de)

	contenu.add_child(StyleRepaire.titre("Moteur : Godot Engine", 30))
	var godot := StyleRepaire.texte("Ce jeu est fait avec Godot Engine (godotengine.org), sous licence MIT :", 22)
	godot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	contenu.add_child(godot)
	var mit := StyleRepaire.texte(Engine.get_license_text(), 18)
	mit.theme_type_variation = &"LabelEncreDiscret"
	mit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	contenu.add_child(mit)

	bouton_licences = StyleRepaire.bouton("Composants et licences", Vector2(360, 60), 24)
	bouton_licences.pressed.connect(montrer_licences)
	contenu.add_child(bouton_licences)
	_colonne_licences = VBoxContainer.new()
	_colonne_licences.add_theme_constant_override("separation", 6)
	contenu.add_child(_colonne_licences)
	if licences_visibles:
		_remplir_licences()


## Les composants du moteur (nom, droits, licence), puis le texte complet de chaque licence.
func montrer_licences() -> void:
	if licences_visibles:
		return
	licences_visibles = true
	bouton_licences.visible = false
	_remplir_licences()


func _remplir_licences() -> void:
	bouton_licences.visible = false
	_colonne_licences.add_child(StyleRepaire.titre("Composants du moteur", 28))
	for comp in Engine.get_copyright_info():
		var lignes := PackedStringArray()
		for part in comp["parts"]:
			for c in part["copyright"]:
				lignes.append("© %s" % c)
			lignes.append("licence %s" % part["license"])
		var l := StyleRepaire.texte("%s — %s" % [comp["name"], " · ".join(lignes)], 17)
		l.theme_type_variation = &"LabelEncreDiscret"
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_colonne_licences.add_child(l)
	var textes := Engine.get_license_info()
	for nom in textes:
		_colonne_licences.add_child(StyleRepaire.titre("Licence %s" % nom, 24))
		var t := StyleRepaire.texte(String(textes[nom]), 16)
		t.theme_type_variation = &"LabelEncreDiscret"
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_colonne_licences.add_child(t)
