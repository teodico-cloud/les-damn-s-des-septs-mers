extends GutTest
## Briques de base : points de vie et temps de recharge.

var sante: Sante


func before_each() -> void:
	sante = Sante.new()
	sante.pv_max = 50.0
	add_child_autofree(sante)


func test_degats_et_plancher_a_zero() -> void:
	assert_eq(sante.subir(20.0), 20.0)
	assert_eq(sante.pv, 30.0)
	assert_eq(sante.subir(100.0), 30.0, "On ne perd pas plus que ses PV restants")
	assert_eq(sante.pv, 0.0)
	assert_true(sante.est_mort)


func test_mort_signalee_une_seule_fois() -> void:
	watch_signals(sante)
	sante.subir(60.0)
	sante.subir(60.0)
	assert_signal_emit_count(sante, "mort", 1)


func test_invulnerable_ne_perd_rien() -> void:
	sante.rendre_invulnerable(10.0)
	assert_eq(sante.subir(20.0), 0.0)
	assert_eq(sante.pv, 50.0)


func test_invulnerabilite_en_temps_de_jeu() -> void:
	# pendant un arrêt sur image le jeu est presque figé : l'invulnérabilité doit l'être aussi
	# (sinon une esquive lancée juste après un coup lourd durait moins longtemps)
	sante.set_physics_process(false)   # on fait avancer son horloge de jeu à la main
	sante.rendre_invulnerable(0.1)
	OS.delay_msec(150)                 # du temps réel passe, mais aucun temps de jeu
	assert_true(sante.est_invulnerable(), "Le temps réel seul ne fait pas finir l'invulnérabilité")
	sante._physics_process(0.06)
	assert_true(sante.est_invulnerable(), "Toujours invulnérable après 0,06 s de jeu")
	sante._physics_process(0.06)
	assert_false(sante.est_invulnerable(), "Plus invulnérable après 0,12 s de jeu")


func test_degats_negatifs_ignores() -> void:
	assert_eq(sante.subir(-5.0), 0.0)
	assert_eq(sante.pv, 50.0)


func test_soin_complet_ressuscite() -> void:
	sante.subir(60.0)
	sante.soigner_completement()
	assert_false(sante.est_mort)
	assert_eq(sante.pv, 50.0)


func test_recharge() -> void:
	var r := Recharge.new(2.0)
	assert_true(r.prete())
	r.declencher()
	assert_false(r.prete())
	assert_almost_eq(r.fraction(), 1.0, 0.001)
	r.avancer(1.0)
	assert_almost_eq(r.fraction(), 0.5, 0.001)
	r.avancer(1.5)
	assert_true(r.prete())
	assert_eq(r.restant, 0.0)
