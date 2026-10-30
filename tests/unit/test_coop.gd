extends GutTest
## Briques de la coop testables sans réseau : adresse et code, marionnettes (squelette et héros
## affichés d'après l'hôte), événements décidés par l'hôte pour le héros de l'invité.
## L'échange réel entre deux copies du jeu est testé par tools/test_coop.sh.

const EQ: Equilibrage = preload("res://data/equilibrage.tres")

var monde: Node3D



## Dégâts exacts dans ces tests : pas de coup critique (testés à part dans test_nervosite.gd).
func before_all() -> void:
	Combat.chance_critique = 0.0


func after_all() -> void:
	Combat.chance_critique = -1.0


func before_each() -> void:
	monde = Node3D.new()
	add_child_autofree(monde)
	var sol := StaticBody3D.new()
	sol.collision_layer = Combat.COUCHE_MONDE
	var forme := CollisionShape3D.new()
	var boite := BoxShape3D.new()
	boite.size = Vector3(40, 0.2, 40)
	forme.shape = boite
	sol.add_child(forme)
	sol.position.y = -0.1
	monde.add_child(sol)


func after_each() -> void:
	Reseau.quitter()


func test_code_et_adresse() -> void:
	var a: String = Reseau.adresse_locale()
	if a == "":
		pass_test("Pas de réseau ici : rien à vérifier")
		return
	var code: int = Reseau.code_local()
	assert_eq(code, int(a.split(".")[3]), "Le code est le dernier nombre de l'adresse")
	assert_eq(Reseau.adresse_depuis_code(code), a, "Le code redonne l'adresse sur le même réseau")
	assert_eq(Reseau.adresse_depuis_code(0), "", "Code hors limites refusé")
	assert_eq(Reseau.adresse_depuis_code(300), "", "Code hors limites refusé")


func test_heros_differents_imposes() -> void:
	assert_eq(Reseau._autre_heros(&"bretteur"), &"occultiste")
	assert_eq(Reseau._autre_heros(&"occultiste"), &"bretteur")


func test_hors_coop_par_defaut() -> void:
	assert_false(Reseau.est_en_coop())
	assert_false(Reseau.est_invite())


func test_commandes_signalent_les_actions() -> void:
	var c := CommandesHeros.new()
	watch_signals(c)
	c.demander(&"esquive", 0.0)
	assert_signal_emitted_with_parameters(c, "action_demandee", [&"esquive"])


func test_squelette_marionnette_affiche_sans_agir() -> void:
	var e := Ennemi.creer(true)
	e.marionnette = true
	monde.add_child(e)
	await wait_physics_frames(2)
	# il n'a aucune règle : ni dégâts, ni marque, ni chaînes, ni déplacement par lui-même
	assert_eq(e.recevoir_coup(30.0, null, true), 0.0)
	e.immobiliser(2.0)
	assert_ne(e.etat, Ennemi.Etat.ENCHAINE)
	# il affiche ce que l'hôte envoie
	e.appliquer_instantane(Ennemi.Etat.PREPARATION, "1H_Melee_Attack_Chop", 1.0, 21.0, true)
	assert_eq(e.etat, Ennemi.Etat.PREPARATION)
	assert_true(e.marque.visible, "Annonce au sol visible")
	assert_not_null(e._yeux.material_override, "Yeux rouges")
	assert_eq(e.sante.pv, 21.0)
	assert_true(e._rune.visible, "Rune de la Marque visible")
	e.appliquer_instantane(Ennemi.Etat.ENCHAINE, "Idle_Combat", 0.25, 21.0, false)
	assert_not_null(e._chaines, "Chaînes visibles")
	assert_false(e.marque.visible)
	assert_false(e._rune.visible, "Marque effacée")
	e.appliquer_instantane(Ennemi.Etat.MORT, "Death_C_Skeletons", 1.0, 0.0, false)
	assert_null(e._chaines)
	assert_false(e.is_in_group("ennemis"), "Un mort ne compte plus")
	var pos := e.global_position
	await wait_physics_frames(10)
	assert_eq(e.global_position, pos, "Il ne bouge pas tout seul")


func test_instantane_squelette_aller_retour() -> void:
	var hote := Ennemi.creer(true)
	hote.position = Vector3(2, 0, 3)
	monde.add_child(hote)
	await wait_physics_frames(2)
	hote.marquer(null, 5.0)
	var invite := Ennemi.creer(true)
	invite.marionnette = true
	monde.add_child(invite)
	await wait_physics_frames(1)
	var d: Array = hote.instantane()
	invite.appliquer_instantane(d[2], d[3], d[4], d[5], d[6])
	assert_eq(invite.etat, hote.etat)
	assert_eq(invite.sante.pv, hote.sante.pv)
	assert_true(invite.est_marque())


func test_instantane_tient_dans_un_paquet_wifi() -> void:
	# 8 squelettes debout + 3 vaincus (les 0,6 s avant de disparaître) + 2 héros : sous 1 392 octets
	# (au-delà, Godot découpe l'instantané, et un morceau perdu le perd tout entier)
	var gen := GenerateurEnnemis.new()
	gen.demarrage_auto = false
	monde.add_child(gen)
	for i in 11:
		var e := Ennemi.creer(true)
		e.name = "Squelette_%d" % (100 + i)
		e.position = Vector3(i - 5, 0, 2)
		gen.add_child(e)
	var a := Bretteur.new()
	a.name = "HerosHote"
	monde.add_child(a)
	var b := Occultiste.new()
	b.name = "HerosInvite"
	monde.add_child(b)
	await wait_physics_frames(3)
	var tues := 0
	for e in gen.get_children():
		if tues < 3:
			e.marquer(a, 5.0)
			e.sante.subir(9999.0, a)
			tues += 1
	var s := SynchroArene.new()
	autofree(s)
	s.generateur = gen
	s.heros_local = a
	s.heros_partenaire = b
	var ennemis: Dictionary = s._etat_ennemis()
	assert_eq(ennemis.size(), 11)
	var taille := var_to_bytes([99999, s._etat_heros(), ennemis, 99999]).size()
	assert_lt(taille, 1300, "Instantané de %d octets" % taille)
	# un squelette vaincu voyage en court, avec son tueur (les os partent loin de lui chez l'invité)
	var court: Array = SynchroArene._deballer(ennemis["Squelette_100"])
	assert_eq(court.size(), 4)
	assert_eq(court[3], "HerosHote")
	# et un squelette debout se retrouve identique chez l'invité (à la précision près)
	var debout: Ennemi = gen.get_node("Squelette_110")
	var v: Array = debout.instantane()
	var w: Array = SynchroArene._deballer(ennemis["Squelette_110"])
	assert_eq(w.size(), v.size())
	assert_almost_eq((w[0] as Vector3).distance_to(v[0]), 0.0, 0.001)
	for i in range(1, v.size()):
		if v[i] is bool:
			assert_eq(w[i], v[i])
		else:
			assert_almost_eq(float(w[i]), float(v[i]), 0.001, "valeur %d" % i)


func test_marionnette_vaincue_eclate_loin_du_tueur() -> void:
	var e := Ennemi.creer(true)
	e.marionnette = true
	monde.add_child(e)
	var tueur := Node3D.new()
	tueur.position = Vector3(-3, 0, 0)
	monde.add_child(tueur)
	await wait_physics_frames(2)
	var avant := monde.get_child_count()
	e.appliquer_mort(tueur)
	assert_eq(e.etat, Ennemi.Etat.MORT)
	assert_false(e.visuel.visible, "Il a éclaté")
	assert_gt(monde.get_child_count(), avant, "Ses os volent")
	var vers_x := 0.0
	for c in monde.get_children():
		if c is RigidBody3D:
			vers_x += c.linear_velocity.x
	assert_gt(vers_x, 0.0, "Les os partent à l'opposé du tueur")


func test_heros_marionnette_ne_simule_rien() -> void:
	var h := Bretteur.new()
	h.marionnette = true
	monde.add_child(h)
	await wait_physics_frames(2)
	h.commandes.deplacement = Vector3(1, 0, 0)
	var pos := h.global_position
	await wait_physics_frames(10)
	assert_eq(h.global_position, pos, "Une marionnette ne bouge que par l'hôte")
	h.appliquer_instantane(Heros.Etat.ATTAQUE, "1H_Melee_Attack_Chop", 1.3, 63.0, true)
	assert_eq(h.etat, Heros.Etat.ATTAQUE)
	assert_eq(h.sante.pv, 63.0)
	assert_eq(h.anim.current_animation, "1H_Melee_Attack_Chop")


func test_evenements_de_l_hote_pour_le_heros_de_l_invite() -> void:
	var h := Occultiste.new()
	h.reapparition_auto = false
	monde.add_child(h)
	await wait_physics_frames(2)
	h.evenement_autorite("touche", 65.0, Vector3(0, 0, 3))
	assert_eq(h.etat, Heros.Etat.TOUCHE, "Coup décidé par l'hôte")
	assert_eq(h.sante.pv, 65.0)
	h.evenement_autorite("mort", 0.0, Vector3.ZERO)
	assert_eq(h.etat, Heros.Etat.MORT)
	await wait_physics_frames(int(EQ.heros_delai_reapparition * 60.0) + 10)
	assert_eq(h.etat, Heros.Etat.MORT, "L'invité ne réapparaît pas tout seul")
	h.evenement_autorite("reapparu", EQ.occ_pv_max, Vector3(3, 0, 1))
	assert_eq(h.etat, Heros.Etat.LIBRE)
	assert_almost_eq(h.global_position.x, 3.0, 0.05, "À l'endroit décidé par l'hôte")
	assert_eq(h.sante.pv, EQ.occ_pv_max)


func test_riposte_decidee_par_l_hote() -> void:
	var h := Bretteur.new()
	monde.add_child(h)
	await wait_physics_frames(2)
	h.evenement_autorite("riposte", 100.0, Vector3(0, 0, -2))
	assert_eq(h.etat, Heros.Etat.RIPOSTE)
	assert_almost_eq(h.avant().z, -1.0, 0.05, "Tourné vers l'attaquant")


# ---------------------------------------------------------------- réanimation (règles de l'hôte)
func _duo() -> Array:
	var a := Bretteur.new()
	a.position = Vector3(-1, 0, 0)
	monde.add_child(a)
	var b := Occultiste.new()
	b.position = Vector3(1, 0, 0)
	monde.add_child(b)
	var gen := GenerateurEnnemis.new()
	gen.nombre = 0
	monde.add_child(gen)
	var regles := ReglesCoop.new()
	regles.configurer(a, b, gen)
	monde.add_child(regles)
	await wait_physics_frames(2)
	return [a, b, regles]


func _secondes(s: float) -> void:
	await wait_physics_frames(int(ceil(s * 60.0)) + 1)


func test_a_terre_il_ne_reapparait_pas_seul() -> void:
	var duo: Array = await _duo()
	var a: Heros = duo[0]
	var b: Heros = duo[1]
	b.global_position = Vector3(8, 0, 0)   # partenaire loin
	Combat.porter_coup(b, a, 500.0, false)
	await _secondes(EQ.heros_delai_reapparition + 0.5)
	assert_eq(a.etat, Heros.Etat.MORT, "Toujours à terre : seul le partenaire peut le relever")
	assert_eq(a.progres_reanimation, 0.0)


func test_le_partenaire_releve_en_restant_pres() -> void:
	var duo: Array = await _duo()
	var a: Heros = duo[0]
	var b: Heros = duo[1]
	b.global_position = Vector3(0, 0, 0.5)   # juste à côté (zone de 1.8 m)
	Combat.porter_coup(b, a, 500.0, false)
	await _secondes(EQ.reanimation_duree * 0.5)
	assert_almost_eq(a.progres_reanimation, 0.5, 0.1, "La moitié de la réanimation après 1,5 s")
	assert_true(a._zone_reanimation.visible, "Zone verte visible")
	await _secondes(EQ.reanimation_duree * 0.5 + 0.1)
	assert_eq(a.etat, Heros.Etat.LIBRE, "Relevé")
	assert_almost_eq(a.sante.pv, EQ.heros_pv_max * EQ.reanimation_pv, 0.01, "Avec la moitié de ses PV")
	assert_true(a.sante.est_invulnerable(), "Un instant intouchable")
	assert_false(a._zone_reanimation.visible, "Zone retirée")


func test_s_eloigner_fait_redescendre_la_reanimation() -> void:
	var duo: Array = await _duo()
	var a: Heros = duo[0]
	var b: Heros = duo[1]
	b.global_position = Vector3(0, 0, 0.5)   # juste à côté (zone de 1.8 m)
	Combat.porter_coup(b, a, 500.0, false)
	await _secondes(EQ.reanimation_duree * 0.5)
	var p := a.progres_reanimation
	b.global_position = Vector3(8, 0, 0)
	await _secondes(1.0)
	assert_lt(a.progres_reanimation, p, "La progression redescend quand il s'éloigne")
	assert_eq(a.etat, Heros.Etat.MORT)


func test_les_deux_a_terre_retour_au_depart() -> void:
	var duo: Array = await _duo()
	var a: Heros = duo[0]
	var b: Heros = duo[1]
	var regles: ReglesCoop = duo[2]
	a.global_position = Vector3(-4, 0, 3)
	b.global_position = Vector3(4, 0, -3)
	Combat.porter_coup(b, a, 500.0, false)
	Combat.porter_coup(a, b, 500.0, false)
	await _secondes(0.5)
	assert_gt(regles.temps_avant_retour, 0.0, "Compte à rebours lancé")
	await _secondes(EQ.coop_delai_retour)
	assert_eq(a.etat, Heros.Etat.LIBRE)
	assert_eq(b.etat, Heros.Etat.LIBRE)
	assert_eq(a.sante.pv, EQ.heros_pv_max, "Retour au départ avec tous ses PV")
	assert_almost_eq(a.global_position.x, -1.0, 0.1, "À son point de départ")
	assert_almost_eq(b.global_position.x, 1.0, 0.1)


# ---------------------------------------------------------------- instantanés (relecture du jalon 2)
func test_instantane_n_envoie_pas_la_vitesse_figee_par_l_arret_sur_image() -> void:
	var e := Ennemi.creer(true)
	monde.add_child(e)
	var h := Bretteur.new()
	monde.add_child(h)
	await wait_physics_frames(2)
	e._jouer("Hit_A", 1.4, 0.0, true)
	h._jouer("Hit_A", 1.3, 0.0, true)
	e.anim.speed_scale = 0.0   # arrêt sur image local de l'hôte au moment de l'instantané
	h.anim.speed_scale = 0.0
	assert_almost_eq(float(e.instantane()[4]), 1.4, 0.01, "Squelette : la vitesse voulue, pas 0")
	assert_almost_eq(float(h.instantane()[4]), 1.3, 0.01, "Héros : la vitesse voulue, pas 0")


func test_marionnette_calee_sur_le_temps_de_l_hote() -> void:
	var e := Ennemi.creer(true)
	e.marionnette = true
	monde.add_child(e)
	await wait_physics_frames(2)
	# l'hôte annonce un coup commencé il y a 0,5 s : la zone doit être déjà remplie aux 5/7
	e.appliquer_instantane(Ennemi.Etat.PREPARATION, "1H_Melee_Attack_Chop", 0.84, 60.0, false, 0.5)
	await wait_physics_frames(1)
	assert_almost_eq(e._remplissage.scale.x, 0.5 / EQ.squelette_preparation, 0.08, "Remplissage calé sur l'hôte")
	assert_almost_eq(e.anim.current_animation_position, 0.5 * 0.84, 0.08, "Animation calée sur l'hôte")
	# même état ré-entré chez l'hôte (temps qui repart de 0) : l'animation repart aussi
	e.appliquer_instantane(Ennemi.Etat.PREPARATION, "1H_Melee_Attack_Chop", 0.84, 60.0, false, 0.0)
	assert_lt(e.anim.current_animation_position, 0.1, "Annonce relancée")
