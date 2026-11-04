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
	var carte := PanelContainer.new()
	carte.add_theme_stylebox_override("panel", StyleRepaire.style(false, Color(0.2, 0.15, 0.09, 0.95), StyleRepaire.OR_VIF))
	var dans_carte := VBoxContainer.new()
	carte.add_child(dans_carte)
	dans_carte.add_child(StyleRepaire.texte("Destination : le Récif des Pendus", 32, StyleRepaire.OR_VIF))
	dans_carte.add_child(StyleRepaire.texte("Quatre salles, l'antre du Bosco Maudit, puis la chaloupe sous les vagues.", 22))
	contenu.add_child(carte)

	var rangee := HBoxContainer.new()
	rangee.add_theme_constant_override("separation", 16)
	contenu.add_child(rangee)
	var l_heros := StyleRepaire.texte("Héros :", 26, Color(StyleRepaire.COULEUR_OS, 0.8))
	l_heros.custom_minimum_size = Vector2(110, 0)
	rangee.add_child(l_heros)
	for h in NOMS_HEROS:
		var b := StyleRepaire.bouton(NOMS_HEROS[h], Vector2(300, 70), 28)
		b.toggle_mode = true
		b.pressed.connect(choisir_heros.bind(h))
		rangee.add_child(b)
		boutons_heros[h] = b
	_marquer_heros()

	choix_malediction = ChoixMalediction.new()
	choix_malediction.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	contenu.add_child(choix_malediction)

	bouton_partir = StyleRepaire.bouton("Lever l'ancre !", Vector2(420, 90), 36, StyleRepaire.OR_VIF)
	bouton_partir.pressed.connect(func(): partir.emit(Partie.heros_local))
	var centre := CenterContainer.new()
	centre.add_child(bouton_partir)
	contenu.add_child(centre)


func choisir_heros(archetype: StringName) -> void:
	Partie.heros_local = archetype
	_marquer_heros()
	heros_change.emit(archetype)


func _marquer_heros() -> void:
	for h in boutons_heros:
		var b: Button = boutons_heros[h]
		b.button_pressed = h == Partie.heros_local
		var c := StyleRepaire.OR_VIF if h == Partie.heros_local else StyleRepaire.COULEUR_OS
		for etat in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(etat, c)
		b.add_theme_stylebox_override("normal", StyleRepaire.style(false, Color(0.16, 0.11, 0.08, 0.92),
				StyleRepaire.OR_VIF if h == Partie.heros_local else Color(StyleRepaire.COULEUR_OR, 0.5)))
