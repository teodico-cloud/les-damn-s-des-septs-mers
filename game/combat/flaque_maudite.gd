class_name FlaqueMaudite
extends Node3D
## Flaque maudite du prêtre noyé : une mare verte qui bouillonne quelques secondes. Un héros qui reste
## dedans perd des PV (sans être sonné : ce n'est pas un coup) ; la roulade ou la téléportation
## permettent d'en sortir. `active` : elle blesse (hôte ou seul) ; sinon simple image (invité).

const EQ: Equilibrage = preload("res://data/equilibrage.tres")
const TIC := 0.5   ## secondes entre deux pertes de PV

static var _disque: CylinderMesh
static var _bulle: SphereMesh

var active := true
var _age := 0.0
var _prochain_tic := TIC
var _mat: StandardMaterial3D


static func creer(monde: Node, pos: Vector3, p_active: bool) -> FlaqueMaudite:
	var f := FlaqueMaudite.new()
	f.active = p_active
	f.position = Vector3(pos.x, 0.06, pos.z)
	monde.add_child(f)
	return f


func _ready() -> void:
	if _disque == null:
		_disque = CylinderMesh.new()
		_disque.top_radius = EQ.flaque_rayon
		_disque.bottom_radius = EQ.flaque_rayon
		_disque.height = 0.03
		_disque.radial_segments = 32
		_disque.rings = 1
		_bulle = SphereMesh.new()
		_bulle.radius = 0.07
		_bulle.height = 0.14
		_bulle.radial_segments = 8
		_bulle.rings = 4
	var m := MeshInstance3D.new()
	m.mesh = _disque
	_mat = StandardMaterial3D.new()
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.albedo_color = Color(0.1, 0.45, 0.2, 0.0)
	_mat.emission_enabled = true
	_mat.emission = Color(0.15, 0.7, 0.3)
	_mat.emission_energy_multiplier = 0.8
	_mat.roughness = 0.1
	m.material_override = _mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	var bulles := CPUParticles3D.new()
	bulles.mesh = _bulle
	bulles.amount = 14
	bulles.lifetime = 0.9
	bulles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	bulles.emission_sphere_radius = EQ.flaque_rayon * 0.8
	bulles.scale_amount_min = 0.5
	bulles.scale_amount_max = 1.3
	bulles.direction = Vector3.UP
	bulles.spread = 15.0
	bulles.initial_velocity_min = 0.3
	bulles.initial_velocity_max = 0.8
	bulles.gravity = Vector3.ZERO
	var mat_bulle := StandardMaterial3D.new()
	mat_bulle.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_bulle.albedo_color = Color(0.4, 1.0, 0.55)
	bulles.material_override = mat_bulle
	bulles.scale = Vector3(1, 0.15, 1)   # bulles à ras de la flaque
	add_child(bulles)
	var t := create_tween()
	t.tween_property(_mat, "albedo_color:a", 0.7, 0.3)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= EQ.flaque_duree:
		set_physics_process(false)
		var t := create_tween()
		t.tween_property(_mat, "albedo_color:a", 0.0, 0.4)
		t.tween_callback(queue_free)
		return
	if not active:
		return
	_prochain_tic -= delta
	if _prochain_tic > 0.0:
		return
	_prochain_tic += TIC
	for h in get_tree().get_nodes_in_group("heros"):
		if h is Heros and h.est_vivant() and not h.marionnette:
			var d: Vector3 = h.global_position - global_position
			d.y = 0.0
			if d.length() <= EQ.flaque_rayon:
				h.subir_continu(EQ.flaque_degats_seconde * TIC, self)
