class_name PanneauRepaire
extends Control
## Un lieu du repaire ouvert par-dessus la grotte (refonte de l'interface, 05/11) : un parchemin cloué sur du bois,
## une plaque de fer oxydé qui porte son nom et déborde en haut à gauche, « Fermer » qui déborde en haut à droite,
## des volutes d'or dans les coins. Chaque lieu remplit `contenu` dans `_remplir()` (et le refait dans
## `rafraichir()`) ; on y écrit à l'encre (StyleRepaire).
## Toute action (achat, recyclage, relance…) commence par `appui_accepte()` : après une action, le panneau se
## refait et un autre bouton peut apparaître sous le doigt (le niveau suivant, « Sûr ? Recycler ») ; un double
## appui nerveux ne doit pas le toucher (relecture du jalon 5 : la cale achetée deux fois d'un double appui).

signal ferme

const DELAI_ENTRE_ACTIONS := 0.4   ## secondes pendant lesquelles un nouvel appui est ignoré après une action
const MARGE_X := 96.0
const MARGE_HAUT := 66.0
const MARGE_BAS := 18.0

var titre := "Lieu"
var marge_x := MARGE_X          ## (un panneau plus petit, comme les Réglages, change ses marges dans _init)
var marge_haut := MARGE_HAUT
var marge_bas := MARGE_BAS
var cadre: PanelContainer
var contenu: VBoxContainer
var bouton_fermer: Button
var plaque: PanelContainer
var _derniere_action := -1000000   ## en ms, temps réel (le repaire n'a ni ralenti ni arrêt sur image)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)   # (déjà dans l'arbre : sinon il garde sa taille nulle)
	mouse_filter = Control.MOUSE_FILTER_STOP   # (rien ne passe au repaire derrière)
	cadre = PanelContainer.new()
	cadre.theme_type_variation = &"PanelParchemin"
	cadre.set_anchors_preset(Control.PRESET_FULL_RECT)
	cadre.offset_left = marge_x
	cadre.offset_right = -marge_x
	cadre.offset_top = marge_haut
	cadre.offset_bottom = -marge_bas
	add_child(cadre)
	var deco := Control.new()   # (sous le texte : la rose des vents en filigrane)
	deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cadre.add_child(deco)
	var rose := TextureRect.new()
	rose.texture = load("res://assets/ui/matieres/rose_des_vents.png")
	rose.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rose.modulate = Color(0.35, 0.22, 0.1, 0.12)
	rose.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rose.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	rose.offset_left = -270
	rose.offset_top = -270
	rose.offset_right = 10
	rose.offset_bottom = 10
	deco.add_child(rose)
	var defile := ScrollContainer.new()
	defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	defile.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cadre.add_child(defile)
	contenu = VBoxContainer.new()
	contenu.add_theme_constant_override("separation", 12)
	contenu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	defile.add_child(contenu)
	_ornements()
	# la plaque du nom, qui déborde en haut à gauche ; « Fermer », en haut à droite
	plaque = PanelContainer.new()
	plaque.theme_type_variation = &"PanelPlaque"
	plaque.position = Vector2(marge_x - 26, marge_haut - 46)
	plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.text = titre
	l.theme_type_variation = &"LabelTitre"
	l.add_theme_font_size_override("font_size", 40)
	plaque.add_child(l)
	add_child(plaque)
	bouton_fermer = Button.new()
	bouton_fermer.text = "Fermer"
	bouton_fermer.theme_type_variation = &"BoutonPetit"
	bouton_fermer.custom_minimum_size = Vector2(170, 60)
	bouton_fermer.anchor_left = 1.0
	bouton_fermer.anchor_right = 1.0
	bouton_fermer.offset_left = -marge_x - 150
	bouton_fermer.offset_right = -marge_x + 20
	bouton_fermer.offset_top = marge_haut - 40
	bouton_fermer.offset_bottom = marge_haut + 20
	bouton_fermer.pressed.connect(fermer)
	add_child(bouton_fermer)
	EffetsUI.animer_bouton(bouton_fermer)
	_remplir()
	_ouverture()


## Volutes d'or dans deux coins du parchemin.
func _ornements() -> void:
	var coin: Texture2D = load("res://assets/ui/matieres/coin.png")
	for c in [[Vector2(1, 0), true, false], [Vector2(0, 1), false, true]]:
		var t := TextureRect.new()
		t.texture = coin
		t.flip_h = c[1]
		t.flip_v = c[2]
		t.size = Vector2(76, 76)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t.anchor_left = c[0].x
		t.anchor_right = c[0].x
		t.anchor_top = c[0].y
		t.anchor_bottom = c[0].y
		t.offset_left = -marge_x - 100 if c[0].x > 0 else marge_x + 24
		t.offset_right = t.offset_left + 76
		t.offset_top = marge_haut + 26 if c[0].y == 0 else -marge_bas - 100
		t.offset_bottom = t.offset_top + 76
		add_child(t)


## Le parchemin se pose (léger zoom), la plaque glisse depuis la gauche.
func _ouverture() -> void:
	modulate.a = 0.0
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "modulate:a", 1.0, 0.16)
	cadre.pivot_offset = get_viewport_rect().size / 2.0 - cadre.position
	cadre.scale = Vector2.ONE * 0.97
	t.tween_property(cadre, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	EffetsUI.entree(plaque, 0.06, Vector2(-30, 0), 0.3)


func fermer() -> void:
	ferme.emit()


## Faux pendant DELAI_ENTRE_ACTIONS après l'action précédente (l'appui est alors ignoré) ; sinon, l'action
## est notée et l'appui accepté.
func appui_accepte() -> bool:
	var t := Time.get_ticks_msec()
	if t - _derniere_action < int(DELAI_ENTRE_ACTIONS * 1000.0):
		return false
	_derniere_action = t
	return true


## Refait le contenu (après un achat, un changement…).
func rafraichir() -> void:
	for c in contenu.get_children():
		contenu.remove_child(c)
		c.queue_free()
	_remplir()


func _remplir() -> void:
	pass
