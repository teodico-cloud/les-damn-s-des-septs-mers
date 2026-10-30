class_name OrbeVie
extends Node3D
## Orbe de vie (façon Diablo, choix de Téo) : lâchée par un squelette vaincu, elle flotte au-dessus
## du sol en palpitant ; un héros blessé qui passe dessus la ramasse et reprend des PV (voir Arene).
## Elle s'efface seule au bout de orbe_duree secondes. Purement visuelle : la règle est dans l'arène.

const EQ: Equilibrage = preload("res://data/equilibrage.tres")

static var _maillage: SphereMesh
static var _matiere: StandardMaterial3D

var prise := false
var _boule: MeshInstance3D
var _age := 0.0


static func creer() -> OrbeVie:
	return OrbeVie.new()


func _ready() -> void:
	if _maillage == null:
		_maillage = SphereMesh.new()
		_maillage.radius = 0.2
		_maillage.height = 0.4
		_maillage.radial_segments = 16
		_maillage.rings = 8
		_matiere = StandardMaterial3D.new()
		_matiere.albedo_color = Color(0.75, 0.05, 0.08)
		_matiere.emission_enabled = true
		_matiere.emission = Color(1.0, 0.12, 0.12)
		_matiere.emission_energy_multiplier = 2.5
		_matiere.roughness = 0.2
	_boule = MeshInstance3D.new()
	_boule.mesh = _maillage
	_boule.material_override = _matiere
	_boule.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_boule.position.y = 0.55
	add_child(_boule)
	# petite apparition : elle jaillit du squelette
	_boule.scale = Vector3.ONE * 0.1
	create_tween().tween_property(_boule, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if prise:
		return
	_age += delta
	_boule.position.y = 0.55 + 0.1 * sin(_age * 3.0)
	var pulse := 1.0 + 0.08 * sin(_age * 6.0)
	if _age > 0.3:
		_boule.scale = Vector3.ONE * pulse
	if _age > EQ.orbe_duree:
		prise = true
		var t := create_tween()
		t.tween_property(_boule, "scale", Vector3.ONE * 0.01, 0.4)
		t.tween_callback(queue_free)


## Ramassée : elle monte vers le héros en rétrécissant, puis disparaît.
func prendre() -> void:
	if prise:
		return
	prise = true
	var t := create_tween().set_parallel(true)
	t.tween_property(_boule, "position:y", 1.6, 0.25)
	t.tween_property(_boule, "scale", Vector3.ONE * 0.05, 0.25)
	t.chain().tween_callback(queue_free)
