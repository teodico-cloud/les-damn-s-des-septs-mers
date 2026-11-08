extends SceneTree
## Captures (08/11) : écran titre, « Comment jouer » (chaque onglet), « Crédits » (haut, puis licences dépliées et défilées).
## Usage : xvfb-run -a godot --path . <rendu> -s "$PWD/tools/capture_aide.gd" -- <dossier>
var dossier := ""
func _initialize() -> void:
	dossier = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(dossier)
	_go()
func _cap(nom: String, n := 20) -> void:
	for i in n:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(dossier.path_join(nom))
	print("Capture : ", nom)
func _go() -> void:
	var e = load("res://ui/screens/demarrage.tscn").instantiate()
	e.changer_de_scene = false
	root.add_child(e)
	await _cap("titre.png", 90)
	e.ouvrir_aide()
	for o in e.panneau_aide.ONGLETS:
		e.panneau_aide.choisir_onglet(o)
		await _cap("aide_%s.png" % o, 25)
	e.fermer_parchemin()
	await _cap("titre_apres.png", 10)
	e.ouvrir_credits()
	await _cap("credits.png", 25)
	e.panneau_credits.montrer_licences()
	await _cap("credits_licences.png", 10)
	var d: ScrollContainer = e.panneau_credits.contenu.get_parent()
	d.scroll_vertical = 900
	await _cap("credits_defile.png", 10)
	quit(0)
