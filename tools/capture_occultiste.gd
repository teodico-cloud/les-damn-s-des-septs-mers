extends SceneTree
## Captures mises en scène de l'Occultiste dans l'arène (vérification visuelle sans téléphone).
## Usage : godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 1280x720 \
##         -s <chemin absolu>/tools/capture_occultiste.gd -- <dossier de sortie>
## Ne pas typer avec les classes du jeu (voir CLAUDE.md, pièges).
## Produit : occ_yeux_rouges.png, occ_teleportation.png, occ_marque.png, occ_projectile.png, occ_chaines.png.

var arene: Node
var h
var e
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
	print("Capture : ", chemin, "  (squelette : état %d, PV %.0f ; Occultiste : état %d, PV %.0f)" % [e.etat, e.sante.pv, h.etat, h.sante.pv])


func _demander(action: StringName) -> void:
	h.commandes.demander(action, h.horloge)


func _scenario() -> void:
	dossier = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "build/apercus"
	root.get_node("Partie").heros_local = &"occultiste"
	arene = load("res://game/arene/arene.tscn").instantiate()
	root.add_child(arene)
	await _attendre(5)
	for x in arene.generateur.get_children():
		x.queue_free()
	arene.generateur.set_process(false)
	h = arene.heros
	h.global_position = Vector3(0, 0, 1.5)
	h.rotation.y = PI * 1.25
	e = load("res://game/enemies/ennemi.gd").creer(true)
	e.position = h.global_position + Vector3(-1.3, 0, -1.3)   # côté fond, face à la caméra
	arene.add_child(e)
	await _attendre(22)
	await _capture("occ_yeux_rouges.png")

	# téléportation vers la caméra, loin du coup
	h.commandes.deplacement = Vector3(0.7, 0, 0.7)
	_demander(&"esquive")
	await _attendre(2)
	h.commandes.deplacement = Vector3.ZERO
	await _attendre(7)
	await _capture("occ_teleportation.png")

	await _attendre(30)
	_demander(&"competence_1")
	await _attendre(25)
	await _capture("occ_marque.png")

	_demander(&"attaque")
	await _attendre(16)
	await _capture("occ_projectile.png")

	await _attendre(40)
	_demander(&"competence_2")
	await _attendre(30)
	await _capture("occ_chaines.png")
	quit()
