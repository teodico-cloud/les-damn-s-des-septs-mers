class_name FlaqueNoyee
extends Node3D
## Lame du Noyé (objet légendaire du Bretteur) : la roulade laisse derrière elle une traînée d'eau
## maudite, bleu-vert, qui blesse les squelettes qui y restent. `lanceur` : le héros qui l'a laissée
## (ses bonus de dégâts comptent) ; null : simple image (chez l'invité, l'hôte compte les dégâts).

const EQ: Equilibrage = preload("res://data/equilibrage.tres")
const TIC := 0.5   ## secondes entre deux blessures

static var _disque: CylinderMesh
static var _mat_base: StandardMaterial3D

var lanceur: Node3D
var _age := 0.0
var _prochain_tic := TIC
var _mat: StandardMaterial3D


static func creer(monde: Node, pos: Vector3, p_lanceur: Node3D) -> FlaqueNoyee:
	var f := FlaqueNoyee.new()
	f.lanceur = p_lanceur
	f.position = Vector3(pos.x, 0.07, pos.z)
	if monde and monde.is_inside_tree():
		monde.add_child(f)
	return f


func _ready() -> void:
	if _disque == null:
		_disque = CylinderMesh.new()
		_disque.top_radius = EQ.noyee_rayon
		_disque.bottom_radius = EQ.noyee_rayon
		_disque.height = 0.02
		_disque.radial_segments = 20
		_disque.rings = 1
		_mat_base = StandardMaterial3D.new()
		_mat_base.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat_base.albedo_color = Color(0.1, 0.35, 0.45, 0.6)
		_mat_base.emission_enabled = true
		_mat_base.emission = Color(0.2, 0.75, 0.85)
		_mat_base.emission_energy_multiplier = 0.9
		_mat_base.roughness = 0.05
	var m := MeshInstance3D.new()
	m.mesh = _disque
	_mat = _mat_base.duplicate()   # chacune s'efface à son rythme
	m.material_override = _mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	add_to_group("eau_noyee")


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= EQ.noyee_duree:
		set_physics_process(false)
		var t := create_tween()
		t.tween_property(_mat, "albedo_color:a", 0.0, 0.35)
		t.parallel().tween_property(_mat, "emission_energy_multiplier", 0.0, 0.35)
		t.tween_callback(queue_free)
		return
	if lanceur == null or not is_instance_valid(lanceur):
		return
	_prochain_tic -= delta
	if _prochain_tic > 0.0:
		return
	_prochain_tic += TIC
	for e in get_tree().get_nodes_in_group("ennemis"):
		if e is Ennemi and e.est_ciblable():
			var d: Vector3 = e.global_position - global_position
			d.y = 0.0
			# (les flaques d'une traînée se chevauchent : un squelette n'est blessé qu'une fois par tic)
			var dernier: float = e.get_meta("eau_noyee", -10.0)
			if d.length() <= EQ.noyee_rayon + 0.3 and lanceur.horloge - dernier >= TIC * 0.9:
				e.set_meta("eau_noyee", lanceur.horloge)
				Combat.porter_coup(lanceur, e, EQ.noyee_degats_seconde * TIC, false)
