class_name DecorMenu
extends Node3D
## Décor de l'écran titre (refonte de l'interface, 05/11) : le navire des damnés amarré à un ponton, de nuit,
## dans la brume ; lanternes vertes, une torche sur le ponton, la houle. La caméra dérive lentement et garde
## le navire dans la moitié droite de l'écran (la gauche porte le titre et le menu). Purement décoratif.

const DECOR := "res://assets/models/decor/"
const ECHELLE := 0.8
const TORCHE := Color(1.0, 0.55, 0.2)
const VERT := Color(0.35, 1.0, 0.55)

var camera: Camera3D
var navire: Navire
var _t := 0.0
var _depart := Vector3(8.5, 3.2, 11.5)
var _cible := Vector3(-7.2, 2.4, -1.6)


func _ready() -> void:
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.015, 0.02, 0.035)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.3, 0.4, 0.55)
	e.ambient_light_energy = 0.35
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.fog_enabled = true
	e.fog_light_color = Color(0.08, 0.11, 0.15)
	e.fog_density = 0.035
	e.glow_enabled = true
	e.glow_intensity = 0.9
	e.glow_bloom = 0.1
	we.environment = e
	add_child(we)
	var lune := DirectionalLight3D.new()
	lune.rotation_degrees = Vector3(-35, 140, 0)   # dans le dos du navire : les voiles se découpent
	lune.light_color = Color(0.55, 0.65, 1.0)
	lune.light_energy = 0.8
	add_child(lune)
	# la mer
	var eau := MeshInstance3D.new()
	var plan := PlaneMesh.new()
	plan.size = Vector2(60.0, 60.0)
	plan.subdivide_width = 60
	plan.subdivide_depth = 60
	eau.mesh = plan
	var mat_eau := ShaderMaterial.new()
	mat_eau.shader = load("res://game/expedition/eau.gdshader")
	mat_eau.set_shader_parameter("houle", 0.35)
	eau.material_override = mat_eau
	eau.position = Vector3(0, -0.45, 0)
	add_child(eau)
	# le navire, de flanc
	navire = Navire.new()
	navire.position = Vector3(-4.0, -1.25, -1.0)
	navire.rotation_degrees.y = 75.0
	navire.niveaux = Bateau.niveaux()
	add_child(navire)
	# le ponton, au premier plan, et ce qu'on y a laissé
	for i in 4:
		_objet("floor_wood_large_dark" if i % 2 else "floor_wood_large", Vector3(3.2 * i + 0.6, -0.15, 3.6), 0.0)
	_objet("barrel_large", Vector3(7.4, 0.0, 2.6), 20.0)
	_objet("barrel_small_stack", Vector3(9.4, 0.0, 3.9), -35.0)
	_objet("crates_stacked", Vector3(5.2, 0.0, 2.3), 12.0)
	var torche := OmniLight3D.new()
	torche.position = Vector3(6.4, 1.5, 3.4)
	torche.light_color = TORCHE
	torche.light_energy = 1.3
	torche.omni_range = 6.0
	add_child(torche)
	for p in [Vector3(-4.0, 2.0, 2.6), Vector3(-7.5, 2.4, -3.0)]:
		var l := OmniLight3D.new()
		l.position = p
		l.light_color = VERT
		l.light_energy = 0.8
		l.omni_range = 7.0
		add_child(l)
	camera = Camera3D.new()
	camera.fov = 45.0
	camera.position = _depart
	add_child(camera)
	camera.look_at(_cible)


func _process(delta: float) -> void:
	_t += delta
	camera.position = _depart + Vector3(sin(_t * 0.11) * 0.9, sin(_t * 0.23) * 0.18, cos(_t * 0.08) * 0.5)
	camera.look_at(_cible + Vector3(0, sin(_t * 0.17) * 0.08, 0))


func _objet(nom: String, pos: Vector3, rot_y: float) -> void:
	var n: Node3D = load(DECOR + nom + ".glb").instantiate()
	n.position = pos
	n.rotation_degrees.y = rot_y
	n.scale = Vector3.ONE * ECHELLE
	add_child(n)
