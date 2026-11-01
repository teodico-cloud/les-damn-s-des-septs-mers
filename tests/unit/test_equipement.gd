extends GutTest
## Jalon 4, étape 2 (liste validée par Téo le 01/11) : effets des objets, sauvegarde (écriture sûre,
## copie de secours, anti-doublon), équipement porté (un seul endroit à la fois), effets en combat,
## arme en main, objets uniques, écran Équipement, équipement envoyé à l'autre téléphone.

const EQ: Equilibrage = preload("res://data/equilibrage.tres")

var monde: Node3D


func before_all() -> void:
	Combat.chance_critique = 0.0


func after_all() -> void:
	Combat.chance_critique = -1.0
	Arene.chance_orbe = -1.0
	Partie.destination = &"arene"
	Partie.debug_depart = &""
	Sauvegarde.reinitialiser()


func before_each() -> void:
	Engine.time_scale = 1.0
	Partie.revenir_en_solo()
	Partie.heros_local = &"bretteur"
	Partie.debug_depart = &""
	Partie.debug_sante_infinie = false
	Partie.destination = &"arene"
	Partie.malediction = 0
	Arene.chance_orbe = 0.0
	Sauvegarde.reinitialiser()
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
	Partie.destination = &"arene"


func _o(base: String, rarete := 0, effets := {}) -> Dictionary:
	return {"id": "%s_%d_%d" % [base, rarete, randi()], "base": base, "rarete": rarete, "effets": effets}


func _heros(type: StringName, objets: Array, pos := Vector3.ZERO) -> Heros:
	var h := Heros.creer(type)
	h.equiper(objets)
	h.position = pos
	monde.add_child(h)
	return h


func _squelette(pos: Vector3) -> Ennemi:
	var e := Ennemi.creer_type(&"matelot", true)
	e.position = pos
	monde.add_child(e)
	return e


# ---------------------------------------------------------------- effets des objets
func test_effet_de_base_selon_la_rarete() -> void:
	assert_almost_eq(Equipement.effets(_o("sabre", 0))["degats"], 0.10, 0.0001, "Commun : l'effet de base")
	assert_almost_eq(Equipement.effets(_o("sabre", 1))["degats"], 0.125, 0.0001, "Rare : ×1,25")
	assert_almost_eq(Equipement.effets(_o("sabre", 2))["degats"], 0.15, 0.0001, "Épique : ×1,5")
	var hache := Equipement.effets(_o("hache", 2))
	assert_almost_eq(hache["degats"], 0.45, 0.0001)
	assert_almost_eq(hache["vitesse_attaque"], -0.15, 0.0001, "Un défaut ne grossit jamais avec la rareté")
	var lame := Equipement.effets(_o("lame_du_noye", 3))
	assert_almost_eq(lame["degats"], 0.15, 0.0001, "Arme unique : l'effet de base d'une arme Épique")
	assert_eq(lame["lame_du_noye"], 1.0)
	var plus := Equipement.effets(_o("fiole", 1, {"degats": 0.08}))
	assert_almost_eq(plus["orbes"], 0.5, 0.0001)
	assert_almost_eq(plus["degats"], 0.08, 0.0001, "Les effets en plus s'ajoutent")


func test_bonus_additionne_tout() -> void:
	var b := Equipement.bonus([_o("sabre", 0), _o("fiole", 0, {"degats": 0.08}), _o("chandelle", 0)])
	assert_almost_eq(b["degats"], 0.18, 0.0001)
	assert_almost_eq(b["pv"], 15.0, 0.0001)
	assert_almost_eq(b["orbes"], 0.4, 0.0001)


func test_textes_des_effets() -> void:
	assert_eq(Equipement.texte("degats", 0.1), "+10 % de dégâts")
	assert_eq(Equipement.texte("vitesse_attaque", -0.15), "−15 % de vitesse d'attaque")
	assert_eq(Equipement.texte("pv", 15.0), "+15 PV max")
	assert_eq(Equipement.texte("recharges", 0.08), "Recharges −8 %")
	assert_eq(Equipement.texte("vol_de_vie", 0.03), "Vol de vie 3 %")
	assert_eq(Equipement.texte("lame_du_noye", 1.0), Butin.UNIQUES["lame_du_noye"]["effet"])
	var lignes := Equipement.textes(_o("hache", 0))
	assert_eq(lignes, [["+30 % de dégâts", true], ["−15 % de vitesse d'attaque", false]], "Le défaut en rouge")


func test_comparaison() -> void:
	var avant := Equipement.bonus([_o("sabre", 0)])
	var apres := Equipement.bonus([_o("hache", 0)])
	var c := Equipement.comparer(avant, apres)
	assert_eq(c, [["▲ +20 % de dégâts", true], ["▼ −15 % de vitesse d'attaque", false]])
	var talisman := Equipement.comparer({}, Equipement.bonus([_o("talisman_pendu", 4)]))
	assert_has(talisman, ["▲ +40 % de dégâts", true])
	assert_has(talisman, ["▼ Les orbes de vie ne vous soignent plus", false], "Le défaut d'un Maudit : ▼")
	var perdu := Equipement.comparer(Equipement.bonus([_o("lame_du_noye", 3)]), apres)
	assert_has(perdu, ["▼ Perdu : " + Butin.UNIQUES["lame_du_noye"]["effet"], false])


func test_ce_qui_va_ou() -> void:
	assert_true(Equipement.convient(_o("sabre"), &"bretteur", "arme"))
	assert_false(Equipement.convient(_o("sabre"), &"occultiste", "arme"), "Pas l'arme de l'autre héros")
	assert_false(Equipement.convient(_o("sabre"), &"bretteur", "relique_1"))
	assert_true(Equipement.convient(_o("fiole"), &"occultiste", "relique_2"), "Les reliques vont aux deux")
	assert_false(Equipement.convient(_o("fiole"), &"bretteur", "arme"))
	assert_true(Equipement.convient(_o("grimoire_du_pendu", 3), &"occultiste", "arme"))


func test_effets_en_plus_tires_a_la_chute() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 3
	for i in 300:
		var rarete := i % 5
		var o := Butin.tirer_objet(r, &"bretteur", 0, rarete)
		var attendu: int = {0: 0, 1: 1, 2: 2, 3: 0, 4: 0}[int(o["rarete"])]
		assert_eq(o["effets"].size(), attendu, "%s : %d effet(s) en plus" % [Butin.nom_complet(o), attendu])
		for cle in o["effets"]:
			assert_true(EQ.equip_effets_plus.has(cle))


# ---------------------------------------------------------------- sauvegarde
func test_sauvegarde_aller_retour() -> void:
	var objet := _o("hache", 2, {"critique": 0.06, "pv": 10.0})
	assert_true(Sauvegarde.encaisser("exp_1", [objet], 42))
	assert_true(Sauvegarde.equiper(&"bretteur", "arme", objet["id"]))
	Sauvegarde.donnees = {}
	Sauvegarde.charger()
	assert_eq(Sauvegarde.doublons(), 42)
	assert_eq(Sauvegarde.objets(), [objet], "Relu tel quel (rareté entière)")
	assert_eq(typeof(Sauvegarde.objets()[0]["rarete"]), TYPE_INT)
	assert_eq(Sauvegarde.porte(&"bretteur", "arme"), objet)
	assert_eq(Sauvegarde.donnees["version"], Sauvegarde.VERSION)
	assert_false(Sauvegarde.restauree)


func test_anti_doublon_par_expedition() -> void:
	var objet := _o("sabre", 1)
	assert_true(Sauvegarde.encaisser("exp_1", [objet], 10))
	assert_false(Sauvegarde.encaisser("exp_1", [_o("hache")], 10), "La même expédition une seconde fois : ignorée")
	assert_eq(Sauvegarde.doublons(), 10)
	assert_eq(Sauvegarde.objets().size(), 1)
	assert_true(Sauvegarde.encaisser("exp_2", [objet], 5))
	assert_eq(Sauvegarde.objets().size(), 1, "Un objet déjà dans les coffres n'est pas compté deux fois")
	assert_eq(Sauvegarde.doublons(), 15)
	assert_eq(Sauvegarde.donnees["historique"].size(), 2)


func test_fichier_abime_copie_de_secours() -> void:
	Sauvegarde.encaisser("exp_1", [_o("sabre")], 10)
	Sauvegarde.encaisser("exp_2", [_o("hache")], 20)   # (la copie de secours garde l'état d'avant)
	var f := FileAccess.open(Sauvegarde.chemin, FileAccess.WRITE)
	f.store_string("{\"version\": 1, \"doub")   # écriture coupée net (téléphone éteint)
	f.close()
	Sauvegarde.charger()
	assert_true(Sauvegarde.restauree, "La copie de secours a servi")
	assert_eq(Sauvegarde.doublons(), 10, "L'état d'avant la dernière écriture")
	assert_not_null(Sauvegarde._lire(Sauvegarde.chemin), "Le fichier abîmé est remplacé")
	# tout est illisible : un profil neuf, sans planter
	for s in ["", ".bak"]:
		var g := FileAccess.open(Sauvegarde.chemin + s, FileAccess.WRITE)
		g.store_string("n'importe quoi")
		g.close()
	Sauvegarde.charger()
	assert_eq(Sauvegarde.doublons(), 0)
	assert_eq(Sauvegarde.objets(), [])


func test_conversion_d_une_sauvegarde_incomplete() -> void:
	var d := Sauvegarde.convertir({"version": 1, "doublons": -5, "objets": [{"id": "a", "base": "inconnu"},
			{"id": "b", "base": "fiole", "rarete": 1.0}, "pas un objet"], "equipement": {"bretteur": {"arme": "b"}}})
	assert_eq(d["doublons"], 0)
	assert_eq(d["objets"], [{"id": "b", "base": "fiole", "rarete": 1, "effets": {}}], "Objets inconnus écartés")
	assert_eq(d["equipement"]["bretteur"]["arme"], "b")
	assert_eq(d["equipement"]["occultiste"], {"arme": "", "relique_1": "", "relique_2": ""}, "Les clés manquantes sont ajoutées")


func test_equiper_un_seul_endroit_a_la_fois() -> void:
	var sabre := _o("sabre")
	var fiole := _o("fiole")
	var baton := _o("baton")
	Sauvegarde.encaisser("e", [sabre, fiole, baton], 0)
	assert_false(Sauvegarde.equiper(&"bretteur", "relique_1", sabre["id"]), "Une arme ne va pas en relique")
	assert_false(Sauvegarde.equiper(&"bretteur", "arme", baton["id"]), "Ni l'arme de l'autre héros")
	assert_false(Sauvegarde.equiper(&"bretteur", "arme", "inconnu"))
	assert_true(Sauvegarde.equiper(&"bretteur", "relique_1", fiole["id"]))
	assert_true(Sauvegarde.equiper(&"bretteur", "relique_2", fiole["id"]))
	assert_eq(Sauvegarde.porte(&"bretteur", "relique_1"), {}, "Déplacée d'une relique à l'autre")
	assert_true(Sauvegarde.equiper(&"occultiste", "relique_1", fiole["id"]))
	assert_eq(Sauvegarde.porte(&"bretteur", "relique_2"), {}, "Passée à l'autre héros")
	assert_eq(Sauvegarde.equipes(&"occultiste"), [fiole])
	Sauvegarde.retirer(&"occultiste", "relique_1")
	assert_eq(Sauvegarde.equipes(&"occultiste"), [])


# ---------------------------------------------------------------- effets sur le héros
func test_pv_et_vitesse() -> void:
	var h := _heros(&"bretteur", [_o("chandelle", 2), _o("coeur_kraken", 4)])
	await wait_physics_frames(2)
	assert_almost_eq(h.sante.pv_max, 100.0 * 1.5 + 22.5, 0.01, "Cœur de Kraken ×1,5, chandelle Épique +22,5")
	assert_almost_eq(h.sante.pv, h.sante.pv_max, 0.01)
	h.commandes.deplacement = Vector3(1, 0, 0)
	await wait_physics_frames(3)
	assert_almost_eq(Vector2(h.velocity.x, h.velocity.z).length(), EQ.heros_vitesse * 0.8, 0.05, "20 % moins vite")
	h.sante.definir_pv(h.sante.pv_max * 0.5)
	h.equiper([])
	assert_almost_eq(h.sante.pv_max, 100.0, 0.01, "Équipement retiré : PV max d'origine")
	assert_almost_eq(h.sante.pv, 50.0, 0.01, "Même part des PV")


func test_recharges() -> void:
	var h := _heros(&"bretteur", [_o("trousseau", 1), _o("sabre", 1, {"recharges": 0.08})])
	assert_almost_eq(h.recharge_esquive.duree, EQ.esquive_recharge * (1.0 - 0.3125 - 0.08), 0.001, "Trousseau Rare + recharges")
	assert_almost_eq(h.recharge_competence_1.duree, EQ.parade_recharge * 0.92, 0.001)
	var o := _heros(&"occultiste", [_o("grimoire", 0)])
	assert_almost_eq(o.recharge_competence_1.duree, EQ.occ_marque_recharge * 0.8, 0.001, "Grimoire : Marque −20 %")
	assert_almost_eq(o.recharge_competence_2.duree, EQ.occ_chaines_recharge * 0.8, 0.001)
	assert_almost_eq(o.recharge_esquive.duree, EQ.occ_tele_recharge, 0.001, "Pas la téléportation")
	var b := _heros(&"bretteur", [_o("grimoire", 0)])
	assert_almost_eq(b.recharge_competence_1.duree, EQ.parade_recharge, 0.001, "Rien pour le Bretteur")
	var plafond := _heros(&"bretteur", [_o("trousseau", 2, {"recharges": 0.08}), _o("trousseau", 2, {"recharges": 0.08})])
	assert_almost_eq(plafond.recharge_esquive.duree, EQ.esquive_recharge * (1.0 - EQ.equip_max_recharges), 0.001, "Jamais plus de la moitié")


func test_vitesse_d_attaque() -> void:
	var h := _heros(&"bretteur", [_o("hache")])
	assert_almost_eq(h._vitesse_combo(), EQ.combo_vitesse_animation * 0.85, 0.001, "Hache : coups 15 % plus lents")
	var c := _heros(&"bretteur", [_o("coutelas")])
	assert_almost_eq(c._vitesse_combo(), EQ.combo_vitesse_animation * 1.15, 0.001)
	var o := _heros(&"occultiste", [_o("baguette")])
	assert_almost_eq(o._vitesse_tir(), EQ.occ_tir_vitesse_animation * 1.2, 0.001, "Baguette : tirs 20 % plus rapides")
	o._dernier_tir = 0.0
	o.horloge = EQ.occ_tir_cadence / 1.2 + 0.001
	assert_true(o._attaque_possible(), "Cadence de tir plus rapide")
	o.horloge = EQ.occ_tir_cadence / 1.2 - 0.01
	assert_false(o._attaque_possible())


func test_degats_critiques_et_vol_de_vie() -> void:
	var h := _heros(&"bretteur", [_o("sabre", 0, {"vol_de_vie": 0.03}), _o("cle", 0)], Vector3(0, 0, 0))
	var e := _squelette(Vector3(0, 0, 1.5))
	await wait_physics_frames(2)
	h.sante.definir_pv(50.0)
	var avant := e.sante.pv
	Combat.porter_coup(h, e, 10.0, false)
	assert_almost_eq(avant - e.sante.pv, 11.0, 0.01, "Sabre : +10 % de dégâts")
	assert_almost_eq(h.sante.pv, 50.0 + 11.0 * 0.03, 0.001, "Vol de vie : 3 % des dégâts")
	e.etourdir(2.0)
	avant = e.sante.pv
	Combat.porter_coup(h, e, 10.0, false)
	assert_almost_eq(avant - e.sante.pv, 13.5, 0.01, "Clé du geôlier : +25 % sur un squelette étourdi")
	var c := _heros(&"bretteur", [_o("coutelas", 2)])
	assert_almost_eq(Combat.chance_de_critique(c), 0.12, 0.0001, "Coutelas Épique : +12 % de critiques")
	assert_almost_eq(Combat.chance_de_critique(h), 0.0, 0.0001)


func test_epines() -> void:
	var h := _heros(&"bretteur", [_o("trousseau", 2, {"epines": 0.2})])
	var pres := _squelette(Vector3(0, 0, 1.4))
	var loin := Ennemi.creer_type(&"arbaletrier", true)
	loin.position = Vector3(0, 0, 8)
	monde.add_child(loin)
	await wait_physics_frames(2)
	var pv := pres.sante.pv
	Combat.porter_coup(pres, h, 10.0, false)
	assert_almost_eq(pv - pres.sante.pv, 2.0, 0.01, "Épines : 20 % renvoyés au corps-à-corps")
	h.sante.invulnerable_jusqua = 0.0
	var pv_loin := loin.sante.pv
	Combat.porter_coup(loin, h, 10.0, false)
	assert_eq(loin.sante.pv, pv_loin, "Pas de loin")


func test_sablier_esquive_au_dernier_moment() -> void:
	var h := _heros(&"bretteur", [_o("sablier_maree", 3)])
	var pres := _squelette(Vector3(0, 0, 1.4))
	var loin := _squelette(Vector3(6, 0, 0))
	await wait_physics_frames(2)
	h.commandes.demander(&"esquive", h.horloge)
	await wait_physics_frames(2)
	assert_eq(h.etat, Heros.Etat.ESQUIVE)
	Combat.porter_coup(pres, h, 10.0, false)
	assert_eq(h.sante.pv, h.sante.pv_max, "Esquivé")
	assert_eq(pres.etat, Ennemi.Etat.ETOURDI, "Le squelette tout près est figé")
	assert_ne(loin.etat, Ennemi.Etat.ETOURDI, "Pas celui à 6 m")
	pres._changer(Ennemi.Etat.POURSUITE)
	Combat.porter_coup(pres, h, 10.0, false)
	assert_ne(pres.etat, Ennemi.Etat.ETOURDI, "Une fois par esquive")
	var sans := _heros(&"bretteur", [], Vector3(10, 0, 10))
	var autre := _squelette(Vector3(10, 0, 11.4))
	await wait_physics_frames(2)
	sans.commandes.demander(&"esquive", sans.horloge)
	await wait_physics_frames(2)
	Combat.porter_coup(autre, sans, 10.0, false)
	assert_ne(autre.etat, Ennemi.Etat.ETOURDI, "Sans le sablier, rien")


func test_arme_en_main() -> void:
	var h := _heros(&"bretteur", [_o("hache"), _o("fiole")])
	await wait_physics_frames(1)
	var attache := h.visuel.find_child("handslot_r", true, false)
	var arme := attache.get_node_or_null("ArmePortee")
	assert_not_null(arme, "La hache dans sa main")
	assert_false(attache.get_node("Bretteur_Sabre").visible, "Son sabre de départ est rangé")
	h.equiper([_o("fiole")])
	await wait_physics_frames(1)
	assert_true(attache.get_node("Bretteur_Sabre").visible, "Sans arme trouvée : son arme de départ")
	assert_eq(attache.get_children().filter(func(c): return c.name == "ArmePortee" and not c.is_queued_for_deletion()).size(), 0)
	var o := _heros(&"occultiste", [_o("grimoire_du_pendu", 3)])
	await wait_physics_frames(1)
	assert_not_null(o.visuel.find_child("handslot_r", true, false).get_node_or_null("ArmePortee"))


# ---------------------------------------------------------------- objets uniques
func test_lame_du_noye() -> void:
	var h := _heros(&"bretteur", [_o("lame_du_noye", 3)])
	var e := _squelette(Vector3(0, 0, 2.0))
	await wait_physics_frames(2)
	e.sante.pv_max = 500.0
	e.sante.definir_pv(500.0)
	e.immobiliser(30.0)   # (il reste dans l'eau)
	h.commandes.deplacement = Vector3(0, 0, 1)
	h.commandes.demander(&"esquive", h.horloge)
	await wait_physics_frames(int(EQ.esquive_duree * 60) + 4)
	h.commandes.deplacement = Vector3.ZERO
	var flaques := get_tree().get_nodes_in_group("eau_noyee")
	assert_gt(flaques.size(), 2, "La roulade laisse une traînée d'eau (%d flaques)" % flaques.size())
	var pv := e.sante.pv
	await wait_physics_frames(70)
	assert_lt(e.sante.pv, pv, "Elle blesse le squelette qui y reste")
	# (environ 1,2 s mesurées : au plus 3 tics de 0,5 s × 16/s × 1,15, même sur plusieurs flaques à la fois)
	assert_lte(pv - e.sante.pv, 3.0 * EQ.noyee_degats_seconde * 0.5 * 1.15 + 0.1, "Une seule fois par tic, même sur plusieurs flaques")
	var b := _heros(&"bretteur", [], Vector3(10, 0, 0))
	await wait_physics_frames(2)
	var avant := get_tree().get_nodes_in_group("eau_noyee").size()
	b.commandes.demander(&"esquive", b.horloge)
	await wait_physics_frames(25)
	assert_lte(get_tree().get_nodes_in_group("eau_noyee").size(), avant, "Sans la lame : rien")


func test_grimoire_du_pendu() -> void:
	Partie.heros_local = &"occultiste"
	Sauvegarde.encaisser("e", [{"id": "gp", "base": "grimoire_du_pendu", "rarete": 3, "effets": {}}], 0)
	Sauvegarde.equiper(&"occultiste", "arme", "gp")
	var a: Arene = load("res://game/arene/arene.tscn").instantiate()
	add_child_autofree(a)
	await wait_physics_frames(3)
	a.hud.menu_demande.disconnect(a.retour_menu)
	assert_eq(a.heros.b("grimoire_du_pendu"), 1.0, "L'arène équipe le héros (choix de Téo : partout)")
	for i in 60:   # (sortie de terre)
		await wait_seconds(0.1)
		if a.generateur.get_children().filter(func(s): return s is Ennemi and s.est_ciblable()).size() >= 3:
			break
	a.generateur.nombre = 0   # (plus de remplaçants)
	var vaincus := 0
	watch_signals(EventBus)
	for s in a.generateur.get_children():
		if s is Ennemi and not s.allie and s.est_ciblable():
			s.sante.subir(9999.0, a.heros)
			vaincus += 1
			if vaincus == 3:
				break
	assert_eq(vaincus, 3)
	await wait_seconds(EQ.pendu_delai + 0.3)
	var allies := a.generateur.get_children().filter(func(e): return e is SqueletteAllie)
	assert_eq(allies.size(), EQ.pendu_max, "Relevés à ses côtés (au plus %d)" % EQ.pendu_max)
	var allie: SqueletteAllie = allies[0]
	assert_false(allie.is_in_group("ennemis"), "Ni visé, ni compté")
	assert_eq(a.generateur.allies(), EQ.pendu_max)
	var compte: int = get_signal_emit_count(EventBus, "ennemi_vaincu")
	allie._vie = EQ.pendu_duree
	await wait_physics_frames(3)
	assert_eq(allie.etat, Ennemi.Etat.MORT, "Son temps fini, il retombe en os")
	assert_eq(get_signal_emit_count(EventBus, "ennemi_vaincu"), compte, "Sans compter pour un squelette vaincu (ni butin)")
	Partie.heros_local = &"bretteur"


func test_le_squelette_releve_frappe_les_squelettes() -> void:
	var gen := GenerateurEnnemis.new()
	gen.demarrage_auto = false
	gen.nombre = 0
	monde.add_child(gen)
	var e := _squelette(Vector3(0, 0, 2.0))
	e.immobiliser(30.0)
	var allie := gen.relever_allie(Vector3(0, 0, 0.6), null)
	allie._apparition_rapide = true
	await wait_physics_frames(2)
	allie._changer(Ennemi.Etat.POURSUITE)
	allie.collision_layer = 0
	var pv := e.sante.pv
	await wait_seconds(2.5)
	assert_lt(e.sante.pv, pv, "Il frappe le squelette le plus proche")
	assert_eq(gen.vivants(), 0, "Il ne compte pas dans la salle")


func test_talisman_et_fiole_sur_les_orbes() -> void:
	Partie.destination = &"expedition"
	Arene.chance_orbe = 1.0
	Sauvegarde.encaisser("e", [{"id": "tal", "base": "talisman_pendu", "rarete": 4, "effets": {}}], 0)
	Sauvegarde.equiper(&"bretteur", "relique_1", "tal")
	var e: Expedition = load("res://game/expedition/expedition.tscn").instantiate()
	add_child_autofree(e)
	await wait_physics_frames(3)
	e.hud.menu_demande.disconnect(e.retour_menu)
	e.poser_orbe("Orbe_t", e.heros.global_position)
	e.heros.sante.definir_pv(40.0)
	await wait_physics_frames(3)
	assert_false((e.orbes.get_node("Orbe_t") as OrbeVie).prise, "Talisman du Pendu : l'orbe ne le soigne pas")
	assert_eq(e.heros.sante.pv, 40.0)
	e.heros.equiper([{"id": "f", "base": "fiole", "rarete": 0, "effets": {}}])
	await wait_physics_frames(3)
	assert_true((e.orbes.get_node("Orbe_t") as OrbeVie).prise)
	assert_almost_eq(e.heros.sante.pv, 40.0 + 100.0 * EQ.orbe_soin * 1.4, 0.01, "Fiole : +40 %")


func test_doublons_et_flasque_en_expedition() -> void:
	Partie.destination = &"expedition"
	var e: Expedition = load("res://game/expedition/expedition.tscn").instantiate()
	add_child_autofree(e)
	await wait_physics_frames(3)
	e.hud.menu_demande.disconnect(e.retour_menu)
	e.heros.equiper([{"id": "d", "base": "doublon", "rarete": 0, "effets": {}}, {"id": "f", "base": "flasque", "rarete": 0, "effets": {}}])
	var ici := e.heros.global_position + Vector3(0, 0, 0.3)
	e._lacher(e.heros, {}, 10, ici, ici)
	for o in e.butin_au_sol.get_children():
		o.pose = true
	await wait_physics_frames(3)
	assert_eq(e.sacs[String(e.heros.name)]["doublons"], 13, "Doublon terni : +30 %")
	e.heros.sante.definir_pv(50.0)
	e._on_salle_videe()
	assert_almost_eq(e.heros.sante.pv, 60.0, 0.01, "Flasque de rhum : 10 % des PV à chaque salle nettoyée")


func test_fin_d_expedition_dans_les_coffres() -> void:
	Partie.destination = &"expedition"
	var e: Expedition = load("res://game/expedition/expedition.tscn").instantiate()
	add_child_autofree(e)
	await wait_physics_frames(3)
	e.hud.menu_demande.disconnect(e.retour_menu)
	var objet := _o("hache", 2, {"pv": 10.0})
	e._mettre_au_sac(String(e.heros.name), objet, 0)
	e._mettre_au_sac(String(e.heros.name), {}, 33)
	e._terminer(true)
	assert_eq(Sauvegarde.doublons(), 33, "Victoire : les doublons dans les coffres")
	assert_eq(Sauvegarde.objets(), [objet])
	assert_true(e.id_expedition in Sauvegarde.donnees["expeditions"])
	e._afficher_fin(true, ["x"], {})
	assert_eq(Sauvegarde.doublons(), 33, "Jamais comptée deux fois")


func test_defaite_rien_dans_les_coffres() -> void:
	Partie.destination = &"expedition"
	var e: Expedition = load("res://game/expedition/expedition.tscn").instantiate()
	add_child_autofree(e)
	await wait_physics_frames(3)
	e.hud.menu_demande.disconnect(e.retour_menu)
	e._mettre_au_sac(String(e.heros.name), _o("sabre"), 12)
	e._terminer(false)
	assert_eq(Sauvegarde.doublons(), 0)
	assert_eq(Sauvegarde.objets(), [])
	assert_eq(Sauvegarde.donnees["historique"][-1]["reussite"], false, "Notée dans l'historique")


# ---------------------------------------------------------------- écran Équipement, coop
func test_ecran_equipement() -> void:
	var sabre := _o("sabre", 1)
	var hache := _o("hache", 2)
	var fiole := _o("fiole")
	var baton := _o("baton")
	Sauvegarde.encaisser("e", [sabre, hache, fiole, baton], 87)
	var ecran = load("res://ui/screens/equipement.tscn").instantiate()
	ecran.changer_de_scene = false
	add_child_autofree(ecran)
	await wait_process_frames(3)
	assert_eq(ecran.label_doublons.text, "87 doublons")
	assert_eq(ecran.objets_possibles(), [hache, sabre], "Les armes du Bretteur, les plus rares d'abord")
	ecran.choisir_objet(hache)
	var textes: Array = ecran.fiche.get_children().map(func(l): return l.text)
	assert_has(textes, "Hache d'abordage")
	assert_has(textes, "▲ +45 % de dégâts", "Comparaison avec l'arme portée (aucune)")
	ecran.equiper_selection()
	assert_eq(Sauvegarde.porte(&"bretteur", "arme"), hache)
	assert_eq(ecran.boutons_emplacements["arme"].text, "Hache d'abordage")
	assert_not_null(ecran._modele.visuel.find_child("handslot_r", true, false).get_node_or_null("ArmePortee"), "En main sur l'écran")
	ecran.choisir_objet(sabre)
	textes = ecran.fiche.get_children().map(func(l): return l.text)
	assert_has(textes, "▼ −32 % de dégâts", "À la place de la hache (sabre Rare +12,5 %, hache Épique +45 %)")
	assert_has(textes, "▲ +15 % de vitesse d'attaque")
	ecran.choisir_emplacement("relique_1")
	assert_eq(ecran.objets_possibles(), [fiole])
	ecran.montrer_heros(&"occultiste")
	assert_eq(ecran.objets_possibles(), [baton])
	ecran.choisir_objet(baton)
	ecran.equiper_selection()
	ecran.retirer()
	assert_eq(Sauvegarde.equipes(&"occultiste"), [])


func test_coffres_de_test() -> void:
	var ecran = load("res://ui/screens/demarrage.tscn").instantiate()
	add_child_autofree(ecran)
	await wait_process_frames(2)
	ecran.remplir_coffres_de_test()
	ecran.remplir_coffres_de_test()
	assert_eq(Sauvegarde.objets().size(), Butin.BASES.size() + Butin.UNIQUES.size(), "Un de chaque, une seule fois")
	for u in Butin.UNIQUES:
		assert_false(Sauvegarde.objet("test_" + u).is_empty(), u)


func test_equipement_recu_de_l_autre_telephone() -> void:
	var bon := _o("baton", 2)
	var liste := [bon, _o("sabre"), _o("fiole"), "pas un objet", {"id": "x", "base": "inconnu"}, _o("chandelle"), _o("cle")]
	var r := Reseau.equipement_valide(liste, &"occultiste")
	assert_eq(r.size(), 3, "Trois au plus")
	assert_eq(r[0], bon)
	assert_false(r.any(func(o): return o["base"] == "sabre"), "Pas l'arme de l'autre héros")
	assert_eq(Reseau.equipement_valide("n'importe quoi", &"bretteur"), [])


func test_l_invite_voit_l_eau_et_le_sablier() -> void:
	var h := _heros(&"bretteur", [])
	h.name = "HerosInvite"
	var s := SynchroArene.new()
	autofree(s)
	s.arene = monde
	s.heros_local = h
	await wait_physics_frames(1)
	var avant := monde.get_child_count()
	s._effet_recu("HerosHote", "eau_noyee", Vector3(1, 0, 1))
	var eau := monde.get_children().filter(func(c): return c is FlaqueNoyee)
	assert_eq(eau.size(), 1, "L'eau de la Lame du Noyé du partenaire, chez l'invité")
	assert_null(eau[0].lanceur, "L'image seulement : l'hôte compte les dégâts")
	s._effet_recu("HerosInvite", "eau_noyee", Vector3(2, 0, 2))
	assert_eq(monde.get_children().filter(func(c): return c is FlaqueNoyee).size(), 1, "La nôtre est déjà montrée par notre roulade")
	s._effet_recu("HerosInvite", "sablier", Vector3(0, 0, 0))
	assert_eq(monde.get_child_count(), avant + 2, "Le cercle du Sablier, même pour notre héros (décidé par l'hôte)")
