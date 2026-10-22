extends GutTest
## Écran de combat au toucher : plusieurs doigts à la fois, bouton Menu, appli mise en arrière-plan.

var hud: HudCombat
var heros: Heros


func before_each() -> void:
	var monde := Node3D.new()
	add_child_autofree(monde)
	heros = Heros.new()
	monde.add_child(heros)
	var camera := CameraCombat.new()
	camera.cible = heros
	monde.add_child(camera)
	hud = HudCombat.new()
	hud.heros = heros
	hud.camera = camera
	monde.add_child(hud)
	await wait_process_frames(2)


func _toucher(index: int, pos: Vector2, appuye: bool, annule := false) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = appuye
	e.canceled = annule
	hud._input(e)


func _cote_joystick() -> Vector2:
	var taille := hud.get_viewport().get_visible_rect().size
	return Vector2(taille.x * 0.2, taille.y * 0.6)


func _centre_menu() -> Vector2:
	return hud.bouton_menu.get_global_rect().get_center()


func test_joystick_et_attaque_en_meme_temps() -> void:
	_toucher(0, _cote_joystick(), true)
	_toucher(1, hud.bouton_attaque.centre_ecran(), true)
	assert_true(hud.joystick.actif, "Le pouce gauche tient le joystick")
	assert_true(hud.bouton_attaque.appuye, "Le pouce droit appuie sur Attaque")
	assert_true(heros.commandes.en_attente(&"attaque", heros.horloge), "L'attaque est demandée au héros")
	_toucher(1, hud.bouton_attaque.centre_ecran(), false)
	assert_false(hud.bouton_attaque.appuye)
	assert_true(hud.joystick.actif, "Lever le doigt d'Attaque ne lâche pas le joystick")


func test_chaque_bouton_demande_son_action() -> void:
	var attendus := {
		hud.bouton_esquive: &"esquive",
		hud.bouton_parade: &"competence_1",
		hud.bouton_fente: &"competence_2",
	}
	var i := 0
	for b in attendus:
		heros.commandes.vider()
		_toucher(i, b.centre_ecran(), true)
		assert_true(heros.commandes.en_attente(attendus[b], heros.horloge), "Bouton %s" % b.texte)
		_toucher(i, b.centre_ecran(), false)
		i += 1


func test_menu_avec_un_second_doigt() -> void:
	watch_signals(hud)
	_toucher(0, _cote_joystick(), true)
	_toucher(1, _centre_menu(), true)
	_toucher(1, _centre_menu(), false)
	assert_signal_emit_count(hud, "menu_demande", 1, "Menu marche même avec le pouce sur le joystick")


func test_menu_toucher_annule_ne_fait_rien() -> void:
	watch_signals(hud)
	_toucher(0, _centre_menu(), true)
	_toucher(0, _centre_menu(), false, true)
	assert_signal_not_emitted(hud, "menu_demande", "Un toucher annulé par le téléphone n'ouvre pas le menu")


func test_toucher_a_droite_hors_bouton_ne_lance_pas_le_joystick() -> void:
	var taille := hud.get_viewport().get_visible_rect().size
	_toucher(0, Vector2(taille.x * 0.6, taille.y * 0.2), true)
	assert_false(hud.joystick.actif)


func test_perte_du_focus_relache_tout() -> void:
	_toucher(0, _cote_joystick(), true)
	_toucher(1, hud.bouton_attaque.centre_ecran(), true)
	hud.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)   # appel, notification, retour à l'accueil…
	assert_false(hud.bouton_attaque.appuye, "Attaque n'est plus enfoncée")
	assert_eq(hud.bouton_attaque.doigt, -1)
	assert_false(hud.joystick.actif, "Le joystick est lâché")
	await wait_process_frames(2)
	assert_eq(heros.commandes.deplacement, Vector3.ZERO, "Le héros s'arrête")
