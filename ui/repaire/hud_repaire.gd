class_name HudRepaire
extends CanvasLayer
## Interface du repaire (jalon 5 ; refonte de l'interface, 05/11) : joystick flottant à gauche ; en haut à gauche,
## « Menu » et la plaque du lieu ; en haut à droite, la bourse sur une lanière de cuir (doublons et matériaux,
## chacun avec son icône : toujours lisible, même quand une enseigne passe dessous — annexe retenue par Téo) ;
## à droite, les raccourcis vers les quatre lieux (des planches ; un sceau de cire « ! » quand un achat y est
## possible) ; en bas à droite, « Ouvrir » quand le héros est devant un lieu ; un lieu ouvert s'affiche en
## parchemin par-dessus le repaire.

signal ouvrir_demande(lieu: StringName)
signal menu_demande

const ICONES := {"doublons": "doublon", "bois": "bois", "fer": "fer", "essence": "essence"}

var repaire: Node                   ## le Repaire (héros, caméra)
var heros: Heros
var racine: Control
var joystick: JoystickFlottant
var bouton_menu: Button
var barre: HBoxContainer            ## doublons et matériaux, en haut à droite
var labels_ressources := {}         ## "doublons" / "bois"… -> Label (le nombre)
var colonne_raccourcis: VBoxContainer
var raccourcis := {}                ## lieu -> Button
var bouton_ouvrir: Button
var label_message: Label
var panneau: Control                ## le lieu ouvert (panneau) ; null sinon
var voile: ColorRect                ## assombrit le repaire derrière un panneau
var voile_noir: ColorRect           ## fondu au noir (arrivée, départ du repaire)
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

	bouton_menu = StyleRepaire.bouton("Menu", Vector2(150, 60), 24)
	bouton_menu.position = Vector2(22, 18)
	bouton_menu.pressed.connect(func(): menu_demande.emit())
	racine.add_child(bouton_menu)

	var plaque := PanelContainer.new()
	plaque.theme_type_variation = &"PanelPlaque"
	plaque.position = Vector2(186, 16)
	plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var titre := Label.new()
	titre.text = "Le repaire"
	titre.theme_type_variation = &"LabelTitre"
	titre.add_theme_font_size_override("font_size", 34)
	plaque.add_child(titre)
	racine.add_child(plaque)

	var bourse := PanelContainer.new()
	bourse.theme_type_variation = &"PanelCuir"
	bourse.anchor_left = 1.0
	bourse.anchor_right = 1.0
	bourse.offset_left = -22
	bourse.offset_right = -22
	bourse.offset_top = 16
	bourse.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	bourse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	racine.add_child(bourse)
	barre = HBoxContainer.new()
	barre.add_theme_constant_override("separation", 26)
	bourse.add_child(barre)
	for cle in ["doublons"] + Array(Butin.MATIERES):
		var case := HBoxContainer.new()
		case.add_theme_constant_override("separation", 6)
		barre.add_child(case)
		var icone := TextureRect.new()
		icone.texture = load("res://assets/ui/icones/%s.svg" % ICONES[cle])
		icone.custom_minimum_size = Vector2(36, 36)
		icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		case.add_child(icone)
		var l := Label.new()
		l.theme_type_variation = &"LabelGras"
		l.add_theme_font_size_override("font_size", 26)
		l.add_theme_color_override("font_color", Color("deba70") if cle == "doublons" else Color("d9c79f"))
		case.add_child(l)
		labels_ressources[cle] = l

	colonne_raccourcis = VBoxContainer.new()
	colonne_raccourcis.add_theme_constant_override("separation", 12)
	colonne_raccourcis.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	colonne_raccourcis.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	colonne_raccourcis.grow_vertical = Control.GROW_DIRECTION_BOTH
	colonne_raccourcis.position = Vector2(-22, -60)
	racine.add_child(colonne_raccourcis)
	var penche := [-0.8, 0.5, -0.4, 0.7]   # (un peu de travers : clouées à la main)
	for i in Repaire.ORDRE_LIEUX.size():
		var l: StringName = Repaire.ORDRE_LIEUX[i]
		var b := StyleRepaire.bouton(Repaire.LIEUX[l]["nom"], Vector2(250, 62), 24)
		b.rotation_degrees = penche[i]
		b.pressed.connect(func(): ouvrir_demande.emit(l))
		colonne_raccourcis.add_child(b)
		raccourcis[l] = b

	bouton_ouvrir = StyleRepaire.bouton("", Vector2(390, 92), 32)
	bouton_ouvrir.theme_type_variation = &"BoutonPrincipal"
	bouton_ouvrir.add_theme_font_size_override("font_size", 32)
	bouton_ouvrir.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	bouton_ouvrir.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	bouton_ouvrir.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bouton_ouvrir.position = Vector2(-412, -112)
	bouton_ouvrir.visible = false
	bouton_ouvrir.pressed.connect(func():
		if lieu_affiche != &"":
			ouvrir_demande.emit(lieu_affiche))
	racine.add_child(bouton_ouvrir)

	label_message = Label.new()
	label_message.theme_type_variation = &"LabelTitre"
	label_message.add_theme_font_size_override("font_size", 36)
	label_message.add_theme_constant_override("outline_size", 8)
	label_message.set_anchors_preset(Control.PRESET_CENTER)
	label_message.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_message.position.y = -150
	label_message.visible = false
	racine.add_child(label_message)

	voile = ColorRect.new()
	voile.color = Color(0.02, 0.015, 0.01, 0.62)
	voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	voile.visible = false
	add_child(voile)
	var couche := CanvasLayer.new()   # (le fondu au noir passe au-dessus des panneaux)
	couche.layer = 40
	add_child(couche)
	var plein := Control.new()
	plein.set_anchors_preset(Control.PRESET_FULL_RECT)
	plein.mouse_filter = Control.MOUSE_FILTER_IGNORE
	couche.add_child(plein)
	voile_noir = EffetsUI.voile(plein)
	rafraichir()
	Sauvegarde.changee.connect(rafraichir)


## Doublons et matériaux de l'entrepôt (les nombres ; l'icône dit lequel).
func rafraichir() -> void:
	labels_ressources["doublons"].text = str(Sauvegarde.doublons())
	for m in Butin.MATIERES:
		labels_ressources[m].text = str(Sauvegarde.ressource(m))


## Sceau de cire « ! » sur le raccourci d'un lieu (un achat y est possible) ; il bat doucement.
func marquer(lieu: StringName, oui: bool) -> void:
	var b: Button = raccourcis.get(lieu)
	if b == null:
		return
	var p := b.get_node_or_null("Pastille") as TextureRect
	if p == null:
		p = TextureRect.new()
		p.name = "Pastille"
		p.texture = load("res://assets/ui/matieres/sceau_marque.png")
		p.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		p.size = Vector2(46, 46)
		p.position = Vector2(-18, -16)
		p.pivot_offset = Vector2(23, 23)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(p)
		var t := p.create_tween().set_loops()
		t.tween_property(p, "scale", Vector2.ONE * 1.12, 0.5).set_trans(Tween.TRANS_SINE)
		t.tween_property(p, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE)
	p.visible = oui


## Fondu au noir, puis `appel` (le changement de scène).
func fondu_puis(appel: Callable) -> void:
	EffetsUI.fondu_puis(voile_noir, appel)


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
