extends SceneTree
## Capture d'écran d'une scène du jeu (pour vérifier le rendu sans téléphone).
## Usage : godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 \
##         -s <chemin absolu>/tools/capture_scene.gd -- res://scene.tscn sortie.png [actions] [images]

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var scene: Node = load(args[0]).instantiate()
	root.add_child(scene)
	var actions := int(args[2]) if args.size() > 2 else 0
	var images := int(args[3]) if args.size() > 3 else 30
	for i in 10:
		await process_frame
	for i in actions:
		scene.call("action_suivante")
	for i in images:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(args[1])
	quit()
