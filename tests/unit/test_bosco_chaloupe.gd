extends GutTest
## Jalon 3, étape 3 (choix de Téo) : le Bosco Maudit (brute à la hache, coups mi-parables, sonné contre
## un mur, rage à mi-vie), la malédiction 0–5 choisie au départ, la chaloupe à tenir 45 s à bord,
## l'écran de fin enrichi, et ce que voit l'invité en coop.

const EQ: Equilibrage = preload("res://data/equilibrage.tres")

var monde: Node3D


func before_all() -> void:
	Combat.chance_critique = 0.0


func after_all() -> void:
	Combat.chance_critique = -1.0
	Arene.chance_orbe = -1.0
	Partie.debug_depart = &""
	Partie.destination = &"arene"
	Partie.malediction = 0


func before_each() -> void:
	Engine.time_scale = 1.0
	Partie.revenir_en_solo()
	Partie.heros_local = &"bretteur"
	Partie.debug_depart = &""
	Partie.debug_sante_infinie = false
	Partie.destination = &"arene"
	Partie.malediction = 0
	Arene.chance_orbe = 0.0
	monde = Node3D.new()
	add_child_autofree(monde)
	var sol := StaticBody3D.new()
	sol.collision_layer = Combat.COUCHE_MONDE
	var forme := CollisionShape3D.new()
	var boite := BoxShape3D.new()
	boite.size = Vector3(80, 0.2, 80)
	forme.shape = boite
	sol.add_child(forme)
	sol.position.y = -0.1
	monde.add_child(sol)


func after_each() -> void:
	Engine.time_scale = 1.0
	Partie.destination = &"arene"
	Partie.malediction = 0


func _secondes(s: float) -> void:
	await wait_physics_frames(int(ceil(s * 60.0)) + 1)


func _generateur() -> GenerateurEnnemis:
	var gen := GenerateurEnnemis.new()
	gen.demarrage_auto = false
	gen.nombre = 0
	gen.reserve = 0
	monde.add_child(gen)
	return gen


## Un Bosco déjà sorti de terre, à l'origine, tourné vers +z.
func _bosco(gen: GenerateurEnnemis = null) -> Bosco:
	var b := Ennemi.creer_type(&"bosco", true) as Bosco
	b.name = "Bosco_1"
	if gen:
		gen.add_child(b)
	else:
		monde.add_child(b)
	b.rotation.y = 0.0
	return b


func _heros(type: StringName, pos: Vector3, vers_bosco := true) -> Heros:
	var h := Heros.creer(type)
	h.position = pos
	monde.add_child(h)
	if vers_bosco:
		h.rotation.y = atan2(-pos.x, -pos.z)   # face à l'origine
	return h


func _mur(z: float) -> void:
	var m := StaticBody3D.new()
	m.collision_layer = Combat.COUCHE_MONDE
	var f := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(8, 3, 1)
	f.shape = b
	m.add_child(f)
	m.position = Vector3(0, 1.5, z)
	monde.add_child(m)


## Attend la fin de l'annonce de l'attaque en cours, moins `avant` secondes.
func _attendre_annonce(b: Bosco, avant := 0.0) -> void:
	while b.etat == Ennemi.Etat.PREPARATION and b._t < b._duree_annonce() - avant:
		await wait_physics_frames(1)


# ---------------------------------------------------------------- Bosco
func test_le_bosco() -> void:
	var b := _bosco()
	await wait_physics_frames(2)
	assert_eq(b.sante.pv_max, EQ.bosco_pv, "PV pour ~1 min 30 en solo")
	assert_true(b.is_in_group("boss"), "Barre de vie du boss")
	assert_almost_eq(b.visuel.scale.x, EQ.bosco_taille, 0.001, "Plus grand que les matelots")
	assert_eq(Ennemi.type_depuis_nom("Bosco_7"), &"bosco")


func test_coup_au_sol_touche_devant() -> void:
	var b := _bosco()
	var devant := _heros(&"occultiste", Vector3(0, 0, 3.0))
	var cote := _heros(&"bretteur", Vector3(3.0, 0, 0.5))
	await wait_physics_frames(2)
	b._commencer(Bosco.Attaque.COUP, Vector3(0, 0, 1))
	assert_true(b._annonce.visible, "Zone au sol annoncée")
	assert_false(b.signal_parade(), "Pas encore dorée")
	await _attendre_annonce(b, 0.2)
	assert_true(b.signal_parade(), "Dorée à la fin : c'est le moment de parer")
	await _secondes(0.4)
	assert_eq(devant.sante.pv, EQ.occ_pv_max - EQ.bosco_coup_degats, "Le héros devant est touché")
	assert_eq(cote.sante.pv, 100.0, "Le héros sur le côté, non")


func test_coup_au_sol_se_pare() -> void:
	var b := _bosco()
	var h: Bretteur = _heros(&"bretteur", Vector3(0, 0, 2.6))
	await wait_physics_frames(2)
	b._commencer(Bosco.Attaque.COUP, Vector3(0, 0, 1))
	await _attendre_annonce(b, 0.15)
	h.commandes.demander(&"competence_1", h.horloge)
	await _secondes(0.4)
	assert_eq(h.sante.pv, 100.0, "Paré (choix de Téo : ses coups simples se parent)")
	assert_eq(h.etat, Heros.Etat.RIPOSTE, "Riposte")
	await _secondes(0.6)
	assert_eq(b.etat, Ennemi.Etat.ETOURDI, "La riposte l'étourdit…")
	assert_almost_eq(b._duree_etat, EQ.riposte_etourdissement_parfaite * EQ.bosco_etourdissement, 0.01, "…deux fois moins longtemps qu'un matelot")


func test_tourbillon_imparable() -> void:
	var b := _bosco()
	var h: Bretteur = _heros(&"bretteur", Vector3(0, 0, 2.2))
	var loin := _heros(&"occultiste", Vector3(0, 0, -4.2))
	await wait_physics_frames(2)
	b._commencer(Bosco.Attaque.TOURBILLON, Vector3(0, 0, 1))
	assert_false(b.coup_parable())
	await _attendre_annonce(b, 0.15)
	assert_false(b.signal_parade(), "Jamais doré : imparable")
	h.commandes.demander(&"competence_1", h.horloge)
	await _secondes(0.4)
	assert_eq(h.sante.pv, 100.0 - EQ.bosco_tourbillon_degats, "La Parade ne protège pas du tourbillon")
	assert_eq(loin.sante.pv, EQ.occ_pv_max, "Hors du cercle : rien")


func test_roulade_evite_le_tourbillon() -> void:
	var b := _bosco()
	var h := _heros(&"bretteur", Vector3(0, 0, 2.2))
	await wait_physics_frames(2)
	b._commencer(Bosco.Attaque.TOURBILLON, Vector3(0, 0, 1))
	await _attendre_annonce(b, 0.1)
	h.sante.rendre_invulnerable(0.6)   # comme pendant une roulade
	await _secondes(0.4)
	assert_eq(h.sante.pv, 100.0)


func test_charge_contre_un_mur_il_est_sonne() -> void:
	var b := _bosco()
	_mur(9.5)
	var h := _heros(&"occultiste", Vector3(0.3, 0, 6.0))
	await wait_physics_frames(2)
	b._commencer(Bosco.Attaque.CHARGE, Vector3(0, 0, 1))
	assert_true(b._mur, "La charge finira contre le mur")
	assert_false(b.coup_parable(), "Imparable")
	await _attendre_annonce(b)
	await _secondes(1.0)
	assert_eq(h.sante.pv, EQ.occ_pv_max - EQ.bosco_charge_degats, "Le héros sur sa route est touché une fois")
	assert_eq(b.etat, Ennemi.Etat.ETOURDI, "Contre le mur : sonné")
	assert_gt(b.global_position.z, 7.0, "Il a chargé jusqu'au mur")
	assert_true(b._etoiles != null and b._etoiles.visible, "Étoiles au-dessus de la tête")
	await _secondes(EQ.bosco_charge_sonne + 0.1)
	assert_ne(b.etat, Ennemi.Etat.ETOURDI, "Sonné 2 s (choix de Téo)")
	assert_false(b._etoiles.visible)


func test_charge_sans_mur() -> void:
	var b := _bosco()
	await wait_physics_frames(2)
	b._commencer(Bosco.Attaque.CHARGE, Vector3(0, 0, 1))
	assert_false(b._mur)
	assert_almost_eq(b._longueur_charge, EQ.bosco_charge_longueur, 0.01)
	await _attendre_annonce(b)
	await _secondes(EQ.bosco_charge_longueur / EQ.bosco_charge_vitesse + 0.2)
	assert_eq(b.etat, Ennemi.Etat.RECUPERATION, "Sans mur : il s'arrête et repart")


func test_ni_recul_ni_interruption() -> void:
	var b := _bosco()
	var h := _heros(&"bretteur", Vector3(0, 0, 6.0))
	await wait_physics_frames(2)
	b._commencer(Bosco.Attaque.COUP, Vector3(0, 0, 1))
	await wait_physics_frames(2)
	Combat.porter_coup(h, b, 22.0, true)   # coup lourd : un matelot serait interrompu
	assert_eq(b.etat, Ennemi.Etat.PREPARATION, "Le Bosco continue son attaque")
	assert_eq(b._recul, Vector3.ZERO, "Il ne recule pas")
	assert_eq(b.sante.pv, EQ.bosco_pv - 22.0, "Mais il perd ses PV")


func test_rage_a_mi_vie() -> void:
	var gen := _generateur()
	var b := _bosco(gen)
	var _h := _heros(&"occultiste", Vector3(0, 0, 9.0))
	await wait_physics_frames(2)
	assert_false(b.enrage)
	b.sante.subir(b.sante.pv_max * 0.51)
	await wait_physics_frames(2)
	assert_eq(b.etat, Ennemi.Etat.INCANTATION, "Il crie")
	assert_true(b.enrage, "Enragé")
	await _secondes(EQ.bosco_rage_cri * 0.5)
	var matelots := gen.get_children().filter(func(e): return e is Ennemi and e.type_ennemi() == &"matelot")
	assert_eq(matelots.size(), EQ.bosco_rage_renforts, "Il appelle 3 matelots (choix de Téo)")
	await _secondes(EQ.bosco_rage_cri * 0.6)
	assert_ne(b.etat, Ennemi.Etat.INCANTATION)
	b.sante.subir(10.0)
	await _secondes(0.3)
	assert_ne(b.etat, Ennemi.Etat.INCANTATION, "Une seule rage")
	assert_eq(gen.get_children().filter(func(e): return e is Ennemi and e.type_ennemi() == &"matelot").size(), EQ.bosco_rage_renforts)
	# vaincu : son équipage s'effondre avec lui
	b.sante.subir(99999.0)
	await wait_physics_frames(2)
	for m in matelots:
		assert_false(m.est_vivant(), "L'équipage du Bosco s'effondre avec lui")
	assert_false(b.is_in_group("boss"))


func test_enrage_plus_rapide() -> void:
	var b := _bosco()
	await wait_physics_frames(2)
	b.attaque = Bosco.Attaque.COUP
	var normale := b._duree_annonce()
	b._devenir_enrage()
	assert_almost_eq(b._duree_annonce(), normale / EQ.bosco_rage_vitesse, 0.001)


func test_riposte_sur_le_bosco_qui_approche() -> void:
	# (relecture) le Bosco lance son coup de loin (jusqu'à 4 m) : la riposte doit encore l'atteindre
	var b := _bosco()
	b._recharge_charge = 99.0      # pas de charge : on veut le coup au sol
	b._dernier_tourbillon = true   # ni de tourbillon
	var h: Bretteur = _heros(&"bretteur", Vector3(0, 0, 7.0))
	await _secondes(0.1)
	await _attendre_debut_attaque(b)
	assert_eq(b.attaque, Bosco.Attaque.COUP)
	var distance := b.global_position.distance_to(h.global_position)
	assert_gt(distance, EQ.riposte_distance_max, "Il frappe de plus loin qu'une riposte ordinaire (%.1f m)" % distance)
	h.rotation.y = atan2(b.global_position.x - h.global_position.x, b.global_position.z - h.global_position.z)
	await _attendre_annonce(b, 0.15)
	h.commandes.demander(&"competence_1", h.horloge)
	await _secondes(0.9)
	assert_eq(h.sante.pv, 100.0, "Paré")
	assert_lt(b.sante.pv, EQ.bosco_pv, "La riposte l'atteint")
	assert_eq(b.etat, Ennemi.Etat.ETOURDI, "et l'étourdit")


func _attendre_debut_attaque(b: Bosco) -> void:
	for i in 300:
		if b.etat == Ennemi.Etat.PREPARATION:
			return
		await wait_physics_frames(1)


func test_chaines_pendant_le_cri() -> void:
	# (relecture) des chaînes au début du cri coupaient l'appel : l'équipage ne venait jamais
	var gen := _generateur()
	var b := _bosco(gen)
	var _h := _heros(&"occultiste", Vector3(0, 0, 9.0))
	await wait_physics_frames(2)
	b.sante.subir(b.sante.pv_max * 0.51)
	await wait_physics_frames(3)
	assert_eq(b.etat, Ennemi.Etat.INCANTATION)
	b.immobiliser(2.0)
	await wait_physics_frames(2)
	var matelots := gen.get_children().filter(func(e): return e is Ennemi and e.type_ennemi() == &"matelot")
	assert_eq(matelots.size(), EQ.bosco_rage_renforts, "Son équipage vient quand même")


func test_l_equipage_sort_devant_lui() -> void:
	var gen := _generateur()
	var b := _bosco(gen)
	await wait_physics_frames(2)
	b.rotation.y = 0.0
	b._appeler_renforts()
	for m in b.renforts:
		assert_gt(b.to_local(m.position).z, 0.0, "Devant lui, pas dans son dos (contre un mur)")


func test_salle_videe_une_seule_fois() -> void:
	# (relecture) le Bosco vaincu avec son équipage debout annonçait la salle vidée deux fois
	Partie.debug_depart = &"bosco"
	var e := await _expedition()
	await _secondes(0.3)
	var annonces := [0]
	e.generateur.salle_videe.connect(func(): annonces[0] += 1)
	e.bosco.sante.subir(e.bosco.sante.pv_max * 0.51)
	await _attendre_renforts(e.bosco)
	assert_eq(e.bosco.renforts.size(), EQ.bosco_rage_renforts)
	e.bosco.sante.subir(99999.0, e.heros)
	await wait_physics_frames(3)
	assert_eq(annonces[0], 1, "Une seule fois")


func _attendre_renforts(b: Bosco) -> void:
	for i in 400:
		if b.renforts.size() > 0:
			return
		await wait_physics_frames(1)


func test_rien_ne_suit_dans_la_salle_suivante() -> void:
	# (relecture) une flaque posée juste avant de prendre la porte blessait dans la salle suivante
	var e := await _expedition()
	FlaqueMaudite.creer(e, Salles.ENTREE, true)
	var c := Carreau.new()
	e.add_child(c)
	e._changer_de_salle(2, PlanExpedition.TRESOR, "tresor", [])
	await wait_physics_frames(2)
	assert_eq(e.get_children().filter(func(n): return n is FlaqueMaudite or n is Carreau).size(), 0)


# ---------------------------------------------------------------- malédiction, dans le jeu
func test_mer_avare_dans_le_jeu() -> void:
	Partie.destination = &"expedition"
	Partie.malediction = 4
	Arene.chance_orbe = -1.0
	assert_almost_eq(Arene.chance_orbe_effective(), EQ.orbe_chance * EQ.mal_orbes, 0.001, "Orbes 2 fois plus rares")
	Arene.chance_orbe = 0.0
	Partie.debug_depart = &"tresor"
	var e := await _expedition()
	e.heros.sante.definir_pv(20.0)
	e.heros.global_position = e.salle.coffre.global_position + Vector3(1.2, 0, 0.6)
	await wait_physics_frames(3)
	assert_eq(e.heros.sante.pv, 20.0 + 100.0 * EQ.exp_tresor_soin * EQ.mal_coffre, "Coffre moitié moins")


func test_pieges_plus_rapides_dans_le_jeu() -> void:
	Partie.destination = &"expedition"
	Partie.malediction = 5
	var e := await _expedition()
	e._changer_de_salle(2, PlanExpedition.PIEGE, "salle_pics", [])
	await wait_physics_frames(2)
	var p: PiegePics = e.salle.pics[0]
	# un instant où la dalle est au repos à vitesse normale, mais déjà en alerte à ×1,3
	var t := -1.0
	for i in 400:
		var x := i * 0.01
		if p.phase(x) == 0 and p.phase(x * EQ.mal_vitesse_pieges) == 1:
			t = x
			break
	assert_gt(t, 0.0)
	e.temps_salle = t
	await wait_physics_frames(1)
	assert_true(p._alerte.visible, "Malédiction 5 : les pics vont plus vite")
	assert_eq(e.generateur.reserve + e.generateur.vivants(), EQ.exp_ennemis_piege + EQ.mal_ennemis_salle, "Salle piège : +2 squelettes aussi")
	assert_eq(e.generateur.nombre, maxi(EQ.exp_ensemble - 2, 3) + EQ.mal_ensemble)


func test_tourbillon_dangereux_pendant_la_rotation() -> void:
	var b := _bosco()
	var h := _heros(&"occultiste", Vector3(0, 0, 5.0))
	await wait_physics_frames(2)
	b._commencer(Bosco.Attaque.TOURBILLON, Vector3(0, 0, 1))
	await _attendre_annonce(b)
	await _secondes(0.25)
	assert_eq(h.sante.pv, EQ.occ_pv_max, "Hors du cercle au début")
	h.global_position = Vector3(0, 0, 2.0)   # il entre dans le cercle pendant que la hache tourne
	await _secondes(0.15)
	assert_eq(h.sante.pv, EQ.occ_pv_max - EQ.bosco_tourbillon_degats, "Touché quand même (une fois)")


func test_horde_quand_l_invite_part() -> void:
	Partie.destination = &"expedition"
	Partie.malediction = 2
	var e := await _expedition()
	e._changer_de_salle(2, PlanExpedition.PIEGE, "salle_pics", [])
	await wait_physics_frames(2)
	e.generateur.nombre = 99
	e._continuer_seul()
	assert_eq(e.generateur.nombre, maxi(EQ.exp_ensemble - 2, 3) + EQ.mal_ensemble, "Salle piège et malédiction gardées")


# ---------------------------------------------------------------- l'antre
func _expedition() -> Expedition:
	var e: Expedition = load("res://game/expedition/expedition.tscn").instantiate()
	add_child_autofree(e)
	await wait_physics_frames(3)
	e.hud.menu_demande.disconnect(e.retour_menu)
	return e


func test_l_antre_du_bosco() -> void:
	Partie.debug_depart = &"bosco"
	var e := await _expedition()
	assert_not_null(e.bosco, "Le Bosco sort de terre dans l'antre")
	assert_eq(e.generateur.get_children().filter(func(x): return x is Ennemi).size(), 1, "Seul (son équipage vient à mi-vie)")
	await wait_physics_frames(3)
	assert_true(e.hud.barre_boss.visible, "Barre de vie du Bosco en haut de l'écran")
	await _secondes(0.5)
	e.bosco.sante.subir(99999.0, e.heros)
	await wait_physics_frames(3)
	assert_true(e.salle.portes[0].ouverte, "Bosco vaincu : la porte de la chaloupe s'ouvre")
	assert_false(e.hud.barre_boss.visible)
	var lignes := e._bilan(true)
	assert_true(lignes.any(func(l): return String(l).begins_with("Bosco vaincu en")), "Écran de fin : temps contre le Bosco")


# ---------------------------------------------------------------- malédiction
func test_malediction_seulement_en_expedition() -> void:
	Partie.malediction = 5
	Partie.destination = &"arene"
	assert_eq(Malediction.niveau(), 0, "L'arène reste au niveau 0")
	var m := Ennemi.creer_type(&"matelot", true)
	monde.add_child(m)
	assert_eq(m.sante.pv_max, EQ.squelette_pv_max)


func test_echelle_de_malediction() -> void:
	Partie.destination = &"expedition"
	var matelot := Ennemi.creer_type(&"matelot", true)
	monde.add_child(matelot)
	var attendu := [
		# pv, +squelettes, +debout, dégâts, orbes, coffre, Bosco enragé, pièges
		[1.0, 0, 0, 1.0, 1.0, 1.0, false, 1.0],
		[1.25, 0, 0, 1.0, 1.0, 1.0, false, 1.0],
		[1.25, 2, 1, 1.0, 1.0, 1.0, false, 1.0],
		[1.25, 2, 1, 1.25, 1.0, 1.0, false, 1.0],
		[1.25, 2, 1, 1.25, 0.5, 0.5, false, 1.0],
		[1.25, 2, 1, 1.25, 0.5, 0.5, true, EQ.mal_vitesse_pieges],
	]
	for n in 6:
		Partie.malediction = n
		var a: Array = attendu[n]
		assert_almost_eq(Malediction.mult_pv(), a[0], 0.001, "PV, niveau %d" % n)
		assert_eq(Malediction.bonus_ennemis(), a[1], "squelettes en plus, niveau %d" % n)
		assert_eq(Malediction.bonus_ensemble(), a[2])
		assert_almost_eq(Malediction.mult_degats_recus(matelot), a[3], 0.001, "dégâts, niveau %d" % n)
		assert_almost_eq(Malediction.mult_orbes(), a[4], 0.001)
		assert_almost_eq(Malediction.mult_coffre(), a[5], 0.001)
		assert_eq(Malediction.bosco_enrage(), a[6])
		assert_almost_eq(Malediction.vitesse_pieges(), a[7], 0.001)
		assert_almost_eq(Malediction.mult_butin(), 1.0 + 0.2 * n, 0.001, "+20 % de butin par niveau")
	assert_eq(Malediction.texte_butin(3), "×1,6")


func test_lames_maudites_sur_les_heros() -> void:
	Partie.destination = &"expedition"
	Partie.malediction = 3
	var h := _heros(&"bretteur", Vector3(0, 0, 0))
	var m := Ennemi.creer_type(&"matelot", true)
	m.position = Vector3(0, 0, 2)
	monde.add_child(m)
	await wait_physics_frames(2)
	Combat.porter_coup(m, h, 20.0, false)
	assert_eq(h.sante.pv, 100.0 - 25.0, "Coup d'un squelette +25 %")
	h.sante.invulnerable_jusqua = 0.0
	var pics := PiegePics.new()
	monde.add_child(pics)
	await wait_physics_frames(1)
	h.sante.invulnerable_jusqua = 0.0
	Combat.porter_coup(pics, h, 18.0, true)
	assert_eq(h.sante.pv, 75.0 - 18.0, "Pas les pièges")


func test_os_durcis_et_equipage_nombreux() -> void:
	Partie.destination = &"expedition"
	Partie.malediction = 2
	var e := await _expedition()
	var gen := e.generateur
	assert_eq(gen.nombre, EQ.exp_ensemble + EQ.mal_ensemble, "Un squelette de plus debout")
	assert_eq(gen.reserve + gen.vivants(), EQ.exp_ennemis_salle + EQ.mal_ennemis_salle, "Deux de plus dans la salle")
	for s in gen.get_children():
		assert_almost_eq(s.sante.pv_max, EQ.squelette_pv_max * (1.0 + EQ.mal_pv), 0.01, "Os durcis")


func test_bosco_enrage_des_le_debut_au_niveau_5() -> void:
	Partie.destination = &"expedition"
	Partie.malediction = 5
	var b := _bosco()
	await wait_physics_frames(2)
	assert_true(b.enrage)
	assert_almost_eq(b.sante.pv_max, EQ.bosco_pv * (1.0 + EQ.mal_pv), 0.01)


func test_choix_de_la_malediction() -> void:
	Partie.malediction = 0
	var c := ChoixMalediction.new()
	add_child_autofree(c)
	await wait_physics_frames(1)
	assert_true(c.bouton_moins.disabled, "Pas en dessous de 0")
	c.bouton_plus.pressed.emit()
	c.bouton_plus.pressed.emit()
	c.bouton_plus.pressed.emit()
	assert_eq(Partie.malediction, 3)
	assert_eq(c.label_titre.text, "Malédiction 3 — Lames maudites")
	assert_eq(c.label_effets.text.split(" · ").size(), 3, "Effets cumulés")
	assert_string_contains(c.label_butin.text, "×1,6")
	for i in 5:
		c.bouton_plus.pressed.emit()
	assert_eq(Partie.malediction, 5, "Pas au-dessus de 5")
	assert_true(c.bouton_plus.disabled)


func test_l_hote_envoie_la_malediction() -> void:
	Reseau._lancer("expedition", 4)
	assert_eq(Partie.destination, &"expedition")
	assert_eq(Partie.malediction, 4, "L'invité joue au même niveau")


# ---------------------------------------------------------------- chaloupe
func test_chaloupe_tenir_45_s_a_bord() -> void:
	Partie.debug_depart = &"chaloupe"
	var e := await _expedition()
	assert_eq(e.chaloupe_restant, -1.0, "Personne à bord : rien ne se passe")
	e.heros.global_position = e.salle.zone_chaloupe
	await wait_physics_frames(2)
	assert_almost_eq(e.chaloupe_restant, EQ.chaloupe_duree, 0.2, "On monte : le compte commence")
	assert_string_contains(e.hud.label_salle.text, "La chaloupe part dans")
	e._verifier_chaloupe(10.0)
	assert_almost_eq(e.chaloupe_restant, EQ.chaloupe_duree - 10.0, 0.2)
	e.heros.global_position = e.salle.zone_chaloupe + Vector3(4.5, 0, 0)
	await wait_physics_frames(2)
	var avant := e.chaloupe_restant
	e._verifier_chaloupe(10.0)
	assert_eq(e.chaloupe_restant, avant, "Personne à bord : le compte s'arrête (sans rien perdre)")
	assert_string_contains(e.hud.label_salle.text, "Remontez dans la chaloupe")
	assert_false(e.finie)
	e.heros.global_position = e.salle.zone_chaloupe
	await wait_physics_frames(2)
	e._verifier_chaloupe(EQ.chaloupe_duree)
	assert_true(e.finie and e.reussite, "45 s à bord : expédition réussie")


func test_vagues_de_la_chaloupe() -> void:
	Partie.debug_depart = &"chaloupe"
	var e := await _expedition()
	e.heros.global_position = e.salle.zone_chaloupe
	await wait_physics_frames(2)
	assert_eq(e.vagues_lancees, 1, "Une vague dès qu'on monte")
	e._verifier_chaloupe(EQ.chaloupe_duree - 1.0)
	assert_lt(e.vagues_lancees, EQ.chaloupe_vagues, "Quai plein : la vague suivante attend")
	assert_lte(e.generateur.vivants(), EQ.chaloupe_max_debout + EQ.chaloupe_vague - 1, "Jamais plus d'une vague au-delà du plafond")
	var tous: Array = []
	for tour in 6:   # on vainc ceux qui sont sortis : les vagues en retard sortent
		for s in e.generateur.get_children():
			if s is Ennemi and s.est_vivant():
				tous.append(s.type_ennemi())
				s.sante.subir(9999.0, e.heros)
		await wait_physics_frames(2)
		e._verifier_chaloupe(0.0)
	assert_eq(e.vagues_lancees, EQ.chaloupe_vagues, "Toutes les vagues sont sorties")
	assert_eq(tous.size(), EQ.chaloupe_vagues * EQ.chaloupe_vague)
	assert_eq(tous.count(&"arbaletrier"), EQ.chaloupe_vagues - EQ.chaloupe_arbaletrier_des + 1, "Un arbalétrier par vague à partir de la 3e")
	for p in e.salle.points_vague():
		assert_false(e.salle.dans_chaloupe(p), "Ils ne sortent pas dans la chaloupe")
		assert_lt(p.x, -Salle.DEMI + 2 * Salle.PAS, "Ils sortent de l'eau, au bord du quai")
	assert_gt(e.salle.houle, 0.9, "La houle a grossi")


func test_equipage_nombreux_dans_les_vagues() -> void:
	Partie.destination = &"expedition"
	Partie.malediction = 2
	Partie.debug_depart = &"chaloupe"
	var e := await _expedition()
	e.heros.global_position = e.salle.zone_chaloupe
	await wait_physics_frames(2)
	assert_eq(e.generateur.vivants(), EQ.chaloupe_vague + 1, "Malédiction 2 : un squelette de plus par vague")


func test_instantane_du_quai_tient_dans_un_paquet_wifi() -> void:
	# quai à deux, malédiction 2 : au plus plafond - 1 + une vague de 5 debout, plus 3 vaincus
	var gen := _generateur()
	var debout := EQ.chaloupe_max_debout - 1 + EQ.chaloupe_vague_coop + 1
	for i in debout + 3:
		var x := Ennemi.creer_type(&"arbaletrier" if i % 4 == 0 else &"matelot", true)
		x.name = "%s_%d" % [Ennemi.PREFIXES[x.type_ennemi()], 100 + i]
		x.position = Vector3(i - 7, 0, 2)
		gen.add_child(x)
	var a := _heros(&"bretteur", Vector3(0, 0, 5))
	a.name = "HerosHote"
	var b := _heros(&"occultiste", Vector3(1, 0, 5))
	b.name = "HerosInvite"
	await wait_physics_frames(3)
	var morts := 0
	for x in gen.get_children():
		if morts < 3:
			x.sante.subir(9999.0, a)
			morts += 1
	var s := SynchroArene.new()
	autofree(s)
	s.generateur = gen
	s.heros_local = a
	s.heros_partenaire = b
	var d := s._etat_heros()
	d["@temps"] = 12.5
	d["@chaloupe"] = Vector2(23.0, 1.0)
	var taille := var_to_bytes([99999, d, s._etat_ennemis(), 99999]).size()
	assert_lt(taille, 1392, "Instantané du quai : %d octets pour %d debout" % [taille, debout])


func test_ecran_de_fin_enrichi() -> void:
	Partie.destination = &"expedition"
	Partie.malediction = 3
	var e := await _expedition()
	var lignes := e._bilan(false)
	assert_has(lignes, "Malédiction 3 — Lames maudites — bonus de butin ×1,6")


# ---------------------------------------------------------------- coop (invité)
func test_l_invite_voit_le_bosco() -> void:
	var gen := _generateur()
	var s := SynchroArene.new()
	autofree(s)
	s.generateur = gen
	var donnees := [Vector3(0, 0, 0), 0.0, int(Ennemi.Etat.POURSUITE), 0, 1.0, 1000.0, false, 0.0]
	s._creer_ou_retirer_ennemis({"Bosco_4": donnees})
	var b := gen.get_node("Bosco_4") as Bosco
	assert_not_null(b, "Le Bosco est recréé d'après son nom")
	assert_true(b.marionnette)
	await wait_physics_frames(2)
	# l'hôte annonce une charge de 6 m : l'invité dessine la ligne
	b.effet_recu("bosco_charge", Vector3(0, 0, 6.0))
	b.appliquer_instantane(int(Ennemi.Etat.PREPARATION), b.code_anim("2H_Melee_Idle"), 0.6, 1000.0, false, 0.3)
	assert_eq(b.attaque, Bosco.Attaque.CHARGE)
	assert_almost_eq(b._longueur_charge, 6.0, 0.01)
	assert_true(b._annonce.visible, "La zone de la charge chez l'invité")
	assert_almost_eq(b._jauge.scale.z, 0.3 / b._duree_annonce(), 0.05, "Remplie comme chez l'hôte")
	b.effet_recu("bosco_rage", Vector3.ZERO)
	assert_true(b.enrage, "La rage aussi")


func test_l_invite_voit_le_depart_de_la_chaloupe() -> void:
	Partie.debug_depart = &"chaloupe"
	var e := await _expedition()
	e.heros.global_position = e.salle.zone_chaloupe
	await wait_physics_frames(2)
	var s := SynchroArene.new()
	autofree(s)
	s.arene = e
	s.heros_local = e.heros
	var d := s._etat_heros()
	assert_true(d.has("@chaloupe"), "L'hôte envoie le compte à rebours")
	assert_almost_eq((d["@chaloupe"] as Vector2).x, e.chaloupe_restant, 0.01)
	e.caler_chaloupe(20.0, false)
	assert_string_contains(e.hud.label_salle.text, "Remontez dans la chaloupe ! (20 s)")
