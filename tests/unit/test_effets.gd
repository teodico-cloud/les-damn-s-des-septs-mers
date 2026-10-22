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
	EventBus.coup_porte.emit(Vector3.ZERO, 10.0, false, false, null, null)
	assert_lt(Engine.time_scale, 1.0, "Le coup déclenche l'arrêt sur image")
	await _attendre_reel(0.3)
	assert_eq(Engine.time_scale, 1.0, "Puis le jeu reprend sa vitesse normale")


func test_coups_rapproches_puis_reprise() -> void:
	await _effets()
	for i in 3:
		await get_tree().physics_frame
		EventBus.coup_porte.emit(Vector3.ZERO, 10.0, i == 2, false, null, null)
		await _attendre_reel(0.02)
	await _attendre_reel(0.3)
	assert_eq(Engine.time_scale, 1.0, "Plusieurs coups rapprochés : le jeu reprend quand même")
