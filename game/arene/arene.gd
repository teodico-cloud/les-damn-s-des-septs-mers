class_name Arene
extends Node3D
## Arène d'entraînement : le héros choisi contre des Matelots squelettes qui reviennent sans fin,
## dans une salle de forteresse. Construit tout par code : salle, héros, ennemis, caméra, effets,
## interface. En coop (jalon 2) : deux héros ; l'hôte fait tourner le combat, l'invité l'affiche
## (voir SynchroArene). Chacun voit un anneau doré sous son héros, vert sous celui du partenaire.
## Les squelettes vaincus lâchent parfois une orbe de vie (jalon 3, façon Diablo).
## L'expédition (Expedition) hérite de cette scène et remplace le lieu, le départ et la horde.

const SCENE_MENU := "res://ui/screens/demarrage.tscn"
const DECOR := "res://assets/models/decor/"
const ECHELLE_DECOR := 0.8   ## les meubles KayKit paraissaient trop grands à côté des héros allongés
const DEMI_COTE := 6.4       ## la salle va de -6,4 à +6,4 m
const EQ: Equilibrage = preload("res://data/equilibrage.tres")

var heros: Heros               ## le héros de ce téléphone
var heros_partenaire: Heros    ## coop : celui de l'autre téléphone
var synchro: SynchroArene
var regles: ReglesCoop         ## coop, hôte : réanimation et retour au départ
var camera: CameraCombat
var effets: EffetsCombat
var generateur: GenerateurEnnemis
var hud: HudCombat
var torches: Array[OmniLight3D] = []
var orbes: Node3D                ## orbes de vie au sol (« Orbe_3 » : même nom des deux côtés en coop)
var _compteur_orbes := 0
var orbes_ramassees := 0
var _temps := 0.0
## Tests : chance qu'un squelette lâche une orbe (-1 : celle de l'équilibrage).
static var chance_orbe := -1.0


func _ready() -> void:
	get_tree().set_quit_on_go_back(false)
	_ambiance()
	_construire_lieu()
	var coop := Reseau.est_en_coop()
	var hote := Reseau.est_hote()
	heros = Heros.creer(Partie.heros_local)
	heros.name = "HerosInvite" if coop and not hote else "HerosHote"
	heros.position = _depart_heros(heros.name, coop)
	add_child(heros)
	heros.rotation.y = PI * 0.25
	if coop:
		heros_partenaire = Heros.creer(Reseau.heros_partenaire)
		heros_partenaire.name = "HerosHote" if heros.name == "HerosInvite" else "HerosInvite"
		heros_partenaire.position = _depart_heros(heros_partenaire.name, coop)
		heros_partenaire.marionnette = not hote   # chez l'invité, le héros de l'hôte est affiché, pas simulé
		add_child(heros_partenaire)
		heros_partenaire.rotation.y = PI * 0.25
		heros.ajouter_anneau(Color("e0b04a"))
		heros_partenaire.ajouter_anneau(Color("5fe08a"))
		heros.reapparition_auto = hote            # l'invité attend l'ordre de l'hôte

	camera = CameraCombat.new()
	camera.cible = heros
	add_child(camera)
	camera.current = true

	var appoint := OmniLight3D.new()   # éclaire le héros côté caméra, le suit
	appoint.light_color = Color(1.0, 0.8, 0.6)
	appoint.light_energy = 1.3
	appoint.omni_range = 8.0
	appoint.position = Vector3(1.6, 3.2, 1.6)
	heros.add_child(appoint)

	effets = EffetsCombat.new()
	effets.camera = camera
	effets.en_coop = coop
	effets.heros_local = heros
	add_child(effets)

	orbes = Node3D.new()
	orbes.name = "Orbes"
	add_child(orbes)

	generateur = GenerateurEnnemis.new()
	generateur.name = "Ennemis"
	generateur.demi_cote = DEMI_COTE - 1.4
	_configurer_generateur(coop, hote)
	add_child(generateur)
	if not coop or hote:   # chez l'invité, l'hôte décide des orbes
		EventBus.ennemi_vaincu.connect(_on_ennemi_vaincu)

	if coop and hote:
		regles = ReglesCoop.new()
		regles.name = "Regles"
		regles.configurer(heros, heros_partenaire, generateur)
		add_child(regles)
	if coop:
		synchro = SynchroArene.new()
		synchro.name = "Synchro"
		synchro.configurer(self, heros, heros_partenaire, generateur)
		add_child(synchro)
		synchro.connexion_instable.connect(func(oui: bool):
			hud.alerte("Connexion instable… (vérifie le Wi-Fi des deux téléphones)" if oui else ""))
		Reseau.partenaire_parti.connect(_on_partenaire_parti)

	hud = HudCombat.new()
	hud.heros = heros
	hud.heros_partenaire = heros_partenaire
	hud.regles = regles
	hud.camera = camera
	hud.menu_demande.connect(retour_menu)
	add_child(hud)
	_pret()


# ---------------------------------------------------------------- étapes (remplacées par l'expédition)
func _construire_lieu() -> void:
	_salle()


func _depart_heros(nom: StringName, coop: bool) -> Vector3:
	return _depart(nom) if coop else Vector3(0, 0, 1.5)


func _configurer_generateur(coop: bool, hote: bool) -> void:
	if coop:
		generateur.nombre = EQ.arene_nb_ennemis_coop if hote else 0   # chez l'invité : marionnettes seulement
		generateur.demarrage_auto = false   # l'hôte attend que l'arène de l'invité soit ouverte
	else:
		generateur.nombre = EQ.arene_nb_ennemis


## Tout est en place (héros, horde, interface).
func _pret() -> void:
	pass


## Coop : l'arène de l'invité est ouverte (appelé par SynchroArene chez l'hôte).
func invite_pret() -> void:
	generateur.demarrer()   # les squelettes sortent de terre quand les deux joueurs sont là


# ---------------------------------------------------------------- orbes de vie (choix de Téo)
func _on_ennemi_vaincu(e: Node) -> void:
	var chance := chance_orbe if chance_orbe >= 0.0 else EQ.orbe_chance * Malediction.mult_orbes()
	if not (e is Node3D) or randf() >= chance:
		return
	_compteur_orbes += 1
	var nom := "Orbe_%d" % _compteur_orbes
	var pos: Vector3 = (e as Node3D).global_position
	poser_orbe(nom, pos)
	if synchro:
		synchro.envoyer_orbe(nom, pos, "")


func poser_orbe(nom: String, pos: Vector3) -> void:
	if orbes.get_node_or_null(NodePath(nom)):
		return
	var o := OrbeVie.creer()
	o.name = nom
	o.position = Vector3(pos.x, 0.0, pos.z)
	orbes.add_child(o)


## L'hôte (ou le joueur seul) : un héros blessé qui passe sur une orbe la ramasse.
func _ramasser_orbes() -> void:
	for o in orbes.get_children():
		if not (o is OrbeVie) or o.prise:
			continue
		for h in [heros, heros_partenaire]:
			if h == null or not is_instance_valid(h) or not h.est_vivant() or h.sante.pv >= h.sante.pv_max:
				continue
			var d: Vector3 = h.global_position - o.global_position
			d.y = 0.0
			if d.length() <= EQ.orbe_rayon:
				var soin: float = h.sante.soigner(h.sante.pv_max * EQ.orbe_soin)
				o.prendre()
				orbes_ramassees += 1
				EventBus.soin.emit(h, soin)
				if synchro:
					synchro.envoyer_orbe(o.name, o.global_position, String(h.name))
				break


## Coop, invité : l'hôte a posé une orbe (`prise_par` vide) ou quelqu'un l'a ramassée.
func orbe_recue(nom: String, pos: Vector3, prise_par: String) -> void:
	if prise_par == "":
		poser_orbe(nom, pos)
		return
	var o := orbes.get_node_or_null(NodePath(nom)) as OrbeVie
	if o:
		o.prendre()


func _physics_process(_delta: float) -> void:
	if not Reseau.est_invite():
		_ramasser_orbes()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		retour_menu()


func retour_menu() -> void:
	if not is_inside_tree():
		return
	Engine.time_scale = 1.0
	Reseau.quitter()
	Partie.revenir_en_solo()
	get_tree().change_scene_to_file(SCENE_MENU)


static func _depart(nom: StringName) -> Vector3:
	return Vector3(-1.2, 0, 1.5) if nom == &"HerosHote" else Vector3(1.2, 0, 1.5)


## Le partenaire a quitté la partie : l'hôte continue seul ; l'invité revient au menu.
func _on_partenaire_parti(raison: String) -> void:
	if not is_inside_tree():
		return
	if heros.name == "HerosHote":
		if is_instance_valid(heros_partenaire):
			heros_partenaire.queue_free()
		if synchro:
			synchro.queue_free()
			synchro = null
		if regles:
			regles.queue_free()
			regles = null
		hud.heros_partenaire = null
		hud.regles = null
		effets.en_coop = false
		_continuer_seul()
		hud.afficher_message(raison + "\nTu continues seul.", 4.0)
		Reseau.quitter()
		Partie.revenir_en_solo()
	else:
		hud.afficher_message(raison + "\nRetour au menu…", 3.0)
		get_tree().create_timer(3.0).timeout.connect(retour_menu)


## L'hôte continue seul après le départ de l'invité.
func _continuer_seul() -> void:
	heros.reapparition_auto = true   # seul : il réapparaît de nouveau tout seul
	generateur.nombre = EQ.arene_nb_ennemis   # seul : la horde de l'arène en solo (les suivants ne sont plus remplacés)
	generateur.demarrer()


func _process(delta: float) -> void:
	_temps += delta
	for i in torches.size():
		torches[i].light_energy = 2.2 + 0.35 * sin(_temps * 9.0 + i * 2.1) + 0.2 * sin(_temps * 23.0 + i)


# ---------------------------------------------------------------- décor
func _ambiance() -> void:
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.02, 0.03, 0.05)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.3, 0.4, 0.55)
	e.ambient_light_energy = 0.45
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.fog_enabled = true
	e.fog_light_color = Color(0.05, 0.08, 0.11)
	e.fog_density = 0.012
	e.glow_enabled = true
	e.glow_intensity = 0.9
	e.glow_bloom = 0.08
	we.environment = e
	add_child(we)
	var lune := DirectionalLight3D.new()
	lune.rotation_degrees = Vector3(-55, -30, 0)
	lune.light_color = Color(0.55, 0.65, 1.0)
	lune.light_energy = 0.4
	lune.shadow_enabled = true
	lune.directional_shadow_max_distance = 30.0
	add_child(lune)


func _objet(nom: String, pos: Vector3, rot_y := 0.0) -> Node3D:
	var n: Node3D = load(DECOR + nom + ".glb").instantiate()
	n.position = pos
	n.rotation_degrees.y = rot_y
	n.scale = Vector3.ONE * ECHELLE_DECOR
	add_child(n)
	return n


func _obstacle(centre: Vector3, taille: Vector3) -> void:
	var corps := StaticBody3D.new()
	corps.collision_layer = Combat.COUCHE_MONDE
	corps.collision_mask = 0
	var forme := CollisionShape3D.new()
	var boite := BoxShape3D.new()
	boite.size = taille
	forme.shape = boite
	corps.position = centre
	corps.add_child(forme)
	add_child(corps)


func _salle() -> void:
	var pas := 4.0 * ECHELLE_DECOR
	var dalles := ["floor_tile_large", "floor_tile_large_rocks"]
	# 4 × 4 dalles de jeu, plus 2 rangées hors jeu côté caméra pour ne pas voir le vide
	for ix in 6:
		for iz in 6:
			var x := -DEMI_COTE + pas * (ix + 0.5)
			var z := -DEMI_COTE + pas * (iz + 0.5)
			_objet(dalles[(ix * 7 + iz * 3) & 1], Vector3(x, 0, z))
	for i in 4:
		var c := -DEMI_COTE + pas * (i + 0.5)
		_objet("wall_arched" if i == 1 else "wall", Vector3(c, 0, -DEMI_COTE - 0.4))
		_objet("wall", Vector3(-DEMI_COTE - 0.4, 0, c), 90)
	_objet("pillar", Vector3(-DEMI_COTE - 0.2, 0, -DEMI_COTE - 0.2))

	# sol et limites de la salle (les côtés vers la caméra n'ont pas de mur visible)
	_obstacle(Vector3(0, -0.1, 0), Vector3(DEMI_COTE * 2 + 2, 0.2, DEMI_COTE * 2 + 2))
	# (hauts de 8 m : les os projetés ne passent pas par-dessus)
	_obstacle(Vector3(0, 4, -DEMI_COTE - 0.2), Vector3(DEMI_COTE * 2 + 2, 8, 0.4))
	_obstacle(Vector3(0, 4, DEMI_COTE + 0.2), Vector3(DEMI_COTE * 2 + 2, 8, 0.4))
	_obstacle(Vector3(-DEMI_COTE - 0.2, 4, 0), Vector3(0.4, 8, DEMI_COTE * 2 + 2))
	_obstacle(Vector3(DEMI_COTE + 0.2, 4, 0), Vector3(0.4, 8, DEMI_COTE * 2 + 2))

	# meubles dans les coins du fond, avec leur volume
	_objet("barrel_large", Vector3(-5.3, 0, -5.3))
	_obstacle(Vector3(-5.3, 0.8, -5.3), Vector3(1.4, 1.6, 1.4))
	_objet("crates_stacked", Vector3(5.1, 0, -5.2), 20)
	_obstacle(Vector3(5.1, 0.9, -5.2), Vector3(1.8, 1.8, 1.8))
	_objet("keg_decorated", Vector3(3.2, 0, -5.6))
	_obstacle(Vector3(3.2, 0.7, -5.6), Vector3(1.2, 1.4, 1.0))
	_objet("chest_gold", Vector3(-5.6, 0, 1.2), 90)
	_obstacle(Vector3(-5.6, 0.6, 1.2), Vector3(1.3, 1.2, 1.5))
	_objet("coin_stack_large", Vector3(-5.5, 0, 2.6))

	# torches du mur du fond et du mur de gauche
	for p in [Vector3(-2.4, 1.8, -DEMI_COTE), Vector3(2.4, 1.8, -DEMI_COTE)]:
		_objet("torch_mounted", p)
		_torche(p + Vector3(0, 0.55, 0.45), torches.is_empty())
	_objet("torch_mounted", Vector3(-DEMI_COTE, 1.8, -2.0), 90)
	_torche(Vector3(-DEMI_COTE + 0.45, 2.35, -2.0), false)

	var tresor := OmniLight3D.new()   # lueur maudite du coffre
	tresor.position = Vector3(-5.0, 1.2, 1.6)
	tresor.light_color = Color(0.3, 1.0, 0.55)
	tresor.light_energy = 1.6
	tresor.omni_range = 4.0
	add_child(tresor)


func _torche(pos: Vector3, ombre: bool) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = Color(1.0, 0.55, 0.2)
	l.light_energy = 2.4
	l.omni_range = 8.0
	l.shadow_enabled = ombre
	l.omni_shadow_mode = OmniLight3D.SHADOW_DUAL_PARABOLOID
	add_child(l)
	torches.append(l)
