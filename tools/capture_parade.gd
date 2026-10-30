extends SceneTree
## Captures de la parade : la zone au sol encore rouge, puis dorée (moment de parer), puis une parade
## parfaite (étincelles, éclair, « PARFAIT ! »). Usage : xvfb-run -a godot --path . --rendering-method
## gl_compatibility --rendering-driver opengl3 --resolution 1280x720 -s <chemin absolu>/tools/capture_parade.gd -- <dossier>
## Ne pas typer avec les classes du jeu (voir CLAUDE.md, pièges).

var dossier := ""
var arene
var h


func _initialize() -> void:
	_go()


func _images(n: int) -> void:
	for i in n:
		await physics_frame


func _capture(nom: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(dossier)
	var chemin := dossier.path_join(nom)
	if root.get_texture().get_image().save_png(chemin) != OK:
		push_error("capture impossible : " + chemin)
		quit(1)
	print("Capture : ", chemin)


## Annonce figée à `reste` secondes du coup (animation calée au même instant).
func _annonce(e, reste: float) -> void:
	var EQ = load("res://data/equilibrage.tres")
	e._t = EQ.squelette_preparation - reste
	e._preparer_visuel()
	e.anim.speed_scale = 1.0
	e.anim.seek(e._t * EQ.squelette_impact_animation / EQ.squelette_preparation, true)
	e.anim.speed_scale = 0.0
	print("annonce : reste %.2f s, signal doré = %s" % [reste, e.signal_parade()])


func _go() -> void:
	dossier = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "build/apercus"
	root.get_node("Partie").heros_local = &"bretteur"
	arene = load("res://game/arene/arene.tscn").instantiate()
	root.add_child(arene)
	await _images(5)
	h = arene.heros
	h.sante.rendre_invulnerable(1000.0)
	await _images(150)   # la horde sort de terre
	var e = null
	for s in arene.generateur.get_children():
		s.set_physics_process(false)   # tout le monde s'arrête : on met en scène un seul coup
		if e == null and s.etat != 0 and s.etat != 7:
			e = s
	if e == null:
		push_error("aucun squelette")
		quit(1)
		return
	var vers_heros: Vector3 = Vector3(0.5, 0, 1.0).normalized()   # le squelette derrière le héros, vu de la caméra
	e.global_position = h.global_position - vers_heros * 1.7
	e._commencer_preparation(vers_heros)
	h.rotation.y = atan2(-vers_heros.x, -vers_heros.z)
	await _images(2)
	_annonce(e, 0.55)
	await _capture("parade_zone_rouge.png")
	_annonce(e, 0.25)
	await _capture("parade_zone_doree.png")
	# parade juste à temps : le coup arrive 3 images après l'appui
	h.commandes.demander(&"competence_1", h.horloge)
	await _images(3)
	h.rotation.y = atan2(-vers_heros.x, -vers_heros.z)
	print("héros : état %d (3 = parade), %.2f s dans la parade" % [h.etat, h._t])
	load("res://game/combat/combat.gd").porter_coup(e, h, 10.0, false)
	print("héros : état %d (4 = riposte)" % h.etat)
	# (le rendu est lent ici : à la 2e image, les étincelles de 0,4 s ont déjà disparu)
	await _capture("parade_parfaite.png")
	quit()
