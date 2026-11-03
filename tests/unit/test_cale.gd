extends GutTest
## Jalon 4, étape 3 (choix de Téo du 03/11) : la cale (8 objets au plus à la fin d'une expédition réussie,
## les plus rares cochés d'avance, les autres revendus en doublons), la cale visible en route, et
## l'extraction d'urgence de l'invité quand l'hôte part en pleine expédition.

const EQ: Equilibrage = preload("res://data/equilibrage.tres")


func before_all() -> void:
	Combat.chance_critique = 0.0


func after_all() -> void:
	Combat.chance_critique = -1.0
	Arene.chance_orbe = -1.0
	Partie.destination = &"arene"
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


func _expedition() -> Expedition:
	var e: Expedition = load("res://game/expedition/expedition.tscn").instantiate()
	add_child_autofree(e)
	await wait_physics_frames(3)
	e.hud.menu_demande.disconnect(e.retour_menu)
	return e


func _o(base: String, rarete: int, n: int) -> Dictionary:
	return {"id": "%s_%d_%d" % [base, rarete, n], "base": base, "rarete": rarete, "effets": {}}


## Un sac de 11 objets : 1 Légendaire, 2 Épiques, 3 Rares, 5 Communs (dans le désordre).
func _remplir(e: Expedition) -> Array:
	var objets := [_o("cle", 0, 1), _o("sabre", 1, 2), _o("fiole", 0, 3), _o("lame_du_noye", 3, 4), _o("hache", 2, 5),
			_o("chandelle", 0, 6), _o("trousseau", 1, 7), _o("coutelas", 0, 8), _o("flasque", 2, 9), _o("doublon", 1, 10),
			_o("cle", 0, 11)]
	for o in objets:
		e._mettre_au_sac(String(e.heros.name), o, 0)
	e._mettre_au_sac(String(e.heros.name), {}, 40)
	return objets


func test_prix_et_ordre_de_rarete() -> void:
	assert_eq(Butin.prix_revente(_o("cle", 0, 1)), EQ.cale_prix_raretes[0])
	assert_eq(Butin.prix_revente(_o("coeur_kraken", 4, 1)), EQ.cale_prix_raretes[4])
	# (un gros sac : au-delà d'une quinzaine, le tri de Godot ne garde plus l'ordre des égaux tout seul)
	var sac := []
	for i in 40:
		sac.append(_o("cle", [0, 1, 2][i % 3], i))
	var tries := Butin.par_rarete(sac)
	for k in range(1, tries.size()):
		var a: Dictionary = tries[k - 1]
		var b: Dictionary = tries[k]
		assert_true(a["rarete"] > b["rarete"] or (a["rarete"] == b["rarete"] and a["id"].split("_")[2].to_int() < b["id"].split("_")[2].to_int()),
				"Les plus rares d'abord ; à rareté égale, dans l'ordre du ramassage (%s puis %s)" % [a["id"], b["id"]])


func test_cale_visible_en_route() -> void:
	var e := await _expedition()
	var objets := _remplir(e)
	assert_eq(e.hud.label_sac.text, "Sac : %d objets / cale %d · 40 doublons" % [objets.size(), EQ.cale_places])
	assert_eq(e.hud.label_sac.get_theme_color("font_color"), Color(1.0, 0.55, 0.15), "En orange : il faudra trier")
	e.hud.afficher_sac(3, 0, 8)
	assert_eq(e.hud.label_sac.get_theme_color("font_color"), Color("e0b04a"))


func test_sans_tri_quand_tout_tient() -> void:
	var e := await _expedition()
	for i in EQ.cale_places:
		e._mettre_au_sac(String(e.heros.name), _o("cle", 0, i), 0)
	e._terminer(true)
	assert_null(e.hud.panneau_tri, "Pas de tri : tout tient dans la cale")
	assert_not_null(e.hud.panneau_fin)
	assert_eq(Sauvegarde.objets().size(), EQ.cale_places)


func test_tri_de_la_cale() -> void:
	var e := await _expedition()
	var objets := _remplir(e)
	e._terminer(true)
	assert_true(e.tri_en_cours)
	assert_not_null(e.hud.panneau_tri, "Le sac dépasse la cale : on trie avant l'écran de fin")
	assert_null(e.hud.panneau_fin)
	assert_eq(Sauvegarde.objets().size(), 0, "Rien n'est encore dans les coffres")
	var gardes: Array = e.hud.gardes_tri().map(func(o): return o["id"])
	assert_eq(gardes.size(), EQ.cale_places, "Les %d plus rares cochés d'avance" % EQ.cale_places)
	assert_false("cle_0_11" in gardes, "Le Commun ramassé en dernier n'est pas coché")
	assert_false("coutelas_0_8" in gardes)
	assert_true("lame_du_noye_3_4" in gardes)
	# cale pleine : cocher un 9e ne fait rien (et le dit)
	e.hud.basculer_tri("cle_0_11")
	assert_eq(e.hud.gardes_tri().size(), EQ.cale_places)
	assert_string_contains(e.hud._label_tri.text, "La cale est pleine")
	# on échange : le sabre revendu, la petite clé gardée
	e.hud.basculer_tri("sabre_1_2")
	e.hud.basculer_tri("cle_0_11")
	assert_true(e.hud._tri_boutons["cle_0_11"].text.begins_with("✓"))
	assert_string_contains(e.hud._tri_boutons["sabre_1_2"].text, "revendu : +%d doublons" % EQ.cale_prix_raretes[1])
	var attendu: int = 40 + EQ.cale_prix_raretes[1] + EQ.cale_prix_raretes[0] * 2   # (revendus : le sabre, la chandelle, le coutelas)
	assert_string_contains(e.hud._label_tri.text, "revendus : 3 objets, +%d doublons" % (attendu - 40))
	e.hud.valider_tri()
	await wait_physics_frames(1)
	assert_false(e.tri_en_cours)
	assert_not_null(e.hud.panneau_fin, "Puis l'écran de fin")
	var ids := Sauvegarde.objets().map(func(o): return o["id"])
	assert_eq(ids.size(), EQ.cale_places, "La cale dans les coffres")
	assert_true("cle_0_11" in ids)
	assert_false("sabre_1_2" in ids, "Revendu")
	assert_eq(Sauvegarde.doublons(), attendu, "Doublons du sac + revente")
	var textes := e.hud.panneau_fin.find_children("*", "Label", true, false).map(func(l): return l.text)
	assert_has(textes, "Butin rapporté : 8 objets et %d doublons" % attendu)
	assert_has(textes, "Revendus faute de place : 3 objets, +%d doublons" % (attendu - 40))
	assert_eq(objets.size(), 11)


func test_on_peut_en_garder_moins() -> void:
	var e := await _expedition()
	_remplir(e)
	e._terminer(true)
	for o in e.hud.gardes_tri().slice(0, 7):
		e.hud.basculer_tri(o["id"])
	e.hud.valider_tri()
	assert_eq(Sauvegarde.objets().size(), 1, "Un seul gardé, le reste revendu")


func test_l_appli_se_ferme_pendant_le_tri() -> void:
	var e := await _expedition()
	_remplir(e)
	e._terminer(true)
	e.hud.basculer_tri("lame_du_noye_3_4")   # (décoché juste avant de fermer)
	e.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)   # (l'appli se ferme ; la mise en pause : test_relecture_j4)
	assert_false(e.tri_en_cours)
	var ids := Sauvegarde.objets().map(func(o): return o["id"])
	assert_eq(ids.size(), EQ.cale_places - 1, "La sélection en cours est gardée")
	assert_false("lame_du_noye_3_4" in ids)
	e.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	assert_eq(Sauvegarde.objets().size(), EQ.cale_places - 1, "Une seule fois")


func test_defaite_pas_de_tri() -> void:
	var e := await _expedition()
	_remplir(e)
	e._terminer(false)
	assert_null(e.hud.panneau_tri, "Perdue : rien à trier")
	assert_eq(Sauvegarde.objets().size(), 0)
	assert_eq(Sauvegarde.doublons(), 0)


func test_pendant_le_tri_les_commandes_du_combat_dorment() -> void:
	var e := await _expedition()
	_remplir(e)
	e._terminer(true)
	var toucher := InputEventScreenTouch.new()
	toucher.pressed = true
	toucher.index = 0
	toucher.position = Vector2(200, 500)   # (moitié gauche : d'habitude, le joystick)
	e.hud._input(toucher)
	assert_false(e.hud.joystick.actif, "Pas de joystick sous l'écran de tri")


# ---------------------------------------------------------------- extraction d'urgence
func test_extraction_d_urgence_de_l_invite() -> void:
	var e := await _expedition()
	e.heros.name = "HerosInvite"   # (ce téléphone joue l'invité)
	e._mettre_au_sac("HerosInvite", _o("hache", 2, 1), 0)
	e._mettre_au_sac("HerosInvite", {}, 17)
	e._on_partenaire_parti("Ton partenaire a quitté la partie.")
	assert_true(e.finie)
	assert_true(e.reussite, "Son butin est sauvé")
	var textes := e.hud.panneau_fin.find_children("*", "Label", true, false).map(func(l): return l.text)
	assert_has(textes, "Extraction d'urgence !")
	assert_has(textes, "Ton partenaire a quitté la partie.")
	assert_has(textes, "Butin rapporté : 1 objet et 17 doublons")
	assert_eq(Sauvegarde.doublons(), 17)
	assert_eq(Sauvegarde.objets().size(), 1)


func test_extraction_d_urgence_avec_tri() -> void:
	var e := await _expedition()
	e.heros.name = "HerosInvite"
	_remplir(e)
	e._on_partenaire_parti("Ton partenaire a quitté la partie.")
	assert_not_null(e.hud.panneau_tri, "Dans la limite de la cale : tri d'abord")
	e.hud.valider_tri()
	assert_eq(Sauvegarde.objets().size(), EQ.cale_places)


func test_l_hote_continue_seul() -> void:
	var e := await _expedition()
	e._on_partenaire_parti("Ton partenaire a quitté la partie.")
	assert_false(e.finie, "L'hôte continue l'expédition seul")
	assert_eq(Sauvegarde.donnees["historique"].size(), 0)
