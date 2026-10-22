extends SceneTree
## Essai de la coop avec deux copies du jeu sur la même machine (voir tools/test_coop.sh).
## Usage : godot --headless --path . -s <chemin absolu>/tools/test_coop.gd -- hote
##         godot --headless --path . -s <chemin absolu>/tools/test_coop.gd -- invite 127.0.0.1
## L'hôte joue le Bretteur et reste sur place ; l'invité (Occultiste) se déplace puis tire.
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
		partie.heros_local = &"bretteur"
		partie.mode = 1   # HOTE
		if reseau.heberger(&"bretteur") != OK:
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
	# l'hôte ne bouge pas ; il note toutes les secondes ce qu'il voit. À 3 s, il met le héros de
	# l'invité à terre puis va se placer à côté de lui pour le relever.
	var partenaire_x_max := -INF
	arene.heros.sante.rendre_invulnerable(100.0)   # que les squelettes ne gâchent pas l'essai
	for i in 9:
		await _attendre(1.0)
		_mesurer()
		if i == 2 and is_instance_valid(arene.heros_partenaire):
			arene.heros_partenaire.recevoir_coup(500.0, null, false)
			print("MESURE hote met l'invité à terre")
		if i >= 2 and i <= 6 and is_instance_valid(arene.heros_partenaire):
			arene.heros.global_position = arene.heros_partenaire.global_position + Vector3(-0.6, 0, 0)
		if i == 4:
			await _capture("coop_hote.png")
		if is_instance_valid(arene.heros_partenaire):
			partenaire_x_max = maxf(partenaire_x_max, arene.heros_partenaire.global_position.x)
	# départ en x = 1,2 ; au moins 1,5 m vers la droite (moins qu'en vrai : sans carte graphique, le jeu
	# peut tourner plus lentement que le temps réel quand il dessine des images)
	_verifier(partenaire_x_max > 2.7, "le héros de l'invité s'est déplacé vers la droite chez l'hôte (x max %.2f)" % partenaire_x_max)
	var ennemis: Array = arene.generateur.get_children()
	var touches := 0
	for e in ennemis:
		if e.get("sante") and e.sante.pv < e.sante.pv_max:
			touches += 1
	print("MESURE hote fin ennemis=%d touches_par_projectiles=%d invite_pos=%s" % [ennemis.size(), touches, _p(arene.heros_partenaire)])
	if is_instance_valid(arene.heros_partenaire):
		_verifier(arene.heros_partenaire.est_vivant(), "le héros de l'invité a été relevé")
	_verifier(touches >= 1, "les tirs de l'invité ont touché des squelettes chez l'hôte (%d touchés)" % touches)
	_verifier(arene.generateur.nombre == 3, "3 squelettes gardés en vie à deux (%d)" % arene.generateur.nombre)


func _invite() -> void:
	var h = arene.heros
	# 1) se déplacer vers la droite pendant 1,5 s
	var fin := Time.get_ticks_msec() + 1500
	while Time.get_ticks_msec() < fin:
		h.commandes.deplacement = Vector3(1, 0, 0)
		await process_frame
	h.commandes.deplacement = Vector3.ZERO
	await _attendre(0.6)
	_mesurer()
	_verifier(h.global_position.x > 2.7, "notre héros a bougé tout de suite chez nous (x %.2f)" % h.global_position.x)
	_comparer_avec_l_hote(h)
	# 2) tirer pendant 4 s (doigt gardé sur Attaque) en surveillant la fluidité de l'affichage :
	#    plus grand saut d'une image à l'autre du héros de l'hôte et des squelettes
	fin = Time.get_ticks_msec() + 4000
	var capture_faite := false
	var vu_a_terre := false
	var vu_releve := false
	var avant := {}
	var plus_grand_saut := 0.0
	while Time.get_ticks_msec() < fin:
		h.commandes.demander(&"attaque", h.horloge)
		await physics_frame
		if h.etat == 7:   # MORT : à terre
			vu_a_terre = true
		elif vu_a_terre:
			vu_releve = true
		if not capture_faite and Time.get_ticks_msec() > fin - 3000:
			capture_faite = true
			await _capture("coop_invite.png")
		for n in [arene.heros_partenaire] + arene.generateur.get_children():
			if not is_instance_valid(n):
				continue
			var p: Vector3 = n.global_position
			if avant.has(n.name) and n.get("etat") != 0:   # 0 : sortie de terre (apparition sur place)
				plus_grand_saut = maxf(plus_grand_saut, (p - avant[n.name]).length())
			avant[n.name] = p
	print("MESURE invite fluidite plus_grand_saut_par_image=%.3f m recalages=%d plus_grand_recalage=%.2f m" % [plus_grand_saut, arene.synchro.recalages, arene.synchro.plus_grand_recalage])
	_verifier(plus_grand_saut < 0.4, "affichage fluide du monde de l'hôte (saut max %.2f m par image)" % plus_grand_saut)
	var fin_attente := Time.get_ticks_msec() + 4000
	while Time.get_ticks_msec() < fin_attente and not vu_releve:
		await physics_frame
		if h.etat == 7:
			vu_a_terre = true
		elif vu_a_terre:
			vu_releve = true
	_verifier(vu_a_terre, "l'hôte a mis notre héros à terre (vu chez nous)")
	_verifier(vu_releve, "puis notre partenaire nous a relevés (vu chez nous)")
	await _attendre(1.0)
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
