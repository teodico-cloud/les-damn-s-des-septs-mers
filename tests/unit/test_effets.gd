extends GutTest
## L'arrêt sur image doit toujours se terminer : Engine.time_scale revient à 1.


func before_each() -> void:
	Engine.max_fps = 60   # cadence d'un téléphone : sans elle, l'écart d'une image est trop petit pour se voir


func after_each() -> void:
	Engine.time_scale = 1.0
	Engine.max_fps = 0


func _attendre_reel(s: float) -> void:
	var fin := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < fin:
		await get_tree().process_frame


func _effets() -> EffetsCombat:
	var effets := EffetsCombat.new()
	add_child_autofree(effets)
	await wait_process_frames(1)
	return effets


func test_arret_sur_image_se_termine() -> void:
	await _effets()
	await get_tree().physics_frame   # en jeu, le coup arrive pendant l'image de physique
	EventBus.coup_porte.emit(Vector3.ZERO, 10.0, false, false, null, null, false)
	assert_lt(Engine.time_scale, 1.0, "Le coup déclenche l'arrêt sur image")
	await _attendre_reel(0.3)
	assert_eq(Engine.time_scale, 1.0, "Puis le jeu reprend sa vitesse normale")


func test_coups_rapproches_puis_reprise() -> void:
	await _effets()
	for i in 3:
		await get_tree().physics_frame
		EventBus.coup_porte.emit(Vector3.ZERO, 10.0, i == 2, false, null, null, false)
		await _attendre_reel(0.02)
	await _attendre_reel(0.3)
	assert_eq(Engine.time_scale, 1.0, "Plusieurs coups rapprochés : le jeu reprend quand même")


func test_parade_parfaite_en_coop_ne_ralentit_rien() -> void:
	var effets := await _effets()
	effets.en_coop = true
	var h := Bretteur.new()
	add_child_autofree(h)
	await wait_physics_frames(2)
	await get_tree().physics_frame
	EventBus.parade_parfaite.emit(h, Vector3.ZERO)
	assert_eq(Engine.time_scale, 1.0, "En coop, le jeu de l'hôte ne ralentit jamais (le partenaire joue aussi)")
	assert_eq(h.anim.speed_scale, 1.0, "Le héros n'est pas figé : sa riposte reste calée sur l'impact")
	assert_true(effets.get_children().any(func(n): return n is Label3D and n.text == "PARFAIT !"), "Mais « PARFAIT ! » s'affiche")


func test_ralenti_de_la_parade_parfaite_puis_reprise() -> void:
	var EQ: Equilibrage = load("res://data/equilibrage.tres")
	var effets := await _effets()
	await get_tree().physics_frame
	EventBus.parade_parfaite.emit(null, Vector3.ZERO)
	assert_almost_eq(Engine.time_scale, EQ.parade_parfaite_ralenti_vitesse, 0.001, "Court ralenti")
	assert_true(effets.get_children().any(func(n): return n is Label3D and n.text == "PARFAIT !"), "« PARFAIT ! » affiché")
	# un coup pendant le ralenti : l'arrêt sur image (plus lent) l'emporte, puis le ralenti continue
	EventBus.coup_porte.emit(Vector3.ZERO, 10.0, false, false, null, null, false)
	assert_almost_eq(Engine.time_scale, EQ.arret_image_vitesse, 0.001)
	await _attendre_reel(EQ.arret_image + 0.06)
	assert_almost_eq(Engine.time_scale, EQ.parade_parfaite_ralenti_vitesse, 0.001, "Le ralenti continue après l'arrêt")
	await _attendre_reel(EQ.parade_parfaite_ralenti)
	assert_eq(Engine.time_scale, 1.0, "Puis le jeu reprend sa vitesse normale")
