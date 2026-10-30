class_name Carreau
extends Node3D
## Carreau d'arbalète (jalon 3) : file en ligne droite à hauteur de poitrine. Un héros en roulade ou
## téléporté le laisse passer ; un Bretteur qui pare de face le renvoie vers les squelettes (choix
## de Téo) ; sinon il blesse. Renvoyé, il ne touche plus que les ennemis (et les tonneaux).
## En coop, seul l'hôte le fait toucher ; l'invité n'en voit que l'image (marionnette).

const EQ: Equilibrage = preload("res://data/equilibrage.tres")

static var _forme: SphereShape3D
static var _tige: CylinderMesh
static var _pointe: CylinderMesh
static var _mat_bois: StandardMaterial3D
static var _mat_fer: StandardMaterial3D
static var _mat_trainee_rouge: StandardMaterial3D
static var _mat_trainee_or: StandardMaterial3D

var tireur: Node3D               ## l'arbalétrier (ou le héros qui l'a renvoyé)
var direction := Vector3.FORWARD
var renvoye := false
var parfait := false             ## renvoyé par une parade parfaite : coup critique
var marionnette := false
var _parcouru := 0.0
var _ignores: Array[RID] = []    ## héros qui l'ont esquivé (il passe à travers)
var _requete := PhysicsShapeQueryParameters3D.new()
var _trainee: MeshInstance3D


## Lance un carreau dans `monde` ; prévient le réseau (EventBus.projectile_tire).
static func tirer(monde: Node, par: Node3D, depart: Vector3, dir: Vector3, p_renvoye := false) -> Carreau:
	var c := Carreau.new()
	c.tireur = par
	c.direction = Vector3(dir.x, 0, dir.z).normalized()
	c.renvoye = p_renvoye
	c.position = depart
	monde.add_child(c)
	EventBus.projectile_tire.emit(par, depart, c.direction, &"carreau_renvoye" if p_renvoye else &"carreau")
	return c


## Coop, invité : seulement l'image (l'hôte décide de ce qu'il touche).
static func image(monde: Node, par: Node3D, depart: Vector3, dir: Vector3, p_renvoye: bool) -> Carreau:
	var c := Carreau.new()
	c.marionnette = true
	c.tireur = par
	c.direction = Vector3(dir.x, 0, dir.z).normalized()
	c.renvoye = p_renvoye
	c.position = depart
	monde.add_child(c)
	return c


func _ready() -> void:
	if _forme == null:
		_forme = SphereShape3D.new()
		_forme.radius = 0.3
		_tige = CylinderMesh.new()
		_tige.top_radius = 0.045   # gros pour un carreau : il doit se lire de loin sur un téléphone
		_tige.bottom_radius = 0.045
		_tige.height = 0.8
		_tige.radial_segments = 6
		_tige.rings = 1
		_pointe = CylinderMesh.new()
		_pointe.top_radius = 0.0
		_pointe.bottom_radius = 0.09
		_pointe.height = 0.2
		_pointe.radial_segments = 6
		_pointe.rings = 1
		_mat_bois = StandardMaterial3D.new()
		_mat_bois.albedo_color = Color(0.35, 0.22, 0.12)
		_mat_fer = StandardMaterial3D.new()
		_mat_fer.albedo_color = Color(0.6, 0.6, 0.65)
		_mat_fer.metallic = 0.8
		_mat_trainee_rouge = StandardMaterial3D.new()
		_mat_trainee_rouge.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat_trainee_rouge.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat_trainee_rouge.albedo_color = Color(1.0, 0.22, 0.12, 0.75)
		_mat_trainee_or = _mat_trainee_rouge.duplicate()
		_mat_trainee_or.albedo_color = Color(1.0, 0.8, 0.25, 0.85)
	_requete.shape = _forme
	_ajuster_masque()
	# la tige est couchée le long de l'axe z local, la pointe devant
	var tige := MeshInstance3D.new()
	tige.mesh = _tige
	tige.material_override = _mat_bois
	tige.rotation.x = PI / 2.0
	add_child(tige)
	var pointe := MeshInstance3D.new()
	pointe.mesh = _pointe
	pointe.material_override = _mat_fer
	pointe.rotation.x = PI / 2.0
	pointe.position.z = 0.5
	add_child(pointe)
	_trainee = MeshInstance3D.new()
	var t := BoxMesh.new()
	t.size = Vector3(0.12, 0.12, 1.6)
	_trainee.mesh = t
	_trainee.position.z = -1.15
	_trainee.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_trainee)
	_maj_image()


func _ajuster_masque() -> void:
	_requete.collision_mask = Combat.COUCHE_MONDE | (Combat.COUCHE_ENNEMIS if renvoye else Combat.COUCHE_HEROS)
	_requete.exclude = _ignores.duplicate()
	if is_instance_valid(tireur) and tireur is CollisionObject3D:
		_requete.exclude.append((tireur as CollisionObject3D).get_rid())


func _maj_image() -> void:
	_trainee.material_override = _mat_trainee_or if renvoye else _mat_trainee_rouge
	if direction.length() > 0.01 and is_inside_tree():
		look_at(global_position + direction, Vector3.UP, true)


func _physics_process(delta: float) -> void:
	var pas := EQ.carreau_vitesse * delta
	global_position += direction * pas
	_parcouru += pas
	if _parcouru >= EQ.carreau_portee:
		queue_free()
		return
	var touche := _premier_obstacle()
	if touche == null:
		return
	if touche is Heros and not renvoye:
		_toucher_heros(touche)
	elif touche.has_method("recevoir_coup") and renvoye:
		if not marionnette:
			Combat.porter_coup(tireur if is_instance_valid(tireur) else null, touche, EQ.carreau_renvoi_degats, true, parfait)
		EffetsMagie.eclat(get_parent(), global_position)
		queue_free()
	else:
		EffetsMagie.eclat(get_parent(), global_position)   # un mur, un meuble
		queue_free()


func _toucher_heros(h: Heros) -> void:
	if marionnette:
		queue_free()   # chez l'invité : l'hôte dira s'il a été renvoyé (un nouveau carreau partira)
		return
	if h.sante.est_invulnerable() or not h.est_vivant():
		_ignores.append(h.get_rid())   # roulade, téléportation : il passe à travers
		_ajuster_masque()
		return
	if h.has_method("renvoyer_carreau") and h.renvoyer_carreau(self):
		return   # renvoyé par la Parade : il repart (voir renvoyer)
	Combat.porter_coup(self, h, EQ.carreau_degats, false)
	queue_free()


## Parade du Bretteur : le carreau repart vers son tireur, devient doré et ne touche plus que les
## ennemis. Un nouveau carreau part pour l'invité (le sien s'est arrêté sur le héros).
func renvoyer(par: Node3D, p_parfait: bool) -> void:
	var cible := tireur
	var dir := -direction
	if is_instance_valid(cible):
		dir = Combat.direction_plate(global_position, cible.global_position)
	queue_free()
	var c := Carreau.tirer(get_parent(), par, global_position, dir, true)
	c.parfait = p_parfait


## Premier héros, ennemi ou élément du décor dans la zone du carreau ; null s'il n'y a rien.
func _premier_obstacle() -> Node3D:
	_requete.transform = Transform3D(Basis.IDENTITY, global_position)
	var obstacle: Node3D = null
	for hit in get_world_3d().direct_space_state.intersect_shape(_requete, 8):
		var c = hit.get("collider")
		if c is Node3D:
			if c is Heros or c.has_method("recevoir_coup"):
				return c   # un combattant passe avant le décor
			obstacle = c
	return obstacle
