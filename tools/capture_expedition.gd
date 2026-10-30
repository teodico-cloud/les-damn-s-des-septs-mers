extends SceneTree
## Captures de l'expédition (jalon 3) : écran titre et mode test, première salle avec la horde, salle
## nettoyée et portes ouvertes, salle suivante, orbe de vie, trésor, chaloupe, écran de fin.
## Usage : xvfb-run -a godot --path . --rendering-method gl_compatibility --rendering-driver opengl3
##         --resolution 1280x720 -s <chemin absolu>/tools/capture_expedition.gd -- <dossier>
## Ne pas typer avec les classes du jeu (voir CLAUDE.md, pièges).

var dossier := ""
var partie


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


func _expedition(depart: StringName):
	partie.debug_depart = depart
	var e = load("res://game/expedition/expedition.tscn").instantiate()
	root.add_child(e)
	await _images(5)
	e.hud.menu_demande.disconnect(e.retour_menu)
	return e


func _vider(e) -> void:
	for tour in 60:
		for s in e.generateur.get_children():
			if s.etat != 7:
				s.sante.subir(9999.0, e.heros)
		if e.generateur.reserve == 0 and e.generateur.vivants() == 0:
			return
		await _images(20)


func _go() -> void:
	dossier = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "build/apercus"
	partie = root.get_node("Partie")
	partie.heros_local = &"bretteur"
	# écran titre, avec le mode test ouvert
	var titre = load("res://ui/screens/demarrage.tscn").instantiate()
	root.add_child(titre)
	await _images(2)
	titre.panneau_test.visible = true
	await _capture("exp_titre.png")
	titre.queue_free()
	await _images(2)

	# première salle : la horde sort de terre
	var e = await _expedition(&"")
	e.heros.sante.rendre_invulnerable(1000.0)
	await _images(150)
	await _capture("exp_salle1.png")
	# salle nettoyée : les portes s'ouvrent ; une orbe de vie au sol
	load("res://game/arene/arene.gd").chance_orbe = 1.0
	await _vider(e)
	load("res://game/arene/arene.gd").chance_orbe = 0.0
	e.heros.global_position = e.salle.portes[0].devant() + Vector3(2.4, 0, 3.0)
	e.heros.rotation.y = -PI * 0.75
	e.camera.recentrer()
	await _images(40)
	await _capture("exp_portes.png")
	print("salle 1 : %s, portes %s" % [e.modele, e.types_portes])
	# on prend la porte de gauche
	e.heros.global_position = e.salle.portes[1].devant()
	await _images(90)
	print("salle 2 : %s (%s)" % [e.modele, e.type_salle])
	await _images(100)
	await _capture("exp_salle2.png")
	e.queue_free()
	await _images(3)

	# trésor
	e = await _expedition(&"tresor")
	e.heros.sante.definir_pv(35.0)
	e.heros.global_position = e.salle.coffre.global_position + Vector3(1.45, 0, 0.3)
	e.heros.rotation.y = -PI * 0.5
	await _images(12)
	await _capture("exp_tresor.png")
	e.queue_free()
	await _images(3)

	# chaloupe, puis écran de fin
	e = await _expedition(&"chaloupe")
	e.heros.global_position = e.salle.zone_chaloupe + Vector3(2.6, 0, 2.0)
	e.camera.recentrer()
	await _images(30)
	await _capture("exp_chaloupe.png")
	e.heros.global_position = e.salle.zone_chaloupe
	await _images(60)
	await _capture("exp_fin.png")
	e.queue_free()
	await _images(3)
	quit()
