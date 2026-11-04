extends GutTest
## Jalon 5, étape 1 (choix de Téo du 04/11) : le repaire où l'on marche (grotte, quai, navire), ses quatre
## lieux (bouton « Ouvrir » devant eux, raccourcis), la salle des cartes qui lance l'expédition, l'entrepôt
## (matériaux et plafonds, équipement), le retour au repaire après l'expédition, l'écran titre.

const EQ: Equilibrage = preload("res://data/equilibrage.tres")


func after_all() -> void:
	Partie.destination = &"arene"
	Partie.malediction = 0
	Partie.lieu_repaire = &""
	Partie.heros_local = &"bretteur"
	Sauvegarde.reinitialiser()


func before_each() -> void:
	Engine.time_scale = 1.0
	Partie.revenir_en_solo()
	Partie.heros_local = &"bretteur"
	Partie.destination = &"arene"
	Partie.malediction = 0
	Partie.lieu_repaire = &""
	Sauvegarde.reinitialiser()


func _repaire() -> Repaire:
	var r: Repaire = load("res://game/repaire/repaire.tscn").instantiate()
	r.changer_de_scene = false
	add_child_autofree(r)
	await wait_physics_frames(3)
	return r


func _ici(r: Repaire, lieu: StringName) -> Vector3:
	return r.LIEUX[lieu]["pos"]


func test_le_repaire_se_construit() -> void:
	Sauvegarde.encaisser("e", [], 57, {}, {"bois": 12, "fer": 3})
	Partie.heros_local = &"occultiste"
	var r := await _repaire()
	assert_not_null(r.heros)
	assert_eq(r.heros.archetype, &"occultiste", "Le héros choisi marche dans le repaire")
	assert_not_null(r.navire, "Le navire au quai")
	assert_true(r.navire.find_child("Voile", true, false) != null, "Avec ses voiles")
	var enseignes := r.find_children("*", "Label3D", false, false).map(func(l): return l.text)
	for l in Repaire.ORDRE_LIEUX:
		assert_has(enseignes, Repaire.LIEUX[l]["nom"])
	assert_eq(r.hud.labels_ressources["doublons"].text, "57 doublons")
	assert_eq(r.hud.labels_ressources["bois"].text, "12 bois de coque")
	assert_eq(r.hud.labels_ressources["fer"].text, "3 fer noir")
	assert_eq(r.hud.labels_ressources["essence"].text, "0 essence maudite")


func test_on_arrive_au_quai_apres_l_expedition() -> void:
	Partie.lieu_repaire = &"quai"
	var r := await _repaire()
	var d := Vector2(r.heros.global_position.x - (-4.8), r.heros.global_position.z - 3.2).length()
	assert_lt(d, 0.5, "Sur le quai (%.2f m)" % d)
	assert_eq(Partie.lieu_repaire, &"", "Une seule fois")


func test_on_revient_devant_l_entrepot() -> void:
	Partie.lieu_repaire = &"entrepot"
	var r := await _repaire()
	assert_eq(r.lieu_proche, &"entrepot", "Juste devant l'entrepôt")


func test_le_bouton_ouvrir_devant_un_lieu() -> void:
	var r := await _repaire()
	assert_false(r.hud.bouton_ouvrir.visible, "Au milieu : rien à ouvrir")
	r.heros.global_position = _ici(r, &"cartes")
	await wait_physics_frames(2)
	assert_eq(r.lieu_proche, &"cartes")
	assert_true(r.hud.bouton_ouvrir.visible)
	assert_eq(r.hud.bouton_ouvrir.text, "Ouvrir : Salle des cartes")
	r.hud.bouton_ouvrir.pressed.emit()
	assert_true(r.hud.panneau is PanneauCartes, "Le bouton ouvre le lieu")
	assert_false(r.hud.bouton_ouvrir.visible, "Caché sous le panneau")
	r.hud.fermer_panneau()
	r.heros.global_position = Vector3(1.6, 0, 1.4)
	await wait_physics_frames(2)
	assert_false(r.hud.bouton_ouvrir.visible, "Reparti : le bouton s'efface")


func test_on_marche_au_joystick() -> void:
	var r := await _repaire()
	var depart := r.heros.global_position
	var toucher := InputEventScreenTouch.new()
	toucher.index = 0
	toucher.pressed = true
	toucher.position = Vector2(200, 500)
	r.hud._input(toucher)
	var glisser := InputEventScreenDrag.new()
	glisser.index = 0
	glisser.position = Vector2(320, 500)   # vers la droite de l'écran
	r.hud._input(glisser)
	assert_true(r.hud.joystick.actif)
	await wait_physics_frames(30)
	assert_gt((r.heros.global_position - depart).length(), 1.0, "Le héros a marché")
	toucher.pressed = false
	r.hud._input(toucher)
	await wait_physics_frames(2)
	var arret := r.heros.global_position
	await wait_physics_frames(10)
	assert_lt((r.heros.global_position - arret).length(), 0.2, "Pouce levé : il s'arrête")


func test_on_ne_tombe_pas_a_l_eau() -> void:
	var r := await _repaire()
	r.heros.global_position = Vector3(-4.8, 0, 1.6)
	r.hud.joystick.commencer(0, Vector2(200, 500))
	r.hud.joystick.deplacer(Vector2(85, 410))   # vers le haut à gauche de l'écran : vers l'eau
	await wait_physics_frames(120)
	assert_gt(r.heros.global_position.x, Repaire.X_MIN - 0.6, "Arrêté au bord du quai (x = %.2f)" % r.heros.global_position.x)
	assert_gt(r.heros.global_position.y, -0.3, "Pas dans l'eau")


func test_panneau_ouvert_le_joystick_ne_bouge_rien() -> void:
	var r := await _repaire()
	r.ouvrir(&"entrepot")
	var toucher := InputEventScreenTouch.new()
	toucher.index = 0
	toucher.pressed = true
	toucher.position = Vector2(200, 500)
	r.hud._input(toucher)
	assert_false(r.hud.joystick.actif)


# ---------------------------------------------------------------- lieux
func test_la_salle_des_cartes_lance_l_expedition() -> void:
	var r := await _repaire()
	r.hud.raccourcis[&"cartes"].pressed.emit()
	var p := r.hud.panneau as PanneauCartes
	assert_not_null(p, "Le raccourci ouvre la salle des cartes")
	await wait_process_frames(2)
	p.boutons_heros[&"occultiste"].pressed.emit()
	await wait_physics_frames(2)
	assert_eq(r.heros.archetype, &"occultiste", "L'Occultiste marche maintenant dans le repaire")
	assert_eq(r.hud.heros, r.heros)
	assert_eq(r.camera.cible, r.heros)
	p.choix_malediction.choisir(2, false)
	p.bouton_partir.pressed.emit()
	assert_eq(r.scene_demandee, Partie.SCENES[&"expedition"])
	assert_eq(Partie.destination, &"expedition")
	assert_eq(Partie.heros_local, &"occultiste")
	assert_eq(Partie.malediction, 2)
	assert_eq(Partie.mode, Partie.Mode.SOLO)


func test_l_entrepot_montre_les_materiaux() -> void:
	Sauvegarde.encaisser("e", [{"id": "s", "base": "sabre", "rarete": 0, "effets": {}}], 40, {},
			{"bois": 30, "essence": Sauvegarde.plafond("essence")})
	Sauvegarde.equiper(&"bretteur", "arme", "s")
	var r := await _repaire()
	r.ouvrir(&"entrepot")
	var p := r.hud.panneau as PanneauEntrepot
	assert_not_null(p)
	await wait_process_frames(2)
	var textes: Array = p.find_children("*", "Label", true, false).map(func(l): return l.text)
	assert_has(textes, "40 doublons")
	assert_has(textes, "30 / %d" % Sauvegarde.plafond("bois"))
	assert_has(textes, "0 / %d" % Sauvegarde.plafond("fer"))
	assert_has(textes, "Coffres : 1 objet, dont 1 porté")
	var plein: Label = p.find_children("Compte", "Label", true, false)[2]
	assert_eq(plein.get_theme_color("font_color"), StyleRepaire.ROUGE, "Plein : en rouge")
	p.bouton_equipement.pressed.emit()
	assert_eq(r.scene_demandee, Repaire.SCENE_EQUIPEMENT)
	assert_eq(Partie.lieu_repaire, &"entrepot", "On reviendra devant l'entrepôt")


func test_chantier_et_forge_pas_encore_ouverts() -> void:
	var r := await _repaire()
	r.ouvrir(&"chantier")
	assert_null(r.hud.panneau)
	assert_true(r.hud.label_message.visible)
	assert_string_contains(r.hud.label_message.text, "étape 2")
	r.ouvrir(&"forge")
	assert_string_contains(r.hud.label_message.text, "étape 3")


func test_retour_d_android_ferme_d_abord_le_lieu() -> void:
	var r := await _repaire()
	r.ouvrir(&"entrepot")
	r._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_null(r.hud.panneau, "Le lieu se ferme")
	assert_eq(r.scene_demandee, "", "On reste au repaire")
	r._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_eq(r.scene_demandee, Repaire.SCENE_MENU, "Puis l'écran titre")


func test_menu_vers_l_ecran_titre() -> void:
	var r := await _repaire()
	r.hud.bouton_menu.pressed.emit()
	assert_eq(r.scene_demandee, Repaire.SCENE_MENU)


# ---------------------------------------------------------------- autour du repaire
func test_apres_l_expedition_on_revient_au_repaire() -> void:
	Partie.destination = &"expedition"
	var e: Expedition = load("res://game/expedition/expedition.tscn").instantiate()
	add_child_autofree(e)
	await wait_physics_frames(3)
	assert_eq(e._scene_retour(), Expedition.SCENE_REPAIRE)
	assert_eq(Partie.lieu_repaire, &"quai", "Sur le quai")
	Partie.destination = &"arene"
	var a: Arene = load("res://game/arene/arene.tscn").instantiate()
	add_child_autofree(a)
	await wait_physics_frames(2)
	assert_eq(a._scene_retour(), Arene.SCENE_MENU, "L'arène d'entraînement revient à l'écran titre")


func test_l_equipement_revient_devant_l_entrepot() -> void:
	var ecran = load("res://ui/screens/equipement.tscn").instantiate()
	ecran.changer_de_scene = false
	add_child_autofree(ecran)
	await wait_process_frames(2)
	ecran.retour_menu()
	assert_eq(Partie.lieu_repaire, &"entrepot")


func test_l_ecran_titre_mene_au_repaire() -> void:
	var ecran = load("res://ui/screens/demarrage.tscn").instantiate()
	add_child_autofree(ecran)
	await wait_process_frames(2)
	assert_eq(ecran.bouton_repaire.text, "Le repaire")
	var textes: Array = ecran.find_children("*", "Button", true, false).map(func(b): return b.text)
	assert_false(textes.has("Équipement"), "L'équipement est passé à l'entrepôt")
	assert_false(textes.has("Expédition"), "On part de la salle des cartes")
	ecran.remplir_ressources_de_test()
	for m in Butin.MATIERES:
		assert_eq(Sauvegarde.ressource(m), Sauvegarde.plafond(m), m + " : l'entrepôt rempli")
	assert_eq(Sauvegarde.doublons(), 1000, "Sans surplus revendu")
	ecran.remplir_ressources_de_test()
	assert_eq(Sauvegarde.doublons(), 2000)
