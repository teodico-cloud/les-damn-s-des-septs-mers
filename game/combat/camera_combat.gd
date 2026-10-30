class_name CameraCombat
extends Camera3D
## Caméra isométrique qui suit le héros en douceur, avec une secousse pour les impacts.

const DIRECTION := Vector3(1.0, 1.35, 1.0)   ## d'où regarde la caméra (diagonale, en hauteur)
@export var distance := 13.0
@export var lissage := 6.0

var cible: Node3D
var _centre := Vector3.ZERO
var _tremblement := 0.0
var _bruit := FastNoiseLite.new()
var _temps := 0.0


func _ready() -> void:
	fov = 36.0
	_bruit.frequency = 4.0
	if cible:
		_centre = cible.global_position
	_placer()


## Saut de la cible (changement de salle) : la caméra y va d'un coup, sans glisser à travers la salle.
func recentrer() -> void:
	if cible and is_instance_valid(cible):
		_centre = cible.global_position
		_placer()


func secouer(force: float) -> void:
	_tremblement = clampf(max(_tremblement, force), 0.0, 1.0)


## Convertit la direction du joystick (x vers la droite de l'écran, y vers le bas) en direction au sol.
func joystick_vers_monde(v: Vector2) -> Vector3:
	var droite := global_transform.basis.x
	droite.y = 0.0
	var haut_ecran := -global_transform.basis.z
	haut_ecran.y = 0.0
	return droite.normalized() * v.x + haut_ecran.normalized() * -v.y


func _process(delta: float) -> void:
	_temps += delta
	if cible and is_instance_valid(cible):
		_centre = _centre.lerp(cible.global_position, clampf(lissage * delta, 0.0, 1.0))
	_tremblement = max(0.0, _tremblement - 2.5 * delta)
	_placer()


func _placer() -> void:
	var regard := _centre + Vector3(0, 1.0, 0)
	var pos := regard + DIRECTION.normalized() * distance
	look_at_from_position(pos, regard, Vector3.UP)
	if _tremblement > 0.0:
		var amp := _tremblement * _tremblement * 0.35
		h_offset = _bruit.get_noise_2d(_temps * 60.0, 0.0) * amp
		v_offset = _bruit.get_noise_2d(0.0, _temps * 60.0) * amp
	else:
		h_offset = 0.0
		v_offset = 0.0
