extends GutTest
## Expédition (jalon 3) : plan des salles, réserve finie de squelettes, salles faites main, portes,
## coffre, chaloupe, défaite, orbes de vie, Menu à confirmer. Choix de Téo : 4 salles, puis le Bosco,
## puis la chaloupe ; PV gardés + orbes ; en coop, les deux devant la même porte.

const EQ: Equilibrage = preload("res://data/equilibrage.tres")

var monde: Node3D


func before_all() -> void:
	Combat.chance_critique = 0.0


func after_all() -> void:
	Combat.chance_critique = -1.0
	Arene.chance_orbe = -1.0
	Partie.debug_depart = &""
	Partie.debug_sante_infinie = false


func before_each() -> void:
	Engine.time_scale = 1.0
	Partie.revenir_en_solo()
	Partie.heros_local = &"bretteur"
	Partie.debug_depart = &""
	Partie.debug_sante_infinie = false
	Arene.chance_orbe = 0.0
	monde = Node3D.new()
	add_child_autofree(monde)


func after_each() -> void:
	Engine.time_scale = 1.0


func _sol() -> void:
	var sol := StaticBody3D.new()
	sol.collision_layer = Combat.COUCHE_MONDE
	var forme := CollisionShape3D.new()
	var boite := BoxShape3D.new()
	boite.size = Vector3(40, 0.2, 40)
	forme.shape = boite
	sol.add_child(forme)
	sol.position.y = -0.1
	monde.add_child(sol)


func _expedition() -> Expedition:
	var e: Expedition = load("res://game/expedition/expedition.tscn").instantiate()
	add_child_autofree(e)
	await wait_physics_frames(3)
	return e


## Vainc tous les squelettes de la salle (ceux qui ressortent aussi) jusqu'à ce qu'elle soit vide.
func _nettoyer(e: Expedition) -> void:
	for tour in 40:
		for s in e.generateur.get_children():
			if s is Ennemi and s.etat != Ennemi.Etat.MORT:
				s.sante.subir(9999.0, e.heros)
		if e.generateur.reserve == 0 and e.generateur.vivants() == 0:
			break
		await wait_seconds(0.3)
	await wait_physics_frames(2)


# ---------------------------------------------------------------- plan
func test_plan_suit_les_regles() -> void:
	var p := PlanExpedition.new(7, 4)
	assert_eq(p.type_impose(1), PlanExpedition.COMBAT, "La première salle est un combat")
	for n in range(1, 4):
		var portes := p.portes_apres(n)
		assert_eq(portes.size(), 2, "Deux portes après la salle %d" % n)
		if PlanExpedition.TRESOR in portes:
			assert_ne(portes[0], portes[1], "Deux types différents quand le trésor est possible")
			p.noter_choix(PlanExpedition.TRESOR)
	assert_eq(p.portes_apres(4), [PlanExpedition.BOSCO], "Après la 4e salle : le Bosco")
	assert_eq(p.portes_apres(5), [PlanExpedition.CHALOUPE], "Après le Bosco : la chaloupe")
	assert_eq(p.portes_apres(6), [], "Après la chaloupe : fin")


func test_un_seul_tresor_par_expedition() -> void:
	for graine in 30:
		var p := PlanExpedition.new(graine, 4)
		var tresors := 0
		for n in range(1, 4):
			var portes := p.portes_apres(n)
			var choix: StringName = PlanExpedition.TRESOR if PlanExpedition.TRESOR in portes else portes[0]
			p.noter_choix(choix)
			if choix == PlanExpedition.TRESOR:
				tresors += 1
		assert_lte(tresors, 1, "Graine %d : au plus un trésor" % graine)


func test_meme_graine_meme_suite() -> void:
	var a := PlanExpedition.new(42, 4)
	var b := PlanExpedition.new(42, 4)
	for n in range(1, 6):
		assert_eq(a.portes_apres(n), b.portes_apres(n))
		assert_eq(a.modele_pour(PlanExpedition.COMBAT), b.modele_pour(PlanExpedition.COMBAT))


func test_pas_deux_fois_la_meme_salle_de_suite() -> void:
	var p := PlanExpedition.new(3, 4)
	var avant := ""
	for i in 12:
		var m := p.modele_pour(PlanExpedition.COMBAT)
		assert_ne(m, avant, "Jamais deux fois la même salle d'affilée")
		avant = m


# ---------------------------------------------------------------- générateur à réserve finie
func test_reserve_finie_puis_salle_videe() -> void:
	_sol()
	var gen := GenerateurEnnemis.new()
	gen.demarrage_auto = false
	monde.add_child(gen)
	watch_signals(gen)
	var points: Array[Vector3] = [Vector3(3, 0, 3), Vector3(-3, 0, -3)]
	gen.preparer_salle(5, 2, points)
	gen.demarrer()
	await wait_physics_frames(2)
	var max_vivants := 0
	for tour in 30:
		max_vivants = maxi(max_vivants, gen.vivants())
		for s in gen.get_children():
			if s is Ennemi and s.etat != Ennemi.Etat.MORT:
				s.sante.subir(9999.0)
		if gen.reserve == 0 and gen.vivants() == 0:
			break
		await wait_seconds(EQ.arene_delai_apparition * 0.5)
	assert_eq(gen.vaincus, 5, "Exactement la réserve de la salle")
	assert_lte(max_vivants, 2, "Jamais plus que « ensemble » debout")
	assert_signal_emit_count(gen, "salle_videe", 1, "La salle est vide une seule fois")
	await wait_seconds(EQ.arene_delai_apparition + 0.3)
	assert_eq(gen.vivants(), 0, "Personne ne ressort ensuite")


func test_renfort_de_la_salle_d_avant_oublie() -> void:
	_sol()
	var gen := GenerateurEnnemis.new()
	gen.demarrage_auto = false
	monde.add_child(gen)
	var points: Array[Vector3] = [Vector3(3, 0, 3)]
	gen.preparer_salle(6, 2, points)
	gen.demarrer()
	await wait_physics_frames(2)
	for s in gen.get_children():
		if s is Ennemi:
			s.sante.subir(9999.0)   # un renfort est prévu…
	var vide: Array[Vector3] = []
	gen.preparer_salle(0, 0, vide)   # … mais on change de salle (trésor)
	await wait_seconds(EQ.arene_delai_apparition + 0.3)
	assert_eq(gen.vivants(), 0, "Le renfort de l'ancienne salle ne sort pas dans la nouvelle")


# ---------------------------------------------------------------- salles faites main
func test_chaque_salle_se_construit() -> void:
	for id in Salles.MODELES:
		var t: StringName = Salles.MODELES[id]["types"][0]
		var portes: Array = [] if t == PlanExpedition.CHALOUPE else ([PlanExpedition.CHALOUPE] if t == PlanExpedition.BOSCO else [PlanExpedition.COMBAT, PlanExpedition.TRESOR])
		var s := Salle.creer(id, portes)
		monde.add_child(s)
		assert_eq(s.portes.size(), portes.size(), "%s : ses portes" % id)
		if t == PlanExpedition.TRESOR:
			assert_not_null(s.coffre, "%s : le coffre" % id)
		if t == PlanExpedition.CHALOUPE:
			assert_not_null(s.chaloupe, "%s : la chaloupe" % id)
			assert_ne(s.zone_chaloupe, Vector3.INF)
		if t == PlanExpedition.COMBAT or t == PlanExpedition.BOSCO:
			assert_gte(s.apparitions().size(), 3, "%s : des points d'apparition" % id)
			for p in s.apparitions():
				assert_gt(p.distance_to(Salles.ENTREE), EQ.arene_distance_apparition_min * 0.6, "%s : pas d'apparition sur l'entrée" % id)
		s.queue_free()
	assert_gte(Salles.modeles_pour(PlanExpedition.COMBAT).size(), 5, "Assez de salles de combat pour varier")


# ---------------------------------------------------------------- expédition jouée
func test_salle_nettoyee_puis_porte() -> void:
	var e := await _expedition()
	assert_eq(e.numero, 1)
	assert_eq(e.type_salle, PlanExpedition.COMBAT)
	assert_eq(e.salle.portes.size(), 2, "Deux portes au choix")
	assert_false(e.salle.portes[0].ouverte, "Fermées pendant le combat")
	await wait_seconds(1.0)
	assert_gt(e.generateur.vivants(), 0, "Les squelettes sortent de terre")
	await _nettoyer(e)
	assert_true(e.salle.portes[0].ouverte, "Salle nettoyée : les portes s'ouvrent")
	assert_eq(e.generateur.vaincus, EQ.exp_ennemis_salle, "Toute la réserve de la salle")
	var porte: Porte = e.salle.portes[1]
	var type_choisi := porte.type
	e.heros.sante.definir_pv(40.0)
	e.heros.global_position = porte.devant()
	await wait_seconds(EQ.exp_fondu * 2.0 + 0.3)
	assert_eq(e.numero, 2, "La porte mène à la salle suivante")
	assert_eq(e.type_salle, type_choisi, "Celle annoncée par la porte")
	assert_almost_eq(e.heros.global_position.distance_to(Salles.ENTREE), 0.0, 0.5, "Le héros entre dans la nouvelle salle")
	assert_eq(e.heros.sante.pv, 40.0 + (EQ.exp_tresor_soin * 100.0 if type_choisi == PlanExpedition.TRESOR and e.salle.coffre_ouvert else 0.0),
		"Les PV sont gardés d'une salle à l'autre")


func test_porte_fermee_ne_se_prend_pas() -> void:
	var e := await _expedition()
	e.heros.global_position = e.salle.portes[0].devant()
	await wait_seconds(EQ.exp_fondu * 2.0 + 0.2)
	assert_eq(e.numero, 1, "Tant que la salle n'est pas nettoyée, on ne sort pas")


func test_coop_les_deux_devant_la_meme_porte() -> void:
	var e := await _expedition()
	await _nettoyer(e)
	var b := Bretteur.new()
	b.position = Salles.ENTREE_INVITE
	e.add_child(b)
	await wait_physics_frames(2)
	var p0: Porte = e.salle.portes[0]
	var p1: Porte = e.salle.portes[1]
	e.heros.global_position = p0.devant()
	assert_null(e.porte_prise([e.heros, b]), "Un seul devant : on attend l'autre")
	b.global_position = p1.devant()
	assert_null(e.porte_prise([e.heros, b]), "Chacun devant une porte différente : rien")
	b.global_position = p0.devant() + Vector3(0.5, 0, 0.2)
	assert_eq(e.porte_prise([e.heros, b]), p0, "Les deux devant la même porte : elle est prise")
	b.sante.subir(9999.0)
	await wait_physics_frames(2)
	assert_null(e.porte_prise([e.heros, b]), "Pas sans le partenaire à terre (il faut le relever)")
	b.queue_free()


func test_tresor_soigne() -> void:
	Partie.debug_depart = &"tresor"
	var e := await _expedition()
	assert_eq(e.type_salle, PlanExpedition.TRESOR)
	assert_true(e.salle.portes[0].ouverte, "Pas de combat : les portes sont ouvertes")
	assert_eq(e.generateur.vivants(), 0)
	e.heros.sante.definir_pv(30.0)
	e.heros.global_position = e.salle.coffre.global_position + Vector3(0, 0, 1.3)
	await wait_physics_frames(3)
	assert_true(e.salle.coffre_ouvert, "Le coffre s'ouvre quand on s'approche")
	assert_almost_eq(e.heros.sante.pv, 30.0 + 100.0 * EQ.exp_tresor_soin, 0.01, "Il soigne")


func test_chaloupe_reussite() -> void:
	Partie.debug_depart = &"chaloupe"
	var e := await _expedition()
	assert_eq(e.type_salle, PlanExpedition.CHALOUPE)
	assert_eq(e.salle.portes.size(), 0, "Plus de porte : la chaloupe")
	e.heros.global_position = e.salle.zone_chaloupe
	await wait_physics_frames(3)
	assert_true(e.finie and e.reussite, "Monter dans la chaloupe : expédition réussie")
	assert_not_null(e.hud.panneau_fin, "Écran de fin")


func test_tomber_seul_perd_l_expedition() -> void:
	var e := await _expedition()
	e.heros.sante.subir(9999.0)
	await wait_seconds(EQ.heros_delai_reapparition + 0.5)
	assert_false(e.heros.est_vivant(), "Pas de retour au départ en expédition")
	await wait_seconds(maxf(EQ.exp_delai_defaite - EQ.heros_delai_reapparition, 0.0) + 0.3)
	assert_true(e.finie and not e.reussite, "Expédition perdue")


func test_bosco_puis_chaloupe() -> void:
	Partie.debug_depart = &"bosco"
	var e := await _expedition()
	assert_eq(e.type_salle, PlanExpedition.BOSCO)
	assert_eq(e.salle.portes.size(), 1)
	assert_eq(e.salle.portes[0].type, PlanExpedition.CHALOUPE, "Une seule porte : la chaloupe")
	await _nettoyer(e)
	assert_eq(e.generateur.vaincus, EQ.exp_ennemis_bosco)
	e.heros.global_position = e.salle.portes[0].devant()
	await wait_seconds(EQ.exp_fondu * 2.0 + 0.3)
	assert_eq(e.type_salle, PlanExpedition.CHALOUPE)


func test_sante_infinie_du_mode_test() -> void:
	Partie.debug_sante_infinie = true
	var e := await _expedition()
	e.heros.sante.subir(60.0)
	await wait_physics_frames(2)
	assert_eq(e.heros.sante.pv, e.heros.sante.pv_max)


# ---------------------------------------------------------------- orbes de vie
func test_orbe_de_vie() -> void:
	Arene.chance_orbe = 1.0
	var e := await _expedition()
	await wait_seconds(1.0)
	var s: Ennemi = null
	for c in e.generateur.get_children():
		if c is Ennemi:
			s = c
			break
	assert_not_null(s)
	var pos := s.global_position
	s.sante.subir(9999.0, e.heros)
	await wait_physics_frames(2)
	assert_eq(e.orbes.get_child_count(), 1, "Le squelette lâche une orbe")
	var o: OrbeVie = e.orbes.get_child(0)
	e.heros.global_position = Vector3(pos.x, e.heros.global_position.y, pos.z)
	await wait_physics_frames(2)
	assert_false(o.prise, "À pleine santé, on ne la gaspille pas")
	e.heros.sante.definir_pv(50.0)
	await wait_physics_frames(2)
	assert_true(o.prise, "Blessé : on la ramasse en passant")
	assert_almost_eq(e.heros.sante.pv, 50.0 + 100.0 * EQ.orbe_soin, 0.01, "Elle soigne")
	assert_eq(e.orbes_ramassees, 1)


# ---------------------------------------------------------------- interface
func test_menu_a_confirmer_en_expedition() -> void:
	var e := await _expedition()
	e.hud.menu_demande.disconnect(e.retour_menu)   # (sinon le test quitterait vers l'écran titre)
	watch_signals(e.hud)
	e.hud._demander_menu()
	assert_signal_not_emitted(e.hud, "menu_demande", "Un appui : on demande confirmation")
	e.hud._demander_menu()
	assert_signal_not_emitted(e.hud, "menu_demande", "Le clic et le toucher d'un même appui ne confirment pas")
	await wait_seconds(0.3)
	e.hud._demander_menu()
	assert_signal_emitted(e.hud, "menu_demande", "Le second appui abandonne")
