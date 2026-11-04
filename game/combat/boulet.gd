class_name Boulet
extends Node3D
## Un boulet de la bordée du navire (jalon 5, choix de Téo : visée au joystick). Après `delai`, un cercle
## rouge se remplit au sol pendant `bordee_annonce` ; le boulet tombe du ciel dans la dernière part,
## explose, et blesse les squelettes autour (le Bosco : moitié moins). Les héros sont épargnés.
## `lanceur` : le héros qui a tiré (l'hôte compte les dégâts) ; null : l'image seulement (chez l'invité).

const EQ: Equilibrage = preload("res://data/equilibrage.tres")
const ROUGE := Color(1.0, 0.25, 0.15)
const CHUTE := 0.35          ## secondes : le boulet tombe pendant la fin de l'annonce
const HAUTEUR := 11.0

static var _ressources := {}

var lanceur: Node3D
var delai := 0.0
var _t := 0.0
var _zone: MeshInstance3D
var _remplissage: MeshInstance3D
var _boule: MeshInstance3D
var _parti := false
var _explose := false


static func creer(monde: Node, point: Vector3, p_lanceur: Node3D, p_delai: float) -> Boulet:
	var b := Boulet.new()
	b.lanceur = p_lanceur
	b.delai = p_delai
	b.position = Vector3(point.x, 0.0, point.z)
	if monde and monde.is_inside_tree():
		monde.add_child(b)
	return b


func _ready() -> void:
	add_to_group("boulets")
	if not _ressources.has("disque"):
		var d := CylinderMesh.new()
		d.top_radius = EQ.bordee_rayon
		d.bottom_radius = EQ.bordee_rayon
		d.height = 0.02
		d.radial_segments = 28
		d.rings = 1
		_ressources["disque"] = d
		for nom in ["mat_zone", "mat_plein"]:
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color = Color(ROUGE, 0.3 if nom == "mat_zone" else 0.65)
			_ressources[nom] = m
		var s := SphereMesh.new()
		s.radius = 0.32
		s.height = 0.64
		s.radial_segments = 12
		s.rings = 6
		_ressources["boule"] = s
		var mb := StandardMaterial3D.new()
		mb.albedo_color = Color(0.08, 0.08, 0.09)
		mb.metallic = 0.6
		mb.roughness = 0.4
		_ressources["mat_boule"] = mb
	_zone = MeshInstance3D.new()
	_zone.mesh = _ressources["disque"]
	_zone.material_override = _ressources["mat_zone"]
	_zone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_zone.position.y = 0.06
	_zone.visible = false
	add_child(_zone)
	_remplissage = MeshInstance3D.new()
	_remplissage.mesh = _ressources["disque"]
	_remplissage.material_override = _ressources["mat_plein"]
	_remplissage.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_remplissage.position.y = 0.07
	_remplissage.scale = Vector3(0.01, 1, 0.01)
	_remplissage.visible = false
	add_child(_remplissage)
	_boule = MeshInstance3D.new()
	_boule.mesh = _ressources["boule"]
	_boule.material_override = _ressources["mat_boule"]
	_boule.visible = false
	add_child(_boule)


func _physics_process(delta: float) -> void:
	_t += delta
	if _t < delai:
		return
	var a := _t - delai   # temps depuis le début de l'annonce
	if not _parti:
		_parti = true
		_zone.visible = true
		_remplissage.visible = true
	var f := clampf(a / EQ.bordee_annonce, 0.0, 1.0)
	_remplissage.scale = Vector3(maxf(f, 0.01), 1, maxf(f, 0.01))
	var debut_chute := EQ.bordee_annonce - CHUTE
	if a >= debut_chute and not _explose:
		_boule.visible = true
		var k := clampf((a - debut_chute) / CHUTE, 0.0, 1.0)
		_boule.position = Vector3(-2.0 * (1.0 - k), HAUTEUR * (1.0 - k * k) + 0.3, -2.0 * (1.0 - k))
	if a >= EQ.bordee_annonce and not _explose:
		_exploser()


func _exploser() -> void:
	_explose = true
	_boule.visible = false
	_zone.visible = false
	_remplissage.visible = false
	var parent := get_parent()
	EffetsMagie.explosion(parent, global_position)
	var arene := _arene()
	if arene and arene.get("camera"):
		arene.camera.secouer(0.45)
	if lanceur and is_instance_valid(lanceur):
		for e in get_tree().get_nodes_in_group("ennemis"):
			if e is Ennemi and e.est_ciblable():
				var d: Vector3 = e.global_position - global_position
				d.y = 0.0
				if d.length() <= EQ.bordee_rayon + 0.3:
					var degats := EQ.bordee_degats * (EQ.bordee_mult_bosco if e is Bosco else 1.0)
					Combat.porter_coup_discret(lanceur, e, degats)   # (cinq boulets : pas d'arrêt sur image)
	queue_free()


func _arene() -> Node:
	var n := get_parent()
	while n and not (n is Arene):
		n = n.get_parent()
	return n
