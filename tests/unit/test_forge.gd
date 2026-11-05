extends GutTest
## Jalon 5, étape 3 (choix de Téo du 04-05/11) : la forge (monter une arme d'une rareté, recycler un objet,
## relancer un effet choisi au niveau 2), l'agrandissement de la forge et de l'entrepôt, leurs pastilles.

const EQ: Equilibrage = preload("res://data/equilibrage.tres")


func after_all() -> void:
	Partie.lieu_repaire = &""
	Partie.heros_local = &"bretteur"
	Sauvegarde.reinitialiser()


func before_each() -> void:
	Partie.revenir_en_solo()
	Partie.heros_local = &"bretteur"
	Partie.lieu_repaire = &""
	Sauvegarde.reinitialiser()
	Sauvegarde.rng.seed = 42


func _o(id: String, base: String, rarete := 0, effets := {}) -> Dictionary:
	return {"id": id, "base": base, "rarete": rarete, "effets": effets}


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


## Entre deux actions dans un panneau du repaire, le doigt se lève (un double appui est ignoré : PanneauRepaire).
func _doigt_leve() -> void:
	await wait_seconds(PanneauRepaire.DELAI_ENTRE_ACTIONS + 0.1)


func _textes(n: Node) -> Array:
	return n.find_children("*", "Label", true, false).map(func(l): return l.text)


# ---------------------------------------------------------------- règles
func test_monter_une_arme_d_une_rarete() -> void:
	Sauvegarde.encaisser("e", [_o("s", "sabre")], 0)
	Sauvegarde.equiper(&"bretteur", "arme", "s")
	_riche()
	var p := Forge.prix_amelioration(Sauvegarde.objet("s"))
	assert_eq(p, EQ.forge_prix_rarete[0])
	assert_true(Sauvegarde.ameliorer_objet("s", 0))
	var s := Sauvegarde.objet("s")
	assert_eq(int(s["rarete"]), Butin.Rarete.RARE)
	assert_eq(s["effets"].size(), 1, "Un effet en plus")
	assert_eq(Sauvegarde.doublons(), 5000 - int(p["doublons"]))
	assert_eq(Sauvegarde.ressource("fer"), 1000 - int(p["fer"]))
	assert_eq(Sauvegarde.porte(&"bretteur", "arme")["id"], "s", "Toujours portée")
	assert_false(Sauvegarde.ameliorer_objet("s", 0), "Un double appui ne la fait pas monter deux fois")
	assert_true(Sauvegarde.ameliorer_objet("s", 1))
	s = Sauvegarde.objet("s")
	assert_eq(int(s["rarete"]), Butin.Rarete.EPIQUE)
	assert_eq(s["effets"].size(), 2, "Deux effets en plus, différents")
	assert_almost_eq(Equipement.effets(s)["degats"] - float(s["effets"].get("degats", 0.0)), 0.10 * EQ.equip_mult_raretes[2], 0.0001,
			"L'effet de base d'une arme Épique")
	assert_false(Sauvegarde.ameliorer_objet("s", 2), "Épique : au plus haut")
	assert_eq(Sauvegarde.donnees["achats"], ["forge_s_1", "forge_s_2"])


func test_les_effets_en_plus_sont_tires_au_hasard() -> void:
	var vus := {}
	for i in 30:
		Sauvegarde.reinitialiser()
		Sauvegarde.rng.seed = i
		Sauvegarde.encaisser("e", [_o("s", "coutelas")], 0)
		_riche()
		Sauvegarde.ameliorer_objet("s", 0)
		Sauvegarde.ameliorer_objet("s", 1)
		var e: Dictionary = Sauvegarde.objet("s")["effets"]
		assert_eq(e.size(), 2)
		for k in e:
			assert_eq(e[k], float(EQ.equip_effets_plus[k]), "La valeur d'un effet en plus")
			vus[k] = true
	assert_gt(vus.size(), 4, "Des effets variés (%d sortes vues)" % vus.size())


func test_ni_les_uniques_ni_les_reliques() -> void:
	Sauvegarde.encaisser("e", [_o("l", "lame_du_noye", 3), _o("f", "fiole"), _o("h", "hache", 2)], 0)
	_riche()
	assert_false(Forge.ameliorable(Sauvegarde.objet("l")), "Objet unique")
	assert_false(Forge.ameliorable(_o("l0", "lame_du_noye", 0)), "Un objet unique, même d'une rareté basse (sauvegarde abîmée)")
	assert_false(Forge.ameliorable(Sauvegarde.objet("f")), "Relique")
	assert_false(Forge.ameliorable(Sauvegarde.objet("h")), "Déjà Épique")
	assert_false(Sauvegarde.ameliorer_objet("l", 3))
	assert_false(Sauvegarde.ameliorer_objet("f", 0))
	assert_eq(Sauvegarde.doublons(), 5000, "Rien n'est payé")


func test_trop_pauvre_pour_la_forge() -> void:
	Sauvegarde.encaisser("e", [_o("s", "sabre")], 50, {}, {"fer": 30})
	assert_false(Sauvegarde.ameliorer_objet("s", 0), "Il manque des doublons")
	assert_eq(int(Sauvegarde.objet("s")["rarete"]), 0)
	assert_eq(Sauvegarde.doublons(), 50)


func test_recycler() -> void:
	Sauvegarde.encaisser("e", [_o("s", "sabre", 1, {"critique": 0.06}), _o("f", "fiole", 2, {}), _o("t", "talisman_pendu", 4)], 0)
	Sauvegarde.equiper(&"bretteur", "arme", "s")
	var r := Sauvegarde.recycler("s")
	assert_eq(r["gardees"]["fer"], EQ.forge_recyclage_arme[1], "Une arme Rare rend du fer noir")
	assert_eq(Sauvegarde.ressource("fer"), EQ.forge_recyclage_arme[1])
	assert_true(Sauvegarde.objet("s").is_empty(), "Disparue des coffres")
	assert_eq(Sauvegarde.porte(&"bretteur", "arme"), {}, "Et de la main du héros")
	assert_eq(Sauvegarde.donnees["equipement"]["bretteur"]["arme"], "", "Son identifiant ne reste pas dans l'équipement")
	assert_eq(Sauvegarde.recycler("s"), {}, "Un double appui ne recycle rien de plus")
	Sauvegarde.recycler("f")
	assert_eq(Sauvegarde.ressource("essence"), EQ.forge_recyclage_relique[2], "Une relique rend de l'essence")
	Sauvegarde.donnees["ressources"]["essence"] = Sauvegarde.plafond("essence")
	var avant := Sauvegarde.doublons()
	r = Sauvegarde.recycler("t")
	assert_eq(int(r["surplus"]["essence"]), EQ.forge_recyclage_relique[4], "Entrepôt plein")
	assert_eq(Sauvegarde.doublons(), avant + EQ.forge_recyclage_relique[4] * int(EQ.mat_prix_surplus["essence"]), "Le surplus revendu")


func test_relancer_un_effet_choisi() -> void:
	Sauvegarde.encaisser("e", [_o("h", "hache", 2, {"critique": 0.06, "pv": 10.0})], 0)
	_riche()
	assert_eq(Sauvegarde.relancer_effet("h", "critique"), "", "Forge niveau 1 : pas encore")
	assert_true(Sauvegarde.agrandir("forge"))
	assert_eq(Sauvegarde.niveau_repaire("forge"), 2)
	assert_false(Sauvegarde.agrandir("forge"), "Une seule fois")
	var avant := Sauvegarde.doublons()
	var nouveau := Sauvegarde.relancer_effet("h", "critique")
	assert_ne(nouveau, "")
	assert_ne(nouveau, "critique", "Remplacé par un autre")
	assert_ne(nouveau, "pv", "Pas un effet qu'il a déjà")
	var e: Dictionary = Sauvegarde.objet("h")["effets"]
	assert_eq(e.size(), 2)
	assert_true(e.has("pv"), "L'autre effet ne bouge pas")
	assert_false(e.has("critique"))
	assert_eq(Sauvegarde.doublons(), avant - int(EQ.forge_prix_relance["doublons"]))
	assert_eq(Sauvegarde.relancer_effet("h", "critique"), "", "Un double appui ne relance pas l'effet nouveau")
	assert_eq(Sauvegarde.relancer_effet("h", "degats_inconnus"), "")


func test_agrandir_l_entrepot() -> void:
	assert_false(Sauvegarde.agrandir("entrepot"), "Trop pauvre")
	_riche()
	assert_true(Sauvegarde.agrandir("entrepot"))
	assert_eq(Sauvegarde.plafond("bois"), int(EQ.mat_plafonds_niveau_2["bois"]))
	assert_false(Sauvegarde.agrandir("entrepot"))
	assert_false(Sauvegarde.agrandir("chantier"), "Pas une installation à agrandir")
	Sauvegarde.enregistrer()
	Sauvegarde.donnees = {}
	Sauvegarde.charger()
	assert_eq(Sauvegarde.niveau_repaire("entrepot"), 2, "Gardé dans la sauvegarde")


# ---------------------------------------------------------------- panneau de la forge
func test_le_panneau_de_la_forge() -> void:
	Sauvegarde.encaisser("e", [_o("s", "sabre"), _o("f", "fiole", 1, {"vitesse": 0.06}),
			_o("c", "coutelas", 2, {"pv": 10.0, "critique": 0.06})], 0)
	_riche()
	var r := await _repaire()
	r.ouvrir(&"forge")
	var p := r.hud.panneau as PanneauForge
	assert_not_null(p)
	await wait_process_frames(2)
	assert_eq(p.boutons.keys(), ["s"], "Améliorer : les armes seulement")
	p.boutons["s"].pressed.emit()
	assert_eq(int(Sauvegarde.objet("s")["rarete"]), 1)
	await wait_process_frames(1)
	assert_has(_textes(p), "Sabre d'abordage : maintenant Rare")
	# recycler : deux appuis
	p.boutons_onglets["recycler"].pressed.emit()
	await wait_process_frames(1)
	assert_eq(p.boutons.size(), 3, "Recycler : tous les objets")
	await _doigt_leve()
	p.boutons["f"].pressed.emit()
	await wait_process_frames(1)
	assert_false(Sauvegarde.objet("f").is_empty(), "Premier appui : on demande confirmation")
	assert_eq(p.boutons["f"].text, "Sûr ? Recycler")
	await _doigt_leve()
	p.boutons["f"].pressed.emit()
	assert_true(Sauvegarde.objet("f").is_empty(), "Second appui : recyclé")
	await wait_process_frames(1)
	assert_true(_textes(p).any(func(t): return t.begins_with("Fiole d'eau noire recyclé")), str(_textes(p)))
	# relancer : agrandir d'abord
	p.boutons_onglets["relancer"].pressed.emit()
	await wait_process_frames(1)
	assert_not_null(p.bouton_agrandir)
	await _doigt_leve()
	p.bouton_agrandir.pressed.emit()
	assert_eq(Sauvegarde.niveau_repaire("forge"), 2)
	await wait_process_frames(1)
	var cle: String = p.boutons_relance.keys().filter(func(k): return k.begins_with("s|"))[0]
	var effet := cle.split("|")[1]
	await _doigt_leve()
	p.boutons_relance[cle].pressed.emit()
	assert_false(Sauvegarde.objet("s")["effets"].has(effet), "L'effet touché est remplacé")
	await wait_process_frames(1)
	assert_has(p.boutons_relance.keys(), "c|critique")
	await _doigt_leve()
	p.boutons_relance["c|critique"].pressed.emit()   # le second effet de l'objet : c'est lui qui change
	var e: Dictionary = Sauvegarde.objet("c")["effets"]
	assert_false(e.has("critique"), str(e))
	assert_true(e.has("pv"), "Le premier effet ne bouge pas")


func test_l_arme_en_main_suit_la_forge() -> void:
	Sauvegarde.encaisser("e", [_o("s", "sabre")], 0)
	Sauvegarde.equiper(&"bretteur", "arme", "s")
	_riche()
	var r := await _repaire()
	assert_eq(r.heros.arme_portee().get("id"), "s", "Le sabre en main")
	r.ouvrir(&"forge")
	var p := r.hud.panneau as PanneauForge
	await wait_process_frames(2)
	p.boutons["s"].pressed.emit()
	assert_eq(int(r.heros.arme_portee().get("rarete", -1)), Butin.Rarete.RARE, "Le héros tient l'arme améliorée")
	p.choisir_onglet("recycler")
	await _doigt_leve()
	p.recycler("s")
	await _doigt_leve()
	p.recycler("s")
	assert_true(r.heros.arme_portee().is_empty(), "Recyclée : plus dans sa main")
	assert_null(r.heros._arme_equipee, "Le modèle du sabre a disparu")


## Relecture du jalon 5 : après une action, le panneau se refait tout de suite ; le second toucher d'un double
## appui tombait sur le nouveau bouton (niveau suivant, « Sûr ? Recycler ») et payait une seconde fois.
func test_un_double_appui_ne_fait_qu_une_action() -> void:
	Sauvegarde.encaisser("e", [_o("s", "sabre"), _o("c", "coutelas", 2, {"pv": 10.0, "critique": 0.06})], 0)
	Sauvegarde.equiper(&"bretteur", "arme", "c")
	_riche()
	Sauvegarde.agrandir("forge")
	var r := await _repaire()
	r.ouvrir(&"chantier")
	var ch := r.hud.panneau as PanneauChantier
	await wait_process_frames(2)
	ch.boutons["cale"].pressed.emit()
	await wait_process_frames(1)   # (le panneau refait : le bouton du niveau 2 est sous le doigt)
	ch.boutons["cale"].pressed.emit()
	assert_eq(Sauvegarde.niveau_bateau("cale"), 1, "Chantier : un niveau, pas deux")
	await _doigt_leve()
	ch.boutons["cale"].pressed.emit()
	assert_eq(Sauvegarde.niveau_bateau("cale"), 2, "Doigt levé puis nouvel appui : le niveau suivant")
	r.hud.fermer_panneau()
	r.ouvrir(&"forge")
	var p := r.hud.panneau as PanneauForge
	await wait_process_frames(2)
	p.boutons["s"].pressed.emit()
	await wait_process_frames(1)
	p.boutons["s"].pressed.emit()
	assert_eq(int(Sauvegarde.objet("s")["rarete"]), Butin.Rarete.RARE, "Forge : une rareté, pas deux")
	await _doigt_leve()
	p.choisir_onglet("relancer")
	await wait_process_frames(1)
	p.boutons_relance["c|critique"].pressed.emit()
	await wait_process_frames(1)
	var nouveau: String = Sauvegarde.objet("c")["effets"].keys().filter(func(k): return k != "pv")[0]
	p.boutons_relance["c|" + nouveau].pressed.emit()
	assert_true(Sauvegarde.objet("c")["effets"].has(nouveau), "Relance : l'effet tout juste obtenu reste")
	assert_eq(Sauvegarde.donnees["achats"].filter(func(a): return a.begins_with("relance_")).size(), 1)
	await _doigt_leve()
	p.choisir_onglet("recycler")
	await wait_process_frames(1)
	p.boutons["c"].pressed.emit()
	await wait_process_frames(1)
	p.boutons["c"].pressed.emit()   # (« Sûr ? Recycler » apparu sous le doigt)
	assert_false(Sauvegarde.objet("c").is_empty(), "Recycler : un double appui ne confirme pas")
	assert_eq(Sauvegarde.porte(&"bretteur", "arme").get("id"), "c", "Toujours dans la main du Bretteur")
	await _doigt_leve()
	p.boutons["c"].pressed.emit()
	assert_true(Sauvegarde.objet("c").is_empty(), "Un vrai second appui : recyclé")


func test_pastilles_de_la_forge_et_de_l_entrepot() -> void:
	var r := await _repaire()
	assert_false(r.pastilles[&"forge"].visible)
	assert_false(r.pastilles[&"entrepot"].visible)
	_riche()
	r.mettre_a_jour_pastilles()
	assert_true(r.pastilles[&"forge"].visible, "Agrandir la forge est payable")
	assert_true(r.pastilles[&"entrepot"].visible)
	r.ouvrir(&"entrepot")
	var p := r.hud.panneau as PanneauEntrepot
	await wait_process_frames(2)
	assert_not_null(p.bouton_agrandir)
	p.bouton_agrandir.pressed.emit()
	assert_eq(Sauvegarde.niveau_repaire("entrepot"), 2)
	assert_false(r.pastilles[&"entrepot"].visible, "Agrandi : plus de pastille")
	await wait_process_frames(1)
	assert_null(p.bouton_agrandir, "Plus rien à agrandir")
	assert_has(_textes(p), "%d / %d" % [1000 - int(EQ.repaire_prix_niveau_2["entrepot"]["bois"]), int(EQ.mat_plafonds_niveau_2["bois"])])
