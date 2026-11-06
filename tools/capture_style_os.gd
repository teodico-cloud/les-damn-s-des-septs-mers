extends SkeletonModifier3D
## Essai de style : change l'échelle de quelques os après l'animation (têtes plus petites).
var echelles := {}   # nom d'os -> Vector3

func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	for nom in echelles:
		var i := sk.find_bone(nom)
		if i >= 0:
			sk.set_bone_pose_scale(i, echelles[nom])
