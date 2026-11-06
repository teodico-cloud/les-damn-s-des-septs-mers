extends GutTest
## Sons (jalon 6, choix de Téo : des ambiances et deux petites musiques de fin, pas de musique continue ; tout
## directement dans le jeu). Le service Sons, ses canaux et volumes, et les endroits du jeu qui le font sonner.
## (On ne peut pas écouter ici : on vérifie que chaque son part au bon moment, grâce au journal de Sons.)

const EQ: Equilibrage = preload("res://data/equilibrage.tres")
const CHEMIN_TEST := "user://reglages_test_sons.json"

var monde: Node3D
var _chemin_avant := ""
var _volumes_avant := {}


func before_all() -> void:
	Combat.chance_critique = 0.0
	_chemin_avant = Reglages.chemin
	_volumes_avant = Reglages.volumes.duplicate()
	Reglages.chemin = CHEMIN_TEST


func after_all() -> void:
	Combat.chance_critique = -1.0
	Sons.garder_journal = false
	Sons.journal.clear()
	Reglages.volumes = _volumes_avant
	Reglages.chemin = _chemin_avant
	Sons.appliquer_volumes()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CHEMIN_TEST))
	Partie.destination = &"arene"


func before_each() -> void:
	Engine.time_scale = 1.0
	Sons.garder_journal = true
	Sons.journal.clear()
	Sons._derniers.clear()
	monde = Node3D.new()
	add_child_autofree(monde)
	var sol := StaticBody3D.new()
	sol.collision_layer = Combat.COUCHE_MONDE
	var forme := CollisionShape3D.new()
	var boite := BoxShape3D.new()
	boite.size = Vector3(60, 0.2, 60)
	forme.shape = boite
	sol.add_child(forme)
	sol.position.y = -0.1
	monde.add_child(sol)


func _noms() -> Array:
	return Sons.journal.map(func(j): return j[0])


func _secondes(s: float) -> void:
	await wait_physics_frames(int(ceil(s * 60.0)) + 1)


func _squelette(pos: Vector3) -> Ennemi:
	var e := Ennemi.creer(true)
	e.position = pos
	monde.add_child(e)
	e.set_physics_process(false)
	return e


# ---------------------------------------------------------------- les fichiers
func test_chaque_son_du_catalogue_existe() -> void:
	var n := 0
	for nom in Sons.CATALOGUE:
		for f in Sons.CATALOGUE[nom][0]:
			var flux = load(Sons.DOSSIER + f + ".ogg")
			assert_true(flux is AudioStream, "%s : %s" % [nom, f])
			if flux is AudioStreamOggVorbis:
				assert_false(flux.loop, "Un son ponctuel ne boucle pas : %s" % f)
			n += 1
	for table in [Sons.AMBIANCES, Sons.JINGLES]:
		for nom in table:
			assert_true(load(Sons.DOSSIER + table[nom][0] + ".ogg") is AudioStream, String(nom))
	assert_gt(n, 40)


func test_les_ambiances_bouclent() -> void:
	for nom in Sons.AMBIANCES:
		var flux: AudioStreamOggVorbis = load(Sons.DOSSIER + Sons.AMBIANCES[nom][0] + ".ogg")
		assert_true(flux.loop, "%s boucle (réglage d'import loop=true)" % nom)
		assert_gt(flux.get_length(), 15.0, "%s : une boucle assez longue pour ne pas se remarquer" % nom)


# ---------------------------------------------------------------- canaux et volumes
func test_les_canaux_et_leurs_volumes() -> void:
	var effets := AudioServer.get_bus_index(Sons.BUS_EFFETS)
	var ambiances := AudioServer.get_bus_index(Sons.BUS_AMBIANCES)
	assert_gt(effets, 0, "Canal Effets")
	assert_gt(ambiances, 0, "Canal Ambiances")
	assert_eq(AudioServer.get_bus_send(effets), &"Master")
	Reglages.choisir_volume("effets", 0.5)
	assert_almost_eq(AudioServer.get_bus_volume_db(effets), linear_to_db(0.5), 0.01, "Effets à 50 %")
	assert_false(AudioServer.is_bus_mute(effets))
	Reglages.choisir_volume("ambiances", 0.0)
	assert_true(AudioServer.is_bus_mute(ambiances), "Ambiances coupées à 0 %")
	Reglages.choisir_volume("general", 0.8)
	assert_almost_eq(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Master")), linear_to_db(0.8), 0.01)
	for c in Reglages.CANAUX:
		Reglages.choisir_volume(c, 1.0)
	assert_false(AudioServer.is_bus_mute(ambiances))


func test_les_volumes_sont_gardes() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CHEMIN_TEST))
	Reglages.choisir_volume("effets", 0.35)
	Reglages.choisir_volume("effets", 0.4)   # (le curseur glisse : une seule écriture, un peu plus tard)
	assert_false(FileAccess.file_exists(CHEMIN_TEST), "Pas écrit à chaque cran")
	await wait_seconds(Reglages.DELAI_ECRITURE + 0.2)
	assert_true(FileAccess.file_exists(CHEMIN_TEST), "Écrit une fois le doigt arrêté")
	Reglages.volumes["effets"] = 1.0
	Reglages.charger()
	assert_almost_eq(Reglages.volume("effets"), 0.4, 0.001, "Relu au prochain lancement")
	assert_eq(Reglages.volume("general"), 1.0)
	# un fichier abîmé ou d'une ancienne version : volumes de départ, valeurs ramenées entre 0 et 1
	var f := FileAccess.open(CHEMIN_TEST, FileAccess.WRITE)
	f.store_string('{"version": 1, "qualite": "normale", "volumes": {"effets": 7, "ambiances": "fort"}}')
	f.close()
	Reglages.charger()
	assert_eq(Reglages.volume("effets"), 1.0)
	assert_eq(Reglages.volume("ambiances"), 1.0)
	Reglages.choisir_volume("effets", 1.0)
	Sons.appliquer_volumes()


func test_les_curseurs_de_l_ecran_reglages() -> void:
	var p := PanneauReglages.new()
	add_child_autofree(p)
	await wait_process_frames(2)
	assert_eq(p.curseurs.size(), 3, "Général, Effets, Ambiances")
	var c: HSlider = p.curseurs["ambiances"]
	assert_eq(c.value, 100.0)
	c.value = 40
	assert_almost_eq(Reglages.volume("ambiances"), 0.4, 0.001, "Le curseur règle le volume tout de suite")
	c.value = 100
	assert_eq(Reglages.volume("ambiances"), 1.0)


# ---------------------------------------------------------------- le service
func test_une_horde_ne_sature_pas() -> void:
	for i in 8:
		Sons.jouer(&"os", Vector3(i, 0, 0))
	assert_eq(_noms().count(&"os"), int(Sons.CATALOGUE[&"os"][3]), "Huit squelettes qui éclatent d'un coup : deux sons")
	await wait_seconds(Sons.FENETRE_REPETITION + 0.05)
	Sons.jouer(&"os", Vector3.ZERO)
	assert_eq(_noms().count(&"os"), int(Sons.CATALOGUE[&"os"][3]) + 1, "Un peu plus tard, ça sonne de nouveau")


func test_les_ambiances_se_fondent() -> void:
	Sons.ambiance([&"ressac", &"vent"], 0.2)
	assert_eq(Sons.couches_ambiance(), [&"ressac", &"vent"])
	var vent: AudioStreamPlayer = Sons._couches[&"vent"]["lecteur"]
	assert_true(vent.playing)
	assert_eq(vent.bus, Sons.BUS_AMBIANCES)
	await wait_seconds(0.4)
	Sons.ambiance([&"vent", &"torches"], 0.2)
	assert_eq(Sons.couches_ambiance(), [&"vent", &"torches"], "Le ressac s'éteint")
	assert_eq(Sons._couches[&"vent"]["lecteur"], vent, "Le vent continue sans reprendre au début")
	await wait_seconds(0.4)
	assert_false(Sons._couches.has(&"ressac"), "Éteint puis retiré")
	assert_almost_eq(vent.volume_db, float(Sons.AMBIANCES[&"vent"][1]), 0.1, "Le vent à son volume")
	Sons.niveau_ambiance(&"vent", 0.5)
	await wait_seconds(0.4)
	assert_almost_eq(vent.volume_db, float(Sons.AMBIANCES[&"vent"][1]) + linear_to_db(0.5), 0.1, "Niveau réglable")
	Sons.ambiance([], 0.01)


# ---------------------------------------------------------------- le jeu sonne
func test_le_sabre_souffle_puis_frappe() -> void:
	var h := Bretteur.new()
	monde.add_child(h)
	await wait_physics_frames(3)
	_squelette(Vector3(0, 0, 1.6))
	Sons.journal.clear()
	h.commandes.demander(&"attaque", h.horloge)
	await _secondes(0.5)
	var noms := _noms()
	assert_has(noms, &"lame", "Le souffle de la lame")
	assert_has(noms, &"coup", "Le choc sur le squelette")
	assert_lt(noms.find(&"lame"), noms.find(&"coup"), "Le souffle juste avant le choc")


func test_un_geste_coupe_ne_souffle_pas() -> void:
	var h := Bretteur.new()
	monde.add_child(h)
	await wait_physics_frames(3)
	var e := _squelette(Vector3(0, 0, 3.0))
	Sons.journal.clear()
	h.commandes.demander(&"attaque", h.horloge)
	await wait_physics_frames(2)
	h.recevoir_coup(5.0, e, true)   # touché avant l'impact : le coup est perdu
	await _secondes(0.5)
	assert_has(_noms(), &"touche", "Le héros touché")
	assert_does_not_have(_noms(), &"lame", "Pas de souffle pour un coup qui n'est pas parti")


func test_marionnette_arrivee_trop_tard_pour_le_souffle() -> void:
	# (coop : le héros de l'autre joueur reçu au milieu d'un coup ; le souffle déjà passé ne sonne pas en retard)
	var h := Bretteur.new()
	h.marionnette = true
	monde.add_child(h)
	await wait_physics_frames(3)
	Sons.journal.clear()
	var code := h.code_anim(EQ.combo_animations[0])
	h.appliquer_instantane(int(Heros.Etat.ATTAQUE), code, 1.65, 100.0, true, 0.0, 0.6)
	await _secondes(0.3)
	assert_does_not_have(_noms(), &"lame")
	h.appliquer_instantane(int(Heros.Etat.LIBRE), h.code_anim("Idle"), 1.0, 100.0, true, 0.0, 0.0)
	h.appliquer_instantane(int(Heros.Etat.ATTAQUE), code, 1.65, 100.0, true, 0.0, 0.0)
	await _secondes(0.3)
	assert_has(_noms(), &"lame", "Reçu au début du coup : il souffle")


func test_squelette_vaincu_et_coups_du_combat() -> void:
	var e := _squelette(Vector3(2, 0, 0))
	await wait_physics_frames(2)
	e.recevoir_coup(999.0, null, true)
	await wait_physics_frames(1)
	assert_has(_noms(), &"coup_lourd")
	assert_has(_noms(), &"os", "Il éclate en os")
	Sons.journal.clear()
	EventBus.coup_porte.emit(Vector3.ZERO, 3.0, false, true, null, null, false)
	assert_does_not_have(_noms(), &"touche", "La flaque ronge les PV sans « coup » : pas de son à chaque tic")
	Combat.coup_discret = true
	EventBus.coup_porte.emit(Vector3.ZERO, 3.0, true, false, null, null, false)
	Combat.coup_discret = false
	assert_eq(_noms(), [], "Coup discret (épines, boulets) : sans son")
	EventBus.coup_porte.emit(Vector3.ZERO, 30.0, true, false, null, null, true)
	assert_has(_noms(), &"critique")
	EventBus.parade_parfaite.emit(null, Vector3.ZERO)
	assert_has(_noms(), &"parade_parfaite")


func test_l_occultiste_tire_et_se_teleporte() -> void:
	var h := Occultiste.new()
	monde.add_child(h)
	await wait_physics_frames(3)
	Sons.journal.clear()
	h.commandes.demander(&"attaque", h.horloge)
	await _secondes(0.4)
	assert_has(_noms(), &"tir_maudit")
	h.commandes.demander(&"esquive", h.horloge)
	await _secondes(0.1)
	assert_has(_noms(), &"teleport")


func test_explosions() -> void:
	EffetsMagie.explosion(monde, Vector3.ZERO)
	EffetsMagie.explosion_maudite(monde, Vector3(3, 0, 0), 2.0)
	assert_has(_noms(), &"explosion")
	assert_has(_noms(), &"explosion_maudite")


func test_un_bouton_fait_toc() -> void:
	var b := Button.new()
	add_child_autofree(b)
	EffetsUI.animer_bouton(b)
	b.pressed.emit()
	assert_eq(_noms(), [&"clic"])


func test_fin_d_expedition_et_butin() -> void:
	Partie.revenir_en_solo()
	Partie.heros_local = &"bretteur"
	Partie.debug_depart = &""
	Partie.destination = &"expedition"
	var e: Expedition = load("res://game/expedition/expedition.tscn").instantiate()
	add_child_autofree(e)
	await wait_physics_frames(3)
	e.hud.menu_demande.disconnect(e.retour_menu)
	assert_has(Sons.couches_ambiance(), &"torches", "Ambiance de l'expédition")
	Sons.journal.clear()
	e._mettre_au_sac(String(e.heros.name), {}, 12)
	e._mettre_au_sac(String(e.heros.name), {}, 2, "fer")
	e._mettre_au_sac(String(e.heros.name), {"id": "x", "base": "sabre", "rarete": Butin.Rarete.EPIQUE, "effets": []}, 0)
	assert_eq(_noms(), [&"pieces", &"fer", &"objet_rare"])
	Sons.journal.clear()
	e._terminer(false)
	assert_has(_noms(), &"defaite", "Petite musique de défaite")
	assert_does_not_have(_noms(), &"victoire")
	Partie.destination = &"arene"


func test_les_ennemis_sonnent() -> void:
	# (choix de Téo du 06/11) sortie de terre, souffle de la lame avant le coup, cri du Bosco, prêtre qui relève
	var sortant := Ennemi.creer()   # (avec sa sortie de terre)
	sortant.position = Vector3(4, 0, 0)
	monde.add_child(sortant)
	await wait_physics_frames(2)
	assert_has(_noms(), &"sortie_terre", "Il sort de terre")
	var e := _squelette(Vector3(-3, 0, 0))
	await wait_physics_frames(2)
	Sons.journal.clear()
	e._commencer_preparation(Vector3(0, 0, 1))
	await _secondes(EQ.squelette_preparation - 0.3)
	assert_does_not_have(_noms(), &"lame_squelette", "Pas avant la fin de l'annonce")
	await _secondes(0.3)
	assert_has(_noms(), &"lame_squelette", "Le souffle de sa lame juste avant l'impact")
	var b := Ennemi.creer_type(&"bosco", true)
	b.position = Vector3(0, 0, 6)
	monde.add_child(b)
	b.set_physics_process(false)
	var p := Ennemi.creer_type(&"pretre", true)
	p.position = Vector3(0, 0, -6)
	monde.add_child(p)
	p.set_physics_process(false)
	await wait_physics_frames(2)
	Sons.journal.clear()
	b._jouer("Taunt", 1.0, 0.1, true)
	p._jouer("Spellcasting", 1.0, 0.1, true)
	await _secondes(0.15)
	assert_has(_noms(), &"cri_bosco", "Le cri de la rage du Bosco")
	assert_has(_noms(), &"relever", "Le prêtre relève les morts")
