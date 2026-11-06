class_name Repaire
extends Node3D
## Le repaire (jalon 5, conception validée) : une grotte avec un quai où le navire est amarré. Le héros y
## marche au joystick ; quatre lieux s'ouvrent quand il s'en approche (bouton « Ouvrir »), ou d'un
## raccourci : la salle des cartes (héros, malédiction, départ), le chantier naval (les améliorations du
## bateau, étape 2), la forge (étape 3) et l'entrepôt (matériaux, coffres, équipement). Tout est construit par
## code. Une pastille « ! » signale un lieu où un achat est possible (annexe retenue par Téo).
##
## Plan (vu d'en haut, la caméra regarde depuis +x +z) : l'eau et le navire à gauche (x < -6,4), le quai
## en bois juste à côté, la salle des cartes au fond, la forge au fond à droite, l'entrepôt à droite.

const SCENE_MENU := "res://ui/screens/demarrage.tscn"
const SCENE_EQUIPEMENT := "res://ui/screens/equipement.tscn"
const DECOR := "res://assets/models/decor/"
const ECHELLE := 0.8
const PAS := 3.2
const RAYON_LIEU := 1.9          ## mètres : le bouton « Ouvrir » apparaît
const TORCHE := Color(1.0, 0.55, 0.2)
const VERT := Color(0.35, 1.0, 0.55)
## Les lieux : où se tenir pour les ouvrir, leur nom.
const LIEUX := {
	&"cartes": {"nom": "Salle des cartes", "pos": Vector3(-0.2, 0, -3.0)},
	&"chantier": {"nom": "Chantier naval", "pos": Vector3(-4.8, 0, -0.6)},
	&"forge": {"nom": "Forge", "pos": Vector3(4.6, 0, -3.0)},
	&"entrepot": {"nom": "Entrepôt", "pos": Vector3(6.4, 0, 2.4)},
}
const ORDRE_LIEUX: Array[StringName] = [&"cartes", &"chantier", &"forge", &"entrepot"]
## Limites où l'on marche (le reste : murs, eau).
const X_MIN := -6.3
const X_MAX := 9.4
const Z_MIN := -5.6
const Z_MAX := 6.0

var heros: Heros
var camera: CameraCombat
var hud: HudRepaire
var navire: Navire
var lieu_proche: StringName = &""
var changer_de_scene := true     ## faux dans les tests : le changement de scène est seulement noté
var scene_demandee := ""         ## (tests) la scène qu'on aurait ouverte
var _torches: Array[OmniLight3D] = []
var enseignes := {}               ## lieu -> Label3D (son nom)
var pastilles := {}               ## lieu -> Sprite3D (sceau de cire « ! » : un achat y est possible)
var _braises: OmniLight3D
var _temps := 0.0


func _ready() -> void:
	get_tree().set_quit_on_go_back(false)
	Engine.time_scale = 1.0
	_ambiance()
	Sons.ambiance([&"ressac", &"gouttes", &"torches"])   # (la grotte au bord de la mer)
	_construire()
	_poser_heros(Partie.heros_local, _arrivee(Partie.lieu_repaire))
	Partie.lieu_repaire = &""
	camera = CameraCombat.new()
	camera.distance = 14.5
	camera.cible = heros
	add_child(camera)
	camera.current = true
	hud = HudRepaire.new()
	hud.repaire = self
	add_child(hud)
	hud.ouvrir_demande.connect(ouvrir)
	hud.menu_demande.connect(retour_menu)
	mettre_a_jour_pastilles()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if hud and hud.panneau:
			hud.fermer_panneau()   # retour d'Android : ferme d'abord le lieu ouvert
		else:
			retour_menu()


func _process(delta: float) -> void:
	_temps += delta
	for i in _torches.size():
		_torches[i].light_energy = 2.2 + 0.35 * sin(_temps * 9.0 + i * 2.1) + 0.2 * sin(_temps * 23.0 + i)
	if _braises:
		_braises.light_energy = 2.6 + 0.6 * sin(_temps * 6.0) + 0.3 * sin(_temps * 17.0)
	_estomper_enseignes(delta)


## Refonte de l'interface (05/11) : une enseigne qui passe sous la bande du haut (Menu, plaque, bourse) ou sous
## les raccourcis de droite s'efface presque, pour ne pas brouiller l'interface.
func _estomper_enseignes(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var ecran := get_viewport().get_visible_rect().size
	for l in enseignes:
		var e: Label3D = enseignes[l]
		var p := cam.unproject_position(e.global_position)
		var cache := p.y < 110.0 or p.x > ecran.x - 300.0
		e.modulate.a = move_toward(e.modulate.a, 0.15 if cache else 1.0, delta * 3.0)


func _physics_process(_delta: float) -> void:
	if heros == null:
		return
	var proche: StringName = &""
	var meilleure := RAYON_LIEU
	for l in ORDRE_LIEUX:
		var d: Vector3 = heros.global_position - LIEUX[l]["pos"]
		d.y = 0.0
		if d.length() <= meilleure:
			meilleure = d.length()
			proche = l
	if proche != lieu_proche:
		lieu_proche = proche
		if hud:
			hud.montrer_lieu(proche)


# ---------------------------------------------------------------- lieux
## Ouvre un lieu (bouton « Ouvrir » ou raccourci).
func ouvrir(lieu: StringName) -> void:
	match lieu:
		&"cartes":
			var p := PanneauCartes.new()
			p.partir.connect(partir)
			p.heros_change.connect(changer_heros)
			hud.ouvrir_panneau(p)
		&"entrepot":
			var p := PanneauEntrepot.new()
			p.equipement_demande.connect(_ouvrir_equipement)
			p.agrandi.connect(mettre_a_jour_pastilles)
			hud.ouvrir_panneau(p)
		&"chantier":
			var p := PanneauChantier.new()
			p.achete.connect(_apres_achat)
			hud.ouvrir_panneau(p)
		&"forge":
			var p := PanneauForge.new()
			p.change.connect(_apres_forge)
			hud.ouvrir_panneau(p)


## Un passage à la forge : l'arme en main a pu changer (recyclée, améliorée), les pastilles aussi.
func _apres_forge() -> void:
	heros.equiper(Sauvegarde.equipes(heros.archetype))
	mettre_a_jour_pastilles()


## Un achat au chantier : le navire change d'aspect, les pastilles se mettent à jour.
func _apres_achat(_amelioration: String) -> void:
	navire.appliquer(Bateau.niveaux())
	mettre_a_jour_pastilles()


## Lieux où un achat est possible maintenant (pastille « ! » sur l'enseigne et le raccourci).
func lieux_a_signaler() -> Array:
	var r := []
	if Bateau.achat_possible():
		r.append(&"chantier")
	for i in [&"forge", &"entrepot"]:   # (seulement leur niveau 2 : sinon la pastille brillerait tout le temps)
		if Forge.agrandissement_possible(String(i)):
			r.append(i)
	return r


func mettre_a_jour_pastilles() -> void:
	var a_signaler := lieux_a_signaler()
	for l in pastilles:
		pastilles[l].visible = l in a_signaler
	if hud:
		for l in ORDRE_LIEUX:
			hud.marquer(l, l in a_signaler)


## Salle des cartes : on lève l'ancre (seul ; à deux, on passe par « Jouer à deux »).
func partir(archetype: StringName) -> void:
	Partie.revenir_en_solo()
	Partie.heros_local = archetype
	Partie.destination = &"expedition"
	_changer_de_scene(Partie.scene_destination())


## Salle des cartes : un autre héros choisi ; c'est lui qui marche dans le repaire.
func changer_heros(archetype: StringName) -> void:
	if heros and heros.archetype == archetype:
		return
	Partie.heros_local = archetype
	var pos := heros.global_position if heros else _arrivee(&"")
	var rot := heros.rotation.y if heros else 0.0
	if heros:
		heros.queue_free()
	_poser_heros(archetype, pos)
	heros.rotation.y = rot
	if camera:
		camera.cible = heros
	if hud:
		hud.heros = heros


func _ouvrir_equipement() -> void:
	Partie.lieu_repaire = &"entrepot"
	_changer_de_scene(SCENE_EQUIPEMENT)


func retour_menu() -> void:
	_changer_de_scene(SCENE_MENU)


func _changer_de_scene(chemin: String) -> void:
	scene_demandee = chemin
	if changer_de_scene and is_inside_tree():
		if hud:   # (refonte de l'interface : un fondu au noir avant de quitter le repaire)
			hud.fondu_puis(func(): get_tree().change_scene_to_file(chemin))
		else:
			get_tree().change_scene_to_file(chemin)


## Où le héros apparaît : au quai en revenant d'expédition, devant le lieu qu'on vient de quitter, sinon au milieu.
static func _arrivee(lieu: StringName) -> Vector3:
	if lieu == &"quai":
		return Vector3(-4.8, 0, 3.2)
	if LIEUX.has(lieu):
		return LIEUX[lieu]["pos"] + Vector3(0.6, 0, 1.3)
	return Vector3(1.6, 0, 1.4)


func _poser_heros(archetype: StringName, pos: Vector3) -> void:
	heros = Heros.creer(archetype)
	heros.equiper(Sauvegarde.equipes(archetype))   # (son arme en main)
	heros.name = "Heros"
	heros.position = pos
	add_child(heros)
	heros.rotation.y = PI * 0.25
	var appoint := OmniLight3D.new()   # éclaire le héros côté caméra, le suit
	appoint.light_color = Color(1.0, 0.8, 0.6)
	appoint.light_energy = 1.2
	appoint.omni_range = 8.0
	appoint.position = Vector3(1.6, 3.2, 1.6)
	heros.add_child(appoint)


# ---------------------------------------------------------------- construction
## Lumière façon Diablo IV (06/11, voir Ambiance).
func _ambiance() -> void:
	add_child(Ambiance.environnement())
	add_child(Ambiance.lune(0.25, 34.0))
	add_child(Ambiance.brume(Vector2(24.0, 16.0), Vector3(-0.5, 0, 0.2)))   # (le quai, la grotte et l'eau du port)


func _construire() -> void:
	# sol : 5 colonnes de dalles (la première est le quai, en bois), plus des rangées hors jeu côté caméra
	for ix in 6:
		for iz in 6:
			var p := Vector3(-4.8 + PAS * ix, 0, -4.8 + PAS * iz)
			var nom: String = "floor_wood_large" if ix == 0 else ["floor_tile_large", "floor_tile_large", "floor_dirt_large"][(ix * 7 + iz * 3) % 3]
			_objet(nom, p, 0)
	# l'eau du port, sous le quai et jusqu'au fond de la grotte
	var eau := MeshInstance3D.new()
	var plan := PlaneMesh.new()
	plan.size = Vector2(12.0, 30.0)
	plan.subdivide_width = 24
	plan.subdivide_depth = 60
	eau.mesh = plan
	var mat_eau := ShaderMaterial.new()
	mat_eau.shader = load("res://game/expedition/eau.gdshader")
	mat_eau.set_shader_parameter("houle", 0.15)
	eau.material_override = mat_eau
	eau.position = Vector3(-12.4, -0.45, 2.0)
	add_child(eau)
	navire = Navire.new()
	navire.name = "Navire"
	navire.position = Vector3(-9.6, -1.25, 0.4)
	navire.niveaux = Bateau.niveaux()
	add_child(navire)
	# murs du fond (aussi au-dessus de l'eau : le port est dans la grotte) et rochers
	for i in 9:
		var x := -14.4 + PAS * (i + 0.5)
		var nom := "wall"
		if x > -6.4 and x < -3.0:
			nom = "wall_scaffold"   # le chantier naval
		elif i % 3 == 1:
			nom = "wall_cracked"
		_objet(nom, Vector3(x, 0, -6.8), 0)
	var angle := 0.0
	for p in [Vector3(-14.0, -0.6, -4.0), Vector3(-14.6, -0.6, 1.5), Vector3(-13.8, -0.6, 6.0), Vector3(-6.7, -0.5, -6.0)]:
		_objet("rubble_large", p, angle)
		angle += 97.0
	# limites où l'on marche (le bord du quai : on ne tombe pas à l'eau)
	_obstacle(Vector3(1.6, -0.1, 0), Vector3(20.0, 0.2, 16.0))
	_obstacle(Vector3(1.6, 4, Z_MIN - 0.7), Vector3(20.0, 8, 0.4))
	_obstacle(Vector3(1.6, 4, Z_MAX + 0.6), Vector3(20.0, 8, 0.4))
	_obstacle(Vector3(X_MIN - 0.3, 4, 0), Vector3(0.4, 8, 16.0))
	_obstacle(Vector3(X_MAX + 0.5, 4, 0), Vector3(0.4, 8, 16.0))
	_salle_des_cartes()
	_chantier()
	_forge()
	_entrepot()
	# torches du mur du fond, et lueurs vertes sur l'eau
	var premiere := true
	for x in [-9.6, -1.6, 3.0, 8.0]:
		_objet("torch_mounted", Vector3(x, 1.8, -6.4), 0)
		var l := Ambiance.torche(Vector3(x, 2.35, -5.95), premiere)
		Ambiance.poussiere_torche(l, Vector3(l.position.x, 0, 0))   # (vers le quai, devant le mur du fond)
		premiere = false
		add_child(l)
		_torches.append(l)
	for p in [Vector3(-11.5, 1.2, -3.0), Vector3(-11.0, 1.2, 5.0)]:
		var l := OmniLight3D.new()
		l.position = p
		l.light_color = VERT
		l.light_energy = 0.8
		l.omni_range = 7.0
		add_child(l)
	for l in ORDRE_LIEUX:
		enseignes[l] = _enseigne(LIEUX[l]["nom"], LIEUX[l]["pos"] + _decalage_enseigne(l))
		var p := Sprite3D.new()   # (refonte : un sceau de cire « ! », comme sur les raccourcis)
		p.texture = load("res://assets/ui/matieres/sceau_marque.png")
		p.pixel_size = 0.0075
		p.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		p.no_depth_test = true
		p.position = LIEUX[l]["pos"] + _decalage_enseigne(l) + Vector3(0, 0.62, 0)
		add_child(p)
		p.name = "Pastille_" + String(l)
		p.visible = false
		pastilles[l] = p


func _decalage_enseigne(l: StringName) -> Vector3:
	match l:
		&"cartes": return Vector3(0, 2.7, -1.6)
		&"chantier": return Vector3(0, 2.7, -1.2)
		&"forge": return Vector3(0, 2.9, -1.4)
	return Vector3(1.2, 2.7, -0.4)


func _salle_des_cartes() -> void:
	var c: Vector3 = LIEUX[&"cartes"]["pos"]
	_objet("table_medium", c + Vector3(0, 0, -1.7), 0)
	_obstacle(c + Vector3(0, 0.5, -1.7), Vector3(2.3, 1.0, 1.4))
	_objet("chair", c + Vector3(-1.5, 0, -1.6), 80)
	_objet("banner_patternB_red", Vector3(c.x - 1.6, 0, -6.35), 0)
	_objet("banner_patternB_red", Vector3(c.x + 1.6, 0, -6.35), 0)
	_objet("shelf_large", Vector3(c.x + 2.4, 0, -6.0), 0)
	# la carte du Récif des Pendus, posée sur la table
	var carte := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(1.1, 0.01, 0.75)
	carte.mesh = b
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.82, 0.72, 0.5)
	m.emission_enabled = true
	m.emission = Color(0.4, 0.33, 0.2)
	m.emission_energy_multiplier = 0.3
	carte.material_override = m
	carte.position = c + Vector3(0.1, 0.83, -1.65)
	carte.rotation_degrees.y = 8.0
	add_child(carte)


func _chantier() -> void:
	var c: Vector3 = LIEUX[&"chantier"]["pos"]
	_objet("crates_stacked", c + Vector3(1.6, 0, -3.6), 0)
	_obstacle(c + Vector3(1.6, 0.9, -3.6), Vector3(1.6, 1.8, 1.6))
	_objet("barrel_large", c + Vector3(-0.9, 0, -4.4), 0)
	_obstacle(c + Vector3(-0.9, 0.6, -4.4), Vector3(1.0, 1.2, 1.0))
	_objet("box_large", c + Vector3(0.9, 0, -1.9), 15)
	_obstacle(c + Vector3(0.9, 0.5, -1.9), Vector3(1.1, 1.0, 1.1))
	# planches de bois de coque empilées
	var tas := Node3D.new()
	tas.position = c + Vector3(1.0, 0, 1.6)
	add_child(tas)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("7a4e2c")
	mat.roughness = 0.85
	for i in 5:
		var pl := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.36, 0.09, 2.2)
		pl.mesh = bm
		pl.material_override = mat
		pl.position = Vector3((i % 3 - 1) * 0.38, 0.05 + 0.1 * (i / 3), 0)
		tas.add_child(pl)
	_obstacle(c + Vector3(1.0, 0.2, 1.6), Vector3(1.2, 0.4, 2.3))


func _forge() -> void:
	var c: Vector3 = LIEUX[&"forge"]["pos"]
	# le foyer : un bloc de pierre et ses braises
	var foyer := Node3D.new()
	foyer.position = c + Vector3(0.4, 0, -2.2)
	add_child(foyer)
	var pierre := MeshInstance3D.new()
	var bp := BoxMesh.new()
	bp.size = Vector3(1.8, 0.9, 1.1)
	pierre.mesh = bp
	var mp := StandardMaterial3D.new()
	mp.albedo_color = Color(0.25, 0.24, 0.26)
	mp.roughness = 0.95
	pierre.material_override = mp
	Matieres.habiller(pierre, "wall")   # (pierre taillée, façon Diablo IV)
	pierre.position.y = 0.45
	foyer.add_child(pierre)
	var braises := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(1.4, 0.06, 0.75)
	braises.mesh = bb
	var mb := StandardMaterial3D.new()
	mb.albedo_color = Color(0.2, 0.05, 0.02)   # (des braises sombres qui rougeoient : avec la lumière façon Diablo IV,
	mb.emission_enabled = true                 #  un orange vif sous la lueur du foyer virait au blanc)
	mb.emission = Color(1.0, 0.22, 0.03)
	mb.emission_energy_multiplier = 0.55
	braises.material_override = mb
	braises.position.y = 0.92
	foyer.add_child(braises)
	_braises = OmniLight3D.new()
	_braises.light_color = Color(1.0, 0.45, 0.15)
	_braises.light_energy = 2.6
	_braises.omni_range = 6.0
	_braises.position = Vector3(0, 1.6, 0.4)
	foyer.add_child(_braises)
	_obstacle(c + Vector3(0.4, 0.5, -2.2), Vector3(1.9, 1.0, 1.2))
	# l'enclume
	var enclume := Node3D.new()
	enclume.position = c + Vector3(-1.4, 0, -1.4)
	add_child(enclume)
	var me := StandardMaterial3D.new()
	me.albedo_color = Color("3a3f48")
	me.metallic = 0.7
	me.roughness = 0.4
	for piece in [[Vector3(0, 0.25, 0), Vector3(0.35, 0.5, 0.35)], [Vector3(0, 0.6, 0), Vector3(0.75, 0.22, 0.32)],
			[Vector3(0.45, 0.62, 0), Vector3(0.25, 0.12, 0.2)]]:
		var m := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = piece[1]
		m.mesh = b
		m.material_override = me
		m.position = piece[0]
		enclume.add_child(m)
	_obstacle(c + Vector3(-1.4, 0.4, -1.4), Vector3(0.8, 0.8, 0.5))
	_objet("sword_shield", Vector3(c.x + 1.8, 1.2, -6.3), 0)
	_objet("barrel_small", c + Vector3(1.9, 0, -0.9), 0)
	_obstacle(c + Vector3(1.9, 0.4, -0.9), Vector3(0.8, 0.8, 0.8))


func _entrepot() -> void:
	var c: Vector3 = LIEUX[&"entrepot"]["pos"]
	_objet("chest_gold", c + Vector3(1.8, 0, -0.6), -90)
	_objet("trunk_large_A", c + Vector3(1.9, 0, 0.9), -90)
	_objet("trunk_large_B", c + Vector3(0.6, 0, 2.6), 180)
	_obstacle(c + Vector3(1.9, 0.5, 0.1), Vector3(1.3, 1.0, 3.2))
	_obstacle(c + Vector3(0.6, 0.5, 2.6), Vector3(1.6, 1.0, 1.0))
	_objet("crates_stacked", c + Vector3(2.0, 0, -2.6), 0)
	_obstacle(c + Vector3(2.0, 0.9, -2.6), Vector3(1.6, 1.8, 1.6))
	_objet("barrel_small_stack", c + Vector3(-0.8, 0, -3.6), 0)
	_obstacle(c + Vector3(-0.8, 0.7, -3.6), Vector3(1.4, 1.4, 0.8))
	_objet("box_stacked", c + Vector3(-1.4, 0, 2.8), 20)
	_obstacle(c + Vector3(-1.4, 0.6, 2.8), Vector3(1.2, 1.2, 1.2))


## Le nom d'un lieu, en lettres d'or au-dessus de lui.
func _enseigne(texte: String, pos: Vector3) -> Label3D:
	var l := Label3D.new()
	l.text = texte
	l.font = load("res://assets/ui/polices/IMFellEnglishSC-Regular.ttf")   # (la police des titres)
	l.font_size = 54
	l.outline_size = 14
	l.outline_modulate = Color(0.06, 0.04, 0.02)
	l.pixel_size = 0.006
	l.modulate = Color("deba70")
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = pos
	add_child(l)
	return l


func _objet(nom: String, pos: Vector3, rot_y: float) -> Node3D:
	var n: Node3D = load(DECOR + nom + ".glb").instantiate()
	Matieres.habiller(n, nom)   # (textures réalistes, façon Diablo IV)
	n.position = pos
	n.rotation_degrees.y = rot_y
	n.scale = Vector3.ONE * ECHELLE
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
