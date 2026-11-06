class_name HudCombat
extends CanvasLayer
## Interface de combat : joystick flottant à gauche, boutons d'action à droite, barre de vie,
## bouton Menu. Gère plusieurs doigts à la fois et traduit tout en CommandesHeros.
## Au clavier (ordinateur) : ZQSD/WASD ou flèches, J attaque, K esquive, L parade, I fente.
## Expédition : nom de la salle en haut, fondu au noir entre deux salles, Menu à confirmer (on ne
## perd pas une expédition d'un doigt maladroit), écran de fin avec le bilan.

signal menu_demande
signal tri_valide(gardes: Array)   ## tri de la cale fini : les objets gardés
signal bordee_demandee(cible: Vector3)   ## jalon 5 : bouton Bordée relâché, le point visé

const COULEUR_OS := Color("e2d6ba")

var heros: Heros
var heros_partenaire: Heros    ## coop (sinon nul)
var regles: Node               ## coop, hôte : ReglesCoop (compte à rebours quand les deux sont à terre)
var camera: CameraCombat
var joystick: JoystickFlottant
var bouton_attaque: BoutonAction
var bouton_esquive: BoutonAction
var bouton_competence_1: BoutonAction
var bouton_competence_2: BoutonAction
var barre_vie: Control
var label_mort: Label
var label_ips: Label
var _minuterie_ips := 0.0
var label_message: Label
var label_partenaire: Label
var label_alerte: Label
var _les_deux_a_terre_depuis := -1.0
var bouton_menu: Button
var _boutons: Array[BoutonAction] = []
var _actions := {}   ## BoutonAction -> nom d'action
var _doigt_menu := -1      ## doigt posé sur le bouton Menu
var _menu_demande := false
var mode_expedition := false
var _pv_retard := 0.0              ## (refonte) la part de vie perdue reste visible un instant, puis fond
var _retard_depuis := 0.0
static var _police_grasse: Font
static var _police_titre: Font
## Bordée (jalon 5, choix de Téo : visée au joystick) : bouton maintenu, une zone rouge au sol suit le pouce
## (glissé depuis le bouton) ; relâché, le navire tire. Sans glisser : devant le héros.
const BORDEE: Equilibrage = preload("res://data/equilibrage.tres")
const ZONE_MORTE_BORDEE := 25.0     ## pixels : en deçà, la zone reste devant le héros
const GLISSE_BORDEE := 170.0        ## pixels : glissé jusqu'à la portée la plus longue
var bouton_bordee: BoutonAction
var viseur_bordee: MeshInstance3D   ## la zone visée, au sol (dans le monde du héros)
var cible_bordee := Vector3.ZERO
var _doigt_bordee := -1
var label_salle: Label
var voile: ColorRect           ## fondu au noir entre deux salles
var panneau_fin: Control
var barre_boss: Control        ## vie du Bosco, en haut au centre, quand il est là
var _boss: Node3D
var _boss_dessine := Vector2(-1, -1)   ## (PV, rage) déjà dessinés : on ne redessine que s'ils changent
var label_malediction: Label   ## expédition : niveau de malédiction, sous les PV
var label_sac: Label           ## expédition : objets et doublons dans le sac (non sécurisés)
var label_matieres: Label      ## jalon 5 : les matériaux du sac (bois de coque, fer noir, essence maudite)
var fil_butin: VBoxContainer   ## ce qu'on vient de ramasser (s'efface tout seul)
var panneau_tri: Control       ## tri de la cale (fin d'expédition, sac trop plein)
var _tri_objets: Array = []    ## du plus rare au moins rare
var _tri_gardes := {}          ## id -> vrai si gardé (coché)
var _tri_places := 8
var _tri_boutons := {}         ## id -> Button
var _label_tri: Label
var _premier_appui_menu := -100.0   ## expédition : heure du 1er appui sur Menu (on attend le 2e)


func _ready() -> void:
	_actions_clavier()
	add_child(EffetsUI.vignette())   # (bords de l'écran assombris, façon Diablo IV, 06/11)
	var racine := Control.new()
	racine.set_anchors_preset(Control.PRESET_FULL_RECT)
	racine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(racine)

	joystick = JoystickFlottant.new()
	racine.add_child(joystick)

	var noms: Dictionary = heros.noms_boutons()
	var icones: Dictionary = heros.icones_boutons()
	bouton_attaque = _bouton(racine, noms[&"attaque"], 96.0, null, Vector2(-170, -170), &"attaque")
	bouton_esquive = _bouton(racine, noms[&"esquive"], 62.0, heros.recharge_esquive, Vector2(-345, -105), &"esquive")
	bouton_competence_1 = _bouton(racine, noms[&"competence_1"], 62.0, heros.recharge_competence_1, Vector2(-330, -285), &"competence_1")
	bouton_competence_2 = _bouton(racine, noms[&"competence_2"], 62.0, heros.recharge_competence_2, Vector2(-170, -365), &"competence_2")
	# bordée (jalon 5) : cachée tant que le navire n'a pas de canons (configurer_bordee)
	bouton_bordee = _bouton(racine, "Bordée", 54.0, null, Vector2(-505, -235), &"bordee")
	bouton_bordee.icone = preload("res://assets/ui/icones/canon.svg")
	_boutons.erase(bouton_bordee)   # (son toucher est à part : on vise avant de tirer)
	bouton_bordee.visible = false

	barre_vie = Control.new()
	barre_vie.position = Vector2(24, 20)
	barre_vie.size = Vector2(400, 40)
	barre_vie.mouse_filter = Control.MOUSE_FILTER_IGNORE
	barre_vie.draw.connect(_dessiner_vie)
	racine.add_child(barre_vie)
	_pv_retard = heros.sante.pv
	heros.sante.change.connect(_sur_change_vie)

	bouton_menu = Button.new()
	bouton_menu.text = "Menu"
	bouton_menu.theme_type_variation = &"BoutonPetit"   # (refonte : une planche cerclée de fer)
	bouton_menu.custom_minimum_size = Vector2(150, 60)
	bouton_menu.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	bouton_menu.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	bouton_menu.position = Vector2(-172, 18)
	bouton_menu.pressed.connect(_demander_menu)   # clic souris (ordinateur) ou 1er doigt
	racine.add_child(bouton_menu)

	# images par seconde (APK de test : pour juger la fluidité avec la horde)
	label_ips = Label.new()
	label_ips.add_theme_font_size_override("font_size", 20)
	label_ips.add_theme_color_override("font_color", Color(COULEUR_OS, 0.7))
	label_ips.add_theme_color_override("font_outline_color", Color.BLACK)
	label_ips.add_theme_constant_override("outline_size", 6)
	label_ips.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	label_ips.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	label_ips.position = Vector2(-120, 98)
	label_ips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	racine.add_child(label_ips)

	label_mort = Label.new()
	label_mort.theme_type_variation = &"LabelTitre"
	label_mort.add_theme_font_size_override("font_size", 48)
	label_mort.add_theme_color_override("font_color", Color("e0603f"))
	label_mort.add_theme_color_override("font_outline_color", Color.BLACK)
	label_mort.add_theme_constant_override("outline_size", 12)
	label_mort.set_anchors_preset(Control.PRESET_CENTER)
	label_mort.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label_mort.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_mort.visible = false
	label_mort.mouse_filter = Control.MOUSE_FILTER_IGNORE
	racine.add_child(label_mort)

	label_partenaire = label_mort.duplicate() as Label
	label_partenaire.theme_type_variation = &"LabelGras"
	label_partenaire.add_theme_color_override("font_color", Color("8fc9bc"))
	label_partenaire.add_theme_font_size_override("font_size", 30)
	label_partenaire.set_anchors_preset(Control.PRESET_CENTER_TOP)
	label_partenaire.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label_partenaire.position.y = 80
	label_partenaire.text = "Ton partenaire est à terre : reste près de lui pour le relever !"
	racine.add_child(label_partenaire)

	label_alerte = label_partenaire.duplicate() as Label
	label_alerte.add_theme_color_override("font_color", Color("deba70"))
	label_alerte.position.y = 130
	label_alerte.visible = false
	racine.add_child(label_alerte)

	label_message = label_mort.duplicate() as Label
	label_message.add_theme_color_override("font_color", Color("d9c79f"))
	label_message.add_theme_font_size_override("font_size", 36)
	label_message.position.y -= 160
	racine.add_child(label_message)

	label_salle = Label.new()
	label_salle.theme_type_variation = &"LabelSousTitre"
	label_salle.add_theme_font_size_override("font_size", 32)
	label_salle.add_theme_color_override("font_color", Color("deba70"))
	label_salle.add_theme_color_override("font_outline_color", Color.BLACK)
	label_salle.add_theme_constant_override("outline_size", 8)
	label_salle.set_anchors_preset(Control.PRESET_CENTER_TOP)
	label_salle.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label_salle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_salle.position.y = 22
	label_salle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	racine.add_child(label_salle)

	barre_boss = Control.new()
	barre_boss.set_anchors_preset(Control.PRESET_CENTER_TOP)
	barre_boss.size = Vector2(620, 58)
	barre_boss.position = Vector2(-310, 70)
	barre_boss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	barre_boss.visible = false
	barre_boss.draw.connect(_dessiner_boss)
	racine.add_child(barre_boss)

	label_malediction = Label.new()
	label_malediction.theme_type_variation = &"LabelGras"
	label_malediction.add_theme_font_size_override("font_size", 22)
	label_malediction.add_theme_color_override("font_color", Color("8fc9bc"))
	label_malediction.add_theme_color_override("font_outline_color", Color.BLACK)
	label_malediction.add_theme_constant_override("outline_size", 6)
	label_malediction.position = Vector2(28, 64)
	label_malediction.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label_malediction.visible = false
	racine.add_child(label_malediction)

	label_sac = label_malediction.duplicate() as Label
	label_sac.add_theme_color_override("font_color", Color("deba70"))
	label_sac.position = Vector2(28, 94)
	label_sac.visible = false
	racine.add_child(label_sac)
	label_matieres = label_malediction.duplicate() as Label
	label_matieres.add_theme_color_override("font_color", Color("d9c79f"))
	label_matieres.position = Vector2(28, 122)
	label_matieres.visible = false
	racine.add_child(label_matieres)

	fil_butin = VBoxContainer.new()
	fil_butin.position = Vector2(28, 160)
	fil_butin.add_theme_constant_override("separation", 2)
	fil_butin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	racine.add_child(fil_butin)

	voile = ColorRect.new()
	voile.color = Color(0, 0, 0, 0)
	voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	voile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	racine.add_child(voile)


func _bouton(parent: Control, texte: String, rayon: float, rec: Recharge, decalage: Vector2, action: StringName) -> BoutonAction:
	var b := BoutonAction.new()
	b.configurer(texte, rayon, rec)
	b.icone = heros.icones_boutons().get(action) as Texture2D
	b.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	b.position = decalage - Vector2(rayon, rayon)
	parent.add_child(b)
	# ancré en bas à droite : la position est relative à ce coin
	b.anchor_left = 1.0
	b.anchor_top = 1.0
	b.anchor_right = 1.0
	b.anchor_bottom = 1.0
	b.offset_left = decalage.x - rayon
	b.offset_top = decalage.y - rayon
	b.offset_right = decalage.x + rayon
	b.offset_bottom = decalage.y + rayon
	_boutons.append(b)
	_actions[b] = action
	return b


static func _actions_clavier() -> void:
	var touches := {
		&"deplacer_gauche": [KEY_A, KEY_Q, KEY_LEFT],
		&"deplacer_droite": [KEY_D, KEY_RIGHT],
		&"deplacer_haut": [KEY_W, KEY_Z, KEY_UP],
		&"deplacer_bas": [KEY_S, KEY_DOWN],
		&"attaque": [KEY_J, KEY_SPACE],
		&"esquive": [KEY_K, KEY_SHIFT],
		&"competence_1": [KEY_L],
		&"competence_2": [KEY_I],
		&"bordee": [KEY_B],
	}
	for action in touches:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for k in touches[action]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(action, e)


# ---------------------------------------------------------------- bordée (jalon 5)
## Les tirs de bordée qui restent : le bouton apparaît si le navire a des canons, grisé quand c'est vide.
func configurer_bordee(tirs: int) -> void:
	bouton_bordee.visible = bouton_bordee.visible or tirs > 0
	bouton_bordee.compteur = tirs
	bouton_bordee.inactif = tirs <= 0
	bouton_bordee.queue_redraw()


func _commencer_visee(doigt: int) -> void:
	_doigt_bordee = doigt
	bouton_bordee.doigt = doigt
	bouton_bordee.appuye = true
	if viseur_bordee == null:
		viseur_bordee = MeshInstance3D.new()
		var anneau := TorusMesh.new()
		anneau.inner_radius = BORDEE.bordee_dispersion + BORDEE.bordee_rayon * 0.5 - 0.2
		anneau.outer_radius = BORDEE.bordee_dispersion + BORDEE.bordee_rayon * 0.5
		anneau.rings = 40
		anneau.ring_segments = 6
		viseur_bordee.mesh = anneau
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(1.0, 0.3, 0.2, 0.75)
		viseur_bordee.material_override = m
		viseur_bordee.scale = Vector3(1, 0.1, 1)
		viseur_bordee.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var croix := MeshInstance3D.new()   # le centre visé
		var disque := CylinderMesh.new()
		disque.top_radius = 0.35
		disque.bottom_radius = 0.35
		disque.height = 0.2
		croix.mesh = disque
		croix.material_override = m
		viseur_bordee.add_child(croix)
		heros.get_parent().add_child(viseur_bordee)
	viseur_bordee.visible = true
	viser_bordee(Vector2.ZERO)


## Le pouce a glissé de `d` pixels depuis le bouton : la zone suit (direction de l'écran, distance selon le
## glissé, jusqu'à la portée) ; sans glisser, elle reste devant le héros.
func viser_bordee(d: Vector2) -> void:
	var dir: Vector3 = heros.avant()
	var dist := BORDEE.bordee_portee_min
	if d.length() >= ZONE_MORTE_BORDEE:
		dir = camera.joystick_vers_monde(d.normalized()) if camera else Vector3(d.x, 0, d.y).normalized()
		dist = lerpf(BORDEE.bordee_portee_min, BORDEE.bordee_portee, clampf((d.length() - ZONE_MORTE_BORDEE) / GLISSE_BORDEE, 0.0, 1.0))
	dir.y = 0.0
	cible_bordee = heros.global_position + dir.normalized() * dist
	cible_bordee.y = 0.0
	if viseur_bordee:
		viseur_bordee.global_position = cible_bordee + Vector3.UP * 0.06


## Le pouce se lève : on tire (sauf si le système a annulé le toucher).
func finir_visee(tirer: bool) -> void:
	_doigt_bordee = -1
	bouton_bordee.doigt = -1
	bouton_bordee.appuye = false
	if viseur_bordee:
		viseur_bordee.visible = false
	if tirer:
		bordee_demandee.emit(cible_bordee)


# ---------------------------------------------------------------- toucher (plusieurs doigts)
func _input(event: InputEvent) -> void:
	if panneau_tri:
		return   # tri de la cale : ni joystick ni boutons du combat (les cases se touchent normalement)
	if event is InputEventScreenTouch:
		if event.pressed:
			# le Menu est géré ici aussi : Godot ne transforme en clic que le 1er doigt posé, et le
			# pouce gauche est souvent déjà sur le joystick
			if bouton_menu.get_global_rect().has_point(event.position):
				_doigt_menu = event.index
				return
			if bouton_bordee.visible and _doigt_bordee == -1 and bouton_bordee.contient(event.position):
				if not bouton_bordee.inactif and heros.est_vivant() and panneau_fin == null:
					_commencer_visee(event.index)
				get_viewport().set_input_as_handled()
				return
			for b in _boutons:
				if b.doigt == -1 and b.contient(event.position):
					b.doigt = event.index
					b.appuye = true
					_demander(_actions[b])
					get_viewport().set_input_as_handled()
					return
			if not joystick.actif and event.position.x < get_viewport().get_visible_rect().size.x * 0.5:
				joystick.commencer(event.index, event.position)
				get_viewport().set_input_as_handled()
		else:
			if _doigt_menu == event.index:
				_doigt_menu = -1
				if not event.canceled and bouton_menu.get_global_rect().has_point(event.position):
					_demander_menu()
			for b in _boutons:
				if b.doigt == event.index:
					b.doigt = -1
					b.appuye = false
			if _doigt_bordee == event.index:
				finir_visee(not event.canceled)
			if joystick.actif and joystick.doigt == event.index:
				joystick.relacher()
	elif event is InputEventScreenDrag:
		if _doigt_bordee == event.index:
			viser_bordee(event.position - bouton_bordee.centre_ecran())
		if joystick.actif and joystick.doigt == event.index:
			joystick.deplacer(event.position)
			get_viewport().set_input_as_handled()


## Alerte qui reste affichée tant qu'elle n'est pas retirée (texte vide) : connexion instable…
func alerte(texte: String) -> void:
	label_alerte.text = texte
	label_alerte.visible = texte != ""


## Message au centre de l'écran pendant `duree` secondes (partenaire parti…).
func afficher_message(texte: String, duree: float) -> void:
	label_message.text = texte
	label_message.visible = true
	get_tree().create_timer(duree).timeout.connect(func(): if is_instance_valid(label_message): label_message.visible = false)


func _demander_menu() -> void:
	if _menu_demande:
		return   # une seule fois, même si le clic et le toucher arrivent tous les deux
	if mode_expedition and panneau_fin == null:
		# expédition en cours : un premier appui demande confirmation (un doigt maladroit ne la perd pas)
		var depuis := Time.get_ticks_msec() / 1000.0 - _premier_appui_menu
		if depuis < 0.2:
			return   # le clic et le toucher d'un même appui arrivent ensemble : pas une confirmation
		if depuis > 2.5:
			_premier_appui_menu = Time.get_ticks_msec() / 1000.0
			afficher_message("Appuie encore sur Menu pour abandonner l'expédition", 2.5)
			return
	_menu_demande = true
	menu_demande.emit()


## Un objet ou des doublons ramassés : une ligne à la couleur de la rareté, qui s'efface (4 au plus).
func afficher_ramasse(texte: String, couleur: Color) -> void:
	var l := Label.new()
	l.text = texte
	l.theme_type_variation = &"LabelGras"
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", couleur)
	l.add_theme_constant_override("outline_size", 7)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fil_butin.add_child(l)
	while fil_butin.get_child_count() > 4:
		var vieux := fil_butin.get_child(0)
		fil_butin.remove_child(vieux)
		vieux.queue_free()
	var t := l.create_tween()
	t.tween_interval(2.6)
	t.tween_property(l, "modulate:a", 0.0, 0.6)
	t.tween_callback(l.queue_free)


## Le sac de l'expédition (non sécurisé : perdu en cas de défaite), et la place dans la cale (annexe
## retenue par Téo) : en orange quand il faudra trier à la fin. Dessous, ses matériaux (`sac`).
func afficher_sac(objets: int, doublons: int, places: int, sac := {}) -> void:
	label_sac.visible = true
	label_sac.text = "Sac : %d objet%s / cale %d · %d doublons" % [objets, "s" if objets > 1 else "", places, doublons]
	label_sac.add_theme_color_override("font_color", Color(1.0, 0.55, 0.15) if objets > places else Color("deba70"))
	label_matieres.text = Butin.texte_matieres(sac)
	label_matieres.visible = label_matieres.text != ""


## Nom de la salle en cours (expédition).
func afficher_salle(texte: String) -> void:
	label_salle.text = texte


## Fondu au noir (vers_noir) ou retour à l'image, en `duree` secondes réelles.
func fondu(vers_noir: bool, duree: float) -> void:
	var t := voile.create_tween()
	t.set_ignore_time_scale(true)
	t.tween_property(voile, "color:a", 1.0 if vers_noir else 0.0, duree)


## Écran de fin d'expédition : titre, lignes du bilan, butin rapporté (à la couleur de sa rareté),
## bouton de retour au menu. `titre` : à la place de « Expédition réussie ! » (extraction d'urgence).
func afficher_resultats(reussite: bool, lignes: Array, objets: Array = [], titre_force := "") -> void:
	if panneau_fin:
		return
	Sons.jingle(&"victoire" if reussite else &"defaite")
	relacher_tout()
	label_mort.visible = false
	label_message.visible = false
	label_sac.visible = false
	label_matieres.visible = false
	fil_butin.visible = false
	var fond := ColorRect.new()
	fond.color = Color(0.02, 0.015, 0.01, 0.0)
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fond)
	panneau_fin = fond
	# refonte de l'interface : le bilan sur un parchemin cloué, scellé de cire (réussite) ; à l'encre
	var feuille := PanelContainer.new()
	feuille.theme_type_variation = &"PanelParchemin"
	feuille.set_anchors_preset(Control.PRESET_CENTER)
	feuille.grow_horizontal = Control.GROW_DIRECTION_BOTH
	feuille.grow_vertical = Control.GROW_DIRECTION_BOTH
	feuille.custom_minimum_size = Vector2(900, 0)
	fond.add_child(feuille)
	var colonne := VBoxContainer.new()
	colonne.alignment = BoxContainer.ALIGNMENT_CENTER
	colonne.add_theme_constant_override("separation", 10 if objets.is_empty() else 6)
	feuille.add_child(colonne)
	var titre := Label.new()
	titre.text = titre_force if titre_force != "" else ("Expédition réussie !" if reussite else "Expédition perdue…")
	titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titre.theme_type_variation = &"LabelEncreTitre"
	titre.add_theme_font_size_override("font_size", 58)
	titre.add_theme_color_override("font_color", Color("2f6b3a") if reussite else Color("8b1e1a"))
	colonne.add_child(titre)
	colonne.add_child(StyleRepaire.separateur(380.0))
	for l in lignes:
		var ligne := Label.new()
		ligne.text = String(l)
		ligne.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ligne.theme_type_variation = &"LabelEncre"
		ligne.add_theme_font_size_override("font_size", 25 if not objets.is_empty() else 28)
		colonne.add_child(ligne)
	if not objets.is_empty():
		var flot := HFlowContainer.new()
		flot.alignment = FlowContainer.ALIGNMENT_CENTER
		flot.custom_minimum_size = Vector2(760, 0)
		flot.add_theme_constant_override("h_separation", 24)
		var tries := objets.duplicate()
		tries.sort_custom(func(x, y): return int(x.get("rarete", 0)) > int(y.get("rarete", 0)))   # les plus rares d'abord
		for o in tries.slice(0, 10):
			var n := Label.new()
			n.text = Butin.nom(o)
			n.theme_type_variation = &"LabelEncreGras"
			n.add_theme_font_size_override("font_size", 24)
			n.add_theme_color_override("font_color", StyleRepaire.encre(Butin.couleur(o)))
			flot.add_child(n)
		if tries.size() > 10:
			var reste := Label.new()
			reste.text = "… et %d autres" % (tries.size() - 10)
			reste.theme_type_variation = &"LabelEncre"
			reste.add_theme_font_size_override("font_size", 24)
			flot.add_child(reste)
		colonne.add_child(flot)
	var espace := Control.new()
	espace.custom_minimum_size = Vector2(0, 10)
	colonne.add_child(espace)
	var b := Button.new()
	b.text = "Retour au repaire"   # (jalon 5 : après une expédition, on rentre au repaire)
	b.theme_type_variation = &"BoutonPrincipal"
	b.custom_minimum_size = Vector2(440, 92)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func():
		_menu_demande = true
		menu_demande.emit())
	EffetsUI.animer_bouton(b)
	colonne.add_child(b)
	if reussite:   # un sceau de cire dans le coin du parchemin
		var deco := Control.new()
		deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
		feuille.add_child(deco)
		var cachet := TextureRect.new()
		cachet.texture = load("res://assets/ui/matieres/sceau.png")
		cachet.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cachet.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cachet.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		cachet.offset_left = -96
		cachet.offset_top = -96
		cachet.offset_right = 14
		cachet.offset_bottom = 14
		deco.add_child(cachet)
	feuille.modulate.a = 0.0
	var t := fond.create_tween()
	t.set_ignore_time_scale(true)
	t.tween_property(fond, "color:a", 0.78, 0.6)
	t.parallel().tween_property(feuille, "modulate:a", 1.0, 0.5).set_delay(0.2)


# ---------------------------------------------------------------- tri de la cale (jalon 4, choix de Téo)
## Le sac dépasse la cale : on choisit les objets à garder (les plus rares sont cochés d'avance) ; les
## autres sont revendus en doublons. « Charger la cale » envoie `tri_valide`.
func afficher_tri(objets: Array, places: int) -> void:
	if panneau_tri or panneau_fin:
		return
	relacher_tout()
	label_mort.visible = false
	label_message.visible = false
	label_sac.visible = false
	label_matieres.visible = false
	fil_butin.visible = false
	_tri_objets = Butin.par_rarete(objets)
	_tri_places = places
	_tri_gardes.clear()
	_tri_boutons.clear()
	for i in _tri_objets.size():
		_tri_gardes[_tri_objets[i]["id"]] = i < places
	var fond := ColorRect.new()
	fond.color = Color(0.02, 0.015, 0.01, 0.82)
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	fond.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(fond)
	panneau_tri = fond
	# refonte de l'interface : le manifeste de la cale, sur un parchemin cloué ; gardé = une planche, revendu = du cuir
	var feuille := PanelContainer.new()
	feuille.theme_type_variation = &"PanelParchemin"
	feuille.set_anchors_preset(Control.PRESET_FULL_RECT)
	feuille.offset_left = 60
	feuille.offset_right = -60
	feuille.offset_top = 14
	feuille.offset_bottom = -10
	fond.add_child(feuille)
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 8)
	feuille.add_child(colonne)
	var titre := _ligne_tri("Charger la cale", 46, Color("2b1d13"))
	titre.theme_type_variation = &"LabelEncreTitre"
	titre.add_theme_font_size_override("font_size", 46)
	colonne.add_child(titre)
	colonne.add_child(_ligne_tri("La cale ne prend que %d objets : touchez-les pour choisir. Les autres sont revendus." % places,
			24, Color("2b1d13")))
	var defile := ScrollContainer.new()
	defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	defile.size_flags_vertical = Control.SIZE_EXPAND_FILL
	colonne.add_child(defile)
	var grille := GridContainer.new()
	grille.columns = 3
	grille.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grille.add_theme_constant_override("h_separation", 12)
	grille.add_theme_constant_override("v_separation", 10)
	defile.add_child(grille)
	for o in _tri_objets:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 82)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		b.add_theme_font_override("font", load("res://assets/ui/polices/AlegreyaSans-Bold.ttf"))
		b.add_theme_font_size_override("font_size", 22)
		for etat in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(etat, Butin.couleur(o))
		b.pressed.connect(basculer_tri.bind(String(o["id"])))
		grille.add_child(b)
		_tri_boutons[String(o["id"])] = b
	_label_tri = _ligne_tri("", 24, Color("2b1d13"))
	colonne.add_child(_label_tri)
	var valider := Button.new()
	valider.text = "Charger la cale"
	valider.theme_type_variation = &"BoutonPrincipal"
	valider.custom_minimum_size = Vector2(420, 84)
	valider.add_theme_font_size_override("font_size", 32)
	valider.pressed.connect(valider_tri)
	EffetsUI.animer_bouton(valider)
	var centre := CenterContainer.new()
	centre.add_child(valider)
	colonne.add_child(centre)
	_rafraichir_tri()


## Touché : gardé ↔ revendu (pas plus d'objets gardés que de places).
func basculer_tri(id: String) -> void:
	if not _tri_gardes.has(id):
		return
	if not _tri_gardes[id] and gardes_tri().size() >= _tri_places:
		_rafraichir_tri("La cale est pleine : décochez d'abord un objet.")
		return
	_tri_gardes[id] = not _tri_gardes[id]
	_rafraichir_tri()


func gardes_tri() -> Array:
	return _tri_objets.filter(func(o): return _tri_gardes.get(String(o["id"]), false))


## « Charger la cale » (ou l'appli qui se ferme pendant le tri : la sélection en cours est gardée).
func valider_tri() -> void:
	if panneau_tri == null:
		return
	var gardes := gardes_tri()
	panneau_tri.queue_free()
	panneau_tri = null
	tri_valide.emit(gardes)


func _rafraichir_tri(alerte_tri := "") -> void:
	var revente := 0
	for o in _tri_objets:
		var id := String(o["id"])
		var garde: bool = _tri_gardes[id]
		var b: Button = _tri_boutons[id]
		b.text = ("✓  " if garde else "") + Butin.nom(o) + "\n" + \
				(Butin.NOMS_RARETES[clampi(int(o.get("rarete", 0)), 0, 4)] if garde else "revendu : +%d doublons" % Butin.prix_revente(o))
		# gardé : une planche (dans la cale) ; revendu : une lanière de cuir, pâlie
		b.theme_type_variation = &"BoutonOngletActif" if garde else &"BoutonOnglet"
		b.modulate.a = 1.0 if garde else 0.7
		if not garde:
			revente += Butin.prix_revente(o)
	var n := gardes_tri().size()
	if alerte_tri != "":
		_label_tri.text = alerte_tri
		_label_tri.add_theme_color_override("font_color", Color("8b1e1a"))
	else:
		_label_tri.text = "Dans la cale : %d / %d · revendus : %d objet%s, +%d doublons" % [n, _tri_places,
				_tri_objets.size() - n, "s" if _tri_objets.size() - n > 1 else "", revente]
		_label_tri.add_theme_color_override("font_color", Color("2b1d13"))


func _ligne_tri(texte: String, taille: int, couleur: Color) -> Label:
	var l := Label.new()
	l.text = texte
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.theme_type_variation = &"LabelEncre"
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", couleur)
	return l


func _style_tri(enfonce: bool, garde: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.3, 0.21, 0.12, 0.95) if garde else Color(0.1, 0.08, 0.07, 0.9)
	if enfonce:
		s.bg_color = s.bg_color.darkened(0.3)
	s.border_color = Color("e0b04a") if garde else Color("5a4a3a")
	s.set_border_width_all(4 if garde else 2)
	s.set_corner_radius_all(12)
	s.content_margin_left = 12
	s.content_margin_right = 12
	return s


## Si l'appli passe en arrière-plan (appel, notification…), Android n'envoie pas toujours la levée
## des doigts : on relâche tout pour ne pas retrouver une attaque bloquée ou un joystick collé.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		relacher_tout()


func relacher_tout() -> void:
	for b in _boutons:
		b.doigt = -1
		b.appuye = false
	_doigt_menu = -1
	if _doigt_bordee != -1:
		finir_visee(false)   # (appel, notifications : la visée est abandonnée, rien n'est tiré)
	if joystick:
		joystick.relacher()


func _demander(action: StringName) -> void:
	if heros:
		heros.commandes.demander(action, heros.horloge)


func _process(delta: float) -> void:
	_minuterie_ips -= delta
	if _minuterie_ips <= 0.0 and label_ips:
		_minuterie_ips = 0.5
		label_ips.text = "%d i/s" % Engine.get_frames_per_second()
	if heros == null:
		return
	# garder l'attaque enfoncée enchaîne le combo
	if bouton_attaque.appuye:
		_demander(&"attaque")
	_faire_fondre_le_retard(delta)
	for action in [&"attaque", &"esquive", &"competence_1", &"competence_2"]:
		if Input.is_action_just_pressed(action):
			_demander(action)
	if Input.is_action_just_pressed(&"bordee") and bouton_bordee.visible and not bouton_bordee.inactif:
		viser_bordee(Vector2.ZERO)   # (clavier : devant le héros)
		bordee_demandee.emit(cible_bordee)
	var v := joystick.valeur
	var clavier := Input.get_vector(&"deplacer_gauche", &"deplacer_droite", &"deplacer_haut", &"deplacer_bas")
	if clavier.length() > v.length():
		v = clavier
	heros.commandes.deplacement = camera.joystick_vers_monde(v) if camera else Vector3(v.x, 0, v.y)

	_textes_a_terre()
	_suivre_boss()
	var n := Malediction.niveau() if mode_expedition else 0
	label_malediction.visible = n > 0 and panneau_fin == null
	if n > 0:
		label_malediction.text = "Malédiction %d" % n


## Barre de vie du Bosco : visible tant qu'il est là et debout (chez l'hôte comme chez l'invité).
func _suivre_boss() -> void:
	if _boss == null or not is_instance_valid(_boss) or not _boss.is_in_group("boss"):
		_boss = get_tree().get_first_node_in_group("boss") as Node3D
	var visible_boss := _boss != null and panneau_fin == null
	if barre_boss.visible != visible_boss:
		barre_boss.visible = visible_boss
		# les textes de la coop descendent sous la barre du Bosco
		label_partenaire.position.y = 80 + (66 if visible_boss else 0)
		label_alerte.position.y = 130 + (66 if visible_boss else 0)
	if visible_boss:
		var etat := Vector2(_boss.sante.pv if _boss.get("sante") else 0.0, 1.0 if _boss.get("enrage") == true else 0.0)
		if etat != _boss_dessine:
			_boss_dessine = etat
			barre_boss.queue_redraw()


func _dessiner_boss() -> void:
	if _boss == null or not is_instance_valid(_boss) or _boss.get("sante") == null:
		return
	var s: Sante = _boss.sante
	var enrage: bool = _boss.get("enrage") == true
	var nom := "Le Bosco Maudit — enragé" if enrage else "Le Bosco Maudit"
	var largeur := barre_boss.size.x
	var titre := HudCombat.police_titre()
	barre_boss.draw_string_outline(titre, Vector2(0, 22), nom, HORIZONTAL_ALIGNMENT_CENTER, largeur, 28, 7, Color(0.04, 0.025, 0.015))
	barre_boss.draw_string(titre, Vector2(0, 22), nom, HORIZONTAL_ALIGNMENT_CENTER, largeur, 28, Color("e0603f") if enrage else Color("deba70"))
	var rect := Rect2(Vector2(0, 30), Vector2(largeur, 26))
	HudCombat.dessiner_jauge(barre_boss, rect, clampf(s.pv / s.pv_max, 0.0, 1.0), -1.0,
			Color(0.62, 0.08, 0.05) if enrage else Color(0.38, 0.04, 0.05), Color(0.9, 0.22, 0.12) if enrage else Color(0.66, 0.12, 0.1))


## Textes quand un héros est à terre (solo : compte à rebours ; coop : réanimation ou retour au départ).
func _textes_a_terre() -> void:
	var moi_a_terre := not heros.est_vivant()
	var coop := heros_partenaire != null and is_instance_valid(heros_partenaire)
	var lui_a_terre := coop and not heros_partenaire.est_vivant()
	label_partenaire.visible = coop and lui_a_terre and not moi_a_terre
	label_mort.visible = moi_a_terre
	if not moi_a_terre:
		_les_deux_a_terre_depuis = -1.0
		return
	if panneau_fin:
		label_mort.visible = false
		return
	if not coop:
		if mode_expedition:
			label_mort.text = "Vous êtes tombé…"
		else:
			label_mort.text = "Vous êtes tombé…\nRetour dans %d s" % ceili(heros.temps_avant_reapparition())
	elif not lui_a_terre:
		_les_deux_a_terre_depuis = -1.0
		label_mort.text = "Tu es à terre !\nTon partenaire peut te relever (%d %%)" % roundi(heros.progres_reanimation * 100.0)
	else:
		var t := Time.get_ticks_msec() / 1000.0
		if _les_deux_a_terre_depuis < 0.0:
			_les_deux_a_terre_depuis = t
		if mode_expedition:
			label_mort.text = "Vous êtes tombés…"
			return
		var reste: float = regles.temps_avant_retour if regles else heros.EQ.coop_delai_retour - (t - _les_deux_a_terre_depuis)
		label_mort.text = "Vous êtes tombés…\nRetour au départ dans %d s" % maxi(ceili(reste), 0)


func _dessiner_vie() -> void:
	var s := heros.sante
	var rect := Rect2(Vector2.ZERO, barre_vie.size)
	var dedans := HudCombat.dessiner_jauge(barre_vie, rect, clampf(s.pv / s.pv_max, 0.0, 1.0),
			clampf(_pv_retard / s.pv_max, 0.0, 1.0), Color(0.42, 0.05, 0.05), Color(0.74, 0.15, 0.12))
	var txt := "PV %d / %d" % [ceili(s.pv), int(s.pv_max)]
	var police := HudCombat.police_grasse()
	var y := dedans.position.y + dedans.size.y / 2.0 + 8.0
	barre_vie.draw_string_outline(police, Vector2(dedans.position.x + 12, y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 23, 6, Color(0.04, 0.025, 0.015))
	barre_vie.draw_string(police, Vector2(dedans.position.x + 12, y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 23, Color("ecdcb8"))


## La vie change : une perte reste visible (une bande claire qui fond après un instant) ; un soin, tout de suite.
func _sur_change_vie(pv: float, _max: float) -> void:
	if pv >= _pv_retard:
		_pv_retard = pv
	else:
		_retard_depuis = 0.0
	barre_vie.queue_redraw()


func _faire_fondre_le_retard(delta: float) -> void:
	if heros == null or _pv_retard <= heros.sante.pv:
		_pv_retard = heros.sante.pv if heros else 0.0
		return
	_retard_depuis += delta
	if _retard_depuis > 0.35:
		_pv_retard = move_toward(_pv_retard, heros.sante.pv, heros.sante.pv_max * 0.7 * delta)
	barre_vie.queue_redraw()


## Une jauge du jeu (vie du héros, du Bosco) : un fourreau de cuir sombre cerclé d'or vieilli, deux embouts de fer
## rivetés, le plein en deux tons (un reflet en haut), des crans tous les 10 % ; `retard` (si > plein) : la part
## qui vient d'être perdue, plus claire. Renvoie le rectangle intérieur.
static func dessiner_jauge(c: CanvasItem, r: Rect2, plein: float, retard: float, fonce: Color, clair: Color) -> Rect2:
	c.draw_rect(Rect2(r.position + Vector2(0, 3), r.size), Color(0, 0, 0, 0.35))
	c.draw_rect(r, Color(0.07, 0.045, 0.03, 0.92))
	var embout := 14.0
	var dedans := Rect2(r.position + Vector2(embout + 3, 5), r.size - Vector2(2 * embout + 6, 10))
	if retard > plein:
		c.draw_rect(Rect2(dedans.position, Vector2(dedans.size.x * retard, dedans.size.y)), Color(0.96, 0.8, 0.5, 0.85))
	if plein > 0.0:
		var p := Rect2(dedans.position, Vector2(dedans.size.x * plein, dedans.size.y))
		c.draw_rect(p, fonce)
		c.draw_rect(Rect2(p.position, Vector2(p.size.x, p.size.y * 0.45)), clair)
		c.draw_rect(Rect2(p.position, Vector2(p.size.x, 2)), Color(1, 0.85, 0.7, 0.35))
	for i in range(1, 10):
		var x := dedans.position.x + dedans.size.x * i / 10.0
		c.draw_line(Vector2(x, dedans.position.y), Vector2(x, dedans.end.y), Color(0.03, 0.01, 0.0, 0.45), 1.0)
	c.draw_rect(dedans.grow(1), Color("b08a42"), false, 2.0)
	for x0 in [r.position.x, r.end.x - embout]:   # embouts de fer rivetés
		c.draw_rect(Rect2(Vector2(x0, r.position.y), Vector2(embout, r.size.y)), Color(0.22, 0.21, 0.2))
		c.draw_rect(Rect2(Vector2(x0, r.position.y), Vector2(embout, 3)), Color(0.4, 0.38, 0.35))
		c.draw_circle(Vector2(x0 + embout / 2.0, r.position.y + r.size.y / 2.0), 3.2, Color(0.55, 0.52, 0.47))
	c.draw_rect(r, Color(0.03, 0.02, 0.01), false, 2.0)
	return dedans


static func police_grasse() -> Font:
	if _police_grasse == null:
		_police_grasse = load("res://assets/ui/polices/AlegreyaSans-Bold.ttf")
	return _police_grasse


static func police_titre() -> Font:
	if _police_titre == null:
		_police_titre = load("res://assets/ui/polices/IMFellEnglishSC-Regular.ttf")
	return _police_titre
