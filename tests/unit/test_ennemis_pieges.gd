extends GutTest
## Jalon 3, étape 2 : arbalétrier squelette (distance, visée, carreau, esquive, renvoi par la Parade),
## prêtre noyé (relever un mort, interrompu par un coup, flaque maudite), dalles à pics, tonneaux de
## poudre, composition des salles, coop (types d'ennemis, carreaux, horloge des pièges).

const EQ: Equilibrage = preload("res://data/equilibrage.tres")

var monde: Node3D


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


func _secondes(s: float) -> void:
	await wait_physics_frames(int(ceil(s * 60.0)) + 1)


func _heros(type: StringName, pos: Vector3) -> Heros:
	var h := Heros.creer(type)
	h.position = pos
	monde.add_child(h)
	return h


func _ennemi(type: StringName, pos: Vector3, pv := -1.0) -> Ennemi:
	var e := Ennemi.creer_type(type, true)
	e.position = pos
	monde.add_child(e)
	if pv > 0.0:
		e.sante.pv_max = pv
		e.sante.pv = pv
	return e


func _carreaux() -> Array:
	return monde.get_children().filter(func(n): return n is Carreau)


# ---------------------------------------------------------------- arbalétrier
func test_arbaletrier_recule_si_l_on_s_approche() -> void:
	var h := _heros(&"occultiste", Vector3(0, 0, 0))
	var a := _ennemi(&"arbaletrier", Vector3(0, 0, 2.0))
	await _secondes(1.0)
	assert_gt(a.global_position.distance_to(h.global_position), 2.6, "Trop près : il recule")


func test_arbaletrier_vise_puis_tire() -> void:
	var h := _heros(&"occultiste", Vector3(0, 0, 0))
	var a := _ennemi(&"arbaletrier", Vector3(0, 0, 6.0))
	await _secondes(0.3)
	assert_eq(a.etat, Ennemi.Etat.PREPARATION, "À bonne distance, il vise")
	assert_true(a._visee.visible, "Le trait rouge annonce le tir")
	assert_false(a.marque.visible, "Pas de zone au sol")
	await _secondes(EQ.arb_visee)
	assert_false(a._visee.visible)
	await _secondes(6.0 / EQ.carreau_vitesse + 0.3)
	assert_eq(h.sante.pv, EQ.occ_pv_max - EQ.carreau_degats, "Le carreau touche")


func test_carreau_esquive() -> void:
	var h := _heros(&"occultiste", Vector3(0, 0, 0))
	var a := _ennemi(&"arbaletrier", Vector3(0, 0, 9.0))
	a.set_physics_process(false)
	await _secondes(0.1)
	h.sante.rendre_invulnerable(2.0)   # comme pendant une roulade ou une téléportation
	var c := Carreau.tirer(monde, a, Vector3(0, 1.25, 3.0), Vector3(0, 0, -1))
	await _secondes(3.0 / EQ.carreau_vitesse + 0.15)
	assert_eq(h.sante.pv, EQ.occ_pv_max, "Esquivé : pas de dégâts")
	assert_true(is_instance_valid(c) and c.global_position.z < -0.5, "Il passe à travers et continue")


func test_parade_renvoie_le_carreau() -> void:
	var b: Bretteur = _heros(&"bretteur", Vector3(0, 0, 0))
	var a := _ennemi(&"arbaletrier", Vector3(0, 0, 6.0), 500.0)
	a.set_physics_process(false)
	await _secondes(0.1)
	b.commandes.demander(&"competence_1", b.horloge)
	await _secondes(EQ.parade_parfaite_fenetre + 0.05)   # parade ordinaire
	assert_eq(b.etat, Heros.Etat.PARADE)
	Carreau.tirer(monde, a, Vector3(0, 1.25, 1.6), Vector3(0, 0, -1))
	await _secondes(0.3)
	assert_eq(b.sante.pv, 100.0, "Paré : pas de dégâts")
	await _secondes(6.0 / EQ.carreau_vitesse + 0.2)
	assert_eq(a.sante.pv, 500.0 - EQ.carreau_renvoi_degats, "Le carreau renvoyé touche l'arbalétrier")


func test_parade_parfaite_renvoie_un_carreau_critique() -> void:
	var b: Bretteur = _heros(&"bretteur", Vector3(0, 0, 0))
	var a := _ennemi(&"arbaletrier", Vector3(0, 0, 6.0), 500.0)
	a.set_physics_process(false)
	await _secondes(0.1)
	watch_signals(EventBus)
	b.commandes.demander(&"competence_1", b.horloge)
	await wait_physics_frames(2)
	Carreau.tirer(monde, a, Vector3(0, 1.25, 1.4), Vector3(0, 0, -1))
	await _secondes(6.0 / EQ.carreau_vitesse + 0.4)
	assert_signal_emitted(EventBus, "parade_parfaite")
	assert_true(b.recharge_competence_1.prete(), "Parade rendue")
	assert_eq(a.sante.pv, 500.0 - EQ.carreau_renvoi_degats * EQ.critique_multiplicateur, "Renvoi critique")


func test_parade_de_dos_ne_renvoie_pas() -> void:
	var b: Bretteur = _heros(&"bretteur", Vector3(0, 0, 0))
	var a := _ennemi(&"arbaletrier", Vector3(0, 0, -6.0), 500.0)
	a.set_physics_process(false)
	b.rotation.y = 0.0   # regarde vers +z ; le carreau arrive de -z
	await _secondes(0.1)
	b.commandes.deplacement = Vector3(0, 0, 1)
	b.commandes.demander(&"competence_1", b.horloge)
	await wait_physics_frames(2)
	b.commandes.deplacement = Vector3.ZERO
	Carreau.tirer(monde, a, Vector3(0, 1.25, -1.6), Vector3(0, 0, 1))
	await _secondes(0.4)
	assert_eq(b.sante.pv, 100.0 - EQ.carreau_degats, "De dos, la parade ne protège pas")


# ---------------------------------------------------------------- prêtre noyé
func _avec_generateur() -> GenerateurEnnemis:
	var gen := GenerateurEnnemis.new()
	gen.demarrage_auto = false
	gen.nombre = 0
	gen.reserve = 0
	monde.add_child(gen)
	return gen


func test_pretre_releve_un_mort() -> void:
	var gen := _avec_generateur()   # (sans héros : il ne fait que relever)
	var p := Ennemi.creer_type(&"pretre", true)
	p.position = Vector3(0, 0, 0)
	gen.add_child(p)
	var m := gen._faire_apparaitre(Vector3(3, 0, 0), &"matelot")
	await _secondes(2.5)   # le matelot sort de terre
	m.sante.subir(9999.0)
	assert_eq(gen.tombes.size(), 1, "Il laisse une tombe")
	p._recharge_relever = 0.0
	await _secondes(0.2)
	assert_eq(p.etat, Ennemi.Etat.INCANTATION, "Le prêtre commence à le relever")
	assert_not_null(p._cercle, "Cercle vert sur la tombe")
	await _secondes(EQ.pretre_incantation + 0.1)
	assert_eq(gen.tombes[0]["etat"], 2, "Relevé")
	var releves := gen.get_children().filter(func(n): return n is Ennemi and n.releve)
	assert_eq(releves.size(), 1, "Le mort ressort de terre")
	releves[0].sante.subir(9999.0)
	assert_eq(gen.tombes.size(), 1, "Une seule fois : un relevé ne laisse pas de tombe")


func test_un_coup_interrompt_l_incantation() -> void:
	var gen := _avec_generateur()
	var h := _heros(&"occultiste", Vector3(0, 0, -12.0))
	var p := Ennemi.creer_type(&"pretre", true)
	p.position = Vector3(0, 0, 0)
	gen.add_child(p)
	gen.tombes.append({"pos": Vector3(3, 0, 0), "type": &"matelot", "etat": 0})
	p._recharge_relever = 0.0
	await _secondes(0.2)
	assert_eq(p.etat, Ennemi.Etat.INCANTATION)
	Combat.porter_coup(h, p, 1.0, false)   # un coup léger suffit (choix de Téo)
	assert_ne(p.etat, Ennemi.Etat.INCANTATION, "Interrompu")
	assert_null(p._cercle, "Le cercle disparaît")
	assert_eq(gen.tombes[0]["etat"], 0, "Le mort reste à terre (tombe libre)")
	await _secondes(EQ.pretre_incantation)
	assert_eq(gen.get_children().filter(func(n): return n is Ennemi and n.releve).size(), 0)


func test_flaque_maudite() -> void:
	var h := _heros(&"occultiste", Vector3(0, 0, 0))
	var p := _ennemi(&"pretre", Vector3(0, 0, 6.0))
	p._recharge_relever = 99.0
	await _secondes(0.2)
	assert_eq(p.etat, Ennemi.Etat.PREPARATION, "Il maudit le sol sous le héros")
	await _secondes(EQ.pretre_annonce_flaque + 0.1)
	var flaques := monde.get_children().filter(func(n): return n is FlaqueMaudite)
	assert_eq(flaques.size(), 1, "La flaque apparaît")
	var pv := h.sante.pv
	await _secondes(1.2)
	assert_lt(h.sante.pv, pv, "Rester dedans fait perdre des PV")
	assert_eq(h.etat, Heros.Etat.LIBRE, "Sans être sonné")
	assert_false(h.sante.est_invulnerable(), "Sans devenir intouchable")
	h.global_position = Vector3(5, 0, 0)
	pv = h.sante.pv
	await _secondes(1.2)
	assert_eq(h.sante.pv, pv, "Dehors : plus rien")


# ---------------------------------------------------------------- pièges
func test_pics_blessent_dessus_au_bon_moment() -> void:
	var pics := PiegePics.new()
	monde.add_child(pics)
	var h := _heros(&"bretteur", Vector3(0.5, 0, 0.5))
	var dehors := _heros(&"occultiste", Vector3(4, 0, 0))
	var s := _ennemi(&"matelot", Vector3(-0.8, 0, -0.5), 500.0)
	await _secondes(0.1)
	var t_repos := 0.1
	var t_alerte := EQ.pics_periode - EQ.pics_sortis - EQ.pics_alerte + 0.05
	var t_sortis := EQ.pics_periode - EQ.pics_sortis + 0.05
	assert_eq(pics.phase(t_repos), 0)
	assert_eq(pics.phase(t_alerte), 1)
	assert_eq(pics.phase(t_sortis), 2)
	pics.regler(t_alerte, true)
	assert_true(pics._alerte.visible, "La dalle rougeoie avant")
	assert_eq(h.sante.pv, 100.0)
	pics.regler(t_sortis, false)
	assert_eq(h.sante.pv, 100.0, "Chez l'invité, rien (l'hôte décide)")
	pics.regler(t_sortis, true)
	assert_eq(h.sante.pv, 100.0 - EQ.pics_degats, "Le héros dessus est blessé")
	assert_eq(s.sante.pv, 500.0 - EQ.pics_degats, "Le squelette aussi")
	assert_eq(dehors.sante.pv, EQ.occ_pv_max, "À côté, rien")
	h.sante.invulnerable_jusqua = 0.0
	pics.regler(t_sortis + 0.1, true)
	assert_eq(h.sante.pv, 100.0 - EQ.pics_degats, "Une seule fois par sortie")


func test_tonneau_de_poudre() -> void:
	var t1 := TonneauPoudre.new()
	monde.add_child(t1)
	var t2 := TonneauPoudre.new()
	t2.position = Vector3(2.0, 0, 0)
	monde.add_child(t2)
	var proche := _ennemi(&"matelot", Vector3(0, 0, 1.5), 500.0)
	var loin := _ennemi(&"matelot", Vector3(0, 0, 8.0), 500.0)
	var h := _heros(&"bretteur", Vector3(-1.5, 0, 0))
	await _secondes(0.1)
	assert_null(h.cible_visee(20.0) if h.cible_visee(20.0) is TonneauPoudre else null, "La visée assistée ignore les tonneaux")
	Combat.porter_coup(h, t1, 10.0, false)
	assert_false(t1.explose, "La mèche brûle d'abord")
	await _secondes(EQ.tonneau_meche + 0.1)
	assert_true(t1.explose, "Boum")
	assert_eq(proche.sante.pv, 500.0 - EQ.tonneau_degats, "Les squelettes autour sont blessés")
	assert_eq(loin.sante.pv, 500.0, "Pas ceux qui sont loin")
	assert_eq(h.sante.pv, 100.0, "Les héros sont épargnés")
	await _secondes(EQ.tonneau_meche + 0.1)
	assert_true(t2.explose, "Le tonneau voisin explose à son tour")


# ---------------------------------------------------------------- composition des salles
func test_composition_d_une_salle() -> void:
	var gen := _avec_generateur()
	var points: Array[Vector3] = [Vector3(5, 0, 5), Vector3(-5, 0, 5)]
	var pretre_au_debut := 0
	for essai in 30:   # tirage au hasard : on le refait plusieurs fois
		gen.preparer_salle(9, 4, points, {&"arbaletrier": 2, &"pretre": 1})
		assert_eq(gen.a_venir.size(), 9)
		assert_eq(gen.a_venir.count(&"arbaletrier"), 2)
		assert_eq(gen.a_venir.count(&"pretre"), 1)
		for i in 4:
			if gen.a_venir[gen.a_venir.size() - 1 - i] == &"pretre":
				pretre_au_debut += 1
	assert_eq(pretre_au_debut, 0, "Pas de prêtre dans le premier groupe")
	gen.demarrer()
	var types := gen.get_children().map(func(e): return e.type_ennemi())
	assert_eq(types.size(), 4)
	for e in gen.get_children():
		assert_true(e.name.begins_with(Ennemi.PREFIXES[e.type_ennemi()] + "_"), "Nom selon le type : %s" % e.name)


func test_composition_selon_la_salle() -> void:
	assert_eq(Expedition.composition(1, PlanExpedition.COMBAT, false), {}, "Salle 1 : des matelots")
	assert_eq(Expedition.composition(2, PlanExpedition.COMBAT, false), {&"arbaletrier": EQ.exp_arbaletriers})
	assert_eq(Expedition.composition(3, PlanExpedition.COMBAT, true),
		{&"arbaletrier": EQ.exp_arbaletriers + 1, &"pretre": EQ.exp_pretres}, "À deux : un arbalétrier de plus")
	assert_eq(Expedition.composition(5, PlanExpedition.BOSCO, false), {}, "L'antre : le Bosco seul (son équipage vient à mi-vie)")


func test_portes_piege_dans_le_plan() -> void:
	var vu_piege := false
	for graine in 40:
		var p := PlanExpedition.new(graine, 4)
		var pieges := 0
		for n in range(1, 4):
			var portes := p.portes_apres(n)
			var choix: StringName = PlanExpedition.PIEGE if PlanExpedition.PIEGE in portes else portes[0]
			vu_piege = vu_piege or PlanExpedition.PIEGE in portes
			p.noter_choix(choix)
			if choix == PlanExpedition.PIEGE:
				pieges += 1
		assert_lte(pieges, 2, "Au plus deux salles piège")
	assert_true(vu_piege, "Des portes « piège » apparaissent")
	assert_gte(Salles.modeles_pour(PlanExpedition.PIEGE).size(), 2)


# ---------------------------------------------------------------- coop
func test_l_invite_recree_le_bon_type() -> void:
	assert_eq(Ennemi.type_depuis_nom("Arbaletrier_12"), &"arbaletrier")
	assert_eq(Ennemi.type_depuis_nom("Pretre_3"), &"pretre")
	assert_eq(Ennemi.type_depuis_nom("Squelette_7"), &"matelot")
	var gen := _avec_generateur()
	var s := SynchroArene.new()
	autofree(s)
	s.generateur = gen
	var donnees := [Vector3(1, 0, 1), 0.0, 1, 0, 1.0, 22.0, false, 0.0]
	s._creer_ou_retirer_ennemis({"Arbaletrier_12": donnees, "Pretre_3": donnees, "Squelette_7": donnees})
	assert_true(gen.get_node("Arbaletrier_12") is Arbaletrier)
	assert_true(gen.get_node("Pretre_3") is PretreNoye)
	assert_true(gen.get_node("Squelette_7").get_script() == Ennemi, "Matelot")
	for e in gen.get_children():
		assert_true(e.marionnette, "Des marionnettes")


func test_l_invite_voit_les_carreaux() -> void:
	var h := _heros(&"bretteur", Vector3(0, 0, 0))
	h.name = "HerosInvite"
	var s := SynchroArene.new()
	autofree(s)
	s.arene = monde
	s.heros_local = h
	s.generateur = _avec_generateur()
	s._projectile_recu("Arbaletrier_1", Vector3(0, 1.25, 6), Vector3(0, 0, -1), "carreau")
	s._projectile_recu("HerosInvite", Vector3(0, 1.25, 1), Vector3(0, 0, 1), "carreau_renvoye")
	var c := _carreaux()
	assert_eq(c.size(), 2, "Le carreau, et celui que NOTRE héros a renvoyé (décidé par l'hôte)")
	for x in c:
		assert_true(x.marionnette, "Des images : l'hôte décide de ce qu'ils touchent")


func test_horloge_des_pieges_calee_sur_l_hote() -> void:
	Partie.revenir_en_solo()
	Partie.debug_depart = &""
	var e: Expedition = load("res://game/expedition/expedition.tscn").instantiate()
	add_child_autofree(e)
	await wait_physics_frames(3)
	var s := SynchroArene.new()
	autofree(s)
	s.arene = e
	s.heros_local = e.heros
	e.temps_salle = 12.5
	var d := s._etat_heros()
	assert_almost_eq(float(d["@temps"]), 12.5, 0.001, "L'hôte envoie l'heure de la salle")
	e.caler_temps_salle(3.25)
	assert_eq(e.temps_salle, 3.25, "L'invité s'y cale")
