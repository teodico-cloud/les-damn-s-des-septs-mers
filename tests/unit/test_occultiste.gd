extends GutTest
## L'Occultiste : projectile maudit, téléportation, Marque maudite, Chaînes spectrales.
## Même petit monde de test que test_combat.gd (60 images de physique = 1 s).

const EQ: Equilibrage = preload("res://data/equilibrage.tres")

var monde: Node3D
var occ: Occultiste



## Dégâts exacts dans ces tests : pas de coup critique (testés à part dans test_nervosite.gd).
func before_all() -> void:
	Combat.chance_critique = 0.0


func after_all() -> void:
	Combat.chance_critique = -1.0


func before_each() -> void:
	Engine.time_scale = 1.0
	monde = Node3D.new()
	add_child_autofree(monde)
	_boite(Vector3(0, -0.1, 0), Vector3(60, 0.2, 60))   # sol
	occ = Occultiste.new()
	monde.add_child(occ)
	await wait_physics_frames(3)


func _boite(centre: Vector3, taille: Vector3) -> void:
	var corps := StaticBody3D.new()
	corps.collision_layer = Combat.COUCHE_MONDE
	var forme := CollisionShape3D.new()
	var boite := BoxShape3D.new()
	boite.size = taille
	forme.shape = boite
	corps.add_child(forme)
	corps.position = centre
	monde.add_child(corps)


func _ennemi(pos: Vector3, immobile := true) -> Ennemi:
	var e := Ennemi.creer(true)
	e.position = pos
	monde.add_child(e)
	if immobile:
		e.set_physics_process(false)
	return e


func _secondes(s: float) -> void:
	await wait_physics_frames(int(ceil(s * 60.0)) + 1)


func _demander(action: StringName) -> void:
	occ.commandes.demander(action, occ.horloge)


func _projectiles() -> int:
	var n := 0
	for c in monde.get_children():
		if c is Projectile:
			n += 1
	return n


# ---------------------------------------------------------------- projectile maudit
func test_l_occultiste_a_80_pv() -> void:
	assert_eq(occ.sante.pv_max, EQ.occ_pv_max)
	assert_eq(occ.noms_boutons()[&"competence_1"], "Marque")


func test_le_projectile_touche_l_ennemi_vise() -> void:
	var e := _ennemi(Vector3(3.5, 0, 3.5))   # en diagonale : la visée assistée le trouve
	_demander(&"attaque")
	await _secondes(0.7)
	assert_eq(e.sante.pv, EQ.squelette_pv_max - EQ.occ_tir_degats, "Le projectile touche")
	assert_eq(_projectiles(), 0, "Puis il disparaît")


func test_le_projectile_s_arrete_a_sa_portee() -> void:
	var e := _ennemi(Vector3(0, 0, 12))   # au-delà de la portée (9 m)
	occ.rotation.y = 0.0                   # regarde vers +z
	_demander(&"attaque")
	await _secondes(1.3)
	assert_eq(e.sante.pv, EQ.squelette_pv_max, "Hors de portée : pas touché")
	assert_eq(_projectiles(), 0, "Le projectile a disparu au bout de sa portée")


func test_le_projectile_s_ecrase_sur_un_mur() -> void:
	_boite(Vector3(0, 1.5, 2.5), Vector3(4, 3, 0.4))
	var e := _ennemi(Vector3(0, 0, 5))
	_demander(&"attaque")
	await _secondes(0.45)   # sans le mur, il volerait encore (il ne s'éteint seul que vers 0,8 s)
	assert_eq(_projectiles(), 0, "Le projectile s'est écrasé sur le mur")
	await _secondes(0.4)
	assert_eq(e.sante.pv, EQ.squelette_pv_max, "Le squelette derrière le mur n'est pas touché")


func test_tir_continu_en_gardant_le_doigt() -> void:
	var e := _ennemi(Vector3(0, 0, 4))
	var coups: Array[float] = []
	e.sante.touche.connect(func(d: float, _s: Node): coups.append(d))
	var debut := occ.horloge
	while occ.horloge - debut < 1.5:   # 1,5 s de jeu doigt appuyé (mesuré à l'horloge du héros)
		_demander(&"attaque")
		await wait_physics_frames(1)
	await _secondes(0.4)
	# un tir toutes les 0,45 s : 3 ou 4 tirs en 1,5 s
	assert_between(coups.size(), 3, 4, "Tirs reçus : %d" % coups.size())


func test_le_tir_vise_l_ennemi_dans_la_direction_du_joystick() -> void:
	var e := _ennemi(Vector3(2.4, 0, 6.6))   # à 7 m, 20° à droite de la direction du joystick
	occ.commandes.deplacement = Vector3(0, 0, 1)
	_demander(&"attaque")
	await _secondes(0.9)
	assert_lt(e.sante.pv, EQ.squelette_pv_max, "Le tir part vers l'ennemi du cône, pas droit devant")


func test_il_bouge_des_que_le_tir_est_parti() -> void:
	_ennemi(Vector3(0, 0, 5))
	_demander(&"attaque")
	await _secondes(EQ.occ_tir_instant / EQ.occ_tir_vitesse_animation + 0.05)
	assert_eq(_projectiles(), 1, "Le projectile est parti")
	occ.commandes.deplacement = Vector3(1, 0, 0)
	await _secondes(0.2)
	assert_eq(occ.etat, Heros.Etat.LIBRE, "Le joystick coupe la fin du geste")
	assert_gt(occ.global_position.x, 0.5, "Il se déplace")


func test_la_cadence_reste_la_meme_en_bougeant() -> void:
	var tirs := [0]
	monde.child_entered_tree.connect(func(n: Node): if n is Projectile: tirs[0] += 1)
	var debut := occ.horloge
	while occ.horloge - debut < 1.5:   # doigt sur Attaque et joystick poussé
		occ.commandes.deplacement = Vector3(0, 0, 1) if int((occ.horloge - debut) * 4.0) % 2 == 0 else Vector3(0, 0, -1)
		_demander(&"attaque")
		await wait_physics_frames(1)
	assert_between(tirs[0], 3, 4, "Pas plus d'un tir toutes les %.2f s : %d tirs" % [EQ.occ_tir_cadence, tirs[0]])


# ---------------------------------------------------------------- téléportation
func test_teleportation_sans_joystick_part_en_arriere() -> void:
	occ.rotation.y = 0.0   # regarde vers +z
	_demander(&"esquive")
	await _secondes(EQ.occ_tele_duree + 0.1)
	assert_almost_eq(occ.global_position.z, -EQ.occ_tele_distance, 0.35, "Il recule de 4 m")
	assert_almost_eq(occ.avant().z, 1.0, 0.05, "Et garde son regard vers l'ennemi")


func test_teleportation_saute_a_4_m_et_rend_intouchable() -> void:
	occ.commandes.deplacement = Vector3(0, 0, 1)
	_demander(&"esquive")
	await wait_physics_frames(2)
	occ.commandes.deplacement = Vector3.ZERO
	assert_eq(occ.etat, Heros.Etat.ESQUIVE)
	assert_false(occ.visuel.visible, "Il a disparu")
	assert_true(occ.sante.est_invulnerable(), "Intouchable pendant le saut")
	await _secondes(EQ.occ_tele_duree + 0.1)
	assert_almost_eq(occ.global_position.z, EQ.occ_tele_distance, 0.35, "Réapparu 4 m plus loin")
	assert_true(occ.visuel.visible, "Il est revenu")
	assert_eq(occ.etat, Heros.Etat.LIBRE)
	assert_false(occ.recharge_esquive.prete(), "En recharge")


func test_teleportation_traverse_un_squelette_mais_pas_un_mur() -> void:
	_ennemi(Vector3(0, 0, 1.5))
	_boite(Vector3(0, 1.5, 3.2), Vector3(4, 3, 0.4))   # mur entre 3,0 et 3,4
	occ.commandes.deplacement = Vector3(0, 0, 1)
	_demander(&"esquive")
	await _secondes(EQ.occ_tele_duree + 0.15)
	assert_gt(occ.global_position.z, 2.0, "Il passe à travers le squelette")
	assert_lt(occ.global_position.z, 3.0, "Mais pas à travers le mur")


# ---------------------------------------------------------------- Marque maudite
func test_la_marque_augmente_les_degats() -> void:
	var e := _ennemi(Vector3(0, 0, 3))
	var partenaire := Bretteur.new()
	partenaire.position = Vector3(10, 0, 0)
	monde.add_child(partenaire)
	partenaire.set_physics_process(false)
	_demander(&"competence_1")
	await _secondes(EQ.occ_marque_instant + 0.1)
	assert_true(e.est_marque(), "La cible est marquée")
	assert_true(e._rune.visible, "La rune verte est visible")
	assert_false(occ.recharge_competence_1.prete(), "La Marque est en recharge")
	assert_almost_eq(Combat.porter_coup(occ, e, 10.0, false), 10.0 * (1.0 + EQ.occ_marque_bonus_soi), 0.01, "+15 % pour l'Occultiste")
	assert_almost_eq(Combat.porter_coup(partenaire, e, 10.0, false), 10.0 * (1.0 + EQ.occ_marque_bonus_partenaire), 0.01, "+40 % pour le partenaire")


func test_la_marque_s_efface_au_bout_de_sa_duree() -> void:
	var e := _ennemi(Vector3(0, 0, 3), false)
	_demander(&"competence_1")
	await _secondes(EQ.occ_marque_instant + 0.1)
	assert_true(e.est_marque())
	await _secondes(EQ.occ_marque_duree)
	assert_false(e.est_marque(), "Effacée au bout de %.0f s" % EQ.occ_marque_duree)
	assert_false(e._rune.visible)
	assert_eq(e.multiplicateur_degats(occ), 1.0)


func test_marque_sans_cible_pas_consommee() -> void:
	_demander(&"competence_1")
	await wait_physics_frames(3)
	assert_eq(occ.etat, Heros.Etat.LIBRE, "Personne à marquer : rien ne se passe")
	assert_true(occ.recharge_competence_1.prete(), "Et la Marque n'est pas consommée")


func test_marque_cible_morte_pendant_le_geste_recharge_rendue() -> void:
	var e := _ennemi(Vector3(0, 0, 3))
	_demander(&"competence_1")
	await wait_physics_frames(2)
	assert_eq(occ.etat, Heros.Etat.INCANTATION)
	Combat.porter_coup(occ, e, 500.0, true)   # tué avant que la marque se pose
	await _secondes(EQ.occ_marque_duree_geste)
	assert_true(occ.recharge_competence_1.prete(), "La Marque n'est pas perdue")


# ---------------------------------------------------------------- Chaînes spectrales
func test_sort_coupe_par_un_coup_recharge_rendue() -> void:
	var e := _ennemi(Vector3(0, 0, 3))
	_demander(&"competence_2")
	await wait_physics_frames(2)
	assert_eq(occ.etat, Heros.Etat.INCANTATION)
	Combat.porter_coup(e, occ, 15.0, false)   # frappé avant que les chaînes partent
	assert_eq(occ.etat, Heros.Etat.TOUCHE)
	assert_true(occ.recharge_competence_2.prete(), "Les Chaînes peuvent être relancées aussitôt")
	await _secondes(EQ.occ_chaines_instant + 0.1)
	assert_ne(e.etat, Ennemi.Etat.ENCHAINE, "Le sort coupé ne part pas")


func test_un_etourdissement_ne_raccourcit_pas_les_chaines() -> void:
	var e := _ennemi(Vector3(0, 0, 3), false)
	await wait_physics_frames(2)
	e.immobiliser(2.0)
	e.etourdir(0.5)
	await _secondes(1.0)
	assert_eq(e.etat, Ennemi.Etat.ENCHAINE, "Toujours enchaîné après 1 s")
	e.etourdir(3.0)
	await _secondes(1.5)
	assert_eq(e.etat, Ennemi.Etat.ENCHAINE, "Un étourdissement plus long prolonge l'immobilisation")


func test_les_chaines_immobilisent_et_coupent_l_annonce() -> void:
	var e := _ennemi(Vector3(0, 0, 1.7), false)
	await wait_physics_frames(3)
	assert_eq(e.etat, Ennemi.Etat.PREPARATION, "Le squelette prépare son coup")
	_demander(&"competence_2")
	await _secondes(EQ.occ_chaines_instant + 0.05)
	assert_eq(e.etat, Ennemi.Etat.ENCHAINE, "Il est enchaîné")
	assert_false(e.marque.visible, "Son annonce est coupée")
	assert_not_null(e._chaines, "Les chaînes sont visibles")
	var pos := e.global_position
	Combat.porter_coup(occ, e, 5.0, true)   # même un coup lourd ne le libère pas
	await _secondes(1.0)
	assert_eq(e.etat, Ennemi.Etat.ENCHAINE)
	assert_lt(e.global_position.distance_to(pos), 0.05, "Il ne bouge pas")
	assert_eq(occ.sante.pv, EQ.occ_pv_max, "Son coup n'est jamais parti")
	await _secondes(EQ.occ_chaines_duree - 1.0)
	assert_ne(e.etat, Ennemi.Etat.ENCHAINE, "Libéré au bout de 2 s")
	assert_null(e._chaines, "Les chaînes ont disparu")


func test_les_chaines_ne_prennent_que_la_zone() -> void:
	var proche := _ennemi(Vector3(0, 0, 3))
	var loin := _ennemi(Vector3(0, 0, -7))
	_demander(&"competence_2")
	await _secondes(EQ.occ_chaines_instant + 0.05)
	assert_eq(proche.etat, Ennemi.Etat.ENCHAINE)
	assert_ne(loin.etat, Ennemi.Etat.ENCHAINE, "Hors de la zone : libre")
