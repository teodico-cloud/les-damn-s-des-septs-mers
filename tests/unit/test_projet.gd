extends GutTest
## Vérifie les réglages du projet et l'écran titre.


func test_version_au_format_x_y_z() -> void:
	var v: String = ProjectSettings.get_setting("application/config/version", "")
	var re := RegEx.new()
	re.compile("^\\d+\\.\\d+\\.\\d+$")
	assert_not_null(re.search(v), "La version doit être au format X.Y.Z (lu : '%s')" % v)


func test_rendu_mobile_et_paysage() -> void:
	assert_eq(ProjectSettings.get_setting("rendering/renderer/rendering_method"), "mobile")
	# 4 = paysage avec rotation automatique (les deux sens)
	assert_eq(ProjectSettings.get_setting("display/window/handheld/orientation"), 4)


func test_ecran_titre_se_charge() -> void:
	var chemin: String = ProjectSettings.get_setting("application/run/main_scene")
	var scene = load(chemin)
	assert_true(scene is PackedScene, "La scène principale doit se charger : %s" % chemin)
	var ecran = scene.instantiate()
	add_child_autofree(ecran)
	await wait_process_frames(2)
	assert_not_null(ecran.bouton_vitrine, "Le bouton « Voir les héros » doit exister")
	assert_eq(ecran.bouton_vitrine.text, "Voir les héros")
	assert_not_null(ecran.bouton_combat, "Le bouton « Combat d'entraînement » doit exister")
	assert_eq(ecran.bouton_combat.text, "Combat d'entraînement")


func test_scene_vitrine_existe() -> void:
	assert_true(ResourceLoader.exists("res://game/vitrine/vitrine.tscn"), "La vitrine ouverte par l'écran titre doit exister")


func test_arene_se_construit_et_fait_venir_les_squelettes() -> void:
	var scene = load("res://game/arene/arene.tscn")
	assert_true(scene is PackedScene, "L'arène ouverte par l'écran titre doit exister")
	var arene = scene.instantiate()
	add_child_autofree(arene)
	await wait_process_frames(2)
	assert_not_null(arene.heros, "Le héros est créé")
	assert_not_null(arene.hud, "L'interface est créée")
	assert_true(arene.camera.current, "La caméra de combat est active")
	var eq: Equilibrage = load("res://data/equilibrage.tres")
	await wait_seconds(eq.arene_delai_apparition + 0.5)
	assert_eq(get_tree().get_nodes_in_group("ennemis").size(), eq.arene_nb_ennemis, "Les squelettes arrivent")
	Engine.time_scale = 1.0
