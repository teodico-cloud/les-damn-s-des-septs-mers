extends GutTest
## Jalon 4, étape 1 (choix de Téo : « au sol, façon Diablo ») : les squelettes, le coffre et le Bosco
## lâchent objets et doublons, chacun le sien à deux, ramassés en passant dessus, dans un sac perdu en
## cas de défaite ; l'écran de fin montre le butin rapporté.

const EQ: Equilibrage = preload("res://data/equilibrage.tres")


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
	Partie.destination = &"expedition"
	Partie.malediction = 0
	Arene.chance_orbe = 0.0


func after_each() -> void:
	Partie.destination = &"arene"
	Partie.malediction = 0


func _expedition() -> Expedition:
	var e: Expedition = load("res://game/expedition/expedition.tscn").instantiate()
	add_child_autofree(e)
	await wait_physics_frames(3)
	e.hud.menu_demande.disconnect(e.retour_menu)
	return e


## Fait retomber tout de suite le butin en vol (sans attendre son saut).
func _poser(e: Expedition) -> void:
	for o in e.butin_au_sol.get_children():
		o.pose = true


func _objet_de(base: String, rarete: int) -> Dictionary:
	return {"id": "%s_%d_%d" % [base, rarete, randi()], "base": base, "rarete": rarete, "effets": []}


func _rng(graine: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = graine
	return r


## Les objets au sol qui reviennent à `h` (ceux en train d'être retirés exclus).
func _au_sol(e: Expedition, h: Node) -> Array:
	if e.butin_au_sol == null:
		return []
	return e.butin_au_sol.get_children().filter(func(o): return not o.is_queued_for_deletion() and o.proprietaire == String(h.name))


# ---------------------------------------------------------------- catalogue
func test_catalogue_complet() -> void:
	for cle in Butin.BASES:
		var d: Dictionary = Butin.BASES[cle]
		assert_true(ResourceLoader.exists(d["modele"]), "%s : modèle %s" % [cle, d["modele"]])
		assert_true(d["type"] in ["arme", "relique"])
	for cle in Butin.UNIQUES:
		var d: Dictionary = Butin.UNIQUES[cle]
		assert_true(ResourceLoader.exists(d["modele"]), "%s : modèle %s" % [cle, d["modele"]])
		assert_true(d["rarete"] >= Butin.Rarete.LEGENDAIRE, "%s : unique = Légendaire ou Maudit" % cle)
		assert_ne(String(d.get("effet", "")), "", "%s : son effet est décrit" % cle)
	assert_eq(Butin.nom({"base": "sabre", "rarete": 1}), "Sabre d'abordage")
	assert_eq(Butin.nom_complet({"base": "lame_du_noye", "rarete": 3}), "Lame du Noyé (Légendaire)")
	assert_eq(Butin.couleur({"base": "cle", "rarete": 4}), Butin.COULEURS[4])


func test_armes_du_bon_heros() -> void:
	var r := _rng(7)
	var raretes := {}
	for i in 600:
		for heros in [&"bretteur", &"occultiste"]:
			var o := Butin.tirer_objet(r, heros, 5)
			var d := Butin.definition(o)
			assert_false(d.is_empty(), "Objet connu : %s" % o)
			assert_true(d["heros"] in ["", String(heros)], "%s ne tire pas %s" % [heros, o["base"]])
			assert_eq(String(o["id"]).length(), 16, "Un identifiant unique")
			raretes[o["rarete"]] = true
	assert_eq(raretes.size(), 5, "Les cinq raretés tombent (malédiction 5, 1200 tirages)")


func test_rarete_minimum_et_malediction() -> void:
	var r := _rng(11)
	for i in 300:
		assert_gte(Butin.tirer_rarete(r, 0, Butin.Rarete.EPIQUE), Butin.Rarete.EPIQUE, "Jamais sous le minimum")
	var belles := [0, 0]   # Épique ou mieux, malédiction 0 puis 5
	for k in 2:
		var rr := _rng(23)
		for i in 4000:
			if Butin.tirer_rarete(rr, 5 * k) >= Butin.Rarete.EPIQUE:
				belles[k] += 1
	assert_between(belles[0], 320, 560, "Malédiction 0 : ~12 %% d'Épique ou mieux (%d/4000)" % belles[0])
	assert_gt(belles[1], belles[0] * 1.6, "Malédiction 5 : nettement plus de belles raretés (%d contre %d)" % [belles[1], belles[0]])


func test_chance_d_objet_et_malediction() -> void:
	Partie.destination = &"arene"
	Partie.malediction = 3
	assert_almost_eq(Butin.chance_objet(&"matelot"), EQ.butin_objet_matelot, 0.0001, "Hors expédition : pas de bonus")
	Partie.destination = &"expedition"
	assert_almost_eq(Butin.chance_objet(&"matelot"), EQ.butin_objet_matelot * 1.6, 0.0001, "Malédiction 3 : ×1,6")
	assert_almost_eq(Butin.chance_objet(&"pretre"), EQ.butin_objet_pretre * 1.6, 0.0001)
	assert_gt(EQ.butin_objet_pretre, EQ.butin_objet_matelot, "Le prêtre lâche plus souvent qu'un matelot")


# ---------------------------------------------------------------- au sol
func test_les_squelettes_lachent_du_butin() -> void:
	var e := await _expedition()
	e._rng_butin.seed = 5
	var s := Ennemi.creer_type(&"matelot", true)
	s.position = Vector3(2, 0, 2)
	e.generateur.add_child(s)
	await wait_physics_frames(2)
	for i in 200:
		e._on_ennemi_vaincu_butin(s)
	var tas := _au_sol(e, e.heros)
	var objets := tas.filter(func(o): return not o.est_doublons()).size()
	var pieces := tas.filter(func(o): return o.est_doublons())
	assert_between(objets, 4, 26, "~6 %% d'objets sur 200 matelots (%d)" % objets)
	assert_between(pieces.size(), 50, 92, "~35 %% de tas de doublons (%d)" % pieces.size())
	for p in pieces:
		assert_between(p.doublons, EQ.butin_doublons_min, EQ.butin_doublons_max)
	for o in tas:
		assert_true(o.visible, "Seul : on voit tout son butin")
		assert_lte(absf(o.position.x), Salle.DEMI - 0.7, "Dans la salle")
		assert_lte(absf(o.position.z), Salle.DEMI - 0.7, "Dans la salle")


func test_le_bosco_lache_un_tresor() -> void:
	Partie.debug_depart = &"bosco"
	var e := await _expedition()
	await wait_physics_frames(30)
	e.bosco.sante.subir(99999.0, e.heros)
	await wait_physics_frames(3)
	var tas := _au_sol(e, e.heros)
	var objets := tas.filter(func(o): return not o.est_doublons())
	assert_eq(objets.size(), EQ.butin_bosco_objets, "Le Bosco lâche ses objets")
	assert_gte(objets.map(func(o): return o.objet["rarete"]).max(), Butin.Rarete.EPIQUE, "Dont au moins un Épique")
	for o in objets:
		assert_gte(o.objet["rarete"], Butin.Rarete.RARE, "Rien de commun sur le Bosco")
	var pieces := tas.filter(func(o): return o.est_doublons())
	assert_eq(pieces.size(), 1)
	assert_eq(pieces[0].doublons, EQ.butin_bosco_doublons)
	# (le hasard : 40 autres tirages, toujours au moins un Épique, jamais de Commun)
	var sans_epique := 0
	var communs := 0
	for i in 40:
		var avant := e.butin_au_sol.get_child_count()
		e._on_ennemi_vaincu_butin(e.bosco)
		var nouveaux := e.butin_au_sol.get_children().slice(avant).filter(func(o): return not o.est_doublons())
		var raretes: Array = nouveaux.map(func(o): return o.objet["rarete"])
		if raretes.max() < Butin.Rarete.EPIQUE:
			sans_epique += 1
		communs += raretes.count(Butin.Rarete.COMMUN)
	assert_eq(sans_epique, 0, "Toujours au moins un Épique sur le Bosco")
	assert_eq(communs, 0, "Jamais de Commun sur le Bosco")


func test_le_coffre_crache_son_tresor() -> void:
	Partie.debug_depart = &"tresor"
	var e := await _expedition()
	e.heros.global_position = e.salle.coffre.global_position + Vector3(1.0, 0, -0.2)
	await wait_physics_frames(3)
	assert_true(e.salle.coffre_ouvert)
	var objets := _au_sol(e, e.heros).filter(func(o): return not o.est_doublons()).map(func(o): return o.objet)
	objets.append_array(e.sacs.get(String(e.heros.name), {"objets": []})["objets"])   # (déjà ramassés)
	assert_eq(objets.size(), EQ.butin_coffre_objets, "Le coffre crache ses objets")
	for o in objets:
		assert_gte(o["rarete"], Butin.Rarete.RARE, "Au moins Rare dans un coffre")


func test_ramasser_en_passant_dessus() -> void:
	var e := await _expedition()
	var objet := {"id": "test01", "base": "hache", "rarete": Butin.Rarete.EPIQUE, "effets": []}
	var ici := e.heros.global_position + Vector3(3.0, 0, 0)
	e._lacher(e.heros, objet, 0, ici, ici)
	e._lacher(e.heros, {}, 12, ici, ici + Vector3(0, 0, 0.5))
	await wait_physics_frames(3)
	assert_eq(_au_sol(e, e.heros).size(), 2, "Encore au sol : trop loin")
	assert_false(e.hud.label_sac.visible, "Sac encore vide")
	e.heros.global_position = ici + Vector3(0, 0, 0.2)
	await wait_physics_frames(3)
	assert_eq(_au_sol(e, e.heros).size(), 2, "Pas ramassé en plein vol")
	await get_tree().create_timer(0.45).timeout
	await wait_physics_frames(2)
	assert_eq(_au_sol(e, e.heros).size(), 0, "Ramassé en passant dessus")
	var sac: Dictionary = e.sacs[String(e.heros.name)]
	assert_eq(sac["objets"], [objet])
	assert_eq(sac["doublons"], 12)
	assert_true(e.hud.label_sac.visible)
	assert_eq(e.hud.label_sac.text, "Sac : 1 objet · 12 doublons")
	var lignes := e.hud.fil_butin.get_children().map(func(l): return l.text)
	assert_has(lignes, "Hache d'abordage (Épique)", "Le fil du butin")
	assert_has(lignes, "+12 doublons")
	var ligne_hache := e.hud.fil_butin.get_children().filter(func(l): return l.text.begins_with("Hache"))[0] as Label
	assert_eq(ligne_hache.get_theme_color("font_color"), Butin.COULEURS[Butin.Rarete.EPIQUE], "À la couleur de sa rareté")


func test_a_terre_on_ne_ramasse_rien() -> void:
	var e := await _expedition()
	var ici := e.heros.global_position + Vector3(0, 0, 0.3)
	e.heros.sante.invulnerable_jusqua = 0.0
	e.heros.sante.subir(99999.0, null)
	await wait_physics_frames(2)
	e._lacher(e.heros, {}, 5, ici, ici)
	_poser(e)
	await wait_physics_frames(3)
	assert_false(e.finie, "(l'écran de fin n'est pas encore là)")
	assert_eq(_au_sol(e, e.heros).size(), 1, "Un héros à terre ne ramasse pas")


func test_le_butin_laisse_derriere_soi_est_perdu() -> void:
	var e := await _expedition()
	var ici := Vector3(4, 0, 4)
	e._lacher(e.heros, {}, 5, ici, ici)
	await wait_physics_frames(2)
	e._changer_de_salle(2, PlanExpedition.COMBAT, e.modele, [])
	await wait_physics_frames(2)
	assert_eq(_au_sol(e, e.heros).size(), 0, "Rien ne suit dans la salle suivante")


# ---------------------------------------------------------------- coop (chacun le sien)
func test_a_deux_chacun_son_butin() -> void:
	Partie.debug_depart = &"bosco"
	var e := await _expedition()
	var invite := Heros.creer(&"occultiste")
	invite.name = "HerosInvite"
	invite.position = Vector3(-3, 0, 3)
	e.add_child(invite)
	e.heros_partenaire = invite
	await wait_physics_frames(30)
	e.bosco.sante.subir(99999.0, e.heros)
	await wait_physics_frames(3)
	var a_moi := _au_sol(e, e.heros)
	var a_lui := _au_sol(e, invite)
	assert_eq(a_moi.size(), EQ.butin_bosco_objets + 1, "Le Bosco lâche pour l'hôte…")
	assert_eq(a_lui.size(), EQ.butin_bosco_objets + 1, "… et autant pour l'invité")
	for o in a_moi:
		assert_true(o.visible, "L'hôte voit le sien")
	for o in a_lui:
		assert_false(o.visible, "Pas celui de l'invité (seul l'invité le voit, chez lui)")
		if not o.est_doublons():
			var d := Butin.definition(o.objet)
			assert_true(d["heros"] in ["", "occultiste"], "Les armes de l'invité sont pour son Occultiste")
	_poser(e)
	# l'hôte passe sur le butin de l'invité : il ne le prend pas
	e.heros.global_position = a_lui[0].global_position
	await wait_physics_frames(3)
	assert_true(is_instance_valid(a_lui[0]) and not a_lui[0].is_queued_for_deletion(), "L'hôte ne prend pas le butin de l'invité")
	# l'invité passe dessus : dans son sac (décidé par l'hôte), sans toucher au sac de l'hôte
	var sac_hote_avant: Dictionary = e.sacs.get("HerosHote", {}).duplicate(true)
	invite.global_position = a_lui[0].global_position
	await wait_physics_frames(3)
	assert_true(e.sacs.has("HerosInvite"), "Le sac de l'invité, tenu par l'hôte")
	assert_eq(e.sacs.get("HerosHote", {}), sac_hote_avant, "Le sac de l'hôte n'a pas bougé")


func test_l_invite_recoit_et_ramasse_son_butin() -> void:
	var e := await _expedition()
	var objet := {"id": "abc123", "base": "baton", "rarete": Butin.Rarete.RARE, "effets": []}
	e.evenement_lieu("butin", [e.numero, "abc123", objet, 0, Vector3(1, 0, 1), Vector3(2, 0, 2)])
	e.evenement_lieu("butin", [e.numero + 1, "zzz", objet, 0, Vector3(1, 0, 1), Vector3(2, 0, 2)])
	var o := e.butin_au_sol.get_node_or_null("Butin_abc123") as ObjetAuSol
	assert_not_null(o, "L'objet tiré par l'hôte apparaît chez l'invité")
	assert_null(e.butin_au_sol.get_node_or_null("Butin_zzz"), "Pas celui d'une autre salle")
	assert_true(o.visible)
	assert_eq(o.proprietaire, String(e.heros.name))
	e.evenement_lieu("ramasse", ["abc123", objet, 0])
	assert_true(o.is_queued_for_deletion(), "Ramassé : il disparaît")
	assert_eq(e.sacs[String(e.heros.name)]["objets"], [objet])
	assert_eq(e.hud.label_sac.text, "Sac : 1 objet · 0 doublons")


# ---------------------------------------------------------------- fin d'expédition
func test_victoire_le_butin_est_rapporte() -> void:
	var e := await _expedition()
	var objet := {"id": "v1", "base": "lame_du_noye", "rarete": Butin.Rarete.LEGENDAIRE, "effets": []}
	e._mettre_au_sac(String(e.heros.name), objet, 0)
	e._mettre_au_sac(String(e.heros.name), {}, 30)
	e._terminer(true)
	await wait_physics_frames(2)
	var textes := e.hud.panneau_fin.find_children("*", "Label", true, false)
	var lame := textes.filter(func(l): return l.text == "Lame du Noyé")
	assert_true(textes.any(func(l): return l.text == "Butin rapporté : 1 objet et 30 doublons"), "Le résumé du butin")
	assert_eq(lame.size(), 1, "L'objet rapporté, sur l'écran de fin")
	assert_eq(lame[0].get_theme_color("font_color"), Butin.COULEURS[Butin.Rarete.LEGENDAIRE], "À la couleur de sa rareté")
	assert_false(e.hud.label_sac.visible, "Le sac s'efface derrière l'écran de fin")


func test_defaite_le_butin_est_perdu() -> void:
	var e := await _expedition()
	var objet := {"id": "d1", "base": "sabre", "rarete": Butin.Rarete.RARE, "effets": []}
	e._mettre_au_sac(String(e.heros.name), objet, 0)
	e._mettre_au_sac(String(e.heros.name), {}, 7)
	e._terminer(false)
	await wait_physics_frames(2)
	var textes := e.hud.panneau_fin.find_children("*", "Label", true, false)
	assert_true(textes.any(func(l): return l.text == "Butin perdu : 1 objet et 7 doublons"), "Défaite : le sac est perdu")
	assert_false(textes.any(func(l): return l.text == "Sabre d'abordage"), "Rien n'est rapporté")


func test_l_invite_voit_son_sac_final() -> void:
	var e := await _expedition()
	var objet := {"id": "i1", "base": "fiole", "rarete": Butin.Rarete.COMMUN, "effets": []}
	var sacs := {"HerosHote": {"objets": [objet], "doublons": 9}, "HerosInvite": {"objets": [], "doublons": 3}}
	e.evenement_lieu("fin", [true, ["Toutes les salles traversées", "Malédiction 0"], sacs])
	await wait_physics_frames(2)
	var textes := e.hud.panneau_fin.find_children("*", "Label", true, false)
	assert_true(textes.any(func(l): return l.text == "Butin rapporté : 1 objet et 9 doublons"),
			"Le sac décidé par l'hôte (ici, notre héros est %s)" % e.heros.name)


func test_les_noms_ne_se_chevauchent_pas() -> void:
	var e := await _expedition()
	var ici := Vector3(2, 0, 2)
	e._lacher(e.heros, _objet_de("sabre", 1), 0, ici, ici)
	e._lacher(e.heros, _objet_de("fiole", 2), 0, ici, ici + Vector3(0.5, 0, 0))
	e._lacher(e.heros, {}, 4, ici, ici + Vector3(-6.0, 0, 0))
	var tas := _au_sol(e, e.heros)
	assert_eq(tas.map(func(o): return o.etage), [0, 1, 0], "Le nom du 2e monte d'un cran ; loin, pas besoin")
	var hauteurs := tas.slice(0, 2).map(func(o): return o.find_children("*", "Label3D", true, false)[0].position.y)
	assert_gt(hauteurs[1], hauteurs[0] + 0.2)


func test_ecran_de_fin_les_plus_rares_d_abord() -> void:
	var e := await _expedition()
	for i in 12:
		e._mettre_au_sac(String(e.heros.name), _objet_de("cle", 0), 0)
	e._mettre_au_sac(String(e.heros.name), _objet_de("coeur_kraken", 4), 0)
	e._terminer(true)
	await wait_physics_frames(2)
	var flot := e.hud.panneau_fin.find_children("*", "HFlowContainer", true, false)[0]
	var textes: Array = flot.get_children().map(func(l): return l.text)
	assert_eq(textes.size(), 11, "Au plus 10 noms, puis le reste en une ligne")
	assert_eq(textes[0], "Cœur de Kraken", "Le plus rare d'abord")
	assert_eq(textes[10], "… et 3 autres")
