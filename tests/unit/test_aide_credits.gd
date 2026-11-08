extends GutTest
## « Comment jouer » et « Crédits » (jalon 6, écrans restants ; choix de Téo du 08/11 : depuis l'écran titre seulement,
## jamais ouverts tout seuls).

const EQ: Equilibrage = preload("res://data/equilibrage.tres")

var ecran


func before_each() -> void:
	ecran = load("res://ui/screens/demarrage.tscn").instantiate()
	ecran.changer_de_scene = false
	add_child_autofree(ecran)
	await wait_process_frames(2)


func _textes(p: Control) -> Array:
	return p.contenu.find_children("*", "Label", true, false) \
			.filter(func(l): return not l.is_queued_for_deletion() and l.is_visible_in_tree()).map(func(l): return l.text)


# ---------------------------------------------------------------- l'écran titre
func test_rien_ne_s_ouvre_tout_seul() -> void:
	assert_null(ecran.panneau_aide, "Au lancement, pas de « Comment jouer » (choix de Téo)")
	assert_null(ecran.panneau_credits)
	assert_eq(ecran.bouton_aide.text, "Comment jouer")
	assert_eq(ecran.bouton_credits.text, "Crédits")


func test_les_boutons_ne_se_chevauchent_pas() -> void:
	await wait_process_frames(60)   # (les planches arrivent en glissant)
	var planches: Array = [ecran.bouton_repaire, ecran.bouton_coop, ecran.bouton_combat, ecran.bouton_vitrine,
			ecran.bouton_reglages, ecran.bouton_aide, ecran.bouton_credits]
	var ecran_entier := Rect2(Vector2.ZERO, ecran.get_viewport_rect().size)
	for i in planches.size():
		var a: Rect2 = planches[i].get_global_rect()
		assert_true(ecran_entier.encloses(a), "%s : dans l'écran" % planches[i].text)
		for j in range(i + 1, planches.size()):
			assert_false(a.grow(-4).intersects(planches[j].get_global_rect().grow(-4)),
					"%s et %s se chevauchent" % [planches[i].text, planches[j].text])


func test_ouvrir_et_refermer() -> void:
	ecran.bouton_aide.pressed.emit()
	assert_true(ecran.panneau_aide is PanneauCommentJouer)
	assert_false(get_tree().is_quit_on_go_back(), "Ouvert : le retour d'Android ne quitte pas le jeu")
	ecran.bouton_credits.pressed.emit()
	ecran.bouton_reglages.pressed.emit()
	assert_null(ecran.panneau_credits, "Un seul parchemin à la fois")
	assert_null(ecran.panneau_reglages)
	ecran._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_null(ecran.panneau_aide, "Le retour d'Android le referme")
	assert_eq(ecran.scene_demandee, "", "Sans quitter l'écran titre")
	ecran.bouton_credits.pressed.emit()
	assert_true(ecran.panneau_credits is PanneauCredits)
	ecran.panneau_credits.bouton_fermer.pressed.emit()
	assert_null(ecran.panneau_credits, "« Fermer »")
	await wait_process_frames(1)
	assert_true(get_tree().is_quit_on_go_back(), "Fermé : le retour d'Android quitte de nouveau le jeu")
	ecran.bouton_reglages.pressed.emit()
	assert_true(ecran.panneau_reglages is PanneauReglages, "Les Réglages s'ouvrent toujours")
	ecran.fermer_reglages()
	assert_null(ecran.panneau_reglages)


# ---------------------------------------------------------------- Comment jouer
func test_six_onglets_et_chacun_a_sa_page() -> void:
	ecran.ouvrir_aide()
	var p: PanneauCommentJouer = ecran.panneau_aide
	assert_eq(p.boutons_onglets.size(), 6)
	var vus := {}
	for o in p.ONGLETS:
		p.boutons_onglets[o].pressed.emit()
		assert_eq(p.onglet, o)
		assert_gte(p.lignes.size(), 4, "%s : une vraie page" % o)
		for l in p.lignes:
			assert_ne(String(l[1]), "", "%s : chaque ligne a un titre" % o)
			assert_gt(String(l[2]).length(), 10, "%s, %s : et une explication" % [o, l[1]])
			assert_false(String(l[2]).contains("%d") or String(l[2]).contains("%s"), "%s, %s : nombre bien écrit" % [o, l[1]])
		vus[str(p.lignes.map(func(l): return l[1]))] = true
		assert_eq(p.boutons_onglets[o].theme_type_variation, &"BoutonOngletActif", "%s : l'onglet choisi se voit" % o)
	assert_eq(vus.size(), 6, "Six pages différentes")
	await wait_process_frames(1)   # (les lignes des pages quittées partent à la fin de l'image)


func test_les_boutons_des_heros_sont_les_vrais() -> void:
	# (si un bouton change de nom ou de dessin dans le jeu, la page suit)
	ecran.ouvrir_aide()
	var p: PanneauCommentJouer = ecran.panneau_aide
	for a in [&"bretteur", &"occultiste"]:
		var h := Heros.creer(a)
		var noms: Dictionary = h.noms_boutons()
		var icones: Dictionary = h.icones_boutons()
		h.free()
		p.choisir_onglet(a)
		var titres := p.lignes.map(func(l): return l[1])
		var dessins := p.lignes.map(func(l): return l[0])
		for b in [&"attaque", &"esquive", &"competence_1", &"competence_2"]:
			assert_has(titres, noms[b], "%s : le bouton %s" % [a, noms[b]])
			assert_has(dessins, icones[b], "%s : avec son dessin" % a)
	await wait_process_frames(1)


func test_les_nombres_viennent_de_l_equilibrage() -> void:
	ecran.ouvrir_aide()
	var p: PanneauCommentJouer = ecran.panneau_aide
	var tout := ""
	for o in p.ONGLETS:
		for l in p.page(o):
			tout += String(l[2]) + "\n"
	assert_string_contains(tout, "Coûte %d de Fureur" % roundi(EQ.fente_cout))
	assert_string_contains(tout, "Coûtent %d Âmes" % roundi(EQ.occ_chaines_cout))
	assert_string_contains(tout, "+%d %%" % roundi(EQ.occ_marque_bonus_partenaire * 100.0))
	assert_string_contains(tout, "tiens %d s" % roundi(EQ.chaloupe_duree))
	assert_string_contains(tout, "Après %d salles" % EQ.exp_nb_salles)
	assert_string_contains(tout, "%d fois de suite" % EQ.occ_tele_charges)


func test_le_parchemin_ne_deborde_pas() -> void:
	# (six onglets sur une rangée faisaient grandir le parchemin au-delà de l'écran)
	ecran.ouvrir_aide()
	var p: PanneauCommentJouer = ecran.panneau_aide
	for o in p.ONGLETS:
		p.choisir_onglet(o)
		await wait_process_frames(2)
		# (sa taille, pas son rectangle à l'écran : le parchemin s'ouvre avec un léger zoom)
		assert_almost_eq(p.cadre.size.x, ecran.get_viewport_rect().size.x - 2.0 * p.marge_x, 1.0,
				"%s : le parchemin garde sa largeur" % o)


# ---------------------------------------------------------------- Crédits
func test_credits_et_licence_de_godot() -> void:
	ecran.ouvrir_credits()
	var p: PanneauCredits = ecran.panneau_credits
	var textes := " ".join(_textes(p))
	for qui in ["KayKit", "Kay Lousberg", "Poly Haven", "Kenney", "Meshy", "Alegreya Sans", "IM Fell English",
			"SIL Open Font License", "Godot Engine"]:
		assert_string_contains(textes, qui)
	assert_has(_textes(p), Engine.get_license_text(), "La licence MIT de Godot, en entier (obligatoire)")
	assert_false(textes.contains("FreeType"), "Les composants : seulement sur demande")
	p.bouton_licences.pressed.emit()
	textes = " ".join(_textes(p))
	assert_string_contains(textes, "FreeType", "Les composants du moteur")
	assert_string_contains(textes, "Licence OFL-1.1", "Le texte des licences (dont celle des polices)")
	assert_false(p.bouton_licences.visible)
