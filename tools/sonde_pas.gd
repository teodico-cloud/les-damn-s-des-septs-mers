extends SceneTree
## Où les pieds touchent le sol dans une animation de course ou de marche (part de la boucle, de 0 à 1) : les instants
## de PasSonores.CONTACTS (10/11). Un pied « touche » quand il descend sous 15 % de sa course au-dessus de son plus bas.
## Usage : godot --headless --path . -s "$PWD/tools/sonde_pas.gd"
func _initialize() -> void:
	_go()


func _go() -> void:
	for p in [["res://assets/models/heroes/Bretteur.glb", "Running_A"], ["res://assets/models/heroes/Occultiste.glb", "Running_A"],
			["res://assets/models/heroes_meshy/Bretteur.glb", "Running_A"],
			["res://assets/models/enemies/Skeleton_Minion.glb", "Running_C"], ["res://assets/models/enemies/Skeleton_Warrior.glb", "Walking_D_Skeletons"],
			["res://assets/models/enemies/Skeleton_Warrior.glb", "Running_A"]]:
		if not ResourceLoader.exists(p[0]):
			print("absent ", p[0]); continue
		var m: Node3D = load(p[0]).instantiate()
		root.add_child(m)
		var ap: AnimationPlayer = m.find_child("AnimationPlayer", true, false)
		var sq: Skeleton3D = m.find_child("Skeleton3D", true, false)
		if not ap.has_animation(p[1]):
			print("pas d'anim ", p[1], " dans ", p[0]); m.free(); continue
		var a := ap.get_animation(p[1])
		var noms := []
		for i in sq.get_bone_count():
			if sq.get_bone_name(i).to_lower().begins_with("foot"):
				noms.append(sq.get_bone_name(i))
		ap.play(p[1])
		var n := 120
		var hauteurs := {}
		for nom in noms:
			hauteurs[nom] = []
		for k in n:
			ap.seek(a.length * k / n, true)
			ap.pause()
			await process_frame
			for nom in noms:
				var g := sq.get_bone_global_pose(sq.find_bone(nom))
				hauteurs[nom].append(g.origin.y)
		var res := []
		for nom in noms:
			var h: Array = hauteurs[nom]
			var bas: float = h.min()
			var haut: float = h.max()
			for k in n:
				var a0: float = h[(k - 1 + n) % n]
				var a1: float = h[k]
				var a2: float = h[(k + 1) % n]
				# le pied arrive en bas : premier instant où il est à moins de 15 % de sa course au-dessus du sol
				if a1 <= bas + 0.15 * (haut - bas) and a0 > bas + 0.15 * (haut - bas):
					res.append("%s %.2f" % [nom, float(k) / n])
		print(p[0].get_file(), " ", p[1], " durée %.2f s : " % a.length, ", ".join(res), "  (os : ", noms, ")")
		m.free()
	quit(0)
