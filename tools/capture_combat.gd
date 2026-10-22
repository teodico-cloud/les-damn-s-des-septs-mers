extends SceneTree
## Captures mises en scène de l'arène (vérification visuelle du combat sans téléphone).
## Usage : godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 1280x720 \
##         -s <chemin absolu>/tools/capture_combat.gd -- <dossier de sortie>
## Ne pas typer avec les classes du jeu (Heros, Ennemi…) : ce script est compilé avant les services
## globaux (EventBus), ce qui ferait échouer la compilation.
## Produit : combat_annonce.png (squelette qui annonce son coup), combat_impact.png (coup du héros),
##           combat_fente.png (fente). Affiche aussi l'état du combat dans la console.

var arene: Node
var dossier := ""


func _initialize() -> void:
	_scenario()


func _attendre(n: int) -> void:
	for i in n:
		await physics_frame


func _capture(nom: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var chemin := dossier.path_join(nom)
	DirAccess.make_dir_recursive_absolute(dossier)
	if root.get_texture().get_image().save_png(chemin) != OK:
		push_error("capture impossible : " + chemin)
		quit(1)
	print("Capture : ", chemin)


func _scenario() -> void:
	dossier = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "build/apercus"
	arene = load("res://game/arene/arene.tscn").instantiate()
	root.add_child(arene)
	await _attendre(5)
	# on remplace les ennemis aléatoires par un squelette placé devant le héros
	for e in arene.generateur.get_children():
		e.queue_free()
	arene.generateur.set_process(false)
	var h = arene.heros
	h.global_position = Vector3(0, 0, 1.5)
	h.rotation.y = PI * 1.25   # le héros regarde vers le fond de la salle
	var e = load("res://game/enemies/ennemi.gd").creer(true)
	# squelette côté fond (la caméra est côté +x +z) : son annonce au sol n'est pas cachée par son corps
	e.position = h.global_position + Vector3(-1.4, 0, -1.4)   # avant add_child (sinon il apparaît un instant à l'origine)
	arene.add_child(e)
	await _attendre(25)
	print("squelette : état %d, distance %.2f" % [e.etat, e.global_position.distance_to(h.global_position)])
	await _capture("combat_annonce.png")
	# le héros roule à travers le squelette (esquive), se retourne et attaque
	h.commandes.demander(&"esquive", h.horloge)
	await _attendre(40)
	print("après esquive : PV héros %.0f" % h.sante.pv)
	h.commandes.demander(&"attaque", h.horloge)
	await _attendre(22)   # impact du 1er coup : 0,40 s / 1,3 ≈ 19 images, + 1 image de prise en compte
	await _capture("combat_impact.png")
	print("après coup : PV squelette %.0f / %.0f" % [e.sante.pv, e.sante.pv_max])
	await _attendre(40)
	h.commandes.demander(&"competence_2", h.horloge)
	await _attendre(9)
	await _capture("combat_fente.png")
	await _attendre(20)
	print("après fente : PV squelette %.0f, héros à %.2f m de son départ" % [e.sante.pv, h.global_position.distance_to(Vector3(0, 0, 1.5))])
	quit()
