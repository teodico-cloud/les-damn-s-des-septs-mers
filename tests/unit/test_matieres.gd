extends GutTest
## Jalon 5, étape 1 (choix de Téo du 04/11) : les matériaux (bois de coque, fer noir, essence maudite)
## lâchés par les squelettes, le Bosco et le coffre, ramassés comme les doublons (sans place dans la cale,
## perdus en cas de défaite), rangés à l'entrepôt (plafond : le surplus est revendu) ; sauvegarde version 2.

const EQ: Equilibrage = preload("res://data/equilibrage.tres")


func before_all() -> void:
	Combat.chance_critique = 0.0


func after_all() -> void:
	Combat.chance_critique = -1.0
	Arene.chance_orbe = -1.0
	Partie.debug_depart = &""
	Partie.destination = &"arene"
	Partie.malediction = 0
	Sauvegarde.reinitialiser()


func before_each() -> void:
	Engine.time_scale = 1.0
	Partie.revenir_en_solo()
	Partie.heros_local = &"bretteur"
	Partie.debug_depart = &""
	Partie.debug_sante_infinie = false
	Partie.destination = &"expedition"
	Partie.malediction = 0
	Arene.chance_orbe = 0.0
	Sauvegarde.reinitialiser()


func after_each() -> void:
	Partie.destination = &"arene"
	Partie.malediction = 0


func _expedition() -> Expedition:
	var e: Expedition = load("res://game/expedition/expedition.tscn").instantiate()
	add_child_autofree(e)
	await wait_physics_frames(3)
	e.hud.menu_demande.disconnect(e.retour_menu)
	return e


func _au_sol(e: Expedition) -> Array:
	return e.butin_au_sol.get_children().filter(func(o): return not o.is_queued_for_deletion()) if e.butin_au_sol else []


func _textes_fin(e: Expedition) -> Array:
	return e.hud.panneau_fin.find_children("*", "Label", true, false).map(func(l): return l.text)


# ---------------------------------------------------------------- au sol
func test_chaque_squelette_lache_son_materiau() -> void:
	var e := await _expedition()
	e._rng_butin.seed = 11
	var attendus := {&"matelot": "bois", &"arbaletrier": "fer", &"pretre": "essence"}
	for type in attendus:
		for o in _au_sol(e):
			o.free()
		var s := Ennemi.creer_type(type, true)
		s.position = Vector3(2, 0, 2)
		e.generateur.add_child(s)
		await wait_physics_frames(1)
		for i in 300:
			e._on_ennemi_vaincu_butin(s)
		var m: String = attendus[type]
		var tas := _au_sol(e).filter(func(o): return o.est_tas() and not o.est_doublons())
		var chance: float = EQ.mat_chance[m]
		assert_between(tas.size(), roundi(300 * chance * 0.75), roundi(300 * chance * 1.25),
				"%s : ~%d %% de tas (%d)" % [type, roundi(chance * 100), tas.size()])
		for o in tas:
			assert_eq(o.matiere, m, "%s → %s" % [type, m])
			assert_between(o.quantite, EQ.mat_min, EQ.mat_max)
		s.free()


func test_la_malediction_grossit_les_tas() -> void:
	Partie.malediction = 5
	var e := await _expedition()
	e._rng_butin.seed = 3
	var s := Ennemi.creer_type(&"matelot", true)
	s.position = Vector3(2, 0, 2)
	e.generateur.add_child(s)
	await wait_physics_frames(1)
	for i in 200:
		e._on_ennemi_vaincu_butin(s)
	var tas := _au_sol(e).filter(func(o): return o.matiere == "bois")
	var total := 0
	for o in tas:
		total += o.quantite
	var moyenne := float(total) / tas.size()
	var attendue := (EQ.mat_min + EQ.mat_max) * 0.5 * Malediction.mult_butin()
	assert_almost_eq(moyenne, attendue, attendue * 0.15, "Malédiction 5 : des tas plus gros (comme les doublons)")


func test_le_bosco_lache_les_trois_materiaux() -> void:
	Partie.debug_depart = &"bosco"
	var e := await _expedition()
	await wait_physics_frames(30)
	e.bosco.sante.subir(99999.0, e.heros)
	await wait_physics_frames(3)
	for m in Butin.MATIERES:
		var tas := _au_sol(e).filter(func(o): return o.matiere == m)
		assert_eq(tas.size(), 1, m)
		assert_eq(tas[0].quantite if not tas.is_empty() else 0, int(EQ.mat_bosco[m]), m)


func test_le_coffre_crache_des_materiaux() -> void:
	Partie.debug_depart = &"tresor"
	var e := await _expedition()
	e.heros.global_position = e.salle.coffre.global_position + Vector3(1.0, 0, -0.2)
	await wait_physics_frames(3)
	var total := {}
	for o in _au_sol(e):
		if o.est_tas():
			total[o.matiere] = int(total.get(o.matiere, 0)) + o.quantite
	var sac: Dictionary = e.sacs.get(String(e.heros.name), Expedition._sac_vide())
	for m in Butin.MATIERES:
		assert_eq(int(total.get(m, 0)) + int(sac[m]), int(EQ.mat_coffre[m]), m + " (au sol ou déjà ramassé)")


func test_ramasser_un_tas_de_materiau() -> void:
	var e := await _expedition()
	e.heros.equiper([{"id": "dt", "base": "doublon", "rarete": 2, "effets": {}}])   # (Doublon terni : doublons seulement)
	var ici := e.heros.global_position + Vector3(0, 0, 0.3)
	e._lacher(e.heros, {}, 3, ici, ici, "bois")
	e._lacher(e.heros, {}, 2, ici, ici, "essence")
	assert_false(e.hud.label_matieres.visible, "Rien dans le sac")
	for o in _au_sol(e):
		o.pose = true
	await wait_physics_frames(3)
	assert_eq(_au_sol(e).size(), 0, "Ramassés en passant dessus")
	var sac: Dictionary = e.sacs[String(e.heros.name)]
	assert_eq(sac["bois"], 3, "Pas de bonus du Doublon terni sur le bois")
	assert_eq(sac["essence"], 2)
	assert_eq(sac["objets"], [], "Pas de place prise dans la cale")
	assert_eq(e.hud.label_sac.text, "Sac : 0 objet / cale 8 · 0 doublons")
	assert_true(e.hud.label_matieres.visible)
	assert_eq(e.hud.label_matieres.text, "3 bois de coque · 2 essence maudite")
	var lignes := e.hud.fil_butin.get_children().map(func(l): return l.text)
	assert_has(lignes, "+3 bois de coque")
	assert_has(lignes, "+2 essence maudite")


# ---------------------------------------------------------------- fin d'expédition et entrepôt
func test_victoire_les_materiaux_vont_a_l_entrepot() -> void:
	var e := await _expedition()
	e._mettre_au_sac(String(e.heros.name), {}, 5, "bois")
	e._mettre_au_sac(String(e.heros.name), {}, 2, "fer")
	e._mettre_au_sac(String(e.heros.name), {}, 9)
	e._terminer(true)
	await wait_physics_frames(2)
	assert_eq(Sauvegarde.ressource("bois"), 5)
	assert_eq(Sauvegarde.ressource("fer"), 2)
	assert_eq(Sauvegarde.ressource("essence"), 0)
	assert_eq(Sauvegarde.doublons(), 9)
	assert_has(_textes_fin(e), "Matériaux : 5 bois de coque · 2 fer noir")


func test_defaite_les_materiaux_sont_perdus() -> void:
	var e := await _expedition()
	e._mettre_au_sac(String(e.heros.name), {}, 5, "bois")
	e._terminer(false)
	await wait_physics_frames(2)
	assert_eq(Sauvegarde.ressource("bois"), 0)
	assert_has(_textes_fin(e), "Matériaux perdus : 5 bois de coque")


func test_entrepot_plein_le_surplus_est_revendu() -> void:
	var plafond := Sauvegarde.plafond("bois")
	Sauvegarde.encaisser("avant", [], 0, {}, {"bois": plafond - 2})
	assert_eq(Sauvegarde.ressource("bois"), plafond - 2)
	var e := await _expedition()
	e._mettre_au_sac(String(e.heros.name), {}, 5, "bois")
	e._terminer(true)
	await wait_physics_frames(2)
	assert_eq(Sauvegarde.ressource("bois"), plafond, "Plein jusqu'au plafond")
	var prix: int = EQ.mat_prix_surplus["bois"]
	assert_eq(Sauvegarde.doublons(), 3 * prix, "Le surplus revendu")
	assert_has(_textes_fin(e), "Entrepôt plein : 3 bois de coque revendus, +%d doublons" % (3 * prix))


func test_plafond_selon_le_niveau_de_l_entrepot() -> void:
	assert_eq(Sauvegarde.plafond("fer"), int(EQ.mat_plafonds["fer"]))
	Sauvegarde.donnees["repaire"]["entrepot"] = 2
	assert_eq(Sauvegarde.plafond("fer"), int(EQ.mat_plafonds_niveau_2["fer"]))
	var r := Sauvegarde.ranger({"fer": 5, "essence": -3})
	assert_eq(r["gardees"], {"bois": 0, "fer": 5, "essence": 0}, "Rien de négatif")
	assert_eq(r["doublons"], 0)


# ---------------------------------------------------------------- sauvegarde version 2
func test_une_sauvegarde_version_1_est_convertie() -> void:
	var v1 := {"version": 1, "doublons": 120, "objets": [{"id": "s", "base": "sabre", "rarete": 1, "effets": {}}],
			"equipement": {"bretteur": {"arme": "s"}}, "expeditions": ["x"], "historique": []}
	var d := Sauvegarde.convertir(v1)
	assert_eq(d["version"], 2)
	assert_eq(d["doublons"], 120, "Rien n'est perdu")
	assert_eq(d["equipement"]["bretteur"]["arme"], "s")
	assert_eq(d["ressources"], {"bois": 0, "fer": 0, "essence": 0})
	assert_eq(d["bateau"], {"cale": 0, "voiles": 0, "coque": 0, "bordee": 0})
	assert_eq(d["repaire"], {"forge": 1, "entrepot": 1})
	var abime := Sauvegarde.convertir({"version": 2, "ressources": {"bois": -4, "fer": 7.0, "essence": "x"},
			"bateau": {"cale": 9, "voiles": -1, "coque": 2}, "repaire": {"forge": 5, "entrepot": 0}})
	assert_eq(abime["ressources"], {"bois": 0, "fer": 7, "essence": 0})
	assert_eq(abime["bateau"], {"cale": 3, "voiles": 0, "coque": 2, "bordee": 0}, "Niveaux de 0 à 3")
	assert_eq(abime["repaire"], {"forge": 2, "entrepot": 1}, "Niveaux 1 et 2")


func test_aller_retour_des_materiaux() -> void:
	Sauvegarde.encaisser("exp", [], 4, {}, {"bois": 12, "fer": 3, "essence": 1})
	Sauvegarde.donnees["bateau"]["voiles"] = 2
	Sauvegarde.enregistrer()
	Sauvegarde.donnees = {}
	Sauvegarde.charger()
	assert_eq(Sauvegarde.ressource("bois"), 12)
	assert_eq(Sauvegarde.ressource("fer"), 3)
	assert_eq(Sauvegarde.ressource("essence"), 1)
	assert_eq(Sauvegarde.niveau_bateau("voiles"), 2)
	assert_eq(Sauvegarde.niveau_repaire("forge"), 1)
	assert_false(Sauvegarde.encaisser("exp", [], 4, {}, {"bois": 12}), "Anti-doublon : pas deux fois")
	assert_eq(Sauvegarde.ressource("bois"), 12)


func test_tri_en_attente_garde_les_materiaux() -> void:
	Sauvegarde.noter_tri_en_attente("exp_t", [], 6, {}, {"bois": 4, "fer": 1})
	Sauvegarde.donnees = {}
	Sauvegarde.charger()   # (Android avait fermé l'appli pendant le tri)
	assert_eq(Sauvegarde.ressource("bois"), 4)
	assert_eq(Sauvegarde.ressource("fer"), 1)
	assert_eq(Sauvegarde.doublons(), 6)


# ---------------------------------------------------------------- coop
func test_l_invite_recoit_et_ramasse_un_tas() -> void:
	var e := await _expedition()
	e.evenement_lieu("butin", [e.numero, "t1", {}, 2, Vector3(1, 0, 1), Vector3(2, 0, 2), "fer"])
	var o := e.butin_au_sol.get_node_or_null("Butin_t1") as ObjetAuSol
	assert_not_null(o, "Le tas tiré par l'hôte apparaît chez l'invité")
	assert_eq(o.matiere if o else "", "fer")
	e.evenement_lieu("ramasse", ["t1", {}, 2, "fer"])
	assert_eq(e.sacs[String(e.heros.name)]["fer"], 2)
	assert_eq(e.hud.label_matieres.text, "2 fer noir")
