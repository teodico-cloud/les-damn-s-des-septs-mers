extends SceneTree
## Captures du repaire (jalon 5) : la grotte vue de jeu (héros au milieu, au quai, devant chaque lieu),
## vue de dessus (vérifier le plan), et les panneaux de la salle des cartes et de l'entrepôt ; « matieres » :
## les tas de matériaux au sol en expédition, le sac en haut à gauche, l'écran de fin (entrepôt plein) ;
## « chantier » : le chantier naval (pauvre puis riche), la pastille, le navire avant et après ses améliorations,
## la malédiction limitée par la coque ; « bordee » : la zone visée, les boulets qui tombent, les explosions ;
## « forge » : ses trois onglets (améliorer, recycler avec confirmation, relancer), l'entrepôt à agrandir.
## Usage : xvfb-run -a godot --path . --rendering-method gl_compatibility --rendering-driver opengl3
##         --resolution 1280x720 -s <chemin absolu>/tools/capture_repaire.gd -- <dossier> [vues|panneaux|dessus|matieres|chantier|bordee|forge]
## Ne pas typer avec les classes du jeu (voir CLAUDE.md, pièges).

var dossier := ""
var repaire


func _initialize() -> void:
	_go()


func _images(n: int) -> void:
	for i in n:
		await physics_frame


## Entre deux actions dans un panneau, le doigt se lève (un double appui y est ignoré : PanneauRepaire).
func _doigt_leve() -> void:
	await create_timer(0.5).timeout


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
	await process_frame   # (les services globaux se chargent après _initialize)
	var args := OS.get_cmdline_user_args()
	dossier = args[0] if args.size() > 0 else "build/apercus/repaire"
	var quoi: String = args[1] if args.size() > 1 else "tout"
	if quoi == "matieres":
		await _matieres()
		quit()
		return
	if quoi == "chantier":
		await _chantier()
		quit()
		return
	if quoi == "bordee":
		await _bordee()
		quit()
		return
	if quoi == "forge":
		await _forge()
		quit()
		return
	var sauvegarde = root.get_node("Sauvegarde")
	sauvegarde.chemin = "user://sauvegarde_captures.json"
	sauvegarde.reinitialiser()
	sauvegarde.encaisser("capture", [
		{"id": "s1", "base": "sabre", "rarete": 1, "effets": {"vol_de_vie": 0.03}},
		{"id": "f1", "base": "fiole", "rarete": 0, "effets": {}},
		{"id": "l1", "base": "lame_du_noye", "rarete": 3, "effets": {}},
	], 312, {}, {"bois": 47, "fer": 12, "essence": 40})
	sauvegarde.equiper(&"bretteur", "arme", "l1")
	root.get_node("Partie").heros_local = &"bretteur"
	root.get_node("Partie").lieu_repaire = &"quai"
	repaire = load("res://game/repaire/repaire.tscn").instantiate()
	repaire.changer_de_scene = false
	root.add_child(repaire)
	await _images(30)
	if quoi in ["tout", "vues"]:
		await _capture("repaire_quai.png")
		for lieu in [&"cartes", &"chantier", &"forge", &"entrepot"]:
			_aller(repaire.LIEUX[lieu]["pos"] + Vector3(0.3, 0, 0.6))
			await _images(30)
			await _capture("repaire_%s.png" % lieu)
	if quoi in ["tout", "dessus"]:
		var cam := Camera3D.new()
		root.add_child(cam)
		cam.look_at_from_position(Vector3(-2.0, 30.0, 0.5), Vector3(-2.0, 0, 0), Vector3.FORWARD)
		cam.fov = 60.0
		cam.current = true
		repaire.hud.visible = false
		await _images(4)
		await _capture("repaire_dessus.png")
		cam.queue_free()
		repaire.camera.current = true
		repaire.hud.visible = true
	if quoi in ["tout", "panneaux"]:
		repaire.ouvrir(&"cartes")
		await _images(6)
		await _capture("repaire_panneau_cartes.png")
		repaire.hud.fermer_panneau()
		repaire.ouvrir(&"entrepot")
		await _images(6)
		await _capture("repaire_panneau_entrepot.png")
		repaire.hud.fermer_panneau()
		repaire.ouvrir(&"chantier")
		await _images(6)
		await _capture("repaire_message_chantier.png")
	quit()


func _matieres() -> void:
	var partie = root.get_node("Partie")
	var sauvegarde = root.get_node("Sauvegarde")
	sauvegarde.chemin = "user://sauvegarde_captures.json"
	sauvegarde.reinitialiser()
	sauvegarde.encaisser("avant", [], 0, {}, {"essence": sauvegarde.plafond("essence") - 1})   # (presque plein)
	partie.heros_local = &"bretteur"
	partie.destination = &"expedition"
	partie.debug_sante_infinie = true
	var e = load("res://game/expedition/expedition.tscn").instantiate()
	root.add_child(e)
	await _images(60)
	e.hud.menu_demande.disconnect(e.retour_menu)
	e.generateur.reserve = 0
	for s in e.generateur.get_children():
		if s.get("sante"):
			s.queue_free()
	var h = e.heros
	var centre := Vector3(0.5, 0, 0.5)
	h.global_position = centre + Vector3(-0.4, 0, 2.6)
	var poses := [["bois", 4, Vector3(-1.6, 0, -0.6)], ["fer", 2, Vector3(0.0, 0, -1.3)], ["essence", 3, Vector3(1.6, 0, -0.5)],
			["doublons", 9, Vector3(0.8, 0, 0.8)]]
	for p in poses:
		e._lacher(h, {}, p[1], centre + p[2] + Vector3(0, 0, -1.0), centre + p[2], p[0])
	await _images(40)
	e.camera.recentrer()
	await _capture("matieres_au_sol.png")
	for p in poses:
		h.global_position = centre + p[2]
		await _images(4)
	h.global_position = centre + Vector3(-0.4, 0, 2.6)
	await _images(6)
	await _capture("matieres_ramassees.png")
	print("sac : ", e.hud.label_sac.text, " / ", e.hud.label_matieres.text)
	e._mettre_au_sac(String(h.name), {"id": "x1", "base": "hache", "rarete": 2, "effets": {}}, 0)
	e._terminer(true)
	await _images(40)
	await _capture("matieres_fin.png")
	print("entrepôt : ", sauvegarde.donnees["ressources"], " doublons ", sauvegarde.doublons())
	e.queue_free()
	await _images(3)
	await _studio_matieres()


## Gros plan des tas, dans un petit studio (sol, torche) : pièces, bois de coque, fer noir, essence maudite.
func _studio_matieres() -> void:
	var studio := Node3D.new()
	root.add_child(studio)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.03, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.4, 0.55)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	we.environment = env
	studio.add_child(we)
	for x in [-3.2, 0.0, 3.2]:
		for z in [-3.2, 0.0]:
			var dalle: Node3D = load("res://assets/models/decor/floor_tile_large.glb").instantiate()
			dalle.position = Vector3(x, 0, z)
			dalle.scale = Vector3.ONE * 0.8
			studio.add_child(dalle)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.7, 0.45)
	l.light_energy = 2.4
	l.omni_range = 9.0
	l.position = Vector3(0.5, 3.0, 2.0)
	studio.add_child(l)
	var ObjetAuSol = load("res://game/butin/objet_au_sol.gd")
	var x := -2.1
	for p in [["doublons", 9], ["bois", 4], ["fer", 2], ["essence", 3]]:
		var o = ObjetAuSol.creer({}, p[1], "Heros", Vector3(x, 0, -0.5), Vector3(x, 0, -0.5), p[0])
		studio.add_child(o)
		x += 1.4
	var cam := Camera3D.new()
	studio.add_child(cam)
	cam.fov = 42.0
	cam.look_at_from_position(Vector3(0, 2.4, 3.6), Vector3(0, 0.4, -0.5))
	cam.current = true
	await _images(40)
	await _capture("matieres_gros_plan.png")


func _chantier() -> void:
	var sauvegarde = root.get_node("Sauvegarde")
	sauvegarde.chemin = "user://sauvegarde_captures.json"
	sauvegarde.reinitialiser()
	sauvegarde.encaisser("capture", [], 90, {}, {"bois": 20, "fer": 3})
	root.get_node("Partie").heros_local = &"bretteur"
	root.get_node("Partie").lieu_repaire = &"chantier"
	repaire = load("res://game/repaire/repaire.tscn").instantiate()
	repaire.changer_de_scene = false
	root.add_child(repaire)
	await _images(30)
	await _capture("chantier_pastille.png")
	repaire.ouvrir(&"chantier")
	await _images(6)
	await _capture("chantier_panneau.png")
	repaire.hud.fermer_panneau()
	# le navire, tel quel puis tout amélioré, vu de près
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.fov = 45.0
	cam.look_at_from_position(Vector3(-3.0, 5.5, 8.5), Vector3(-9.4, 1.6, 0.4))
	cam.current = true
	repaire.hud.visible = false
	await _images(4)
	await _capture("navire_avant.png")
	repaire.navire.appliquer({"cale": 3, "voiles": 3, "coque": 3, "bordee": 3})
	await _images(4)
	await _capture("navire_apres.png")
	cam.queue_free()
	repaire.camera.current = true
	repaire.hud.visible = true
	# riche : on achète, le panneau suit
	sauvegarde.donnees["doublons"] = 600
	sauvegarde.donnees["ressources"] = {"bois": 80, "fer": 80, "essence": 40}   # (sous les plafonds 150 / 80 / 40)
	repaire.navire.appliquer(load("res://game/repaire/bateau.gd").niveaux())
	repaire.ouvrir(&"chantier")
	await _images(4)
	repaire.hud.panneau.acheter("bordee", 1)
	await _doigt_leve()
	repaire.hud.panneau.acheter("voiles", 1)
	await _images(6)
	await _capture("chantier_achete.png")
	repaire.hud.fermer_panneau()
	repaire.ouvrir(&"cartes")
	await _images(6)
	await _capture("cartes_coque.png")


func _bordee() -> void:
	var partie = root.get_node("Partie")
	var sauvegarde = root.get_node("Sauvegarde")
	sauvegarde.chemin = "user://sauvegarde_captures.json"
	sauvegarde.reinitialiser()
	sauvegarde.donnees["bateau"]["bordee"] = 3
	partie.heros_local = &"bretteur"
	partie.destination = &"expedition"
	partie.debug_sante_infinie = true
	partie.debug_depart = &""
	var e = load("res://game/expedition/expedition.tscn").instantiate()
	root.add_child(e)
	await _images(150)   # (la horde sort de terre)
	e.hud.menu_demande.disconnect(e.retour_menu)
	var hud = e.hud
	var centre: Vector2 = hud.bouton_bordee.centre_ecran()
	var toucher := InputEventScreenTouch.new()
	toucher.index = 3
	toucher.pressed = true
	toucher.position = centre
	hud._input(toucher)
	var glisser := InputEventScreenDrag.new()
	glisser.index = 3
	glisser.position = centre + Vector2(-60, -110)
	hud._input(glisser)
	await _images(3)
	await _capture("bordee_visee.png")
	toucher.pressed = false
	hud._input(toucher)
	Engine.time_scale = 0.15
	await _images(12)
	await _capture("bordee_annonce.png")
	await _images(28)
	await _capture("bordee_impact.png")
	Engine.time_scale = 1.0
	await _images(60)
	await _capture("bordee_apres.png")


func _forge() -> void:
	var sauvegarde = root.get_node("Sauvegarde")
	sauvegarde.chemin = "user://sauvegarde_captures.json"
	sauvegarde.reinitialiser()
	sauvegarde.rng.seed = 3
	sauvegarde.encaisser("capture", [
		{"id": "s1", "base": "sabre", "rarete": 0, "effets": {}},
		{"id": "h1", "base": "hache", "rarete": 1, "effets": {"critique": 0.06}},
		{"id": "c1", "base": "coutelas", "rarete": 2, "effets": {"pv": 10.0, "epines": 0.2}},
		{"id": "f1", "base": "fiole", "rarete": 1, "effets": {"vitesse": 0.06}},
		{"id": "k1", "base": "cle", "rarete": 0, "effets": {}},
	], 0)
	sauvegarde.equiper(&"bretteur", "arme", "h1")
	sauvegarde.donnees["doublons"] = 640
	sauvegarde.donnees["ressources"] = {"bois": 70, "fer": 70, "essence": 30}   # (sous les plafonds 150 / 80 / 40)
	root.get_node("Partie").heros_local = &"bretteur"
	root.get_node("Partie").lieu_repaire = &"forge"
	repaire = load("res://game/repaire/repaire.tscn").instantiate()
	repaire.changer_de_scene = false
	root.add_child(repaire)
	await _images(30)
	await _capture("forge_pastilles.png")
	repaire.ouvrir(&"forge")
	await _images(6)
	await _capture("forge_ameliorer.png")
	var p = repaire.hud.panneau
	p.ameliorer("s1", 0)
	await _images(4)
	await _capture("forge_amelioree.png")
	p.choisir_onglet("recycler")
	await _doigt_leve()
	p.recycler("k1")
	await _images(4)
	await _capture("forge_recycler_confirmer.png")
	await _doigt_leve()
	p.recycler("k1")
	await _images(4)
	await _capture("forge_recycle.png")
	p.choisir_onglet("relancer")
	await _images(4)
	await _capture("forge_relancer_verrou.png")
	await _doigt_leve()
	p.agrandir()
	await _images(4)
	await _capture("forge_relancer.png")
	await _doigt_leve()
	p.relancer("c1", "epines")
	await _images(4)
	await _capture("forge_relance.png")
	repaire.hud.fermer_panneau()
	repaire.ouvrir(&"entrepot")
	await _images(6)
	await _capture("entrepot_agrandir.png")


func _aller(p: Vector3) -> void:
	repaire.heros.global_position = p
	repaire.camera.recentrer()
