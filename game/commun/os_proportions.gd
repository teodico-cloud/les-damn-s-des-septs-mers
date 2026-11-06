class_name OsProportions
extends SkeletonModifier3D
## Change l'échelle de quelques os après l'animation (06/11, identité visuelle façon Diablo IV, version rapide) : des
## têtes plus petites, pour des personnages moins « jouets ». Ce qui est attaché à l'os (capuche, chapeau, casque)
## suit. Purement visuel : les collisions ne changent pas. Une échelle absolue par os (jamais multipliée : l'os
## garde sa taille d'une image à l'autre même sans piste d'échelle dans l'animation).

var echelles := {}   ## nom d'os -> Vector3


static func poser(sur: Node, p_echelles: Dictionary) -> OsProportions:
	var squelettes := sur.find_children("*", "Skeleton3D", true, false)
	if squelettes.is_empty():
		return null
	var m := OsProportions.new()
	m.name = "Proportions"
	m.echelles = p_echelles
	squelettes[0].add_child(m)
	return m


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	for nom in echelles:
		var i := sk.find_bone(nom)
		if i >= 0:
			sk.set_bone_pose_scale(i, echelles[nom])
