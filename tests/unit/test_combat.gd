extends GutTest
## Règles du combat du jalon 1 : coups, combo, esquive, parade-riposte, fente, visée assistée,
## annonce et coup du squelette, mort et réapparition. Monde de test minimal (sol + combattants),
## sans interface ni effets, pour que le minutage soit exact (60 images de physique = 1 s).

const EQ: Equilibrage = preload("res://data/equilibrage.tres")

var monde: Node3D
var heros: Heros



## Dégâts exacts dans ces tests : pas de coup critique (testés à part dans test_critiques.gd).
func before_all() -> void:
	Combat.chance_critique = 0.0


func after_all() -> void:
	Combat.chance_critique = -1.0


func before_each() -> void:
	Engine.time_scale = 1.0
	monde = Node3D.new()
	add_child_autofree(monde)
	var sol := StaticBody3D.new()
	sol.collision_layer = Combat.COUCHE_MONDE
	var forme := CollisionShape3D.new()
	var boite := BoxShape3D.new()
	boite.size = Vector3(60, 0.2, 60)
	forme.shape = boite
	sol.add_child(forme)
	sol.position.y = -0.1
	monde.add_child(sol)
	heros = Bretteur.new()
	monde.add_child(heros)
	await wait_physics_frames(3)


func _ennemi(pos: Vector3, immobile := true) -> Ennemi:
	var e := Ennemi.creer(true)
	e.position = pos   # avant add_child : sinon il apparaît un instant sur le héros et le soulève
	monde.add_child(e)
	if immobile:
		e.set_physics_process(false)
	return e


## Squelette solide : pour les tests qui enchaînent plus de coups qu'il n'a de PV (30).
func _robuste(e: Ennemi) -> Ennemi:
	e.sante.pv_max = 500.0
	e.sante.pv = 500.0
	return e


func _secondes(s: float) -> void:
	await wait_physics_frames(int(ceil(s * 60.0)) + 1)


func _demander(action: StringName) -> void:
	heros.commandes.demander(action, heros.horloge)


# ---------------------------------------------------------------- attaque
func test_un_coup_touche_l_ennemi_devant() -> void:
	var e := _ennemi(Vector3(0, 0, 1.6))
	_demander(&"attaque")
	await _secondes(0.45)
	assert_eq(e.sante.pv, EQ.squelette_pv_max - EQ.combo_degats[0], "Le premier coup du combo doit toucher")


func test_un_coup_ne_touche_pas_derriere() -> void:
	var e := _ennemi(Vector3(0, 0, -1.6))
	heros.commandes.deplacement = Vector3(0, 0, 1)   # joystick vers l'avant : pas de visée assistée
	_demander(&"attaque")
	await _secondes(0.45)
	assert_eq(e.sante.pv, EQ.squelette_pv_max, "Un ennemi dans le dos ne doit pas être touché")


func test_combo_de_trois_coups() -> void:
	var e := _robuste(_ennemi(Vector3(0, 0, 1.6)))
	var coups: Array[float] = []
	e.sante.touche.connect(func(degats: float, _source: Node): coups.append(degats))
	# bouton Attaque maintenu (l'interface redemande l'attaque à chaque image)
	for i in 150:
		_demander(&"attaque")
		await wait_physics_frames(1)
		if coups.size() >= 4:
			break
	assert_eq(coups.size(), 4, "Coups reçus : %s" % [coups])
	if coups.size() >= 4:
		assert_eq(coups[0], EQ.combo_degats[0], "1er coup")
		assert_eq(coups[1], EQ.combo_degats[1], "2e coup")
		assert_eq(coups[2], EQ.combo_degats[2], "3e coup, le plus fort")
		assert_eq(coups[3], EQ.combo_degats[0], "Puis le combo recommence au 1er coup")


func test_visee_assistee_tourne_vers_l_ennemi() -> void:
	var e := _ennemi(Vector3(1.6, 0, 0))   # sur le côté
	_demander(&"attaque")
	await _secondes(0.45)
	assert_almost_eq(heros.avant().x, 1.0, 0.05, "Le héros doit se tourner vers l'ennemi")
	assert_lt(e.sante.pv, EQ.squelette_pv_max, "Et le toucher")


func test_la_visee_ignore_un_squelette_qui_sort_de_terre() -> void:
	var sortant := Ennemi.creer()   # animation de sortie de terre : intouchable pendant ~2 s
	sortant.position = Vector3(-1.5, 0, 0)
	monde.add_child(sortant)
	sortant.set_physics_process(false)
	_ennemi(Vector3(3.0, 0, 0))     # actif, plus loin
	assert_eq(sortant.etat, Ennemi.Etat.APPARITION)
	assert_almost_eq(heros.direction_visee().x, 1.0, 0.05, "On vise le squelette actif, pas celui qui sort de terre")


func test_le_joystick_a_priorite_sur_la_visee() -> void:
	_ennemi(Vector3(1.6, 0, 0))
	heros.commandes.deplacement = Vector3(0, 0, -1)
	_demander(&"attaque")
	await _secondes(0.1)
	assert_almost_eq(heros.avant().z, -1.0, 0.05, "Avec le joystick poussé, on frappe dans sa direction")


# ---------------------------------------------------------------- esquive
func test_esquive_rend_invulnerable_puis_plus() -> void:
	var e := _ennemi(Vector3(0, 0, 3))
	_demander(&"esquive")
	await wait_physics_frames(2)
	assert_eq(heros.etat, Heros.Etat.ESQUIVE)
	assert_eq(Combat.porter_coup(e, heros, 15.0, false), 0.0, "Pendant l'esquive, aucun dégât")
	await _secondes(EQ.esquive_invulnerabilite + 0.1)
	assert_eq(Combat.porter_coup(e, heros, 15.0, false), 15.0, "Après la fenêtre, les coups portent")


func test_esquive_a_un_temps_de_recharge() -> void:
	_demander(&"esquive")
	await wait_physics_frames(2)
	assert_false(heros.recharge_esquive.prete(), "Juste après une esquive, elle n'est pas prête")
	await _secondes(EQ.esquive_recharge)
	assert_true(heros.recharge_esquive.prete(), "Elle redevient prête après sa recharge")


func test_esquive_traverse_le_squelette_sans_le_pousser() -> void:
	# squelette qui prépare son coup juste devant : on roule à travers lui et on sort de sa zone
	var e := _ennemi(Vector3(0, 0, 1.7), false)
	await _secondes(0.1)
	assert_eq(e.etat, Ennemi.Etat.PREPARATION)
	var depart := e.global_position
	_demander(&"esquive")
	await _secondes(EQ.esquive_duree + 0.05)
	assert_lt(e.global_position.distance_to(depart), 0.3, "Le squelette ne doit pas être poussé par la roulade")
	assert_gt(heros.global_position.z, e.global_position.z + 1.0, "Le héros est passé derrière lui")
	await _secondes(EQ.squelette_preparation)
	assert_eq(heros.sante.pv, EQ.heros_pv_max, "Le coup du squelette tombe dans le vide")


func test_esquive_deplace_le_heros() -> void:
	_demander(&"esquive")
	await _secondes(EQ.esquive_duree + 0.1)
	assert_almost_eq(heros.global_position.z, EQ.esquive_distance, 0.4, "L'esquive fait rouler vers l'avant")


# ---------------------------------------------------------------- parade-riposte
func test_parade_de_face_declenche_la_riposte() -> void:
	var e := _ennemi(Vector3(0, 0, 1.5))
	_robuste(e)
	_demander(&"competence_1")
	await wait_physics_frames(2)
	assert_eq(heros.etat, Heros.Etat.PARADE)
	assert_eq(Combat.porter_coup(e, heros, 15.0, false), 0.0, "Le coup de face est paré")
	assert_eq(heros.etat, Heros.Etat.RIPOSTE)
	await _secondes(EQ.riposte_instant_impact / 1.2 + 0.1)
	assert_eq(e.sante.pv, 500.0 - EQ.riposte_degats, "La riposte touche l'attaquant")
	assert_eq(e.etat, Ennemi.Etat.ETOURDI, "L'attaquant est étourdi")


func test_parade_ne_protege_pas_du_dos() -> void:
	var e := _ennemi(Vector3(0, 0, -1.5))
	heros.commandes.deplacement = Vector3(0, 0, 1)
	_demander(&"competence_1")
	await wait_physics_frames(2)
	heros.commandes.deplacement = Vector3.ZERO
	assert_eq(heros.etat, Heros.Etat.PARADE)
	assert_eq(Combat.porter_coup(e, heros, 15.0, false), 15.0, "Un coup dans le dos traverse la parade")


func test_parade_a_un_temps_de_recharge() -> void:
	_demander(&"competence_1")
	await wait_physics_frames(2)
	assert_false(heros.recharge_competence_1.prete())
	await _secondes(EQ.parade_fenetre + 0.1)
	_demander(&"competence_1")
	await wait_physics_frames(2)
	assert_ne(heros.etat, Heros.Etat.PARADE, "Pas de seconde parade avant la fin de la recharge")


# ---------------------------------------------------------------- fente
func test_fente_traverse_et_touche_plusieurs_ennemis() -> void:
	var e1 := _ennemi(Vector3(0, 0, 1.5))
	var e2 := _ennemi(Vector3(0, 0, 3.0))
	heros.commandes.deplacement = Vector3(0, 0, 1)
	_demander(&"competence_2")
	await wait_physics_frames(2)
	heros.commandes.deplacement = Vector3.ZERO
	await _secondes(EQ.fente_duree + 0.2)
	assert_eq(e1.sante.pv, EQ.squelette_pv_max - EQ.fente_degats, "1er ennemi touché une seule fois")
	assert_eq(e2.sante.pv, EQ.squelette_pv_max - EQ.fente_degats, "2e ennemi touché aussi")
	assert_gt(heros.global_position.z, 3.5, "Le héros est passé à travers")
	assert_false(heros.recharge_competence_2.prete(), "La fente est en recharge")


# ---------------------------------------------------------------- squelette
func test_le_squelette_annonce_puis_frappe() -> void:
	heros.set_physics_process(false)   # le héros ne bouge pas
	var e := _ennemi(Vector3(0, 0, 1.6), false)
	e.rotation.y = PI   # tourné vers le héros
	await _secondes(0.2)
	assert_eq(e.etat, Ennemi.Etat.PREPARATION, "À portée, le squelette prépare son coup")
	assert_true(e.marque.visible, "L'annonce au sol est visible")
	assert_eq(heros.sante.pv, EQ.heros_pv_max, "Pas encore de dégâts pendant l'annonce")
	await _secondes(EQ.squelette_preparation)
	assert_eq(heros.sante.pv, EQ.heros_pv_max - EQ.squelette_degats, "Puis le coup porte")


func test_les_yeux_rougeoient_pendant_l_annonce() -> void:
	heros.set_physics_process(false)
	var e := _ennemi(Vector3(0, 0, 1.6), false)
	assert_null(e._yeux.material_override, "Yeux normaux au départ")
	await _secondes(0.2)
	assert_eq(e.etat, Ennemi.Etat.PREPARATION)
	assert_not_null(e._yeux.material_override, "Yeux rouges pendant l'annonce")
	await _secondes(EQ.squelette_preparation + EQ.squelette_duree_frappe)
	assert_null(e._yeux.material_override, "Redeviennent normaux après le coup")


func test_coup_leger_n_interrompt_pas_l_annonce_mais_coup_lourd_oui() -> void:
	heros.set_physics_process(false)
	var e := _ennemi(Vector3(0, 0, 1.6), false)
	await _secondes(0.2)
	assert_eq(e.etat, Ennemi.Etat.PREPARATION)
	Combat.porter_coup(heros, e, 5.0, false)
	assert_eq(e.etat, Ennemi.Etat.PREPARATION, "Un coup léger n'interrompt pas l'annonce")
	Combat.porter_coup(heros, e, 5.0, true)
	assert_eq(e.etat, Ennemi.Etat.TOUCHE, "Un coup lourd l'interrompt")


func test_un_squelette_etourdi_le_reste_meme_frappe() -> void:
	heros.set_physics_process(false)
	var e := _ennemi(Vector3(0, 0, 3), false)
	await wait_physics_frames(2)
	e.etourdir(EQ.riposte_etourdissement)
	Combat.porter_coup(heros, e, 5.0, false)
	Combat.porter_coup(heros, e, 5.0, true)
	await _secondes(EQ.squelette_duree_touche_lourd + 0.1)
	assert_eq(e.etat, Ennemi.Etat.ETOURDI, "Frappé pendant qu'il est sonné, il reste sonné")
	await _secondes(EQ.riposte_etourdissement - EQ.squelette_duree_touche_lourd)
	assert_ne(e.etat, Ennemi.Etat.ETOURDI, "Puis il se reprend à la fin de l'étourdissement")


func test_le_recul_du_squelette_est_en_metres() -> void:
	heros.set_physics_process(false)
	for lourd in [false, true]:
		var e := _ennemi(Vector3(0, 0, 3), false)
		await wait_physics_frames(2)
		var depart := e.global_position
		Combat.porter_coup(heros, e, 1.0, lourd)
		var attendu: float = EQ.squelette_recul_coup_lourd if lourd else EQ.squelette_recul_quand_touche
		# mesuré à la fin du recul, avant qu'il ne reparte à l'attaque
		await _secondes(EQ.squelette_duree_touche_lourd - 0.05 if lourd else EQ.squelette_duree_touche - 0.05)
		assert_almost_eq(e.global_position.distance_to(depart), attendu, 0.12,
			"Recul d'un coup %s" % ("lourd" if lourd else "léger"))
		e.queue_free()
		await wait_physics_frames(1)


func test_la_riposte_laisse_le_temps_de_punir() -> void:
	# après la riposte, le squelette sonné reste à portée du combo
	var e := _ennemi(Vector3(0, 0, 1.5), false)
	_robuste(e)
	e.rotation.y = PI
	_demander(&"competence_1")
	await wait_physics_frames(2)
	Combat.porter_coup(e, heros, 15.0, false)   # son coup, paré de face
	await _secondes(EQ.riposte_instant_impact / EQ.riposte_vitesse_animation + EQ.squelette_duree_touche_lourd)
	assert_eq(e.etat, Ennemi.Etat.ETOURDI)
	var portee_combo := EQ.combo_portee + EQ.combo_pas_en_avant + EQ.combo_rayon + 0.45
	assert_lt(heros.global_position.distance_to(e.global_position), portee_combo,
		"Le squelette sonné n'est pas repoussé hors de portée")


func test_le_squelette_meurt_une_seule_fois() -> void:
	var e := _ennemi(Vector3(0, 0, 3))
	watch_signals(e)
	Combat.porter_coup(heros, e, 500.0, true)
	Combat.porter_coup(heros, e, 500.0, true)
	assert_eq(e.etat, Ennemi.Etat.MORT)
	assert_signal_emit_count(e, "vaincu", 1)
	assert_false(e.is_in_group("ennemis"), "Un mort ne compte plus comme ennemi")


# ---------------------------------------------------------------- mort du héros
func test_mort_puis_reapparition() -> void:
	heros.point_reapparition = Vector3(2, 0, 2)
	Combat.porter_coup(heros, heros, 500.0, false)
	await wait_physics_frames(2)
	assert_eq(heros.etat, Heros.Etat.MORT)
	assert_false(heros.est_vivant())
	assert_almost_eq(heros.temps_avant_reapparition(), EQ.heros_delai_reapparition, 0.1, "Le compte à rebours démarre")
	await _secondes(EQ.heros_delai_reapparition)
	assert_eq(heros.etat, Heros.Etat.LIBRE, "Le héros revient")
	assert_eq(heros.sante.pv, EQ.heros_pv_max, "Avec tous ses PV")
	assert_almost_eq(heros.global_position.x, 2.0, 0.1, "Au point de réapparition")
	assert_true(heros.sante.est_invulnerable(), "Et un instant invulnérable")
