extends SceneTree
## Captures de l'écran « Jouer à deux » dans ses différents états (accueil, hôte en attente, recherche).
## Usage : xvfb-run -a godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 \
##         --resolution 1280x720 -s <chemin absolu>/tools/capture_coop_ecrans.gd -- <dossier>

var dossier := ""


func _initialize() -> void:
	_go()


func _capture(nom: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(dossier)
	var chemin := dossier.path_join(nom)
	if root.get_texture().get_image().save_png(chemin) != OK:
		push_error("capture impossible : " + chemin)
		quit(1)
	print("Capture : ", chemin)


func _ecran() -> Node:
	var e: Node = load("res://ui/screens/coop.tscn").instantiate()
	e.changer_de_scene = false
	root.add_child(e)
	return e


func _go() -> void:
	dossier = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "build/apercus"
	var partie: Node = root.get_node("Partie")
	var reseau: Node = root.get_node("Reseau")
	partie.mode = 0
	var e := _ecran()
	await _capture("coop_accueil.png")
	e.choisir_rejoindre()
	await _capture("coop_recherche.png")
	e.queue_free()
	reseau.quitter()
	partie.mode = 1
	partie.heros_local = &"occultiste"
	e = _ecran()
	await _capture("coop_hote_attente.png")
	reseau.quitter()
	quit()
