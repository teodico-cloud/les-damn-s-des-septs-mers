extends SceneTree
## Capture d'écran d'une scène du jeu (pour vérifier le rendu sans téléphone).
## Usage : godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 1280x720 \
##         -s <chemin absolu>/tools/capture_scene.gd -- res://scene.tscn sortie.png [nb_actions] [nb_images]
## nb_actions : nombre d'appels à action_suivante() avant la capture (si la scène l'a).
## Sort avec le code 1 si la capture n'a pas pu être enregistrée.

func _initialize() -> void:
	_capturer()


func _capturer() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("Usage : -- res://scene.tscn sortie.png [nb_actions] [nb_images]")
		quit(1)
		return
	var scene: Node = load(args[0]).instantiate()
	root.add_child(scene)
	var actions := int(args[2]) if args.size() > 2 else 0
	var images := int(args[3]) if args.size() > 3 else 30
	for i in 10:
		await process_frame
	for i in actions:
		if scene.has_method("action_suivante"):
			scene.call("action_suivante")
	for i in images:
		await process_frame
	await RenderingServer.frame_post_draw
	var sortie := ProjectSettings.globalize_path(args[1]) if args[1].begins_with("res://") else args[1]
	DirAccess.make_dir_recursive_absolute(sortie.get_base_dir())
	var err := root.get_texture().get_image().save_png(sortie)
	if err != OK:
		push_error("Impossible d'enregistrer la capture : %s (erreur %d)" % [sortie, err])
		quit(1)
		return
	print("Capture enregistrée : ", sortie)
	quit()
