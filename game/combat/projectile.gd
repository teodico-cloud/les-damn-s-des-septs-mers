class_name Projectile
extends Node3D
## Projectile maudit de l'Occultiste : avance à hauteur de poitrine en s'incurvant vers sa cible (choisie au
## départ, devant lui), touche le premier ennemi rencontré (ou s'écrase sur un mur, un meuble) et y **explose** :
## l'explosion blesse aussi les squelettes tout autour (choix de Téo du 05/11). Au-delà de sa portée, il s'éteint.
## En coop, seul l'hôte compte les dégâts ; l'invité en voit l'image (le même vol : il choisit la même cible).

var tireur: Node3D
var direction := Vector3.FORWARD
var vitesse := 14.0
var portee := 9.0
var degats := 9.0
var rayon := 0.35
var cible: Node3D             ## vers qui il s'incurve (null : tout droit)
var guidage := 180.0          ## degrés par seconde
var explosion_rayon := 1.2
var explosion_degats := 9.0
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
	p.guidage = eq.occ_tir_guidage
	p.explosion_rayon = eq.occ_tir_explosion_rayon
	p.explosion_degats = eq.occ_tir_explosion_degats
	p.position = depart
	p.cible = cible_devant(monde, depart, p.direction, eq.occ_tir_portee, eq.occ_tir_guidage_angle)
	monde.add_child(p)
	EventBus.projectile_tire.emit(par, depart, p.direction, &"orbe")
	Sons.jouer(&"tir_maudit", depart)   # (chez l'invité aussi : il refait ce tir pour l'afficher)
	return p


## Le squelette visable le plus près de la direction du tir (dans un cône de ± `angle` degrés, à portée).
static func cible_devant(monde: Node, depart: Vector3, dir: Vector3, portee: float, angle: float) -> Node3D:
	if monde == null or not monde.is_inside_tree():
		return null
	var meilleur: Node3D = null
	var meilleur_score := INF
	for e in monde.get_tree().get_nodes_in_group("ennemis"):
		if not (e is Node3D and e.has_method("est_ciblable") and e.est_ciblable()):
			continue
		var vers := Combat.direction_plate(depart, e.global_position)
		var d := Vector2(e.global_position.x - depart.x, e.global_position.z - depart.z).length()
		if d > portee or vers == Vector3.ZERO:
			continue
		var a := rad_to_deg(dir.angle_to(vers))
		if a > angle:
			continue
		var score := a + d   # surtout l'angle, la distance départage (comme la visée du héros)
		if score < meilleur_score:
			meilleur_score = score
			meilleur = e
	return meilleur


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
	_virer(delta)
	var pas := vitesse * delta
	global_position += direction * pas
	_parcouru += pas
	var touche := _premier_obstacle()
	if touche != null:
		_exploser(touche)
	elif _parcouru >= portee:
		queue_free()


## S'incurve vers sa cible, de `guidage` degrés par seconde au plus (une cible tombée : tout droit).
func _virer(delta: float) -> void:
	if not (is_instance_valid(cible) and cible.has_method("est_ciblable") and cible.est_ciblable()):
		return
	var voulu := Combat.direction_plate(global_position, cible.global_position)
	if voulu == Vector3.ZERO:
		return
	var a := direction.signed_angle_to(voulu, Vector3.UP)
	var pas := deg_to_rad(guidage) * delta
	direction = direction.rotated(Vector3.UP, clampf(a, -pas, pas)).normalized()
	look_at(global_position + direction, Vector3.UP, true)


## Impact : la cible touchée prend le coup, les squelettes autour l'explosion (coups « discrets » : ni arrêt sur
## image ni secousse de plus). Chez l'invité, Combat ne compte rien : l'image seulement.
func _exploser(touche: Node3D) -> void:
	var qui: Node3D = tireur if is_instance_valid(tireur) else null
	var touches := 0
	if touche.has_method("recevoir_coup"):
		if Combat.porter_coup(qui, touche, degats, false) > 0.0:
			touches += 1
	for e in Combat.cibles_dans_sphere(get_world_3d(), global_position, explosion_rayon, Combat.COUCHE_ENNEMIS, [touche]):
		if e != touche and Combat.porter_coup_discret(qui, e, explosion_degats) > 0.0:
			touches += 1
	# jauge façon Diablo : le tir qui touche remplit les Âmes, et chaque voisin pris dans l'explosion aussi
	# (choix de Téo du 07/11), avec le même plafond par geste que le moulinet
	if qui is Heros:
		qui.jauge_coups(touches)
	EffetsMagie.explosion_maudite(get_parent(), global_position, explosion_rayon)
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
