extends SceneTree
## Sonde (outil de mise au point) : où pointe l'arbalète de l'arbalétrier dans chaque pose ?
## Affiche, pour la main droite et la main gauche, l'angle entre l'avant de l'arbalète (+z du modèle)
## et l'avant du squelette, et la hauteur de l'arbalète.
## Usage : godot --headless --path . -s <chemin absolu>/tools/sonde_arbalete.gd

func _initialize() -> void:
	_go()


func _go() -> void:
	var modele: Node3D = load("res://assets/models/enemies/Skeleton_Rogue.glb").instantiate()
	root.add_child(modele)
	var anim: AnimationPlayer = modele.find_child("AnimationPlayer", true, false)
	var sk: Skeleton3D = modele.find_child("Skeleton3D", true, false)
	var mains := {}
	for os in ["handslot.r", "handslot.l"]:
		var a := BoneAttachment3D.new()
		a.bone_name = os
		sk.add_child(a)
		var arme: Node3D = load("res://assets/models/enemies/Skeleton_Crossbow.gltf").instantiate()
		a.add_child(arme)
		mains[os] = [a, arme]
	await process_frame
	for nom in ["Idle_Combat", "2H_Ranged_Aiming", "2H_Ranged_Shoot", "2H_Ranged_Reload", "Running_C", "Walking_Backwards"]:
		if not anim.has_animation(nom):
			print(nom, " : absente")
			continue
		var duree := anim.get_animation(nom).length
		for t in [0.0, duree * 0.5]:
			anim.play(nom, 0.0)
			anim.seek(t, true)
			anim.pause()
			await process_frame
			await process_frame
			var ligne := "%-20s t=%.2f" % [nom, t]
			for os in mains:
				var arme: Node3D = mains[os][1]
				var b := arme.global_transform.basis.orthonormalized()
				var avant := b.z
				var angle := rad_to_deg(atan2(avant.x, avant.z))
				ligne += "  | %s : avant %+.0f°, pente %+.0f°, haut %s, pos %s" % [os, angle,
						rad_to_deg(asin(clampf(avant.y, -1, 1))), b.y.snapped(Vector3.ONE * 0.01),
						arme.global_position.snapped(Vector3.ONE * 0.01)]
			print(ligne)
	# repère de la main droite dans la pose de visée : de quoi calculer la correction
	anim.play("2H_Ranged_Aiming", 0.0)
	anim.seek(anim.get_animation("2H_Ranged_Aiming").length * 0.5, true)
	anim.pause()
	await process_frame
	await process_frame
	var att: BoneAttachment3D = mains["handslot.r"][0]
	var voulu := Basis.looking_at(Vector3(0, 0, 1), Vector3.UP, true)   # +z vers l'avant du squelette
	var corr := att.global_transform.basis.orthonormalized().inverse() * voulu
	print("correction (main droite, visée) : euler en degrés ", (corr.get_euler() * 180.0 / PI).snapped(Vector3.ONE * 0.1))
	quit()
