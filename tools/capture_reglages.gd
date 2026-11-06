extends SceneTree
## Captures du jalon 6 (refonte) : l'écran titre avec « Réglages », l'écran Réglages (Normale puis Économie),
## le carnet de bord du repaire, et le repaire en Économie / Normale / Belle (pour comparer).
## Usage : xvfb-run -a godot --path . --rendering-method gl_compatibility --rendering-driver opengl3
##         --resolution 1280x720 -s <chemin absolu>/tools/capture_reglages.gd -- <dossier>
## Ne pas typer avec les classes du jeu (voir CLAUDE.md, pièges). Les réglages des captures vont dans un fichier
## à part (le vrai fichier de réglages n'est pas touché).

var dossier := ""
var reglages


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


func _go() -> void:
	await process_frame   # (les services globaux se chargent après _initialize)
	var args := OS.get_cmdline_user_args()
	dossier = args[0] if args.size() > 0 else "build/apercus/reglages"
	reglages = root.get_node("Reglages")
	reglages.chemin = "user://reglages_captures.json"
	reglages.choisir_qualite(1)
	var sauvegarde = root.get_node("Sauvegarde")
	sauvegarde.chemin = "user://sauvegarde_captures.json"
	sauvegarde.reinitialiser()
	sauvegarde.encaisser("capture", [], 312, {}, {"bois": 47, "fer": 12, "essence": 40})

	# l'écran titre, puis ses réglages
	var titre = load("res://ui/screens/demarrage.tscn").instantiate()
	titre.changer_de_scene = false
	root.add_child(titre)
	await create_timer(1.6).timeout
	await _capture("titre_reglages.png")
	titre.ouvrir_reglages()
	await create_timer(0.6).timeout
	await _capture("reglages_normale.png")
	titre.panneau_reglages.boutons_qualite[0].pressed.emit()
	await create_timer(0.4).timeout
	await _capture("reglages_economie.png")
	titre.fermer_reglages()
	reglages.choisir_qualite(1)
	titre.queue_free()
	await _images(2)

	# le repaire : le carnet de bord, puis les trois qualités
	root.get_node("Partie").heros_local = &"bretteur"
	root.get_node("Partie").lieu_repaire = &"quai"
	var repaire = load("res://game/repaire/repaire.tscn").instantiate()
	repaire.changer_de_scene = false
	root.add_child(repaire)
	await _images(40)
	for q in [[0, "economie"], [1, "normale"], [2, "belle"]]:
		reglages.choisir_qualite(q[0])
		await _images(4)
		await _capture("repaire_%s.png" % q[1])
	reglages.choisir_qualite(1)
	repaire.hud.ouvrir_carnet()
	await create_timer(0.5).timeout
	await _capture("carnet.png")
	repaire.hud.panneau.bouton_reglages.pressed.emit()
	await create_timer(0.6).timeout
	await _capture("reglages_repaire.png")
	reglages.choisir_qualite(1)
	quit()
