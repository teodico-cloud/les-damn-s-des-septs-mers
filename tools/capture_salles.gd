extends SceneTree
## Capture de chaque salle d'expédition faite main, seule (sans héros ni ennemis) : une vue de jeu
## centrée au milieu de la salle, et une vue de dessus pour vérifier les passages.
## Usage : xvfb-run -a godot --path . --rendering-method gl_compatibility --rendering-driver opengl3
##         --resolution 1280x720 -s <chemin absolu>/tools/capture_salles.gd -- <dossier> [modèle]
## Ne pas typer avec les classes du jeu (voir CLAUDE.md, pièges).

var dossier := ""


func _initialize() -> void:
	_go()


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


func _ambiance(parent: Node) -> void:
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.02, 0.03, 0.05)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.3, 0.4, 0.55)
	e.ambient_light_energy = 0.45
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	we.environment = e
	parent.add_child(we)
	var lune := DirectionalLight3D.new()
	lune.rotation_degrees = Vector3(-55, -30, 0)
	lune.light_color = Color(0.55, 0.65, 1.0)
	lune.light_energy = 0.4
	parent.add_child(lune)


func _go() -> void:
	var args := OS.get_cmdline_user_args()
	dossier = args[0] if args.size() > 0 else "build/apercus"
	var Salles = load("res://game/expedition/salles.gd")
	var Salle = load("res://game/expedition/salle.gd")
	var ids: Array = Salles.MODELES.keys()
	await process_frame   # (la toute première image sort vide)
	if args.size() > 1:
		ids = [args[1]]
	for id in ids:
		var monde := Node3D.new()
		root.add_child(monde)
		_ambiance(monde)
		var types: Array = []
		var t: StringName = Salles.MODELES[id]["types"][0]
		if t == &"bosco":
			types = [&"chaloupe"]
		elif t != &"chaloupe":
			types = [&"combat", &"tresor"]
		var s = Salle.creer(id, types)
		monde.add_child(s)
		s.ouvrir_portes()
		var cam := Camera3D.new()
		monde.add_child(cam)
		cam.fov = 50.0
		cam.look_at_from_position(Vector3(9.5, 13.0, 9.5), Vector3(-0.8, 0, -0.8))
		cam.current = true
		await _capture("salle_%s.png" % id)
		cam.look_at_from_position(Vector3(0, 22, 0.01), Vector3.ZERO)
		await _capture("salle_%s_dessus.png" % id)
		monde.queue_free()
		await process_frame
	quit()
