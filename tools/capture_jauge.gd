extends SceneTree
## Captures de la jauge façon Diablo (06/11, choix de Téo : un globe) : le Bretteur avec un peu de Fureur (pas assez
## pour la Fente : le bouton s'assombrit et son anneau se remplit), puis assez ; l'Occultiste et ses Âmes.
## Usage : xvfb-run -a godot --path . --rendering-method gl_compatibility --rendering-driver opengl3
##         --resolution 1280x720 -s <chemin absolu>/tools/capture_jauge.gd -- <dossier>
## Ne pas typer avec les classes du jeu (voir CLAUDE.md, pièges).

var dossier := ""


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


func _arene(heros: StringName):
	root.get_node("Partie").heros_local = heros
	var a = load("res://game/arene/arene.tscn").instantiate()
	a.changer_de_scene = false
	root.add_child(a)
	await _images(5)
	a.heros.sante.rendre_invulnerable(1000.0)
	await _images(90)
	return a


func _go() -> void:
	await process_frame
	dossier = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "build/apercus/jauge"
	var a = await _arene(&"bretteur")
	a.heros.jauge = 22.0
	a.heros._dernier_combat = a.heros.horloge + 1000.0   # (pas de baisse pendant les captures)
	await create_timer(1.2).timeout
	await _capture("bretteur_pas_assez.png")
	a.heros.jauge = 72.0
	await create_timer(1.2).timeout
	await _capture("bretteur_assez.png")
	a.queue_free()
	await _images(3)
	var o = await _arene(&"occultiste")
	o.heros.jauge = 55.0
	o.heros._dernier_combat = o.heros.horloge + 1000.0
	await create_timer(1.2).timeout
	await _capture("occultiste.png")
	quit()
