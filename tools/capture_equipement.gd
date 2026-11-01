extends SceneTree
## Captures du jalon 4, étape 2 : les armes portées en main (chaque arme sur son héros, au repos et en
## plein coup), l'écran Équipement (fiche d'un objet et comparaison ▲▼), et les objets uniques en jeu
## (traînée d'eau de la Lame du Noyé, squelette relevé du Grimoire du Pendu, cercle du Sablier).
## Usage : xvfb-run -a godot --path . --rendering-method gl_compatibility --rendering-driver opengl3
##         --resolution 1280x720 -s <chemin absolu>/tools/capture_equipement.gd -- <dossier> [armes|ecran|uniques]
## Ne pas typer avec les classes du jeu (voir CLAUDE.md, pièges).

var dossier := ""
var partie
var sauvegarde
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


func _objet(base: String, rarete: int, effets := {}) -> Dictionary:
	return {"id": "%s_%d" % [base, rarete], "base": base, "rarete": rarete, "effets": effets}


func _go() -> void:
	var args := OS.get_cmdline_user_args()
	dossier = args[0] if args.size() > 0 else "build/apercus"
	var quoi: String = args[1] if args.size() > 1 else "tout"
	partie = root.get_node("Partie")
	sauvegarde = root.get_node("Sauvegarde")
	sauvegarde.chemin = "user://sauvegarde_captures.json"
	sauvegarde.reinitialiser()
	if quoi in ["tout", "armes"]:
		await _armes()
	if quoi in ["tout", "ecran"]:
		await _ecran()
	if quoi in ["tout", "uniques"]:
		await _uniques()
	quit()


func _arene(heros: StringName, objets: Array):
	sauvegarde.reinitialiser()
	sauvegarde.encaisser("uniques_%s" % heros, objets, 0)
	var places := {"arme": 0, "relique_1": 0, "relique_2": 0}
	for o in objets:
		for e in ["arme", "relique_1", "relique_2"]:
			if places[e] == 0 and sauvegarde.equiper(heros, e, o["id"]):
				places[e] = 1
				break
	partie.heros_local = heros
	partie.destination = &"arene"
	partie.debug_sante_infinie = true
	var a = load("res://game/arene/arene.tscn").instantiate()
	root.add_child(a)
	await _images(5)
	a.hud.menu_demande.disconnect(a.retour_menu)
	a.heros.sante.rendre_invulnerable(1000.0)
	for i in 600:   # (les squelettes sortent de terre)
		await _images(1)
		if a.generateur.get_children().filter(func(s): return s.est_ciblable()).size() >= 4:
			break
	return a


## En jeu : la traînée d'eau de la Lame du Noyé, le cercle du Sablier (squelettes figés), le squelette
## relevé par le Grimoire du Pendu.
func _uniques() -> void:
	var a = await _arene(&"bretteur", [_objet("lame_du_noye", 3), _objet("sablier_maree", 3)])
	var h = a.heros
	var squelettes: Array = a.generateur.get_children().filter(func(s): return s.est_ciblable())
	# 1) la traînée d'eau : une roulade dans une partie vide de la salle (les squelettes tenus au fond)
	for i in squelettes.size():
		squelettes[i].global_position = Vector3(-4.0 + 1.6 * i, 0, -4.6)
		squelettes[i].immobiliser(30.0)
	h.global_position = Vector3(-2.6, 0, 2.2)
	await _images(4)
	h.commandes.deplacement = Vector3(1, 0, -0.35).normalized()
	h.commandes.demander(&"esquive", h.horloge)
	await _images(int(0.45 * 60))
	h.commandes.deplacement = Vector3.ZERO
	await _images(4)
	print("eau : %d flaques" % root.get_tree().get_nodes_in_group("eau_noyee").size())
	a.camera.current = true
	await _capture("unique_lame_du_noye.png")
	await _images(int(3.0 * 60))   # (l'eau s'efface)

	# 2) le Sablier : un coup esquivé au dernier moment fige les squelettes autour de lui
	for i in squelettes.size():
		var ang := TAU * i / squelettes.size()
		squelettes[i]._changer(1)   # (POURSUITE : les chaînes tombent)
		squelettes[i].global_position = h.global_position + Vector3(cos(ang), 0, sin(ang)) * 2.0
	await _images(2)
	h.commandes.demander(&"esquive", h.horloge)
	await _images(3)
	h.sante.invulnerable_jusqua = 0.0
	h.sante.rendre_invulnerable(0.3)
	load("res://game/combat/combat.gd").porter_coup(squelettes[0], h, 10.0, false)
	await _images(10)
	print("figés : %d sur %d" % [squelettes.filter(func(s): return s.etat == 6).size(), squelettes.size()])
	await _capture("unique_sablier.png")
	a.queue_free()
	await _images(3)

	a = await _arene(&"occultiste", [_objet("grimoire_du_pendu", 3)])
	h = a.heros
	var cibles: Array = a.generateur.get_children().filter(func(s): return s.est_ciblable())
	h.global_position = Vector3(0, 0, 2.5)
	for i in mini(2, cibles.size()):
		cibles[i].global_position = Vector3(-1.2 + 2.4 * i, 0, 0.0)
		cibles[i].sante.subir(9999.0, h)
	for c in cibles.slice(2):
		c.global_position = Vector3(-2.5 + 1.6 * cibles.find(c), 0, -2.8)
	await _images(int(1.6 * 60))
	print("allies : %d" % a.generateur.allies())
	a.camera.current = true
	await _capture("unique_grimoire_du_pendu.png")
	a.queue_free()
	await _images(3)


## L'écran Équipement : coffres remplis, un sabre porté ; on touche la hache (comparaison ▲▼), puis
## l'emplacement d'une relique et le Cœur de Kraken ; enfin l'Occultiste.
func _ecran() -> void:
	sauvegarde.encaisser("capture", [
		_objet("sabre", 1, {"vol_de_vie": 0.03}), _objet("hache", 2, {"critique": 0.06, "pv": 10.0}),
		_objet("coutelas", 0), _objet("lame_du_noye", 3), _objet("fiole", 1, {"degats": 0.08}),
		_objet("chandelle", 0), _objet("coeur_kraken", 4), _objet("trousseau", 2, {"vitesse": 0.06, "epines": 0.2}),
		_objet("baton", 2, {"recharges": 0.08, "doublons": 0.15}), _objet("grimoire_du_pendu", 3),
	], 87)
	sauvegarde.equiper(&"bretteur", "arme", "sabre_1")
	sauvegarde.equiper(&"bretteur", "relique_1", "fiole_1")
	partie.heros_local = &"bretteur"
	var ecran = load("res://ui/screens/equipement.tscn").instantiate()
	ecran.changer_de_scene = false
	root.add_child(ecran)
	await _images(20)
	ecran.choisir_objet(sauvegarde.objet("hache_2"))
	await _images(6)
	await _capture("equipement_comparaison.png")
	ecran.choisir_emplacement("relique_2")
	ecran.choisir_objet(sauvegarde.objet("coeur_kraken_4"))
	await _images(6)
	await _capture("equipement_relique.png")
	ecran.equiper_selection()
	ecran.choisir_emplacement("arme")
	ecran.choisir_objet(sauvegarde.objet("hache_2"))
	ecran.equiper_selection()
	await _images(10)
	await _capture("equipement_equipe.png")
	ecran.montrer_heros(&"occultiste")
	ecran.choisir_objet(sauvegarde.objet("grimoire_du_pendu_3"))
	await _images(10)
	await _capture("equipement_occultiste.png")
	print("sauvegarde : ", sauvegarde.donnees["equipement"])
	ecran.queue_free()
	await _images(2)


## Studio sombre et neutre, avec un sol (sinon les héros tombent).
func _studio() -> Node3D:
	var studio := Node3D.new()
	root.add_child(studio)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.12, 0.13, 0.16)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.72, 0.8)
	env.ambient_light_energy = 0.6
	we.environment = env
	studio.add_child(we)
	var soleil := DirectionalLight3D.new()
	soleil.rotation_degrees = Vector3(-40, 25, 0)
	soleil.light_energy = 1.1
	studio.add_child(soleil)
	var sol := MeshInstance3D.new()
	var plan := PlaneMesh.new()
	plan.size = Vector2(30, 30)
	sol.mesh = plan
	studio.add_child(sol)
	var dur := StaticBody3D.new()
	dur.collision_layer = 1
	var forme := CollisionShape3D.new()
	var boite := BoxShape3D.new()
	boite.size = Vector3(30, 0.2, 30)
	forme.shape = boite
	forme.position.y = -0.1
	dur.add_child(forme)
	studio.add_child(dur)
	cam = Camera3D.new()
	studio.add_child(cam)
	return studio


## Chaque arme dans la main de son héros (arme de départ, puis les 4 du jeu), au repos et figé en plein
## coup : une image par héros.
func _armes() -> void:
	var Heros = load("res://game/player/heros.gd")
	var rangs := {&"bretteur": ["", "sabre", "hache", "coutelas", "lame_du_noye"],
			&"occultiste": ["", "baguette", "baton", "grimoire", "grimoire_du_pendu"]}
	for archetype in rangs:
		var studio := _studio()
		var tous := []
		for pose in 2:
			for i in rangs[archetype].size():
				var h = Heros.creer(archetype)
				var cle: String = rangs[archetype][i]
				if cle != "":
					h.equiper([_objet(cle, 3 if cle.contains("_") else 2)])
				h.position = Vector3(-4.0 + i * 2.0, 0, -1.2 + pose * 2.6)
				h.set_meta("coup", pose == 1)
				studio.add_child(h)
				tous.append(h)
		await _images(20)
		for h in tous:
			h.set_physics_process(false)
			h.rotation.y = 0.35
			if h.get_meta("coup"):
				var nom := "1H_Melee_Attack_Slice_Diagonal" if h.archetype == &"bretteur" else "Spellcast_Shoot"
				h._jouer(nom, 1.0, 0.0, true)
				h.anim.seek(0.35 if h.archetype == &"bretteur" else 0.4, true)
				h.anim.pause()
		_regarder(Vector3(0.0, 3.0, 8.4), Vector3(0.0, 1.0, 0.1), 52.0)
		await _images(4)
		await _capture("armes_en_main_%s.png" % archetype)
		studio.queue_free()
		await _images(2)
