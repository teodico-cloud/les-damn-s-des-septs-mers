extends SceneTree
## Sonde (outil de mise au point) : où pointe l'arme d'un squelette dans chaque pose ?
## Affiche, pour la main droite et la main gauche, l'angle entre l'avant de l'arme (+z du modèle de
## l'arme, ou l'axe donné) et l'avant du squelette, la pente et la position de l'arme.
## Usage : godot --headless --path . -s <chemin absolu>/tools/sonde_arme.gd -- [modèle.glb arme.gltf axe anims…]
## Sans argument : l'arbalétrier (Skeleton_Rogue + Skeleton_Crossbow, axe z). Axe : x, y ou z.

func _initialize() -> void:
	_go()


func _go() -> void:
	var args := OS.get_cmdline_user_args()
	var chemin_modele := "res://assets/models/enemies/Skeleton_Rogue.glb"
	var chemin_arme := "res://assets/models/enemies/Skeleton_Crossbow.gltf"
	var axe := "z"
	var anims: Array = ["Idle_Combat", "2H_Ranged_Aiming", "2H_Ranged_Shoot", "2H_Ranged_Reload", "Running_C", "Walking_Backwards"]
	if args.size() >= 3:
		chemin_modele = args[0]
		chemin_arme = args[1]
		axe = args[2]
		if args.size() > 3:
			anims = args.slice(3)
	var modele: Node3D = load(chemin_modele).instantiate()
	root.add_child(modele)
	var anim: AnimationPlayer = modele.find_child("AnimationPlayer", true, false)
	var sk: Skeleton3D = modele.find_child("Skeleton3D", true, false)
	var mains := {}
	for os in ["handslot.r", "handslot.l"]:
		var a := BoneAttachment3D.new()
		a.bone_name = os
		sk.add_child(a)
		var arme: Node3D = load(chemin_arme).instantiate()
		a.add_child(arme)
		mains[os] = [a, arme]
	await process_frame
	for nom in anims:
		if not anim.has_animation(nom):
			print(nom, " : absente")
			continue
		var duree := anim.get_animation(nom).length
		for t in [0.0, duree * 0.35, duree * 0.5, duree * 0.75]:
			anim.play(nom, 0.0)
			anim.seek(t, true)
			anim.pause()
			await process_frame
			await process_frame
			var ligne := "%-28s t=%.2f" % [nom, t]
			for os in mains:
				var arme: Node3D = mains[os][1]
				var b := arme.global_transform.basis.orthonormalized()
				var avant: Vector3 = b.x if axe == "x" else (b.y if axe == "y" else b.z)
				var angle := rad_to_deg(atan2(avant.x, avant.z))
				ligne += "  | %s : avant %+.0f°, pente %+.0f°, pos %s" % [os, angle,
						rad_to_deg(asin(clampf(avant.y, -1, 1))), arme.global_position.snapped(Vector3.ONE * 0.01)]
			print(ligne)
	quit()
