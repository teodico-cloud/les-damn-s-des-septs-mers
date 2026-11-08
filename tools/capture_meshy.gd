extends SceneTree
## Héros Meshy (07/11, à l'essai) : le même combat filmé avec le héros actuel ou le héros Meshy.
## Usage : xvfb-run -a godot --path . <rendu> -s "$PWD/tools/capture_meshy.gd" -- <bretteur|occultiste> <essai|actuel> <dossier>
## « essai » : le Mode test « Héros Meshy » (Partie.debug_heros_meshy) ; « actuel » : les héros KayKit du jeu.

var arene: Node
var h
var dossier := ""
var prefixe := ""
var squelettes := []


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var archetype: String = a[0]
	var nom := "Bretteur" if archetype == "bretteur" else "Occultiste"
	dossier = a[2]
	prefixe = "%s_%s_" % [archetype, a[1]]
	if a[1] == "essai":
		root.get_node("Partie").debug_heros_meshy = true   # (le Mode test : héros Meshy)
	_scenario(archetype)


func _attendre(n: int) -> void:
	for i in n:
		await physics_frame


func _capture(nom: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(dossier)
	var chemin := dossier.path_join(prefixe + nom)
	root.get_texture().get_image().save_png(chemin)
	print("Capture : ", chemin, "  état héros %d" % h.etat)


func _demander(action: StringName) -> void:
	h.commandes.demander(action, h.horloge)


func _scenario(archetype: String) -> void:
	root.get_node("Partie").heros_local = StringName(archetype)
	arene = load("res://game/arene/arene.tscn").instantiate()
	root.add_child(arene)
	await _attendre(5)
	for x in arene.generateur.get_children():
		x.queue_free()
	arene.generateur.set_process(false)
	h = arene.heros
	# preuve que le bon modèle est en scène : nombre de triangles du héros
	var tris := 0
	for mi in h.visuel.find_children("*", "MeshInstance3D", true, false):
		if mi.get_parent().name != "handslot_r" and mi.get_parent().name != "handslot_l":
			for s in mi.mesh.get_surface_count():
				tris += mi.mesh.surface_get_array_index_len(s) / 3
	print("MODELE triangles du corps : ", tris)
	h.sante.pv_max = 99999.0
	h.sante.pv = 99999.0
	h.global_position = Vector3(0, 0, 1.5)
	h.rotation.y = PI * 1.25   # regarde vers le fond de la salle
	for d in [Vector3(-1.6, 0, -1.2), Vector3(-0.6, 0, -2.0), Vector3(-2.4, 0, -0.2)]:
		var e = load("res://game/enemies/ennemi.gd").creer(true)
		e.position = h.global_position + d
		arene.add_child(e)
		e.set_physics_process(false)   # ils posent : ni approche ni coup
		e.sante.pv_max = 9999.0
		e.sante.pv = 9999.0
		squelettes.append(e)
	await _attendre(30)
	await _capture("1_vue_de_jeu.png")
	arene.camera.distance = 5.5
	await _attendre(40)
	await _capture("2_gros_plan_repos.png")
	# course vers la caméra
	h.commandes.deplacement = Vector3(0.7, 0, 0.7)
	await _attendre(26)
	await _capture("3_course.png")
	h.commandes.deplacement = Vector3(-0.7, 0, -0.7)
	await _attendre(20)
	h.commandes.deplacement = Vector3.ZERO
	await _attendre(30)
	# l'attaque, au moment de l'impact
	h.jauge = 100.0
	_demander(&"attaque")
	if archetype == "bretteur":
		await _attendre(22)
	else:
		await _attendre(18)
	await _capture("4_attaque.png")
	await _attendre(50)
	# la compétence 1 (Parade / Marque)
	_demander(&"competence_1")
	await _attendre(16)
	await _capture("5_competence_1.png")
	await _attendre(80)
	h.jauge = 100.0
	_demander(&"competence_2")
	await _attendre(24)
	await _capture("6_competence_2.png")
	quit(0)
