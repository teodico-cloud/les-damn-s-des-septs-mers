class_name TonneauPoudre
extends StaticBody3D
## Tonneau de poudre (salle piège, choix de Téo) : un coup (sabre, projectile, carreau renvoyé,
## explosion voisine) allume la mèche ; il explose un instant après et blesse les squelettes autour
## (pas les héros). Il est sur la couche des ennemis pour être touché, mais pas dans le groupe des
## ennemis : la visée assistée l'ignore. En coop, l'hôte décide ; l'invité voit l'explosion.

const EQ: Equilibrage = preload("res://data/equilibrage.tres")

static var _mat_poudre: StandardMaterial3D

var explose := false
var _meche := -1.0
var _modele: Node3D
var _lueur: OmniLight3D


func _ready() -> void:
	collision_layer = Combat.COUCHE_ENNEMIS
	collision_mask = 0
	var forme := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.42
	cyl.height = 0.85
	forme.shape = cyl
	forme.position.y = 0.42
	add_child(forme)
	_modele = load("res://assets/models/decor/barrel_small.glb").instantiate()
	_modele.scale = Vector3.ONE * 0.85
	add_child(_modele)
	if _mat_poudre == null:
		var base: Material = load("res://assets/materials/kaykit_dungeon.tres")
		_mat_poudre = base.duplicate()
		_mat_poudre.albedo_color = Color(1.0, 0.55, 0.45)   # bois rougi : on le repère parmi les tonneaux du décor
	for m in _modele.find_children("*", "MeshInstance3D", true, false):
		m.material_override = _mat_poudre
	# une croix de poudre noire sur le dessus, et une mèche
	var meche := MeshInstance3D.new()
	var cyl_m := CylinderMesh.new()
	cyl_m.top_radius = 0.025
	cyl_m.bottom_radius = 0.025
	cyl_m.height = 0.25
	meche.mesh = cyl_m
	var mat_m := StandardMaterial3D.new()
	mat_m.albedo_color = Color(0.1, 0.08, 0.06)
	meche.material_override = mat_m
	meche.position = Vector3(0.12, 0.98, 0.0)
	meche.rotation_degrees.z = -20
	add_child(meche)
	_lueur = OmniLight3D.new()
	_lueur.light_color = Color(1.0, 0.5, 0.15)
	_lueur.omni_range = 5.0
	_lueur.light_energy = 0.0
	_lueur.position.y = 1.1
	add_child(_lueur)


## Un coup allume la mèche (rien d'affiché : ce n'est pas un ennemi).
func recevoir_coup(_degats: float, _source: Node3D, _lourd := false, _critique := false) -> float:
	if explose or _meche >= 0.0:
		return 0.0
	_meche = EQ.tonneau_meche
	return 0.0


func _physics_process(delta: float) -> void:
	if _meche < 0.0 or explose:
		return
	_meche -= delta
	_lueur.light_energy = 2.0 + 2.0 * sin(Time.get_ticks_msec() * 0.06)   # la mèche crépite
	if _meche <= 0.0:
		exploser(true)


## `actif` : blesse les squelettes autour (hôte ou seul) ; sinon l'image seulement (invité).
func exploser(actif: bool) -> void:
	if explose:
		return
	explose = true
	collision_layer = 0
	_modele.visible = false
	var centre := global_position + Vector3.UP * 0.5
	if actif:
		for c in Combat.cibles_dans_sphere(get_world_3d(), centre, EQ.tonneau_rayon, Combat.COUCHE_ENNEMIS, [self]):
			Combat.porter_coup(self, c, EQ.tonneau_degats, true)   # (les tonneaux voisins s'allument)
	var monde := get_parent()
	EffetsMagie.explosion(monde, centre)
	EventBus.explosion.emit(self)
	_lueur.light_energy = 6.0
	var t := create_tween()
	t.tween_property(_lueur, "light_energy", 0.0, 0.5)
	t.tween_interval(1.5)
	t.tween_callback(queue_free)
