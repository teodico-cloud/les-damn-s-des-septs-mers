class_name Carnet
extends Control
## Carnet de bord du repaire (jalon 6, annexe retenue par Téo) : le bouton Menu l'ouvre au lieu de quitter tout de
## suite. Un cuir cousu au milieu de l'écran : « Reprendre », « Réglages », « Écran titre ». Toucher à côté du
## carnet le referme (comme « Reprendre »). Il s'ouvre comme un lieu (HudRepaire.ouvrir_panneau) : le joystick
## ne bouge rien tant qu'il est ouvert, et le retour d'Android le referme.

signal ferme
signal reglages_demandes
signal ecran_titre_demande

var cuir: PanelContainer
var bouton_reprendre: Button
var bouton_reglages: Button
var bouton_titre: Button
var _choisi := false   ## un seul choix (un double appui sur « Écran titre » ne quitte pas deux fois)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	cuir = PanelContainer.new()
	cuir.theme_type_variation = &"PanelCuir"
	cuir.set_anchors_preset(Control.PRESET_CENTER)
	cuir.grow_horizontal = Control.GROW_DIRECTION_BOTH
	cuir.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(cuir)
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 14)
	cuir.add_child(colonne)
	var titre := Label.new()
	titre.text = "Carnet de bord"
	titre.theme_type_variation = &"LabelTitre"
	titre.add_theme_font_size_override("font_size", 42)
	titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	colonne.add_child(titre)
	var corde := TextureRect.new()   # (un bout de cordage sous le titre)
	corde.texture = load("res://assets/ui/matieres/cordage.png")
	corde.custom_minimum_size = Vector2(0, 14)
	corde.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	corde.stretch_mode = TextureRect.STRETCH_TILE
	corde.mouse_filter = Control.MOUSE_FILTER_IGNORE
	colonne.add_child(corde)
	bouton_reprendre = _bouton("Reprendre", &"BoutonPrincipal", Vector2(420, 90), func(): ferme.emit())
	colonne.add_child(bouton_reprendre)
	bouton_reglages = _bouton("Réglages", &"", Vector2(420, 78), func(): reglages_demandes.emit())
	colonne.add_child(bouton_reglages)
	bouton_titre = _bouton("Écran titre", &"BoutonPetit", Vector2(420, 66), func(): ecran_titre_demande.emit())
	colonne.add_child(bouton_titre)
	EffetsUI.apparition(cuir, 0.0, 0.2)   # (centré : sa place n'est connue qu'une fois rangé)


func _bouton(texte: String, variation: StringName, taille: Vector2, action: Callable) -> Button:
	var b := Button.new()
	b.text = texte
	b.theme_type_variation = variation
	b.custom_minimum_size = taille
	b.pressed.connect(func():
		if _choisi:
			return
		_choisi = true
		action.call())
	EffetsUI.animer_bouton(b)
	return b


## Toucher à côté du carnet : on reprend.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and not _choisi \
			and not cuir.get_global_rect().has_point(event.global_position):
		_choisi = true
		ferme.emit()
