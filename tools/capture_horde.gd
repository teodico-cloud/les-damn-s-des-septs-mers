extends SceneTree
## Captures du combat « nerveux » : la horde, un coup critique avec la traînée du sabre, un squelette
## qui éclate en os. Usage : xvfb-run -a godot --path . --rendering-method gl_compatibility
## --rendering-driver opengl3 --resolution 1280x720 -s <chemin absolu>/tools/capture_horde.gd -- <dossier>
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


func _plus_proche():
	var meilleur = null
	var d := INF
	for e in arene.generateur.get_children():
		if e.etat != 0 and e.etat != 7 and e.global_position.distance_to(h.global_position) < d:
			d = e.global_position.distance_to(h.global_position)
			meilleur = e
	return meilleur


func _go() -> void:
	dossier = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "build/apercus"
	root.get_node("Partie").heros_local = &"bretteur"
	arene = load("res://game/arene/arene.tscn").instantiate()
	root.add_child(arene)
	await _images(5)
	h = arene.heros
	h.sante.rendre_invulnerable(1000.0)
	# traînée du sabre, avant que la horde n'arrive : les trois formes (diagonal, horizontal, lourd)
	# (le rendu est lent ici : sans ralenti, la traînée de 0,2 s a parfois disparu avant la capture)
	var fx = load("res://game/combat/effets_magie.gd")
	Engine.time_scale = 0.1
	for coup in 3:
		h.rotation.y = PI * 0.25
		fx.trainee_sabre(arene, h.global_position, Vector3(1, 0, 1).normalized(), coup)
		await _images(1)
		await _capture("sabre_%d.png" % (coup + 1))
		await _images(40)
	Engine.time_scale = 1.0
	await _images(120)   # la horde sort de terre et arrive
	await _capture("horde.png")
	var combat = load("res://game/combat/combat.gd")
	combat.chance_critique = 1.0
	var cible = _plus_proche()
	if cible:
		h.global_position = cible.global_position + Vector3(-1.2, 0, -1.2)
	h.commandes.demander(&"attaque", h.horloge)
	await _images(17)
	await _capture("horde_critique.png")
	combat.chance_critique = 0.0
	await _images(30)
	cible = _plus_proche()
	if cible:
		cible.recevoir_coup(500.0, h, true)
	await _images(9)
	await _capture("horde_os.png")
	quit()
