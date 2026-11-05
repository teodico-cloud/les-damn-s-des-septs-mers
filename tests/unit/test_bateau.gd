extends GutTest
## Jalon 5, étape 2 (choix de Téo du 04/11) : le chantier naval et les quatre améliorations du bateau (cale,
## voiles, coque, bordée), leurs prix, l'achat (un niveau à la fois), la pastille « ! », le navire qui change
## d'aspect, et leurs effets en expédition ; la bordée visée au joystick.

const EQ: Equilibrage = preload("res://data/equilibrage.tres")


func before_all() -> void:
	Combat.chance_critique = 0.0


func after_all() -> void:
	Combat.chance_critique = -1.0
	Arene.chance_orbe = -1.0
	Partie.destination = &"arene"
	Partie.malediction = 0
	Partie.debug_depart = &""
	Partie.debug_tout_debloque = false
	Partie.lieu_repaire = &""
	Sauvegarde.reinitialiser()


func before_each() -> void:
	Engine.time_scale = 1.0
	Partie.revenir_en_solo()
	Partie.heros_local = &"bretteur"
	Partie.destination = &"arene"
	Partie.malediction = 0
	Partie.debug_depart = &""
	Partie.debug_sante_infinie = false
	Partie.debug_tout_debloque = false
	Partie.lieu_repaire = &""
	Arene.chance_orbe = 0.0
	Sauvegarde.reinitialiser()


func after_each() -> void:
	Partie.destination = &"arene"
	Partie.malediction = 0
	Reseau.role = Reseau.Role.AUCUN
	Reseau.id_partenaire = 0
	Reseau.bateau_partenaire = {}


## De quoi tout acheter (au-delà des plafonds de l'entrepôt : posé directement).
func _riche() -> void:
	Sauvegarde.donnees["doublons"] = 5000
	for m in Butin.MATIERES:
		Sauvegarde.donnees["ressources"][m] = 1000


func _repaire() -> Repaire:
	var r: Repaire = load("res://game/repaire/repaire.tscn").instantiate()
	r.changer_de_scene = false
	add_child_autofree(r)
	await wait_physics_frames(3)
	return r


func _expedition() -> Expedition:
	Partie.destination = &"expedition"
	var e: Expedition = load("res://game/expedition/expedition.tscn").instantiate()
	add_child_autofree(e)
	await wait_physics_frames(3)
	e.hud.menu_demande.disconnect(e.retour_menu)
	return e


# ---------------------------------------------------------------- niveaux et prix
func test_ce_que_donne_chaque_niveau() -> void:
	assert_eq([0, 1, 2, 3].map(func(n): return Bateau.places_cale(n)), [EQ.cale_places, 10, 12, 15])
	assert_eq([0, 1, 2, 3].map(func(n): return int(Bateau.duree_chaloupe(n))), [int(EQ.chaloupe_duree), 40, 35, 30])
	assert_eq([0, 1, 2, 3].map(func(n): return Bateau.malediction_max(n)), [2, 3, 4, 5])
	assert_eq([0, 1, 2, 3].map(func(n): return Bateau.tirs_bordee(n)), [0, 1, 2, 3])
	assert_eq(Bateau.texte_effet("cale", 2), "12 objets rapportés")
	assert_eq(Bateau.texte_effet("bordee", 0), "Aucun tir de canon")
	assert_eq(Bateau.texte_effet("bordee", 1), "1 tir de canon par expédition")


func test_prix_et_ce_qui_manque() -> void:
	var p := Bateau.prix("coque", 3)
	assert_eq(p, EQ.bateau_prix["coque"][2])
	assert_eq(Bateau.prix("coque", 4), {}, "Pas de niveau 4")
	assert_eq(Bateau.texte_prix({"doublons": 120, "bois": 30, "essence": 5}), "120 doublons · 30 bois de coque · 5 essence maudite")
	assert_eq(Bateau.manque({"doublons": 60, "bois": 15}), {"doublons": 60, "bois": 15}, "Rien en poche")
	Sauvegarde.encaisser("e", [], 70, {}, {"bois": 10})
	assert_eq(Bateau.manque({"doublons": 60, "bois": 15}), {"bois": 5})
	assert_false(Bateau.achat_possible())
	Sauvegarde.encaisser("f", [], 0, {}, {"bois": 10})
	assert_true(Bateau.achat_possible(), "La cale (60 doublons, 15 bois) devient possible")


func test_ameliorer_un_niveau_a_la_fois() -> void:
	var p1 := Bateau.prix("cale", 1)
	assert_false(Sauvegarde.ameliorer_bateau("cale", 1), "Trop pauvre")
	_riche()
	assert_false(Sauvegarde.ameliorer_bateau("cale", 2), "Pas de saut de niveau")
	assert_false(Sauvegarde.ameliorer_bateau("mat", 1), "Amélioration inconnue")
	assert_true(Sauvegarde.ameliorer_bateau("cale", 1))
	assert_eq(Sauvegarde.niveau_bateau("cale"), 1)
	assert_eq(Sauvegarde.doublons(), 5000 - int(p1["doublons"]), "Payé en doublons")
	assert_eq(Sauvegarde.ressource("bois"), 1000 - int(p1["bois"]), "… et en bois")
	assert_false(Sauvegarde.ameliorer_bateau("cale", 1), "Un double appui n'achète pas deux fois")
	assert_eq(Sauvegarde.doublons(), 5000 - int(p1["doublons"]))
	assert_true(Sauvegarde.ameliorer_bateau("cale", 2))
	assert_true(Sauvegarde.ameliorer_bateau("cale", 3))
	assert_false(Sauvegarde.ameliorer_bateau("cale", 4), "Au plus haut")
	assert_eq(Sauvegarde.donnees["achats"], ["bateau_cale_1", "bateau_cale_2", "bateau_cale_3"], "Le journal des achats")
	Sauvegarde.donnees = {}
	Sauvegarde.charger()
	assert_eq(Sauvegarde.niveau_bateau("cale"), 3, "Gardé dans la sauvegarde")
	assert_eq(Sauvegarde.donnees["achats"].size(), 3)


# ---------------------------------------------------------------- chantier naval, pastille, navire
func test_le_chantier_naval() -> void:
	var r := await _repaire()
	r.ouvrir(&"chantier")
	var p := r.hud.panneau as PanneauChantier
	assert_not_null(p, "Le chantier s'ouvre")
	await wait_process_frames(2)
	for a in Bateau.AMELIORATIONS:
		assert_true(p.boutons[a].disabled, a + " : trop pauvre")
	var textes: Array = p.find_children("*", "Label", true, false).map(func(l): return l.text)
	assert_has(textes, "8 objets rapportés  →  niveau 1 : 10 objets rapportés")
	assert_true(textes.any(func(t): return t.begins_with("Prix : ") and t.contains("(il manque ")))
	r.hud.fermer_panneau()
	_riche()
	r.ouvrir(&"chantier")
	p = r.hud.panneau as PanneauChantier
	await wait_process_frames(2)
	assert_false(p.boutons["bordee"].disabled)
	p.boutons["bordee"].pressed.emit()
	assert_eq(Sauvegarde.niveau_bateau("bordee"), 1, "Acheté")
	await wait_process_frames(2)
	textes = p.find_children("*", "Label", true, false).map(func(l): return l.text)
	assert_has(textes, "1 tir de canon par expédition  →  niveau 2 : 2 tirs de canon par expédition", "Le panneau se met à jour")
	assert_eq(r.navire.find_children("Canon*", "", true, false).size(), 2, "Le navire montre ses canons")


func test_la_pastille_du_chantier() -> void:
	var r := await _repaire()
	assert_false(r.pastilles[&"chantier"].visible, "Rien à acheter")
	assert_false(r.hud.raccourcis[&"chantier"].get_node_or_null("Pastille") != null and r.hud.raccourcis[&"chantier"].get_node("Pastille").visible)
	_riche()
	r.mettre_a_jour_pastilles()
	assert_true(r.pastilles[&"chantier"].visible, "« ! » au-dessus du chantier")
	assert_true(r.hud.raccourcis[&"chantier"].get_node("Pastille").visible, "… et sur son raccourci")
	assert_false(r.pastilles[&"cartes"].visible, "La salle des cartes n'a rien à vendre")
	for a in Bateau.AMELIORATIONS:
		for n in 3:
			Sauvegarde.ameliorer_bateau(a, n + 1)
	r.ouvrir(&"chantier")
	(r.hud.panneau as PanneauChantier).achete.emit("cale")   # (comme après un achat)
	assert_false(r.pastilles[&"chantier"].visible, "Tout est acheté : plus de pastille")


func test_le_navire_change_d_aspect() -> void:
	var r := await _repaire()
	var avant: Color = r.navire._voiles[0].material_override.albedo_color
	r.navire.appliquer({"cale": 2, "voiles": 3, "coque": 1, "bordee": 3})
	assert_eq(r.navire.find_children("Caisse*", "", true, false).size(), 2, "Deux caisses sur le pont")
	assert_eq(r.navire.find_children("Canon*", "", true, false).size(), 6, "Trois canons par flanc")
	assert_eq(r.navire.find_children("Bande*", "", true, false).size(), 4, "Des bandes de fer")
	var voile: StandardMaterial3D = r.navire._voiles[0].material_override
	assert_lt(voile.albedo_color.v, avant.v, "Voiles plus sombres")
	assert_true(voile.emission_enabled, "… qui luisent de vert")
	r.navire.appliquer({})
	assert_eq(r.navire.find_children("Canon*", "", true, false).size(), 0)


# ---------------------------------------------------------------- en expédition
func test_la_cale_du_bateau() -> void:
	Sauvegarde.donnees["bateau"]["cale"] = 2
	var e := await _expedition()
	assert_eq(e.cale, 12)
	for i in 11:
		e._mettre_au_sac(String(e.heros.name), {"id": "o%d" % i, "base": "cle", "rarete": 0, "effets": {}}, 0)
	assert_eq(e.hud.label_sac.text, "Sac : 11 objets / cale 12 · 0 doublons")
	e._terminer(true)
	await wait_physics_frames(2)
	assert_false(e.tri_en_cours, "11 objets tiennent dans une cale de 12 : pas de tri")
	assert_eq(Sauvegarde.objets().size(), 11)


func test_les_voiles_raccourcissent_la_chaloupe() -> void:
	Sauvegarde.donnees["bateau"]["voiles"] = 3
	Partie.debug_depart = &"chaloupe"
	var e := await _expedition()
	assert_eq(e.duree_chaloupe, 30.0)
	e.heros.global_position = e.salle.zone_chaloupe
	e._verifier_chaloupe(0.1)
	assert_eq(e.chaloupe_restant, 30.0, "Le compte part de 30 s")
	e._verifier_chaloupe(29.95)
	assert_false(e.finie)
	e._verifier_chaloupe(0.1)
	assert_true(e.finie, "Parti au bout de 30 s")


func test_a_deux_les_meilleures_voiles() -> void:
	Sauvegarde.donnees["bateau"]["voiles"] = 1
	Reseau.role = Reseau.Role.HOTE
	Reseau.id_partenaire = 99
	Reseau.bateau_partenaire = Bateau.niveaux_valides({"voiles": 2, "cale": 9})
	assert_eq(Bateau.duree_chaloupe_partie(), 35.0, "Les voiles de l'invité sont meilleures")
	assert_eq(Reseau.bateau_partenaire["cale"], 3, "Niveaux reçus ramenés à 3 au plus")
	Reseau.bateau_partenaire = {"voiles": 0}
	assert_eq(Bateau.duree_chaloupe_partie(), 40.0, "Les nôtres")


func test_la_coque_limite_la_malediction() -> void:
	Partie.malediction = 5
	var c := ChoixMalediction.new()
	add_child_autofree(c)
	await wait_process_frames(1)
	assert_eq(c.maximum, 2)
	assert_eq(Partie.malediction, 2, "Ramenée au plus haut permis")
	assert_true(c.bouton_plus.disabled)
	assert_true(c.label_coque.visible, "On dit comment aller plus loin")
	c.choisir(1, true)
	assert_eq(Partie.malediction, 2)
	Sauvegarde.donnees["bateau"]["coque"] = 2
	var c2 := ChoixMalediction.new()
	add_child_autofree(c2)
	await wait_process_frames(1)
	c2.choisir(5, false)
	assert_eq(Partie.malediction, 4, "Coque niveau 2 : jusqu'à 4")
	Partie.debug_tout_debloque = true
	var c3 := ChoixMalediction.new()
	add_child_autofree(c3)
	await wait_process_frames(1)
	c3.choisir(5, false)
	assert_eq(Partie.malediction, 5, "Mode test : tout débloqué")
	assert_false(c3.label_coque.visible)


# ---------------------------------------------------------------- bordée
func test_sans_canons_pas_de_bouton() -> void:
	var e := await _expedition()
	assert_false(e.hud.bouton_bordee.visible)
	e.demander_bordee(e.heros.global_position)
	assert_eq(get_tree().get_nodes_in_group("boulets").size(), 0, "Rien ne part")


func test_la_bordee_tire_et_compte() -> void:
	Sauvegarde.donnees["bateau"]["bordee"] = 2
	var e := await _expedition()
	e.generateur.reserve = 0
	for x in e.generateur.get_children():
		x.free()   # (la horde de la salle : rien ne doit blesser le héros pendant le test)
	assert_true(e.hud.bouton_bordee.visible)
	assert_eq(e.hud.bouton_bordee.compteur, 2)
	var s := Ennemi.creer_type(&"matelot", true)
	var cible := e.heros.global_position + Vector3(3.0, 0, -3.0)
	s.position = cible
	e.generateur.add_child(s)
	await wait_physics_frames(80)   # (sortie de terre)
	s.set_physics_process(false)   # (il reste où l'on vise)
	e.demander_bordee(cible)
	assert_eq(get_tree().get_nodes_in_group("boulets").size(), EQ.bordee_boulets, "Cinq boulets")
	assert_eq(e.tirs_bordee[String(e.heros.name)], 1)
	assert_eq(e.hud.bouton_bordee.compteur, 1)
	await wait_physics_frames(roundi((EQ.bordee_annonce + EQ.bordee_ecart * EQ.bordee_boulets) * 60) + 10)
	assert_eq(get_tree().get_nodes_in_group("boulets").size(), 0, "Tous tombés")
	assert_true(not is_instance_valid(s) or not s.est_vivant(), "Le squelette n'y a pas survécu")
	var pv_heros: float = e.heros.sante.pv
	e.heros.global_position = cible + Vector3(0.6, 0, 0)   # dans la zone : les héros sont épargnés
	e.demander_bordee(cible)
	await wait_physics_frames(roundi((EQ.bordee_annonce + EQ.bordee_ecart * EQ.bordee_boulets) * 60) + 10)
	assert_eq(e.heros.sante.pv, pv_heros, "Le héros est épargné")
	assert_eq(e.tirs_bordee[String(e.heros.name)], 0)
	assert_true(e.hud.bouton_bordee.inactif, "Plus de tirs : bouton grisé")
	var avant := get_tree().get_nodes_in_group("boulets").size()
	e.demander_bordee(cible)
	assert_eq(get_tree().get_nodes_in_group("boulets").size(), avant, "Rien de plus")


func test_la_bordee_ne_vise_pas_plus_loin_que_sa_portee() -> void:
	Sauvegarde.donnees["bateau"]["bordee"] = 1
	var e := await _expedition()
	e.heros.global_position = Vector3(-4.0, 0, 4.0)
	e.tirer_bordee(e.heros, Vector3(40.0, 0, -40.0))
	var boulets := get_tree().get_nodes_in_group("boulets")
	var centre: Vector3 = boulets[0].global_position
	var d := Vector2(centre.x - (-4.0), centre.z - 4.0).length()
	assert_lte(d, EQ.bordee_portee + 0.01, "Le premier boulet au plus à la portée (%.1f m)" % d)


func test_le_bosco_n_en_prend_que_la_moitie() -> void:
	Partie.debug_depart = &"bosco"
	var e := await _expedition()
	await wait_physics_frames(200)   # (sortie de terre)
	e.bosco.set_physics_process(false)   # (il reste où tombe le boulet)
	var pv: float = e.bosco.sante.pv
	Boulet.creer(e.salle, e.bosco.global_position, e.heros, 0.0)
	await wait_physics_frames(roundi(EQ.bordee_annonce * 60) + 6)
	assert_almost_eq(pv - e.bosco.sante.pv, EQ.bordee_degats * EQ.bordee_mult_bosco, 0.01)


func test_visee_au_joystick() -> void:
	Sauvegarde.donnees["bateau"]["bordee"] = 3
	var e := await _expedition()
	var hud := e.hud
	var tirs := []
	hud.bordee_demandee.connect(func(c): tirs.append(c))
	var centre := hud.bouton_bordee.centre_ecran()
	var toucher := InputEventScreenTouch.new()
	toucher.index = 2
	toucher.pressed = true
	toucher.position = centre
	hud._input(toucher)
	assert_true(hud.viseur_bordee.visible, "Bouton maintenu : la zone apparaît")
	var devant: Vector3 = e.heros.global_position + e.heros.avant() * EQ.bordee_portee_min
	assert_almost_eq(Vector2(hud.cible_bordee.x, hud.cible_bordee.z).distance_to(Vector2(devant.x, devant.z)), 0.0, 0.05, "Sans glisser : devant le héros")
	var glisser := InputEventScreenDrag.new()
	glisser.index = 2
	glisser.position = centre + Vector2(300, 0)   # vers la droite de l'écran, tout au bout
	hud._input(glisser)
	var attendu: Vector3 = e.heros.global_position + e.camera.joystick_vers_monde(Vector2(1, 0)).normalized() * EQ.bordee_portee
	assert_almost_eq(Vector2(hud.cible_bordee.x, hud.cible_bordee.z).distance_to(Vector2(attendu.x, attendu.z)), 0.0, 0.05, "La zone suit le pouce, jusqu'à la portée")
	assert_almost_eq(hud.viseur_bordee.global_position.x, hud.cible_bordee.x, 0.01)
	toucher.pressed = false
	hud._input(toucher)
	assert_eq(tirs.size(), 1, "Relâché : on tire")
	assert_false(hud.viseur_bordee.visible)
	assert_eq(e.tirs_bordee[String(e.heros.name)], 2)
	# un toucher annulé par le système (appel…) ne tire pas ; une pause non plus
	toucher.pressed = true
	hud._input(toucher)
	toucher.pressed = false
	toucher.canceled = true
	hud._input(toucher)
	toucher.canceled = false
	toucher.pressed = true
	hud._input(toucher)
	hud.relacher_tout()
	assert_eq(tirs.size(), 1, "Annulé : rien ne part")
	assert_eq(e.tirs_bordee[String(e.heros.name)], 2)


func test_l_invite_voit_les_boulets() -> void:
	var monde := Node3D.new()
	add_child_autofree(monde)
	var h := Heros.creer(&"occultiste")
	h.name = "HerosInvite"
	monde.add_child(h)
	var s := SynchroArene.new()
	s.arene = monde
	s.heros_local = h
	await wait_physics_frames(1)
	s._effet_recu("HerosInvite", "boulet_240", Vector3(1, 0, 2))   # (notre propre bordée : décidée par l'hôte)
	var b := monde.get_children().filter(func(c): return c is Boulet)
	assert_eq(b.size(), 1, "Le boulet de notre bordée, montré chez l'invité")
	assert_null(b[0].lanceur, "L'image seulement : l'hôte compte les dégâts")
	assert_almost_eq(b[0].delai, 0.24, 0.001)
