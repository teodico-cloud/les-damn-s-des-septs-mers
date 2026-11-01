extends SceneTree
## Essai de la coop avec deux copies du jeu sur la même machine (voir tools/test_coop.sh).
## Usage : godot --headless --path . -s <chemin absolu>/tools/test_coop.gd -- hote
##         godot --headless --path . -s <chemin absolu>/tools/test_coop.gd -- invite 127.0.0.1
## L'hôte joue le Bretteur (ou HEROS_HOTE=occultiste) ; l'invité prend l'autre héros, se déplace puis attaque.
## DESTINATION=expedition : l'expédition à deux (salle nettoyée, porte prise à deux, salle suivante, fin).
## Chacun écrit ce qu'il voit (lignes « MESURE … ») et vérifie ce qui doit l'être (lignes « VERIF »,
## « ECHEC ») ; le script shell échoue si une vérification échoue.
## Ne pas typer avec les classes du jeu (voir CLAUDE.md, pièges).

var role := ""
var destination: StringName = &"arene"
var reseau: Node
var partie: Node
var arene: Node
var coups_recus := 0
var t0 := 0.0
var echecs := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	role = args[0] if args.size() > 0 else "hote"
	_derouler(args)


func _attendre(s: float) -> void:
	var fin := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < fin:
		await process_frame


func _attendre_signal(sig: Signal, delai: float) -> bool:
	var recu := [false]
	sig.connect(func(_a = null): recu[0] = true, CONNECT_ONE_SHOT)
	var fin := Time.get_ticks_msec() + int(delai * 1000.0)
	while not recu[0] and Time.get_ticks_msec() < fin:
		await process_frame
	return recu[0]


func _echec(raison: String) -> void:
	print("ECHEC %s : %s" % [role, raison])
	quit(1)


## Capture d'écran si CAPTURE_DIR est défini (lancer alors avec un affichage : xvfb-run, rendu Compatibility).
func _capture(nom: String) -> void:
	if not OS.has_environment("CAPTURE_DIR") or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var chemin := OS.get_environment("CAPTURE_DIR").path_join(nom)
	DirAccess.make_dir_recursive_absolute(OS.get_environment("CAPTURE_DIR"))
	root.get_texture().get_image().save_png(chemin)
	print("MESURE %s capture %s" % [role, chemin])


func _verifier(condition: bool, texte: String) -> void:
	if condition:
		print("VERIF ok %s : %s" % [role, texte])
	else:
		echecs += 1
		print("VERIF ECHEC %s : %s" % [role, texte])


func _derouler(args: PackedStringArray) -> void:
	await process_frame
	reseau = root.get_node("Reseau")
	partie = root.get_node("Partie")
	# Wi-Fi imparfait simulé (millisecondes, pourcentage), de chaque côté à la réception
	reseau.latence_simulee = float(OS.get_environment("LATENCE_MS")) / 1000.0 if OS.has_environment("LATENCE_MS") else 0.0
	reseau.gigue_simulee = float(OS.get_environment("GIGUE_MS")) / 1000.0 if OS.has_environment("GIGUE_MS") else 0.0
	reseau.perte_simulee = float(OS.get_environment("PERTE_PCT")) / 100.0 if OS.has_environment("PERTE_PCT") else 0.0
	if reseau.latence_simulee > 0.0 or reseau.perte_simulee > 0.0:
		print("MESURE %s reseau_simule latence=%.0fms gigue=%.0fms perte=%.0f%%" % [role, reseau.latence_simulee * 1000.0, reseau.gigue_simulee * 1000.0, reseau.perte_simulee * 100.0])
	destination = StringName(OS.get_environment("DESTINATION")) if OS.has_environment("DESTINATION") else &"arene"
	# jalon 4 : chaque téléphone a sa sauvegarde et porte son équipement (arme et chandelle, sur ses deux
	# héros) ; l'autre doit le voir (PV max, arme en main). Rien qui change la vitesse : les distances
	# mesurées par l'essai restent les mêmes.
	var sauvegarde = root.get_node("Sauvegarde")
	sauvegarde.chemin = "user://sauvegarde_coop_%s.json" % role
	sauvegarde.reinitialiser()
	sauvegarde.encaisser("coop", [
		{"id": role + "_sabre", "base": "sabre", "rarete": 0, "effets": {}},
		{"id": role + "_grimoire", "base": "grimoire", "rarete": 0, "effets": {}},
		{"id": role + "_chandelle_b", "base": "chandelle", "rarete": 0, "effets": {}},
		{"id": role + "_chandelle_o", "base": "chandelle", "rarete": 0, "effets": {}},
	], 0)
	sauvegarde.equiper(&"bretteur", "arme", role + "_sabre")
	sauvegarde.equiper(&"bretteur", "relique_1", role + "_chandelle_b")
	sauvegarde.equiper(&"occultiste", "arme", role + "_grimoire")
	sauvegarde.equiper(&"occultiste", "relique_1", role + "_chandelle_o")
	if role == "hote":
		partie.heros_local = StringName(OS.get_environment("HEROS_HOTE")) if OS.has_environment("HEROS_HOTE") else &"bretteur"
		partie.mode = 1   # HOTE
		if reseau.heberger(partie.heros_local) != OK:
			return _echec("impossible d'héberger")
		if not await _attendre_signal(reseau.partenaire_connecte, 20.0):
			return _echec("personne ne s'est connecté")
		print("MESURE hote connecte partenaire=%s" % reseau.heros_partenaire)
		await _attendre(0.5)
		if destination == &"expedition":
			partie.malediction = 2   # l'invité doit jouer au même niveau (envoyé au lancement)
		reseau.lancer_combat(destination)
	else:
		partie.mode = 2   # INVITE
		var adresse := args[1] if args.size() > 1 else "127.0.0.1"
		if adresse == "auto":   # recherche automatique sur le réseau (annonces de l'hôte)
			if reseau.chercher() != OK:
				return _echec("impossible d'écouter les annonces")
			var trouvee := [""]
			reseau.partie_trouvee.connect(func(a: String, _i: Dictionary): trouvee[0] = a, CONNECT_ONE_SHOT)
			var fin := Time.get_ticks_msec() + 8000
			while trouvee[0] == "" and Time.get_ticks_msec() < fin:
				await process_frame
			_verifier(trouvee[0] != "", "partie trouvée automatiquement (%s)" % trouvee[0])
			if trouvee[0] == "":
				return _echec("aucune annonce reçue")
			adresse = trouvee[0]
		if reseau.rejoindre(adresse) != OK:
			return _echec("impossible de rejoindre")
		if not await _attendre_signal(reseau.partenaire_connecte, 20.0):
			return _echec("pas de réponse de l'hôte")
		print("MESURE invite connecte heros=%s partenaire=%s" % [partie.heros_local, reseau.heros_partenaire])
		if not await _attendre_signal(reseau.combat_lance, 20.0):
			return _echec("combat jamais lancé")
	if role == "invite":
		_verifier(partie.destination == destination, "l'hôte a lancé « %s »" % destination)
	change_scene_to_file(partie.scene_destination())
	await _attendre(1.0)
	arene = current_scene
	if arene == null:
		return _echec("arène non chargée")
	if destination == &"expedition":
		arene.hud.menu_demande.disconnect(arene.retour_menu)
	arene.hud.set_process(false)   # sinon l'interface remet le joystick à zéro à chaque image
	if role == "invite":
		var fin := Time.get_ticks_msec() + 10000
		while arene.synchro._instantanes.is_empty() and Time.get_ticks_msec() < fin:
			await process_frame
		if arene.synchro._instantanes.is_empty():
			return _echec("aucun instantané reçu de l'hôte")
	_verifier_equipement()
	root.get_node("EventBus").coup_porte.connect(func(_p, _d, _l, _h, _c, _s, _k): coups_recus += 1)
	t0 = Time.get_ticks_msec() / 1000.0
	if destination == &"expedition":
		if role == "hote":
			await _hote_expedition()
		else:
			await _invite_expedition()
	elif role == "hote":
		await _hote()
	else:
		await _invite()
	reseau.quitter()
	await _attendre(0.3)
	quit(1 if echecs > 0 else 0)


## Jalon 4 : les deux téléphones équipent les deux héros pareil (équipement échangé à la connexion).
func _verifier_equipement() -> void:
	var autre := "invite" if role == "hote" else "hote"
	var h = arene.heros
	var p = arene.heros_partenaire
	var base_h: float = 100.0 if h.archetype == &"bretteur" else 80.0
	var base_p: float = 100.0 if p.archetype == &"bretteur" else 80.0
	_verifier(h.arme_portee().get("id", "").begins_with(role + "_"), "notre héros porte notre arme (%s)" % h.arme_portee().get("id", "aucune"))
	_verifier(is_equal_approx(h.sante.pv_max, base_h + 15.0), "nos PV max avec la chandelle (%.0f)" % h.sante.pv_max)
	_verifier(p.arme_portee().get("id", "").begins_with(autre + "_"), "le héros du partenaire porte SON arme (%s)" % p.arme_portee().get("id", "aucune"))
	_verifier(is_equal_approx(p.sante.pv_max, base_p + 15.0), "ses PV max avec sa chandelle (%.0f)" % p.sante.pv_max)
	var main = p.visuel.find_child("handslot_r", true, false)
	_verifier(main != null and main.get_node_or_null("ArmePortee") != null, "son arme dans sa main, chez nous")


func _hote() -> void:
	# L'hôte ne bouge pas tout seul ; il note toutes les secondes ce qu'il voit et provoque des
	# événements à vérifier chez l'invité :
	#   3 s : met le héros de l'invité à terre, puis se place à côté de lui pour le relever ;
	#   4 s : touche un squelette (l'invité doit voir son animation « touché » jouer, pas figée) et en
	#         tue un autre (l'invité doit le voir éclater en os) ;
	#   6 s : (hôte Bretteur) parade parfaite : l'invité doit en voir les effets ;
	#   9 s : les deux héros tombent (retour au départ 3 s plus tard).
	var partenaire_x_max := -INF
	var max_vivants := 0
	arene.heros.sante.rendre_invulnerable(100.0)   # que les squelettes ne gâchent pas l'essai
	for i in 14:
		await _attendre(1.0)
		_mesurer()
		var p = arene.heros_partenaire
		if not is_instance_valid(p):
			continue
		partenaire_x_max = maxf(partenaire_x_max, p.global_position.x)
		max_vivants = maxi(max_vivants, arene.generateur.vivants())
		if i == 2:
			p.sante.invulnerable_jusqua = 0.0   # un squelette a pu le toucher juste avant
			p.recevoir_coup(500.0, null, false)
			_verifier(not p.est_vivant(), "l'hôte met le héros de l'invité à terre")
		if i >= 2 and i <= 6:
			arene.heros.global_position = p.global_position + Vector3(-0.6, 0, 0)
		if i == 3:
			var touche := false
			for e in arene.generateur.get_children():
				if e.etat == 0 or e.etat == 7:   # en train de sortir de terre, ou déjà mort
					continue
				if not touche:
					e.recevoir_coup(1.0, arene.heros, true)
					touche = true
					print("MESURE hote touche %s" % e.name)
				else:
					e.recevoir_coup(500.0, arene.heros, true)
					print("MESURE hote tue %s" % e.name)
					break
		if i == 4:
			await _capture("coop_hote.png")
		if i == 5 and partie.heros_local == &"bretteur":
			var h = arene.heros
			# compteur branché AVANT la Parade : pendant les 3 images d'attente, un vrai squelette peut
			# frapper et être paré parfaitement (vu : l'essai échouait alors une fois sur cinq environ)
			var parfaites := [0]
			var compter := func(_qui, _point): parfaites[0] += 1
			root.get_node("EventBus").parade_parfaite.connect(compter)
			h.commandes.demander(&"competence_1", h.horloge)
			for k in 3:
				await physics_frame
			var source = null
			for e in arene.generateur.get_children():
				if e.etat != 0 and e.etat != 7:   # ni en train de sortir de terre, ni mort
					source = e
					break
			if source and h.etat == 3:   # PARADE : on se tourne vers lui et il frappe
				h.rotation.y = atan2(source.global_position.x - h.global_position.x, source.global_position.z - h.global_position.z)
				h.recevoir_coup(10.0, source, false)
			root.get_node("EventBus").parade_parfaite.disconnect(compter)
			_verifier(h.etat == 4 and parfaites[0] == 1, "parade PARFAITE de l'hôte (riposte lancée) [état %d, parfaites %d, source %s]"
					% [h.etat, parfaites[0], source.name if source else "aucune"])   # RIPOSTE
		if i == 7:
			_verifier(p.est_vivant(), "le héros de l'invité a été relevé")
		if i == 8:
			for h in [arene.heros, p]:
				h.sante.invulnerable_jusqua = 0.0
				h.recevoir_coup(500.0, null, false)
			_verifier(not arene.heros.est_vivant() and not p.est_vivant(), "les deux héros sont à terre")
		if i == 12:
			_verifier(arene.heros.est_vivant() and p.est_vivant(), "les deux à terre : retour au départ")
	# départ en x = 1,2 ; au moins 1,3 m vers la droite (moins qu'en vrai si le jeu dessine des images
	# sans carte graphique : il tourne alors plus lentement que le temps réel)
	_verifier(partenaire_x_max > 2.5, "le héros de l'invité s'est déplacé vers la droite chez l'hôte (x max %.2f)" % partenaire_x_max)
	var attendus: int = load("res://data/equilibrage.tres").arene_nb_ennemis_coop
	_verifier(max_vivants == attendus, "%d squelettes à deux (%d vus en même temps)" % [attendus, max_vivants])
	if partie.heros_local == &"bretteur":   # invité Occultiste : ses tirs doivent compter
		var touches := 0
		for e in arene.generateur.get_children():
			if e.sante.pv < e.sante.pv_max:
				touches += 1
		_verifier(touches + arene.generateur.vaincus >= 1, "les tirs de l'invité ont touché des squelettes chez l'hôte")


func _invite() -> void:
	var h = arene.heros
	# 1) se déplacer vers la droite pendant 0,6 s (loin des murs : les positions ne coïncident pas par hasard)
	var fin := Time.get_ticks_msec() + 600
	while Time.get_ticks_msec() < fin:
		h.commandes.deplacement = Vector3(1, 0, 0)
		await process_frame
	h.commandes.deplacement = Vector3.ZERO
	await _attendre(0.6)
	_mesurer()
	_verifier(h.global_position.x > 2.5 and h.global_position.x < 5.5, "notre héros a bougé tout de suite chez nous (x %.2f)" % h.global_position.x)
	_comparer_avec_l_hote(h)
	# 2) attaquer pendant 4 s (doigt gardé sur Attaque), puis attendre ; on surveille tout du long :
	#    fluidité, mise à terre et réanimation, animation de mort des squelettes, retour au départ
	var debut := Time.get_ticks_msec()
	var capture_faite := false
	var fois_a_terre := 0
	var etait_a_terre := false
	var vu_releve := false
	var touche_anim_max := 0.0
	var vu_eclater := false
	var parades_vues := [0]
	var sur_parade := func(qui, _point):
		if qui == arene.heros_partenaire:
			parades_vues[0] += 1
	root.get_node("EventBus").parade_parfaite.connect(sur_parade)
	var hors_salle := 0.0
	var avant := {}
	var plus_grand_saut := 0.0
	while Time.get_ticks_msec() - debut < 12500:
		if Time.get_ticks_msec() - debut < 4000:
			h.commandes.demander(&"attaque", h.horloge)
		await physics_frame
		var a_terre: bool = h.etat == 7   # MORT
		if a_terre and not etait_a_terre:
			fois_a_terre += 1
		if etait_a_terre and not a_terre and fois_a_terre == 1:
			vu_releve = true
		etait_a_terre = a_terre
		hors_salle = maxf(hors_salle, maxf(absf(h.global_position.x), absf(h.global_position.z)))
		if not capture_faite and Time.get_ticks_msec() - debut > 1000:
			capture_faite = true
			await _capture("coop_invite.png")
		for e in arene.generateur.get_children():
			if e.etat == 7 and not e.visuel.visible:
				vu_eclater = true
			if e.etat == 5 and e.anim.current_animation == "Hit_A":   # TOUCHE
				touche_anim_max = maxf(touche_anim_max, e.anim.current_animation_position)
		for n in [arene.heros_partenaire] + arene.generateur.get_children():
			if not is_instance_valid(n):
				continue
			var p: Vector3 = n.global_position
			if avant.has(n.name) and n.get("etat") != 0:   # 0 : sortie de terre (apparition sur place)
				plus_grand_saut = maxf(plus_grand_saut, (p - avant[n.name]).length())
			avant[n.name] = p
	print("MESURE invite fluidite plus_grand_saut_par_image=%.3f m recalages=%d plus_grand_recalage=%.2f m" % [plus_grand_saut, arene.synchro.recalages, arene.synchro.plus_grand_recalage])
	# (un recul de coup lourd va jusqu'à ~0,1 m par image ; un vrai saut de recalage ferait des mètres)
	_verifier(plus_grand_saut < 0.4, "affichage fluide du monde de l'hôte (saut max %.2f m par image)" % plus_grand_saut)
	_verifier(fois_a_terre >= 1, "l'hôte a mis notre héros à terre (vu chez nous)")
	_verifier(vu_releve, "puis notre partenaire nous a relevés (vu chez nous)")
	_verifier(touche_anim_max > 0.15, "le squelette touché joue son animation chez nous (jusqu'à %.2f s)" % touche_anim_max)
	_verifier(vu_eclater, "le squelette tué éclate en os chez nous")
	_verifier(fois_a_terre >= 2, "les deux à terre : vu chez nous")
	if arene.heros_partenaire.archetype == &"bretteur":
		_verifier(parades_vues[0] >= 1, "la parade parfaite de l'hôte s'affiche chez nous")
	_verifier(hors_salle < 6.5, "notre héros n'est jamais sorti de la salle (%.2f m du centre au plus)" % hors_salle)
	_verifier(h.est_vivant() and h.global_position.distance_to(Vector3(1.2, h.global_position.y, 1.5)) < 1.5,
			"retour au départ chez nous (%s)" % _p(h))
	_mesurer()
	print("MESURE invite fin coups_affiches=%d pos_locale=%s" % [coups_recus, _p(h)])
	_verifier(coups_recus >= 1, "les coups décidés par l'hôte s'affichent chez l'invité (%d)" % coups_recus)
	_comparer_avec_l_hote(h)


# ================================================================ expédition à deux
func _vider_salle() -> bool:
	for tour in 80:
		for e in arene.generateur.get_children():
			if e.etat != 7:
				e.sante.subir(9999.0, arene.heros)
		if arene.generateur.reserve == 0 and arene.generateur.vivants() == 0:
			return true
		await _attendre(0.25)
	return false


func _hote_expedition() -> void:
	# L'hôte : attend l'invité, nettoie la salle 1 (orbes forcées), se place seul devant une porte (rien
	# ne doit se passer), place ensuite le héros de l'invité devant la même porte (salle suivante),
	# puis termine l'expédition (l'invité doit voir l'écran de fin).
	arene.heros.sante.rendre_invulnerable(100.0)
	arene.heros_partenaire.sante.rendre_invulnerable(100.0)
	var fin := Time.get_ticks_msec() + 10000
	while not arene.synchro._invite_pret and Time.get_ticks_msec() < fin:
		await process_frame
	_verifier(arene.synchro._invite_pret, "l'invité a ouvert l'expédition")
	print("MESURE hote salle 1 modele=%s portes=%s" % [arene.modele, arene.types_portes])
	await _attendre(1.5)
	load("res://game/arene/arene.gd").chance_orbe = 1.0
	_verifier(await _vider_salle(), "salle 1 nettoyée")
	load("res://game/arene/arene.gd").chance_orbe = 0.0
	await _attendre(0.5)
	_verifier(arene.salle.portes[0].ouverte, "portes ouvertes")
	var porte = arene.salle.portes[0]
	var type_porte: StringName = porte.type   # (la porte disparaît avec la salle)
	arene.heros.global_position = porte.devant()
	await _attendre(1.0)
	await _capture("exp_coop_hote_porte.png")
	await _attendre(1.0)
	_verifier(arene.numero == 1, "seul devant la porte : on attend le partenaire")
	arene.heros_partenaire.global_position = porte.devant() + Vector3(0.6, 0, 0.3)
	fin = Time.get_ticks_msec() + 5000
	while arene.numero == 1 and Time.get_ticks_msec() < fin:
		await process_frame
	_verifier(arene.numero == 2 and arene.type_salle == type_porte, "les deux devant : salle suivante (%s)" % arene.type_salle)
	print("MESURE hote salle 2 modele=%s type=%s" % [arene.modele, arene.type_salle])
	# étape 2 du jalon 3 : un arbalétrier et un prêtre noyé (l'invité doit les voir tels quels), un
	# carreau tiré et une flaque maudite (l'invité doit voir les deux)
	var gen = arene.generateur
	var arb = gen._faire_apparaitre(Vector3(-1.0, 0, -3.0), &"arbaletrier")
	var pretre = gen._faire_apparaitre(Vector3(-3.5, 0, -0.5), &"pretre")
	await _attendre(3.0)   # sortie de terre
	var avant: Vector3 = (arene.heros_partenaire.global_position - arb.global_position)
	avant.y = 0.0
	load("res://game/combat/carreau.gd").tirer(arene, arb, arb.global_position + Vector3.UP * 1.0, avant.normalized())
	pretre._recharge_relever = 99.0
	pretre._maudire(arene.heros_partenaire.global_position)
	await _attendre(2.5)
	print("MESURE hote temps_salle=%.2f" % arene.temps_salle)
	# jalon 4 : un objet pour l'invité (lui seul le voit), un pour l'hôte (l'invité ne le voit pas) ; le
	# héros de l'invité passe sur le sien : l'hôte le met dans son sac et le dit à l'invité
	var objet_invite := {"id": "coop01", "base": "baton", "rarete": 2, "effets": []}
	var objet_hote := {"id": "coop02", "base": "sabre", "rarete": 1, "effets": []}
	var ici: Vector3 = arene.heros_partenaire.global_position + Vector3(1.6, 0, 0)
	arene._lacher(arene.heros_partenaire, objet_invite, 0, ici, ici)
	arene._lacher(arene.heros, objet_hote, 0, Vector3(-4.5, 0, -4.5), Vector3(-4.5, 0, -4.5))
	await _attendre(1.0)
	var chez_hote = arene.butin_au_sol.get_node_or_null("Butin_coop01")
	_verifier(chez_hote != null and not chez_hote.visible, "le butin de l'invité : invisible chez l'hôte")
	arene.heros_partenaire.global_position = ici
	await _attendre(1.0)
	var sac_invite: Dictionary = arene.sacs.get("HerosInvite", {"objets": []})
	_verifier(sac_invite["objets"].any(func(o): return o["id"] == "coop01"), "le héros de l'invité ramasse son butin (décidé par l'hôte)")
	_verifier(not arene.sacs.get("HerosHote", {"objets": []})["objets"].any(func(o): return o["id"] == "coop01"),
			"… dans le sac de l'invité, pas dans celui de l'hôte")
	# étape 3 : le Bosco (l'invité doit voir sa charge et sa rage), puis la chaloupe (compte à rebours)
	var bosco = gen._faire_apparaitre(Vector3(0.0, 0, -3.0), &"bosco")
	await _attendre(2.5)   # sortie de terre
	bosco._commencer(3, Vector3(0, 0, 1))   # charge
	await _attendre(0.6)
	bosco.sante.subir(bosco.sante.pv - bosco.sante.pv_max * 0.45, arene.heros)   # à mi-vie : la rage
	var fin_rage := Time.get_ticks_msec() + 6000   # (il enrage dès qu'il n'est plus sonné ni en pleine attaque)
	while not bosco.enrage and Time.get_ticks_msec() < fin_rage:
		await process_frame
	await _attendre(1.0)
	print("MESURE hote bosco pv=%.0f/%.0f enrage=%s" % [bosco.sante.pv, bosco.sante.pv_max, bosco.enrage])
	var n: int = arene.numero + 1
	arene.synchro.envoyer_lieu("salle", [n, "chaloupe", "quai", []])
	arene._transition(n, &"chaloupe", "quai", [])
	await _attendre(1.5)
	arene.heros.global_position = arene.salle.zone_chaloupe
	arene.heros_partenaire.global_position = arene.salle.zone_chaloupe + Vector3(0.6, 0, 0.3)
	await _attendre(3.0)
	print("MESURE hote chaloupe=%.1f vagues=%d" % [arene.chaloupe_restant, arene.vagues_lancees])
	arene._terminer(true)
	await _attendre(2.0)


func _invite_expedition() -> void:
	var h = arene.heros
	var fin := Time.get_ticks_msec() + 10000
	while arene.salle == null and Time.get_ticks_msec() < fin:
		await process_frame
	_verifier(arene.salle != null and arene.numero == 1, "première salle reçue de l'hôte")
	if arene.salle == null:
		return
	print("MESURE invite salle 1 modele=%s portes=%s" % [arene.modele, arene.types_portes])
	var vu_portes := false
	var vu_attente := false
	var vu_orbe := false
	fin = Time.get_ticks_msec() + 30000
	while arene.numero == 1 and Time.get_ticks_msec() < fin:
		await physics_frame
		if arene.salle and not arene.salle.portes.is_empty():
			vu_portes = vu_portes or arene.salle.portes[0].ouverte
			if not vu_attente and arene.salle.portes[0]._compteur.text == "1/2":
				vu_attente = true
				await _capture("exp_coop_invite_porte.png")
		vu_orbe = vu_orbe or arene.orbes.get_child_count() > 0
	_verifier(vu_orbe, "orbes de vie posées par l'hôte, vues chez nous")
	_verifier(vu_portes, "portes ouvertes chez nous quand la salle est nettoyée")
	_verifier(vu_attente, "« 1/2 » au-dessus de la porte quand l'hôte attend devant")
	_verifier(arene.numero == 2, "salle suivante reçue")
	print("MESURE invite salle 2 modele=%s type=%s" % [arene.modele, arene.type_salle])
	await _attendre(1.5)
	var entree: Vector3 = load("res://game/expedition/salles.gd").ENTREE_INVITE
	var d := Vector2(h.global_position.x - entree.x, h.global_position.z - entree.z).length()
	_verifier(d < 1.0, "notre héros entre dans la nouvelle salle (à %.2f m de l'entrée)" % d)
	var p = arene.heros_partenaire
	var entree_hote: Vector3 = load("res://game/expedition/salles.gd").ENTREE_HOTE
	var dp := Vector2(p.global_position.x - entree_hote.x, p.global_position.z - entree_hote.z).length()
	_verifier(dp < 1.0, "le héros de l'hôte aussi (à %.2f m)" % dp)
	_verifier(partie.malediction == 2, "malédiction choisie par l'hôte reçue (%d)" % partie.malediction)
	var vu_arb := false
	var vu_pretre := false
	var vu_bosco := false
	var vu_charge := false
	var vu_rage := false
	var vu_compte := false
	var vu_message := false
	var vu_carreau := false
	var vu_flaque := false
	var vu_butin := false
	var vu_butin_hote := false
	var Carreau = load("res://game/combat/carreau.gd")
	var Flaque = load("res://game/combat/flaque_maudite.gd")
	fin = Time.get_ticks_msec() + 30000
	while not arene.finie and Time.get_ticks_msec() < fin:
		await process_frame
		if arene.butin_au_sol:
			var b = arene.butin_au_sol.get_node_or_null("Butin_coop01")
			if b and b.visible and not vu_butin:
				vu_butin = true
				await _capture("exp_coop_invite_butin.png")
			vu_butin_hote = vu_butin_hote or arene.butin_au_sol.get_node_or_null("Butin_coop02") != null
		for e in arene.generateur.get_children():
			if e.has_method("type_ennemi") and e.marionnette:
				vu_arb = vu_arb or e.type_ennemi() == &"arbaletrier"
				vu_pretre = vu_pretre or e.type_ennemi() == &"pretre"
				if e.type_ennemi() == &"bosco":
					vu_bosco = true
					vu_charge = vu_charge or (e.attaque == 3 and e._annonce.visible)
					vu_rage = vu_rage or e.enrage
		if arene.chaloupe_restant > 0.0 and arene.chaloupe_restant < 44.0 and arene.hud.label_salle.text.begins_with("La chaloupe part dans"):
			vu_compte = true
		if arene.hud.label_message.visible and arene.hud.label_message.text.begins_with("Montez dans la chaloupe"):
			vu_message = true
		for n in arene.get_children():
			vu_carreau = vu_carreau or (n.get_script() == Carreau and n.marionnette)
			vu_flaque = vu_flaque or (n.get_script() == Flaque and not n.active)
	_verifier(vu_arb and vu_pretre, "arbalétrier et prêtre noyé recréés chez nous (%s, %s)" % [vu_arb, vu_pretre])
	_verifier(vu_carreau, "carreau de l'arbalétrier vu chez nous")
	_verifier(vu_flaque, "flaque maudite vue chez nous (sans dégâts : c'est l'hôte qui les compte)")
	_verifier(vu_bosco, "Bosco recréé chez nous")
	_verifier(vu_charge, "zone de sa charge dessinée chez nous")
	_verifier(vu_rage, "sa rage vue chez nous")
	_verifier(vu_compte, "compte à rebours de la chaloupe chez nous (%.1f s)" % arene.chaloupe_restant)
	_verifier(vu_message, "message de l'hôte au centre de l'écran chez nous aussi")
	print("MESURE invite temps_salle=%.2f" % arene.temps_salle)
	_verifier(arene.temps_salle > 2.0, "horloge des pièges calée sur l'hôte (%.2f s)" % arene.temps_salle)
	_verifier(arene.finie and arene.reussite and arene.hud.panneau_fin != null, "écran de fin reçu de l'hôte")
	_verifier(vu_butin, "notre butin, tiré par l'hôte, apparaît chez nous")
	_verifier(not vu_butin_hote, "le butin de l'hôte n'apparaît pas chez nous (chacun le sien)")
	var sac: Dictionary = arene.sacs.get(String(h.name), {"objets": []})
	_verifier(sac["objets"].any(func(o): return o["id"] == "coop01"), "ramassé : dans notre sac (%d objets)" % sac["objets"].size())
	if arene.hud.panneau_fin:
		var textes: Array = arene.hud.panneau_fin.find_children("*", "Label", true, false).map(func(l): return l.text)
		_verifier(textes.any(func(x): return x.begins_with("Butin rapporté : ")) and "Bâton de corail" in textes,
				"écran de fin : notre butin rapporté, avec le bâton")


## Compare ce que l'invité affiche avec le dernier instantané reçu de l'hôte.
func _comparer_avec_l_hote(h) -> void:
	var dernier: Array = arene.synchro._instantanes[-1]
	var vu_par_hote: Vector3 = dernier[1][String(h.name)][0]
	var ecart := Vector2(h.global_position.x - vu_par_hote.x, h.global_position.z - vu_par_hote.z).length()
	_verifier(ecart < 0.3, "notre héros est au même endroit chez l'hôte (écart %.2f m)" % ecart)
	var noms_hote: Array = dernier[2].keys()
	var noms_ici := []
	for e in arene.generateur.get_children():
		noms_ici.append(String(e.name))
	noms_hote.sort()
	noms_ici.sort()
	_verifier(noms_hote == noms_ici, "mêmes squelettes des deux côtés (%s)" % ", ".join(noms_ici))
	var partenaire_hote: Vector3 = dernier[1][String(arene.heros_partenaire.name)][0]
	var ecart_p := Vector2(arene.heros_partenaire.global_position.x - partenaire_hote.x, arene.heros_partenaire.global_position.z - partenaire_hote.z).length()
	_verifier(ecart_p < 0.6, "le héros de l'hôte est affiché au bon endroit (écart %.2f m, affichage 0,1 s en retard)" % ecart_p)


func _mesurer() -> void:
	var t := Time.get_ticks_msec() / 1000.0 - t0
	var noms := []
	for e in arene.generateur.get_children():
		noms.append("%s@%s" % [e.name, _p(e)])
	print("MESURE %s t=%.1f local=%s partenaire=%s ennemis=%s" % [role, t, _p(arene.heros), _p(arene.heros_partenaire), " ".join(noms)])


func _p(n) -> String:
	if n == null or not is_instance_valid(n):
		return "-"
	return "(%.2f,%.2f)" % [n.global_position.x, n.global_position.z]
