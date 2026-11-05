class_name PanneauCartes
extends PanneauRepaire
## Salle des cartes (jalon 5) : la destination (le Récif des Pendus, seule région du MVP), le héros, la
## malédiction de départ, et « Lever l'ancre ! ». Seul ; à deux, l'hôte lance depuis « Jouer à deux ».

signal partir(archetype: StringName)
signal heros_change(archetype: StringName)

const NOMS_HEROS := {&"bretteur": "Le Bretteur", &"occultiste": "L'Occultiste"}

var boutons_heros := {}
var choix_malediction: ChoixMalediction
var bouton_partir: Button


func _init() -> void:
	titre = "Salle des cartes"


func _remplir() -> void:
	var carte := StyleRepaire.cadre()
	var dans_carte := VBoxContainer.new()
	dans_carte.add_theme_constant_override("separation", 0)
	carte.add_child(dans_carte)
	dans_carte.add_child(StyleRepaire.texte("Destination", 20, Color(StyleRepaire.COULEUR_OS, 0.7)))
	dans_carte.add_child(StyleRepaire.titre("Le Récif des Pendus", 38, StyleRepaire.ROUGE))
	dans_carte.add_child(StyleRepaire.texte("Quatre salles, l'antre du Bosco Maudit, puis la chaloupe sous les vagues.", 23))
	contenu.add_child(carte)

	var rangee := HBoxContainer.new()
	rangee.add_theme_constant_override("separation", 16)
	contenu.add_child(rangee)
	var l_heros := StyleRepaire.titre("Héros", 30)
	l_heros.custom_minimum_size = Vector2(110, 0)
	l_heros.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rangee.add_child(l_heros)
	for h in NOMS_HEROS:
		var b := StyleRepaire.bouton(NOMS_HEROS[h], Vector2(280, 68), 28)
		b.toggle_mode = true
		b.pressed.connect(choisir_heros.bind(h))
		rangee.add_child(b)
		boutons_heros[h] = b
	_marquer_heros()

	choix_malediction = ChoixMalediction.new()
	choix_malediction.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	contenu.add_child(choix_malediction)

	bouton_partir = StyleRepaire.bouton("Lever l'ancre !", Vector2(440, 96), 38)
	bouton_partir.theme_type_variation = &"BoutonPrincipal"
	bouton_partir.size_flags_horizontal = Control.SIZE_SHRINK_END   # (à droite, sous la main)
	bouton_partir.pressed.connect(func(): partir.emit(Partie.heros_local))
	contenu.add_child(bouton_partir)


func choisir_heros(archetype: StringName) -> void:
	Partie.heros_local = archetype
	_marquer_heros()
	heros_change.emit(archetype)


func _marquer_heros() -> void:
	for h in boutons_heros:
		var b: Button = boutons_heros[h]
		b.button_pressed = h == Partie.heros_local
		# le héros choisi : une planche ; l'autre : une lanière de cuir
		b.theme_type_variation = &"BoutonOngletActif" if h == Partie.heros_local else &"BoutonOnglet"
