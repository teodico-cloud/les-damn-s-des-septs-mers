extends SceneTree
## Captures de l'attaque façon Diablo (05/11) : le Bretteur qui bondit sur un squelette, une taillade en arc, le
## moulinet ; le tir de l'Occultiste qui explose ; le bouton Téléport et ses charges.
## Usage : xvfb-run -a godot --path . --rendering-method gl_compatibility --rendering-driver opengl3
## --resolution 1280x720 -s <chemin absolu>/tools/capture_attaque.gd -- <dossier>
## Ne pas typer avec les classes du jeu (voir CLAUDE.md, pièges). Le rendu est lent ici : les gestes sont
## ralentis (Engine.time_scale) pour les saisir.

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


func _attendre(condition: Callable, max_images := 600) -> void:
	for i in max_images:
		if condition.call():
			return
		await physics_frame


func _plus_proche():
	var meilleur = null
	var d := INF
	for e in arene.generateur.get_children():
		if e.has_method("est_ciblable") and e.est_ciblable() and e.global_position.distance_to(h.global_position) < d:
			d = e.global_position.distance_to(h.global_position)
			meilleur = e
	return meilleur


func _ouvrir(heros: StringName) -> void:
	if arene:
		arene.queue_free()
		await _images(2)
	root.get_node("Partie").heros_local = heros
	arene = load("res://game/arene/arene.tscn").instantiate()
	root.add_child(arene)
	await _images(5)
	h = arene.heros
	h.sante.rendre_invulnerable(100000.0)
	Engine.time_scale = 1.0
	await _images(150)   # la horde sort de terre et arrive


func _go() -> void:
	dossier = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "build/apercus"
	var combat = load("res://game/combat/combat.gd")
	combat.chance_critique = 0.0
	# --- Bretteur : le bond, puis la taillade en arc
	await _ouvrir(&"bretteur")
	var cible = _plus_proche()
	if cible:
		var dir: Vector3 = (h.global_position - cible.global_position)
		dir.y = 0.0
		h.global_position = cible.global_position + dir.normalized() * 3.6   # à 3,6 m : il doit bondir
	await _images(1)
	await _capture("bond_avant.png")
	Engine.time_scale = 0.1
	h.commandes.demander(&"attaque", h.horloge)
	await _images(70)   # à mi-bond
	await _capture("bond_pendant.png")
	await _attendre(func(): return h._impact_fait)
	await _capture("bond_impact.png")
	Engine.time_scale = 1.0
	await _images(40)
	# --- le moulinet, au milieu de la horde
	cible = _plus_proche()
	if cible:
		h.global_position = cible.global_position + Vector3(0.9, 0, 0.9)
	await _images(2)
	Engine.time_scale = 0.1
	h._combo = 1
	h._fin_dernier_coup = h.horloge
	h._commencer_coup(2)
	await _attendre(func(): return h._t >= 0.58 / h._vitesse_coup(2))   # le tour commence
	await _capture("moulinet_debut.png")
	await _attendre(func(): return h._impact_fait)
	await _capture("moulinet_impact.png")
	await _attendre(func(): return h._t >= 1.1 / h._vitesse_coup(2))
	await _capture("moulinet_fin.png")
	Engine.time_scale = 1.0
	# --- Occultiste : le tir qui explose ; le bouton Téléport et ses charges
	await _ouvrir(&"occultiste")
	cible = _plus_proche()
	if cible:
		var dir: Vector3 = (h.global_position - cible.global_position)
		dir.y = 0.0
		h.global_position = cible.global_position + dir.normalized() * 4.0
	for e in arene.generateur.get_children():
		e.set_physics_process(false)   # (figés : l'explosion se voit au milieu d'eux)
	await _images(1)
	Engine.time_scale = 0.1
	var avant: int = arene.get_children().filter(func(n): return n is CPUParticles3D).size()
	h.commandes.demander(&"attaque", h.horloge)
	await _attendre(func(): return arene.get_children().filter(func(n): return n is CPUParticles3D).size() > avant, 1500)
	await _images(10)
	await _capture("tir_explosion.png")
	await _images(30)
	await _capture("tir_explosion_anneau.png")
	Engine.time_scale = 1.0
	await _images(30)
	h.commandes.demander(&"esquive", h.horloge)
	await _images(20)
	await _capture("teleport_une_charge.png")
	h.commandes.demander(&"esquive", h.horloge)
	await _images(40)
	await _capture("teleport_aucune_charge.png")
	quit()
