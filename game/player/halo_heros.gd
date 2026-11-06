class_name HaloHeros
extends OmniLight3D
## La lumière qui suit un héros (06/11, façon Diablo IV, voir Ambiance) : un halo chaud au-dessus de lui, un peu
## côté caméra pour que ses habits sombres et son visage se lisent dans le noir. Sans ombre (peu coûteuse sur
## téléphone). Elle ne tourne pas avec le héros (`top_level`) : elle le suit seulement. Chaque héros a la sienne,
## les deux en coop (purement visuelle, rien ne passe par le réseau).

const HAUTEUR := 2.4
const VERS_CAMERA := 1.1


func _ready() -> void:
	name = "Halo"
	top_level = true
	light_color = Color(1.0, 0.86, 0.68)
	light_energy = 2.2
	omni_range = 6.5
	omni_attenuation = 1.1
	shadow_enabled = false
	_suivre()


func _process(_delta: float) -> void:
	_suivre()


func _suivre() -> void:
	var h := get_parent() as Node3D
	if h == null or not h.is_inside_tree():
		return
	var p := h.global_position + Vector3(0, HAUTEUR, 0)
	var cam := get_viewport().get_camera_3d()
	if cam:
		var vers := cam.global_transform.basis.z
		vers.y = 0.0
		if vers.length() > 0.01:
			p += vers.normalized() * VERS_CAMERA
	global_position = p
