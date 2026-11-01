extends SceneTree
## Captures du jalon 4, étape 1 : le butin au sol façon Diablo (les cinq raretés et leurs colonnes de
## lumière, des doublons), le ramassage (fil du butin, sac), le trésor du Bosco, l'écran de fin (victoire :
## butin rapporté ; défaite : butin perdu), le choix de la malédiction. Affiche aussi l'état dans la console.
## Usage : xvfb-run -a godot --path . --rendering-method gl_compatibility --rendering-driver opengl3
##         --resolution 1280x720 -s <chemin absolu>/tools/capture_butin.gd -- <dossier>
## Ne pas typer avec les classes du jeu (voir CLAUDE.md, pièges).

var dossier := ""
var partie
var cam: Camera3D


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


func _regarder(depuis: Vector3, vers: Vector3, fov := 45.0) -> void:
	cam.fov = fov
	cam.look_at_from_position(depuis, vers)
	cam.current = true


func _expedition(depart: StringName):
	partie.debug_depart = depart
	var e = load("res://game/expedition/expedition.tscn").instantiate()
	root.add_child(e)
	await _images(5)
	e.hud.menu_demande.disconnect(e.retour_menu)
	cam = Camera3D.new()
	e.add_child(cam)
	return e


func _objet(base: String, rarete: int) -> Dictionary:
	return {"id": "%s%d" % [base, rarete], "base": base, "rarete": rarete, "effets": []}


func _go() -> void:
	dossier = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "build/apercus"
	partie = root.get_node("Partie")
	partie.heros_local = &"bretteur"
	partie.debug_sante_infinie = true
	partie.destination = &"expedition"
	partie.malediction = 3
	await _vitrine()
	if OS.get_environment("SEULEMENT_VITRINE") != "":
		quit()
		return

	# ---- une salle de combat : les squelettes tombent, le butin jaillit
	var e = await _expedition(&"")
	var h = e.heros
	h.sante.rendre_invulnerable(1000.0)
	await _images(60)
	e.generateur.reserve = 0
	var centre := Vector3(0.5, 0, 0.5)
	h.global_position = centre + Vector3(-0.4, 0, 2.6)
	var poses := [   # les cinq raretés, en arc devant le héros, et des doublons
		[_objet("coutelas", 0), Vector3(-1.8, 0, -0.6)],
		[_objet("sabre", 1), Vector3(-0.6, 0, -1.4)],
		[_objet("chandelle", 2), Vector3(0.9, 0, -1.3)],
		[_objet("lame_du_noye", 3), Vector3(2.0, 0, -0.3)],
		[_objet("coeur_kraken", 4), Vector3(1.4, 0, 1.0)],
		[{}, Vector3(-0.2, 0, 0.4)],
	]
	for p in poses:
		e._lacher(h, p[0], 0 if not p[0].is_empty() else 14, centre + p[1] + Vector3(0, 0, -1.0), centre + p[1])
	for s in e.generateur.get_children():
		if s.get("sante"):
			s.sante.subir(99999.0, h)   # (les squelettes de la salle éclatent : ils lâchent leur part)
	await _images(200)   # (le message « Salle nettoyée » s'efface)
	print("au sol : %d (dont %d visibles)" % [e.butin_au_sol.get_child_count(),
			e.butin_au_sol.get_children().filter(func(o): return o.visible).size()])
	e.camera.current = true
	await _capture("butin_au_sol.png")
	_regarder(centre + Vector3(0.2, 3.6, 5.6), centre + Vector3(0.2, 0.5, -0.4), 50.0)
	await _capture("butin_raretes.png")

	# ---- on passe dessus : le fil du butin et le sac
	e.camera.current = true
	for p in poses.slice(1, 4):
		h.global_position = centre + p[1]
		await _images(3)
	h.global_position = centre + poses[5][1]
	await _images(8)
	h.global_position = centre + Vector3(-0.4, 0, 2.6)
	await _images(4)
	print("sac : ", e.hud.label_sac.text)
	await _capture("butin_ramasse.png")
	e.queue_free()
	await _images(3)

	# ---- le Bosco vaincu : son trésor (au moins un Épique)
	e = await _expedition(&"bosco")
	h = e.heros
	h.sante.rendre_invulnerable(1000.0)
	await _images(60)
	var ou: Vector3 = e.bosco.global_position   # (son nœud disparaît après l'éclatement)
	h.global_position = ou + Vector3(-2.5, 0, 2.5)
	e.bosco.sante.subir(99999.0, h)
	await _images(200)
	print("Bosco : ", e.butin_au_sol.get_children().map(func(o): return o.doublons if o.objet.is_empty() else load("res://game/butin/butin.gd").nom_complet(o.objet)))
	_regarder(ou + Vector3(0.5, 4.2, 5.8), ou + Vector3(0, 0.4, 0), 50.0)
	await _capture("butin_bosco.png")

	# ---- l'écran de fin : victoire (le butin rapporté, à la couleur de sa rareté)
	var nom := String(h.name)
	for o in [_objet("lame_du_noye", 3), _objet("hache", 2), _objet("fiole", 1), _objet("trousseau", 1),
			_objet("cle", 0), _objet("coutelas", 0)]:
		e._mettre_au_sac(nom, o, 0)
	e._mettre_au_sac(nom, {}, 87)
	e._terminer(true)
	await _images(60)
	await _capture("butin_fin_victoire.png")
	e.queue_free()
	await _images(3)

	# ---- défaite : tout le sac est perdu
	e = await _expedition(&"")
	h = e.heros
	await _images(20)
	e._mettre_au_sac(String(h.name), _objet("sabre", 2), 0)
	e._mettre_au_sac(String(h.name), _objet("flasque", 0), 0)
	e._mettre_au_sac(String(h.name), {}, 23)
	e._terminer(false)
	await _images(60)
	await _capture("butin_fin_defaite.png")
	e.queue_free()
	await _images(3)

	# ---- le choix de la malédiction (le texte du butin)
	var ecran = load("res://ui/screens/choix_heros.tscn").instantiate()
	ecran.changer_de_scene = false
	root.add_child(ecran)
	await _images(10)
	await _capture("malediction_choix.png")
	quit()


## Tous les objets du catalogue, posés au sol à côté des deux héros (pour l'échelle), sur fond sombre.
func _vitrine() -> void:
	var Butin = load("res://game/butin/butin.gd")
	var ObjetAuSol = load("res://game/butin/objet_au_sol.gd")
	var studio := Node3D.new()
	root.add_child(studio)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.07, 0.08, 0.1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.62, 0.7)
	env.ambient_light_energy = 0.5
	we.environment = env
	studio.add_child(we)
	var soleil := DirectionalLight3D.new()
	soleil.rotation_degrees = Vector3(-50, 25, 0)
	soleil.light_energy = 0.9
	studio.add_child(soleil)
	var sol := MeshInstance3D.new()
	var plan := PlaneMesh.new()
	plan.size = Vector2(30, 30)
	sol.mesh = plan
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.22, 0.22, 0.25)
	sol.material_override = m
	studio.add_child(sol)
	var rangs := [
		["sabre", "hache", "coutelas", "lame_du_noye"],
		["baguette", "baton", "grimoire", "grimoire_du_pendu"],
		["cle", "fiole", "chandelle", "doublon", "trousseau"],
		["flasque", "sablier_maree", "talisman_pendu", "coeur_kraken", ""],
	]
	for r in rangs.size():
		for i in rangs[r].size():
			var cle: String = rangs[r][i]
			var pos := Vector3(-2.4 + i * 2.0, 0, -3.3 + r * 2.2)
			var o
			if cle == "":
				o = ObjetAuSol.creer({}, 25, "", pos, pos)
			else:
				var rarete: int = Butin.UNIQUES[cle]["rarete"] if Butin.UNIQUES.has(cle) else [0, 1, 2][i % 3]
				o = ObjetAuSol.creer({"id": cle, "base": cle, "rarete": rarete, "effets": []}, 0, "", pos, pos)
			o.etage = i % 2
			studio.add_child(o)
	var dur := StaticBody3D.new()   # (sinon les héros tombent)
	dur.collision_layer = 1
	var forme := CollisionShape3D.new()
	var boite := BoxShape3D.new()
	boite.size = Vector3(30, 0.2, 30)
	forme.shape = boite
	forme.position.y = -0.1
	dur.add_child(forme)
	studio.add_child(dur)
	for k in 2:
		var hh = load("res://game/player/heros.gd").creer([&"bretteur", &"occultiste"][k])
		hh.position = Vector3(-4.4, 0, -2.6 + k * 2.6)
		studio.add_child(hh)
	cam = Camera3D.new()
	studio.add_child(cam)
	_regarder(Vector3(-0.2, 7.6, 7.4), Vector3(-0.2, 0.2, -0.9), 50.0)
	await _images(40)
	await _capture("butin_vitrine.png")
	studio.queue_free()
	await _images(2)
