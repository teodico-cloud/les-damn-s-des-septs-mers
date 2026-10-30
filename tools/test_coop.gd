extends SceneTree
## Essai de la coop avec deux copies du jeu sur la même machine (voir tools/test_coop.sh).
## Usage : godot --headless --path . -s <chemin absolu>/tools/test_coop.gd -- hote
##         godot --headless --path . -s <chemin absolu>/tools/test_coop.gd -- invite 127.0.0.1
## L'hôte joue le Bretteur (ou HEROS_HOTE=occultiste) ; l'invité prend l'autre héros, se déplace puis attaque.
## Chacun écrit ce qu'il voit (lignes « MESURE … ») et vérifie ce qui doit l'être (lignes « VERIF »,
## « ECHEC ») ; le script shell échoue si une vérification échoue.
## Ne pas typer avec les classes du jeu (voir CLAUDE.md, pièges).

var role := ""
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
	if role == "hote":
		partie.heros_local = StringName(OS.get_environment("HEROS_HOTE")) if OS.has_environment("HEROS_HOTE") else &"bretteur"
		partie.mode = 1   # HOTE
		if reseau.heberger(partie.heros_local) != OK:
			return _echec("impossible d'héberger")
		if not await _attendre_signal(reseau.partenaire_connecte, 20.0):
			return _echec("personne ne s'est connecté")
		print("MESURE hote connecte partenaire=%s" % reseau.heros_partenaire)
		await _attendre(0.5)
		reseau.lancer_combat()
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
	change_scene_to_file("res://game/arene/arene.tscn")
	await _attendre(1.0)
	arene = current_scene
	if arene == null:
		return _echec("arène non chargée")
	arene.hud.set_process(false)   # sinon l'interface remet le joystick à zéro à chaque image
	if role == "invite":
		var fin := Time.get_ticks_msec() + 10000
		while arene.synchro._instantanes.is_empty() and Time.get_ticks_msec() < fin:
			await process_frame
		if arene.synchro._instantanes.is_empty():
			return _echec("aucun instantané reçu de l'hôte")
	root.get_node("EventBus").coup_porte.connect(func(_p, _d, _l, _h, _c, _s): coups_recus += 1)
	t0 = Time.get_ticks_msec() / 1000.0
	if role == "hote":
		await _hote()
	else:
		await _invite()
	reseau.quitter()
	await _attendre(0.3)
	quit(1 if echecs > 0 else 0)


func _hote() -> void:
	# L'hôte ne bouge pas tout seul ; il note toutes les secondes ce qu'il voit et provoque des
	# événements à vérifier chez l'invité :
	#   3 s : met le héros de l'invité à terre, puis se place à côté de lui pour le relever ;
	#   4 s : tue un squelette (l'invité doit voir l'animation de mort en entier) ;
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
			for e in arene.generateur.get_children():
				if e.etat != 0 and e.etat != 7:   # ni en train de sortir de terre, ni déjà mort
					e.recevoir_coup(500.0, arene.heros, true)
					print("MESURE hote tue %s" % e.name)
					break
		if i == 4:
			await _capture("coop_hote.png")
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
	_verifier(max_vivants == 3, "3 squelettes à deux (%d vus en même temps)" % max_vivants)
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
	var mort_anim_max := 0.0
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
			if e.etat == 7 and e.anim.current_animation == "Death_C_Skeletons":
				mort_anim_max = maxf(mort_anim_max, e.anim.current_animation_position)
		for n in [arene.heros_partenaire] + arene.generateur.get_children():
			if not is_instance_valid(n):
				continue
			var p: Vector3 = n.global_position
			if avant.has(n.name) and n.get("etat") != 0:   # 0 : sortie de terre (apparition sur place)
				plus_grand_saut = maxf(plus_grand_saut, (p - avant[n.name]).length())
			avant[n.name] = p
	print("MESURE invite fluidite plus_grand_saut_par_image=%.3f m recalages=%d plus_grand_recalage=%.2f m" % [plus_grand_saut, arene.synchro.recalages, arene.synchro.plus_grand_recalage])
	_verifier(plus_grand_saut < 0.4, "affichage fluide du monde de l'hôte (saut max %.2f m par image)" % plus_grand_saut)
	_verifier(fois_a_terre >= 1, "l'hôte a mis notre héros à terre (vu chez nous)")
	_verifier(vu_releve, "puis notre partenaire nous a relevés (vu chez nous)")
	_verifier(mort_anim_max > 0.5, "le squelette tué joue son animation de mort chez nous (jusqu'à %.2f s)" % mort_anim_max)
	_verifier(fois_a_terre >= 2, "les deux à terre : vu chez nous")
	_verifier(hors_salle < 6.5, "notre héros n'est jamais sorti de la salle (%.2f m du centre au plus)" % hors_salle)
	_verifier(h.est_vivant() and h.global_position.distance_to(Vector3(1.2, h.global_position.y, 1.5)) < 1.5,
			"retour au départ chez nous (%s)" % _p(h))
	_mesurer()
	print("MESURE invite fin coups_affiches=%d pos_locale=%s" % [coups_recus, _p(h)])
	_verifier(coups_recus >= 1, "les coups décidés par l'hôte s'affichent chez l'invité (%d)" % coups_recus)
	_comparer_avec_l_hote(h)


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
