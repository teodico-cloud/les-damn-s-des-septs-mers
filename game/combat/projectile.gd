class_name Projectile
extends Node3D
## Projectile maudit de l'Occultiste : avance en ligne droite à hauteur de poitrine, touche le premier
## ennemi rencontré (ou s'écrase sur un mur, un meuble) et disparaît au-delà de sa portée.
## En coop, seul l'hôte le fera avancer et toucher ; l'invité n'en verra que l'image.

var tireur: Node3D
var direction := Vector3.FORWARD
var vitesse := 14.0
var portee := 9.0
var degats := 9.0
var rayon := 0.35
var _parcouru := 0.0
var _requete := PhysicsShapeQueryParameters3D.new()

static var _boule: SphereMesh
static var _trainee: CapsuleMesh
static var _formes := {}   ## rayon -> SphereShape3D (une seule forme par taille, partagée)


## Crée et lance un projectile dans `monde` (le nœud parent des combattants).
static func tirer(monde: Node, par: Node3D, depart: Vector3, dir: Vector3, eq: Equilibrage) -> Projectile:
	var p := Projectile.new()
	p.tireur = par
	p.direction = Vector3(dir.x, 0, dir.z).normalized()
	p.vitesse = eq.occ_tir_vitesse
	p.portee = eq.occ_tir_portee
	p.degats = eq.occ_tir_degats
	p.rayon = eq.occ_tir_rayon
	p.position = depart
	monde.add_child(p)
	EventBus.projectile_tire.emit(par, depart, p.direction, &"orbe")
	return p


func _ready() -> void:
	if not _formes.has(rayon):
		var f := SphereShape3D.new()
		f.radius = rayon
		_formes[rayon] = f
	_requete.shape = _formes[rayon]
	_requete.collision_mask = Combat.COUCHE_ENNEMIS | Combat.COUCHE_MONDE
	if is_instance_valid(tireur) and tireur is CollisionObject3D:
		_requete.exclude = [(tireur as CollisionObject3D).get_rid()]
	if _boule == null:
		_boule = SphereMesh.new()
		_boule.radius = 0.16
		_boule.height = 0.32
		_boule.radial_segments = 12
		_boule.rings = 6
		_trainee = CapsuleMesh.new()
		_trainee.radius = 0.08
		_trainee.height = 0.8
		_trainee.radial_segments = 8
		_trainee.rings = 2
	var boule := MeshInstance3D.new()
	boule.mesh = _boule
	boule.material_override = EffetsMagie.mat_lueur()
	boule.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(boule)
	# traînée : capsule étirée derrière la boule
	var trainee := MeshInstance3D.new()
	trainee.mesh = _trainee
	trainee.material_override = EffetsMagie.mat_lueur()
	trainee.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	trainee.rotation = Vector3(PI / 2.0, 0, 0)   # couchée le long de l'axe z local
	trainee.position = Vector3(0, 0, -0.4)
	add_child(trainee)
	if direction.length() > 0.01:
		look_at(global_position + direction, Vector3.UP, true)   # l'axe z local suit la direction


func _physics_process(delta: float) -> void:
	var pas := vitesse * delta
	global_position += direction * pas
	_parcouru += pas
	var touche := _premier_obstacle()
	if touche != null:
		if touche.has_method("recevoir_coup"):
			Combat.porter_coup(tireur if is_instance_valid(tireur) else null, touche, degats, false)
		EffetsMagie.eclat(get_parent(), global_position)
		queue_free()
	elif _parcouru >= portee:
		queue_free()


## Premier ennemi (ou élément du décor) dans la zone du projectile ; null s'il n'y a rien.
func _premier_obstacle() -> Node3D:
	_requete.transform = Transform3D(Basis.IDENTITY, global_position)
	var obstacle: Node3D = null
	for hit in get_world_3d().direct_space_state.intersect_shape(_requete, 8):
		var c = hit.get("collider")
		if c is Node3D:
			if c.has_method("recevoir_coup"):
				return c   # un ennemi passe avant le décor
			obstacle = c
	return obstacle
