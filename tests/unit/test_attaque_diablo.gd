extends GutTest
## Attaque de base façon Diablo (choix de Téo du 05/11) : le Bretteur bondit sur le squelette visé (jamais dans
## le vide), ses taillades touchent tout un arc, le moulinet tout autour et plus vite ; le tir de l'Occultiste
## s'incurve vers sa cible et explose ; sa téléportation a deux charges de 3 s.
## Même petit monde de test que test_combat.gd (60 images de physique = 1 s).

const EQ: Equilibrage = preload("res://data/equilibrage.tres")

var monde: Node3D


## Dégâts exacts : pas de coup critique (testés à part dans test_nervosite.gd).
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


func _bretteur() -> Bretteur:
	var h := Bretteur.new()
	monde.add_child(h)
	await wait_physics_frames(3)
	return h


func _occultiste() -> Occultiste:
	var o := Occultiste.new()
	monde.add_child(o)
	await wait_physics_frames(3)
	return o


## Un squelette immobile (sorti de terre, ciblable), avec assez de PV pour ne pas tomber.
func _ennemi(pos: Vector3) -> Ennemi:
	var e := Ennemi.creer(true)
	e.position = pos
	monde.add_child(e)
	e.set_physics_process(false)
	e.sante.pv_max = 500.0
	e.sante.pv = 500.0
	return e


func _secondes(s: float) -> void:
	await wait_physics_frames(int(ceil(s * 60.0)) + 1)


func _plat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# ---------------------------------------------------------------- Bretteur : le bond
func test_le_coup_bondit_sur_le_squelette() -> void:
	var h := await _bretteur()
	var e := _ennemi(Vector3(0, 0, 3.2))
	h.commandes.demander(&"attaque", h.horloge)
	await _secondes(EQ.combo_instant_impact[0] / h._vitesse_coup(0) + 0.05)
	assert_almost_eq(_plat(h.global_position, e.global_position), EQ.combo_aimant_contact, 0.3,
			"Au contact pour l'impact (%.2f m)" % _plat(h.global_position, e.global_position))
	assert_eq(e.sante.pv, 500.0 - EQ.combo_degats[0], "Le coup a porté : jamais dans le vide")


func test_trop_loin_pas_de_bond() -> void:
	var h := await _bretteur()
	var e := _ennemi(Vector3(0, 0, EQ.combo_aimant_portee + 1.5))
	h.commandes.demander(&"attaque", h.horloge)
	await _secondes(EQ.combo_instant_impact[0] / h._vitesse_coup(0) + 0.05)
	assert_lt(h.global_position.length(), EQ.combo_pas_en_avant + 0.15, "Un petit pas seulement")
	assert_eq(e.sante.pv, 500.0, "Trop loin : pas touché")


func test_le_bond_suit_le_joystick() -> void:
	# deux squelettes : le joystick choisit celui de droite, même s'il est un peu plus loin
	var h := await _bretteur()
	var gauche := _ennemi(Vector3(-2.0, 0, 1.0))
	var droite := _ennemi(Vector3(2.6, 0, 1.0))
	h.commandes.deplacement = Vector3(1, 0, 0)
	h.commandes.demander(&"attaque", h.horloge)
	await _secondes(EQ.combo_instant_impact[0] / h._vitesse_coup(0) + 0.05)
	assert_lt(_plat(h.global_position, droite.global_position), EQ.combo_aimant_contact + 0.3, "Sur celui de droite")
	assert_eq(droite.sante.pv, 500.0 - EQ.combo_degats[0])
	assert_eq(gauche.sante.pv, 500.0, "Celui de gauche, derrière lui, n'est pas touché")


# ---------------------------------------------------------------- Bretteur : arcs et moulinet
func test_les_taillades_touchent_tout_un_arc() -> void:
	var h := await _bretteur()
	var devant := _ennemi(Vector3(0, 0, 1.4))   # le plus proche : c'est lui que le coup vise
	var cote_g := _ennemi(Vector3(-1.13, 0, 1.13))
	var cote_d := _ennemi(Vector3(1.13, 0, 1.13))
	var derriere := _ennemi(Vector3(0, 0, -2.0))
	h.commandes.demander(&"attaque", h.horloge)
	await _secondes(EQ.combo_instant_impact[0] / h._vitesse_coup(0) + 0.05)
	for e in [devant, cote_g, cote_d]:
		assert_eq(e.sante.pv, 500.0 - EQ.combo_degats[0], "Dans l'arc : touché (%s)" % e.position)
	assert_eq(derriere.sante.pv, 500.0, "Derrière lui : pas touché par une taillade")


func test_le_moulinet_touche_tout_autour_et_va_vite() -> void:
	var h := await _bretteur()
	var autour := []
	for a in [0.0, PI / 2.0, PI, -PI / 2.0]:
		autour.append(_ennemi(Vector3(sin(a), 0, cos(a)) * 1.8))
	h._combo = 1
	h._fin_dernier_coup = h.horloge
	h._commencer_coup(Bretteur.MOULINET)
	assert_almost_eq(h._duree_action, 0.45, 0.03, "Le moulinet dure environ 0,45 s")
	assert_lt(h._duree_action, 0.63 * 0.8, "Au moins 20 % plus court que l'ancien coup lourd (0,63 s)")
	await _secondes(EQ.combo_instant_impact[2] / h._vitesse_coup(2) + 0.05)
	for e in autour:
		assert_eq(e.sante.pv, 500.0 - EQ.combo_degats[2], "Tout autour : touché (%s)" % e.position)
	await _secondes(h._duree_action)
	assert_eq(h.etat, Heros.Etat.LIBRE, "Fini")


# ---------------------------------------------------------------- Occultiste : le tir
func test_le_tir_s_incurve_vers_sa_cible() -> void:
	var o := await _occultiste()
	var e := _ennemi(Vector3(1.6, 0, 5.0))   # à ~18° de la direction du tir
	Projectile.tirer(monde, o, Vector3(0, 1.25, 0.6), Vector3(0, 0, 1), EQ)
	await _secondes(0.8)
	assert_eq(e.sante.pv, 500.0 - EQ.occ_tir_degats, "Le tir, parti droit devant, l'a rattrapé")
	var p := Projectile.tirer(monde, o, Vector3(0, 1.25, 0.6), Vector3(0, 0, 1), EQ)
	p.cible = null   # sans guidage, il passe à côté
	await _secondes(0.8)
	assert_eq(e.sante.pv, 500.0 - EQ.occ_tir_degats, "Tout droit : raté")


func test_le_tir_ne_se_detourne_pas_vers_un_squelette_sur_le_cote() -> void:
	var o := await _occultiste()
	var e := _ennemi(Vector3(4.0, 0, 3.0))   # à 53° : hors du cône
	var p := Projectile.tirer(monde, o, Vector3(0, 1.25, 0.6), Vector3(0, 0, 1), EQ)
	assert_null(p.cible)
	await _secondes(0.8)
	assert_eq(e.sante.pv, 500.0)


func test_le_tir_explose_et_blesse_autour() -> void:
	var o := await _occultiste()
	var cible := _ennemi(Vector3(0, 0, 4.0))
	var voisin := _ennemi(Vector3(0.9, 0, 4.4))
	var loin := _ennemi(Vector3(3.0, 0, 4.0))
	Projectile.tirer(monde, o, Vector3(0, 1.25, 0.6), Vector3(0, 0, 1), EQ)
	await _secondes(0.6)
	assert_eq(cible.sante.pv, 500.0 - EQ.occ_tir_degats, "La cible")
	assert_eq(voisin.sante.pv, 500.0 - EQ.occ_tir_explosion_degats, "Son voisin, pris dans l'explosion")
	assert_eq(loin.sante.pv, 500.0, "Trop loin de l'explosion")
	assert_eq(o.sante.pv, o.sante.pv_max, "Jamais le tireur")


# ---------------------------------------------------------------- Occultiste : la téléportation à charges
func test_teleportation_a_deux_charges() -> void:
	var o := await _occultiste()
	assert_eq(o.recharge_esquive.charges, EQ.occ_tele_charges)
	o.commandes.demander(&"esquive", o.horloge)
	await _secondes(EQ.occ_tele_duree + 0.1)
	var apres_un := o.global_position
	assert_gt(apres_un.length(), 2.0, "Premier saut")
	o.commandes.demander(&"esquive", o.horloge)
	await _secondes(EQ.occ_tele_duree + 0.1)
	var apres_deux := o.global_position
	assert_gt(apres_deux.distance_to(apres_un), 2.0, "Deuxième saut aussitôt")
	assert_false(o.recharge_esquive.prete(), "Plus de charge")
	o.commandes.demander(&"esquive", o.horloge)
	await _secondes(EQ.occ_tele_duree + 0.1)
	assert_almost_eq(o.global_position.distance_to(apres_deux), 0.0, 0.05, "Pas de troisième saut")
	await _secondes(EQ.occ_tele_recharge)
	assert_eq(o.recharge_esquive.charges, 1, "Une charge revient en 3 s")
	await _secondes(EQ.occ_tele_recharge)
	assert_eq(o.recharge_esquive.charges, 2, "Puis l'autre")


func test_le_bouton_montre_les_charges() -> void:
	var r := Recharge.new(3.0, 2)
	var b := BoutonAction.new()
	b.configurer("Téléport", 62.0, r)
	add_child_autofree(b)
	await wait_process_frames(1)
	assert_eq(b.compteur, 2)
	r.declencher()
	await wait_process_frames(1)
	assert_eq(b.compteur, 1, "Une charge de moins sur la pastille")
	assert_true(r.prete(), "Toujours utilisable")
