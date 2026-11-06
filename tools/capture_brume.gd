extends SceneTree
## Captures de la brume au ras du sol et de la poussière dans la lumière (06/11, jalon 6, choix de Téo avec les sons) :
## une salle avec le héros et des squelettes, avec puis sans brume ; le même coin de près (poussière d'une torche).
## Usage : xvfb-run -a godot --path . --rendering-method gl_compatibility --rendering-driver opengl3
##         --resolution 1280x720 -s <chemin absolu>/tools/capture_brume.gd -- <dossier>
## Ne pas typer avec les classes du jeu (voir CLAUDE.md, pièges).

var dossier := ""


func _initialize() -> void:
	_go()


func _images(n: int) -> void:
	for i in n:
		await physics_frame


func _capture(nom: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(dossier)
	var chemin := dossier.path_join(nom)
	if root.get_texture().get_image().save_png(chemin) != OK:
		push_error("capture impossible : " + chemin)
		quit(1)
	print("Capture : ", chemin)


func _go() -> void:
	await process_frame
	dossier = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "build/apercus/brume"
	root.get_node("Partie").heros_local = &"bretteur"
	var arene = load("res://game/arene/arene.tscn").instantiate()
	arene.changer_de_scene = false
	root.add_child(arene)
	await _images(5)
	arene.heros.sante.rendre_invulnerable(1000.0)
	await _images(150)   # la horde sort de terre
	paused = true        # (image figée : les squelettes ne bougent plus entre deux captures)
	for b in get_nodes_in_group(&"brume"):
		b.process_mode = Node.PROCESS_MODE_ALWAYS
	await _capture("salle_avec_brume.png")
	for b in get_nodes_in_group(&"brume"):
		b.visible = false
	await _capture("salle_sans_brume.png")
	for b in get_nodes_in_group(&"brume"):
		b.visible = true
	# de près : la caméra sur une torche du mur du fond
	var torche = arene.torches[0]
	var cam: Camera3D = arene.camera
	cam.set_process(false)
	cam.set_physics_process(false)
	cam.global_position = torche.global_position + Vector3(2.2, 0.4, 3.4)
	cam.look_at(torche.global_position + Vector3(0, -0.8, 0))
	await _capture("torche_de_pres.png")
	quit()
