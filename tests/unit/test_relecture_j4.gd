extends GutTest
## Relecture de fin du jalon 4 (agent relecteur, 03/11) : un test par défaut trouvé et corrigé.

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
	Partie.destination = &"expedition"
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
	Engine.time_scale = 1.0
	Partie.destination = &"arene"
	Partie.debug_depart = &""


func _expedition() -> Expedition:
	var e: Expedition = load("res://game/expedition/expedition.tscn").instantiate()
	e.changer_de_scene = false
	add_child_autofree(e)
	await wait_physics_frames(3)
	return e


func _o(base: String, rarete: int, n: int) -> Dictionary:
	return {"id": "%s_%d_%d" % [base, rarete, n], "base": base, "rarete": rarete, "effets": {}}


func _sac_plein(e: Expedition) -> void:
	for i in EQ.cale_places + 3:
		e._mettre_au_sac(String(e.heros.name), _o("cle", i % 3, i), 0)
	e._mettre_au_sac(String(e.heros.name), {}, 10)


# ---------------------------------------------------------------- 1. retour d'Android
func test_retour_android_comme_le_menu() -> void:
	var e := await _expedition()
	e.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_false(e.revenu_au_menu, "Un seul geste retour n'abandonne plus l'expédition")
	assert_true(e.hud.label_message.visible)
	assert_string_contains(e.hud.label_message.text, "Appuie encore sur Menu")
	e._terminer(true)
	e.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_true(e.revenu_au_menu, "Après l'écran de fin : retour au menu")


func test_retour_android_pendant_le_tri() -> void:
	var e := await _expedition()
	_sac_plein(e)
	e._terminer(true)
	assert_true(e.tri_en_cours)
	e.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_false(e.tri_en_cours, "Le retour charge la cale…")
	assert_false(e.revenu_au_menu, "… sans quitter : l'écran de fin s'affiche")
	assert_not_null(e.hud.panneau_fin)
	assert_eq(Sauvegarde.objets().size(), EQ.cale_places)


# ---------------------------------------------------------------- 2 et 3. extraction d'urgence
func test_invite_a_terre_quand_l_hote_part() -> void:
	var e := await _expedition()
	e.heros.name = "HerosInvite"
	e._mettre_au_sac("HerosInvite", _o("hache", 2, 1), 30)
	e.heros.sante.invulnerable_jusqua = 0.0
	e.heros.sante.subir(9999.0, null)
	await wait_physics_frames(1)
	e._on_partenaire_parti("Ton partenaire a quitté la partie.")
	assert_true(e.finie)
	assert_false(e.reussite, "À terre : perdu, comme un héros seul à terre")
	assert_eq(Sauvegarde.objets().size(), 0)
	assert_eq(Sauvegarde.doublons(), 0)


func test_coupure_pendant_une_pause() -> void:
	var e := await _expedition()
	e.heros.name = "HerosInvite"
	e._mettre_au_sac("HerosInvite", _o("hache", 2, 1), 30)
	e.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	e._on_partenaire_parti("Ton partenaire a quitté la partie.")
	assert_false(e.reussite, "Coupure pendant sa propre pause : abandon")
	assert_eq(Sauvegarde.objets().size(), 0)
	var textes := e.hud.panneau_fin.find_children("*", "Label", true, false).map(func(l): return l.text)
	assert_has(textes, "La connexion a été perdue pendant que le jeu était en pause.")


func test_coupure_juste_apres_une_longue_pause() -> void:
	var e := await _expedition()
	e.heros.name = "HerosInvite"
	e._mettre_au_sac("HerosInvite", _o("hache", 2, 1), 30)
	e.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	e._pause_debut_ms -= 5000   # (5 s en arrière-plan)
	e.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	e._on_partenaire_parti("Ton partenaire a quitté la partie.")
	assert_false(e.reussite, "La coupure constatée au retour d'une longue pause : abandon")


func test_courte_pause_puis_hote_parti() -> void:
	var e := await _expedition()
	e.heros.name = "HerosInvite"
	e._mettre_au_sac("HerosInvite", _o("hache", 2, 1), 30)
	e.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	e.notification(Node.NOTIFICATION_APPLICATION_RESUMED)   # (un coup d'œil aux notifications)
	e._on_partenaire_parti("Ton partenaire a quitté la partie.")
	assert_true(e.reussite, "Une courte pause n'y est pour rien : extraction d'urgence")
	assert_eq(Sauvegarde.objets().size(), 1)


# ---------------------------------------------------------------- 4. quai : les relevés comptent
func test_les_releves_retiennent_les_vagues() -> void:
	Partie.debug_depart = &"chaloupe"
	var e := await _expedition()
	e.heros.global_position = e.salle.zone_chaloupe
	await wait_physics_frames(2)
	assert_eq(e.vagues_lancees, 1)
	var manque := EQ.chaloupe_max_debout - e.generateur.vivants()
	for i in manque:
		e.generateur.relever_allie(Vector3(1.5 * i - 3.0, 0, 2.0), e.heros)
	e._verifier_chaloupe(EQ.chaloupe_duree - 1.0)
	assert_eq(e.vagues_lancees, 1, "Quai plein (squelettes relevés compris) : la vague attend")


# ---------------------------------------------------------------- 5. coups discrets
func test_coups_discrets_sans_arret_sur_image() -> void:
	var effets := EffetsCombat.new()
	monde.add_child(effets)
	var h := Heros.creer(&"bretteur")
	h.equiper([{"id": "t", "base": "trousseau", "rarete": 2, "effets": {"epines": 0.2}}])
	monde.add_child(h)
	var s := Ennemi.creer_type(&"matelot", true)
	s.position = Vector3(0, 0, 1.4)
	monde.add_child(s)
	await wait_physics_frames(2)
	s.sante.pv_max = 500.0
	s.sante.definir_pv(500.0)
	Combat.porter_coup_discret(h, s, 5.0)
	assert_eq(Engine.time_scale, 1.0, "Eau de la Lame du Noyé, squelette relevé : pas d'arrêt sur image")
	Combat.porter_coup(s, h, 10.0, false)   # (les épines rendent le coup : discret aussi)
	assert_eq(Engine.time_scale, 1.0, "Épines : pas d'arrêt sur image")
	assert_lt(s.sante.pv, 495.0, "(les épines ont bien rendu le coup)")
	Combat.porter_coup(h, s, 5.0, false)
	assert_lt(Engine.time_scale, 1.0, "Un vrai coup du héros, lui, marque l'arrêt")
	Engine.time_scale = 1.0


func test_coup_discret_chez_l_invite() -> void:
	var effets := EffetsCombat.new()
	monde.add_child(effets)
	var s := SynchroArene.new()
	autofree(s)
	s.arene = monde
	s.generateur = monde
	await wait_physics_frames(1)
	s._coup_recu(Vector3.ZERO, 8.0, false, false, "", "", false, true)
	assert_eq(Engine.time_scale, 1.0, "Chez l'invité aussi (l'hôte envoie « discret »)")
	assert_false(Combat.coup_discret, "Remis à faux après")
	s._coup_recu(Vector3.ZERO, 8.0, false, false, "", "", false, false)
	assert_lt(Engine.time_scale, 1.0)
	Engine.time_scale = 1.0


# ---------------------------------------------------------------- 6. tri de la cale et pause
func test_pause_pendant_le_tri_rien_n_est_valide() -> void:
	var e := await _expedition()
	_sac_plein(e)
	e._terminer(true)
	e.hud.basculer_tri(e.hud.gardes_tri()[0]["id"])   # (7 gardés)
	e.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert_true(e.tri_en_cours, "Un appel, les notifications : le tri reste ouvert")
	assert_eq(Sauvegarde.objets().size(), 0, "Rien d'encaissé pour l'instant")
	assert_true(Sauvegarde.donnees.has("tri_en_attente"), "Mais la sélection est notée")
	# Android ferme l'appli pendant la pause : au lancement suivant, la sélection est encaissée
	Sauvegarde.charger()
	assert_eq(Sauvegarde.objets().size(), EQ.cale_places - 1)
	assert_false(Sauvegarde.donnees.has("tri_en_attente"))
	assert_true(e.id_expedition in Sauvegarde.donnees["expeditions"])


func test_pause_puis_retour_puis_tri_fini() -> void:
	var e := await _expedition()
	_sac_plein(e)
	e._terminer(true)
	e.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	e.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	e.hud.valider_tri()
	assert_eq(Sauvegarde.objets().size(), EQ.cale_places)
	assert_false(Sauvegarde.donnees.has("tri_en_attente"), "Le tri fini efface la note")
	Sauvegarde.charger()
	assert_eq(Sauvegarde.objets().size(), EQ.cale_places, "Rien n'est compté deux fois")


# ---------------------------------------------------------------- 7, 8, 9
func test_pas_de_flasque_sur_le_quai() -> void:
	Partie.debug_depart = &"chaloupe"
	var e := await _expedition()
	e.heros.equiper([{"id": "f", "base": "flasque", "rarete": 0, "effets": {}}])
	e.heros.sante.definir_pv(50.0)
	e._on_salle_videe()
	assert_eq(e.heros.sante.pv, 50.0, "Une vague de la chaloupe vaincue n'est pas une salle nettoyée")


func test_le_releve_ne_suit_pas_dans_la_salle_suivante() -> void:
	Partie.heros_local = &"occultiste"
	var e := await _expedition()
	e.heros.equiper([{"id": "gp", "base": "grimoire_du_pendu", "rarete": 3, "effets": {}}])
	var s := Ennemi.creer_type(&"matelot", true)
	s.position = Vector3(1, 0, 1)
	e.generateur.add_child(s)
	await wait_physics_frames(2)
	s.sante.subir(9999.0, e.heros)
	e._changer_de_salle(2, PlanExpedition.COMBAT, e.modele, [])   # (porte prise aussitôt)
	await wait_seconds(EQ.pendu_delai + 0.3)
	assert_eq(e.generateur.allies(), 0, "Il ne ressort pas dans la nouvelle salle")
	Partie.heros_local = &"bretteur"


func test_rien_ne_se_joue_apres_la_fin() -> void:
	var e := await _expedition()
	e._terminer(true)
	e._changer_de_salle(2, PlanExpedition.COMBAT, e.modele, [])
	assert_eq(e.numero, 1, "Plus de salle suivante derrière l'écran de fin")


# ---------------------------------------------------------------- doutes corrigés
func test_sablier_avec_la_teleportation() -> void:
	var h := Heros.creer(&"occultiste")
	h.equiper([{"id": "s", "base": "sablier_maree", "rarete": 3, "effets": {}}])
	monde.add_child(h)
	var s := Ennemi.creer_type(&"matelot", true)
	s.position = Vector3(0, 0, -EQ.occ_tele_distance - 1.0)   # (là où il atterrit : en arrière, 4 m)
	monde.add_child(s)
	await wait_physics_frames(2)
	h.commandes.demander(&"esquive", h.horloge)
	await wait_physics_frames(int(EQ.occ_tele_duree * 60) + 3)
	assert_ne(h.etat, Heros.Etat.ESQUIVE, "(la téléportation est déjà finie…)")
	assert_true(h.sante.est_invulnerable(), "(… mais il est encore intouchable)")
	Combat.porter_coup(s, h, 10.0, false)
	assert_eq(s.etat, Ennemi.Etat.ETOURDI, "Le Sablier joue aussi pour l'Occultiste")


func test_un_vaincu_ne_revient_pas() -> void:
	var s := Ennemi.creer_type(&"matelot", true)
	monde.add_child(s)
	await wait_physics_frames(2)
	s.sante.subir(9999.0, null)
	s._changer(Ennemi.Etat.POURSUITE)   # (ex. le Bosco tué par des épines, dont la charge se termine ensuite)
	assert_eq(s.etat, Ennemi.Etat.MORT)


func test_equipement_relu_verifie() -> void:
	var d := Sauvegarde.convertir({"version": 1, "objets": [
			{"id": "f", "base": "fiole", "rarete": 0}, {"id": "s", "base": "sabre", "rarete": 0}],
			"equipement": {"bretteur": {"arme": "f", "relique_1": "f", "relique_2": "f"},
					"occultiste": {"arme": "s", "relique_1": "inconnu"}}})
	assert_eq(d["equipement"]["bretteur"], {"arme": "", "relique_1": "f", "relique_2": ""},
			"Une relique n'est pas une arme, et un objet n'est porté qu'une fois")
	assert_eq(d["equipement"]["occultiste"], {"arme": "", "relique_1": "", "relique_2": ""}, "Ni l'arme de l'autre, ni un objet disparu")


func test_coupure_entre_les_deux_renommages() -> void:
	Sauvegarde.encaisser("a", [_o("cle", 0, 1)], 10)
	Sauvegarde.encaisser("b", [_o("cle", 0, 2)], 10)
	# l'appli s'éteint après avoir rangé l'ancien fichier en copie de secours, avant de poser le nouveau
	DirAccess.rename_absolute(Sauvegarde.chemin, Sauvegarde.chemin + ".tmp")
	Sauvegarde.charger()
	assert_eq(Sauvegarde.doublons(), 20, "Le nouveau fichier, déjà vérifié, est repris")
