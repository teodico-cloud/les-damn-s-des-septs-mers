class_name HudRepaire
extends CanvasLayer
## Interface du repaire (jalon 5) : joystick flottant à gauche ; en haut, les doublons et les matériaux ;
## à droite, les raccourcis vers les quatre lieux (sans marcher) ; en bas à droite, « Ouvrir » quand le
## héros est devant un lieu ; un lieu ouvert s'affiche en panneau par-dessus le repaire.

signal ouvrir_demande(lieu: StringName)
signal menu_demande

const DOUBLONS := Color("e0b04a")

var repaire: Node                   ## le Repaire (héros, caméra)
var heros: Heros
var racine: Control
var joystick: JoystickFlottant
var bouton_menu: Button
var barre: HBoxContainer            ## doublons et matériaux, en haut à droite
var labels_ressources := {}         ## "doublons" / "bois"… -> Label
var colonne_raccourcis: VBoxContainer
var raccourcis := {}                ## lieu -> Button
var bouton_ouvrir: Button
var label_message: Label
var panneau: Control                ## le lieu ouvert (panneau) ; null sinon
var voile: ColorRect                ## assombrit le repaire derrière un panneau
var lieu_affiche: StringName = &""
var _message_restant := 0.0


func _ready() -> void:
	layer = 5
	HudCombat._actions_clavier()
	if repaire:
		heros = repaire.heros
	racine = Control.new()
	racine.set_anchors_preset(Control.PRESET_FULL_RECT)
	racine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(racine)
	joystick = JoystickFlottant.new()
	racine.add_child(joystick)

	bouton_menu = StyleRepaire.bouton("Menu", Vector2(170, 76))
	bouton_menu.position = Vector2(24, 18)
	bouton_menu.pressed.connect(func(): menu_demande.emit())
	racine.add_child(bouton_menu)

	var titre := StyleRepaire.texte("Le repaire", 34, StyleRepaire.COULEUR_OS)
	titre.position = Vector2(214, 30)
	racine.add_child(titre)

	barre = HBoxContainer.new()
	barre.add_theme_constant_override("separation", 22)
	barre.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	barre.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	barre.position = Vector2(-24, 26)
	barre.alignment = BoxContainer.ALIGNMENT_END
	racine.add_child(barre)
	for cle in ["doublons"] + Array(Butin.MATIERES):
		var l := StyleRepaire.texte("", 24, Butin.COULEURS_TAS[cle])
		barre.add_child(l)
		labels_ressources[cle] = l

	colonne_raccourcis = VBoxContainer.new()
	colonne_raccourcis.add_theme_constant_override("separation", 10)
	colonne_raccourcis.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	colonne_raccourcis.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	colonne_raccourcis.grow_vertical = Control.GROW_DIRECTION_BOTH
	colonne_raccourcis.position = Vector2(-24, -60)
	racine.add_child(colonne_raccourcis)
	for l in Repaire.ORDRE_LIEUX:
		var b := StyleRepaire.bouton(Repaire.LIEUX[l]["nom"], Vector2(250, 64), 24)
		b.pressed.connect(func(): ouvrir_demande.emit(l))
		colonne_raccourcis.add_child(b)
		raccourcis[l] = b

	bouton_ouvrir = StyleRepaire.bouton("", Vector2(380, 92), 30, StyleRepaire.OR_VIF)
	bouton_ouvrir.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	bouton_ouvrir.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	bouton_ouvrir.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bouton_ouvrir.position = Vector2(-404, -116)
	bouton_ouvrir.visible = false
	bouton_ouvrir.pressed.connect(func():
		if lieu_affiche != &"":
			ouvrir_demande.emit(lieu_affiche))
	racine.add_child(bouton_ouvrir)

	label_message = StyleRepaire.texte("", 30, StyleRepaire.COULEUR_OS)
	label_message.set_anchors_preset(Control.PRESET_CENTER)
	label_message.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_message.position.y = -150
	label_message.add_theme_constant_override("outline_size", 8)
	label_message.visible = false
	racine.add_child(label_message)

	voile = ColorRect.new()
	voile.color = Color(0.0, 0.0, 0.0, 0.55)
	voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	voile.visible = false
	add_child(voile)
	rafraichir()
	Sauvegarde.changee.connect(rafraichir)


## Doublons et matériaux de l'entrepôt.
func rafraichir() -> void:
	labels_ressources["doublons"].text = "%d doublons" % Sauvegarde.doublons()
	for m in Butin.MATIERES:
		labels_ressources[m].text = Butin.texte_tas(m, Sauvegarde.ressource(m))


## Pastille « ! » sur le raccourci d'un lieu (un achat y est possible).
func marquer(lieu: StringName, oui: bool) -> void:
	var b: Button = raccourcis.get(lieu)
	if b == null:
		return
	var p := b.get_node_or_null("Pastille") as Label
	if p == null:
		p = Label.new()
		p.name = "Pastille"
		p.text = "!"
		p.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		p.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		p.add_theme_font_size_override("font_size", 28)
		p.add_theme_color_override("font_color", Color.WHITE)
		var fond := StyleBoxFlat.new()
		fond.bg_color = Color(0.85, 0.3, 0.15)
		fond.set_corner_radius_all(18)
		p.add_theme_stylebox_override("normal", fond)
		p.size = Vector2(36, 36)
		p.position = Vector2(-14, -12)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(p)
	p.visible = oui


## Le héros est devant un lieu (ou plus aucun : &"").
func montrer_lieu(lieu: StringName) -> void:
	lieu_affiche = lieu
	bouton_ouvrir.visible = lieu != &"" and panneau == null
	if lieu != &"":
		bouton_ouvrir.text = "Ouvrir : " + Repaire.LIEUX[lieu]["nom"]


func ouvrir_panneau(p: Control) -> void:
	fermer_panneau()
	relacher_tout()
	panneau = p
	voile.visible = true
	add_child(p)
	if p.has_signal("ferme"):
		p.ferme.connect(fermer_panneau)
	racine.visible = false
	montrer_lieu(lieu_affiche)


func fermer_panneau() -> void:
	if panneau == null:
		return
	if is_instance_valid(panneau):
		panneau.queue_free()
	panneau = null
	voile.visible = false
	racine.visible = true
	montrer_lieu(lieu_affiche)
	rafraichir()


func message(texte: String, duree: float) -> void:
	label_message.text = texte
	label_message.visible = true
	_message_restant = duree


func relacher_tout() -> void:
	if joystick:
		joystick.relacher()
	if heros and is_instance_valid(heros):
		heros.commandes.vider()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		relacher_tout()


func _input(event: InputEvent) -> void:
	if panneau:
		return   # un lieu ouvert : le joystick ne bouge rien
	if event is InputEventScreenTouch:
		if event.pressed:
			if not joystick.actif and event.position.x < get_viewport().get_visible_rect().size.x * 0.5 \
					and not bouton_menu.get_global_rect().has_point(event.position):
				joystick.commencer(event.index, event.position)
		elif joystick.actif and joystick.doigt == event.index:
			joystick.relacher()
	elif event is InputEventScreenDrag:
		if joystick.actif and joystick.doigt == event.index:
			joystick.deplacer(event.position)


func _process(delta: float) -> void:
	if _message_restant > 0.0:
		_message_restant -= delta
		if _message_restant <= 0.0:
			label_message.visible = false
	if repaire:
		heros = repaire.heros
	if heros == null or not is_instance_valid(heros):
		return
	var v := Vector2.ZERO if panneau else joystick.valeur
	if panneau == null:
		var clavier := Input.get_vector(&"deplacer_gauche", &"deplacer_droite", &"deplacer_haut", &"deplacer_bas")
		if clavier.length() > v.length():
			v = clavier
	var camera: CameraCombat = repaire.camera if repaire else null
	heros.commandes.deplacement = camera.joystick_vers_monde(v) if camera else Vector3(v.x, 0, v.y)
