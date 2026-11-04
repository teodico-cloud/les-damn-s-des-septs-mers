class_name PanneauRepaire
extends Control
## Un lieu du repaire ouvert par-dessus la grotte : un grand cadre avec son titre et « Fermer ». Chaque
## lieu remplit `contenu` dans `_remplir()` (et le refait dans `rafraichir()`).

signal ferme

var titre := "Lieu"
var cadre: PanelContainer
var contenu: VBoxContainer
var bouton_fermer: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)   # (déjà dans l'arbre : sinon il garde sa taille nulle)
	mouse_filter = Control.MOUSE_FILTER_STOP   # (rien ne passe au repaire derrière)
	cadre = PanelContainer.new()
	cadre.add_theme_stylebox_override("panel", StyleRepaire.style(false, Color(0.1, 0.07, 0.05, 0.96)))
	cadre.set_anchors_preset(Control.PRESET_FULL_RECT)
	cadre.offset_left = 120
	cadre.offset_right = -120
	cadre.offset_top = 28
	cadre.offset_bottom = -28
	add_child(cadre)
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 12)
	cadre.add_child(colonne)
	var entete := HBoxContainer.new()
	colonne.add_child(entete)
	var l := StyleRepaire.texte(titre, 44, StyleRepaire.COULEUR_OS)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entete.add_child(l)
	bouton_fermer = StyleRepaire.bouton("Fermer", Vector2(170, 64), 26)
	bouton_fermer.pressed.connect(fermer)
	entete.add_child(bouton_fermer)
	var defile := ScrollContainer.new()
	defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	defile.size_flags_vertical = Control.SIZE_EXPAND_FILL
	colonne.add_child(defile)
	contenu = VBoxContainer.new()
	contenu.add_theme_constant_override("separation", 12)
	contenu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	defile.add_child(contenu)
	_remplir()


func fermer() -> void:
	ferme.emit()


## Refait le contenu (après un achat, un changement…).
func rafraichir() -> void:
	for c in contenu.get_children():
		contenu.remove_child(c)
		c.queue_free()
	_remplir()


func _remplir() -> void:
	pass
