class_name Expedition
extends Arene
## L'expédition (jalon 3) : une suite de salles faites main du Récif des Pendus (voir PlanExpedition,
## Salles). Dans chaque salle de combat, une réserve de squelettes ; quand tout est vaincu, les portes
## s'ouvrent et annoncent la salle suivante. Choix de Téo : expédition courte (4 salles, l'antre du
## Bosco, la chaloupe) ; PV gardés d'une salle à l'autre (orbes de vie) ; en coop, la porte se prend
## quand les deux héros sont devant. Tomber seul, ou tomber tous les deux : l'expédition est perdue.
## L'antre : le Bosco Maudit (mini-boss). La chaloupe : y tenir 45 s pendant que des squelettes sortent
## de l'eau ; le compte n'avance que si un héros est à bord (choix de Téo) ; à 0 : réussie. La malédiction
## choisie au départ durcit tout (voir Malediction). L'hôte décide de tout et envoie chaque salle à l'invité.

const AUCUN_POINT: Array[Vector3] = []

var plan: PlanExpedition        ## hôte (ou seul) seulement
var salle: Salle
var numero := 0
var type_salle: StringName = &""
var modele := ""
var types_portes: Array = []
var en_transition := false
var finie := false
var reussite := false
var _salle_demarree := false
var _defaite_dans := -1.0
var _debut_ms := 0
var _parades := 0
var _critiques := 0
var temps_salle := 0.0           ## horloge de la salle (pièges) ; chez l'invité, calée sur l'hôte
var _portes_ouvertes_pour := -1  ## invité : n° de salle dont l'hôte a ouvert les portes
var _coffre_ouvert_pour := -1
var bosco: Bosco                  ## antre (hôte) : le Bosco Maudit
var _bosco_debut_ms := -1
var _bosco_fin_ms := -1
var chaloupe_restant := -1.0      ## secondes avant le départ (-1 : personne n'est encore monté) ; invité : d'après l'hôte
var a_bord := false               ## au moins un héros debout dans la chaloupe
var vagues_lancees := 0


# ---------------------------------------------------------------- mise en place
func _construire_lieu() -> void:
	_debut_ms = Time.get_ticks_msec()
	if Reseau.est_invite():
		return   # la salle arrive de l'hôte (evenement_lieu)
	plan = PlanExpedition.new(randi(), EQ.exp_nb_salles)
	var n := 1
	var t := PlanExpedition.COMBAT
	match Partie.debug_depart:   # mode test : commencer ailleurs qu'à la première salle
		&"tresor":
			t = PlanExpedition.TRESOR
		&"bosco":
			n = plan.numero_bosco()
			t = PlanExpedition.BOSCO
		&"chaloupe":
			n = plan.numero_chaloupe()
			t = PlanExpedition.CHALOUPE
	plan.noter_choix(t)
	_construire_salle(n, t, plan.modele_pour(t), plan.portes_apres(n))


func _depart_heros(nom: StringName, coop: bool) -> Vector3:
	return Salle.entree(nom, coop)


func _configurer_generateur(_coop: bool, _hote: bool) -> void:
	generateur.demarrage_auto = false   # chaque salle prépare sa propre réserve
	generateur.nombre = 0
	generateur.reserve = 0


func _pret() -> void:
	hud.mode_expedition = true
	heros.reapparition_auto = false     # tomber, c'est perdre (ou attendre d'être relevé en coop)
	heros.rotation.y = -PI * 0.75       # tourné vers la salle
	if is_instance_valid(heros_partenaire):
		heros_partenaire.rotation.y = -PI * 0.75
	if regles:
		regles.defaite_si_tous_a_terre = true
		regles.tous_a_terre.connect(_on_tous_a_terre)
	if Reseau.est_invite():
		hud.afficher_salle("Arrivée dans le Récif des Pendus…")
		hud.voile.color.a = 1.0          # écran noir jusqu'à la première salle de l'hôte
		return
	generateur.salle_videe.connect(_on_salle_videe)
	EventBus.explosion.connect(_on_explosion)
	EventBus.parade_parfaite.connect(_compter_parade)
	EventBus.coup_porte.connect(_compter_critique)
	hud.afficher_salle(_texte_salle())
	if not Reseau.est_en_coop():
		_demarrer_salle()   # en coop, l'hôte attend que l'invité ait ouvert l'expédition


func _compter_parade(_h: Node3D, _p: Vector3) -> void:
	_parades += 1


func _compter_critique(_pos: Vector3, _d: float, _l: bool, sur_heros: bool, _c: Node3D, _s: Node3D, critique: bool) -> void:
	if critique and not sur_heros:
		_critiques += 1


## Coop, hôte : l'invité est prêt (appelé plusieurs fois s'il redit « prêt ») : on lui envoie la salle
## en cours et ce qui s'y est passé, puis la salle démarre.
func invite_pret() -> void:
	if synchro:
		synchro.envoyer_lieu("salle", [numero, String(type_salle), modele, _portes_texte(types_portes)])
		if salle and not salle.portes.is_empty() and salle.portes[0].ouverte:
			synchro.envoyer_lieu("portes", [numero])
		if salle and salle.coffre_ouvert:
			synchro.envoyer_lieu("coffre", [numero])
	if not _salle_demarree:
		_demarrer_salle()


# ---------------------------------------------------------------- salles
func _texte_salle() -> String:
	match type_salle:
		PlanExpedition.BOSCO:
			return "Antre du Bosco"
		PlanExpedition.CHALOUPE:
			return "La chaloupe : montez à bord !"
	var nom: String = Salles.MODELES.get(modele, {}).get("nom", "")
	return "Salle %d / %d — %s" % [numero, EQ.exp_nb_salles, nom]


func _construire_salle(n: int, t: StringName, m: String, portes: Array) -> void:
	numero = n
	type_salle = t
	modele = m
	types_portes = portes
	_salle_demarree = false
	temps_salle = 0.0
	chaloupe_restant = -1.0
	a_bord = false
	vagues_lancees = 0
	if salle:
		remove_child(salle)
		salle.queue_free()
	if orbes:   # (pas encore créées pour la toute première salle)
		for o in orbes.get_children():
			o.queue_free()
	for c in get_children():
		if c is RigidBody3D or c is FlaqueMaudite or c is Carreau:
			c.queue_free()   # os, flaques et carreaux de la salle d'avant (une flaque y blessait encore)
	salle = Salle.creer(m, portes)
	add_child(salle)
	move_child(salle, 0)


## Squelettes debout à la fois dans la salle en cours (salle piège : moins ; malédiction 2 : +1).
func _ensemble(coop: bool) -> int:
	var n := EQ.exp_ensemble_coop if coop else EQ.exp_ensemble
	if type_salle == PlanExpedition.PIEGE:
		n = maxi(n - 2, 3)
	return n + Malediction.bonus_ensemble()


## Hôte (ou seul) : la salle commence (squelettes, ou coffre et portes ouvertes).
func _demarrer_salle() -> void:
	_salle_demarree = true
	var coop := Reseau.est_en_coop()
	match type_salle:
		PlanExpedition.COMBAT:
			var total := (EQ.exp_ennemis_salle_coop if coop else EQ.exp_ennemis_salle) + Malediction.bonus_ennemis()
			generateur.preparer_salle(total, _ensemble(coop), salle.apparitions(), composition(numero, type_salle, coop))
			generateur.demarrer()
		PlanExpedition.BOSCO:
			generateur.preparer_salle(0, 0, AUCUN_POINT)
			bosco = generateur._faire_apparaitre(salle.donnees.get("bosco", Vector3(0, 0, -2.6)), &"bosco") as Bosco
			bosco.rotation.y = atan2(Salles.ENTREE.x - bosco.position.x, Salles.ENTREE.z - bosco.position.z)   # face à l'entrée
			bosco.vaincu.connect(_on_bosco_vaincu)
			_bosco_debut_ms = Time.get_ticks_msec()
			_message("Le Bosco Maudit !", 2.5)
		PlanExpedition.PIEGE:
			var total := (EQ.exp_ennemis_piege_coop if coop else EQ.exp_ennemis_piege) + Malediction.bonus_ennemis()
			generateur.preparer_salle(total, _ensemble(coop), salle.apparitions(), composition(numero, type_salle, coop))
			generateur.demarrer()
			_message("Attention aux dalles qui rougeoient…\net frappez les tonneaux de poudre !", 3.0)
		PlanExpedition.TRESOR:
			generateur.preparer_salle(0, 0, AUCUN_POINT)
			_ouvrir_portes()
			_message("Un coffre maudit…", 2.0)
		PlanExpedition.CHALOUPE:
			generateur.preparer_salle(0, 0, AUCUN_POINT)
			_message("Montez dans la chaloupe\net tenez bon %d s !" % int(EQ.chaloupe_duree), 3.0)


## Qui sort de terre dans une salle (le reste en matelots) : des arbalétriers à partir de la 2e salle,
## un prêtre noyé à partir de la 3e (l'antre : le Bosco seul, puis son équipage à mi-vie).
static func composition(n: int, type: StringName, coop: bool) -> Dictionary:
	var c := {}
	var arb := EQ.exp_arbaletriers + (1 if coop else 0)
	match type:
		PlanExpedition.COMBAT:
			if n >= 2:
				c[&"arbaletrier"] = arb
			if n >= 3:
				c[&"pretre"] = EQ.exp_pretres
		PlanExpedition.PIEGE:
			if n >= 2:
				c[&"arbaletrier"] = 1
	return c


## Message au centre de l'écran, chez l'hôte et chez l'invité.
func _message(texte: String, duree: float) -> void:
	hud.afficher_message(texte, duree)
	if synchro:
		synchro.envoyer_lieu("message", [numero, texte, duree])


func _on_salle_videe() -> void:
	if type_salle in [PlanExpedition.COMBAT, PlanExpedition.BOSCO, PlanExpedition.PIEGE]:
		_ouvrir_portes()
		var coop := is_instance_valid(heros_partenaire)
		hud.afficher_message("Salle nettoyée !\nChoisissez une porte… ensemble" if coop else "Salle nettoyée !\nChoisis ta porte", 2.5)


func _ouvrir_portes() -> void:
	salle.ouvrir_portes()
	if synchro:
		synchro.envoyer_lieu("portes", [numero])


## Héros encore dans la partie (le partenaire, en coop).
func heros_actifs() -> Array:
	var r := [heros]
	if is_instance_valid(heros_partenaire):
		r.append(heros_partenaire)
	return r


## La porte que tous les héros (debout) ont choisie, ou null. Met aussi à jour les « 1/2 ».
func porte_prise(liste: Array) -> Porte:
	if salle == null:
		return null
	var choisie: Porte = null
	for p in salle.portes:
		var devant := 0
		for h in liste:
			if p.heros_devant(h) and h.est_vivant():
				devant += 1
		p.afficher_attente(devant, liste.size())
		if p.ouverte and devant == liste.size():
			choisie = p
	return choisie


func _prendre_porte(p: Porte) -> void:
	var t := p.type
	plan.noter_choix(t)
	var n := numero + 1
	var m := plan.modele_pour(t)
	var ps := plan.portes_apres(n)
	if synchro:
		synchro.envoyer_lieu("salle", [n, String(t), m, _portes_texte(ps)])
	_transition(n, t, m, ps)


## Fondu au noir, nouvelle salle, retour à l'image.
func _transition(n: int, t: StringName, m: String, ps: Array) -> void:
	en_transition = true
	hud.fondu(true, EQ.exp_fondu)
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_interval(EQ.exp_fondu)
	tw.tween_callback(_changer_de_salle.bind(n, t, m, ps))


func _changer_de_salle(n: int, t: StringName, m: String, ps: Array) -> void:
	_construire_salle(n, t, m, ps)
	var coop := Reseau.est_en_coop()
	var a_placer := [heros] if Reseau.est_invite() else heros_actifs()
	for h in a_placer:
		h.global_position = Salle.entree(h.name, coop)
		h.velocity = Vector3.ZERO
		h.rotation.y = -PI * 0.75
	if Reseau.est_invite() and synchro:
		synchro.oublier_predictions()
	camera.recentrer()
	hud.fondu(false, EQ.exp_fondu)
	hud.afficher_salle(_texte_salle())
	if Reseau.est_invite():
		if _portes_ouvertes_pour == n:
			salle.ouvrir_portes()
		if _coffre_ouvert_pour == n:
			salle.ouvrir_coffre()
	else:
		_demarrer_salle()
	en_transition = false


static func _portes_texte(ps: Array) -> Array:
	return ps.map(func(x): return String(x))


# ---------------------------------------------------------------- chaque image
func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if finie or salle == null:
		return
	if not Reseau.est_invite() and not en_transition:
		temps_salle += delta
	salle.regler_pieges(temps_salle * Malediction.vitesse_pieges(), not Reseau.est_invite())
	if Partie.debug_sante_infinie and not Reseau.est_invite():
		for h in heros_actifs():
			if h.est_vivant() and h.sante.pv < h.sante.pv_max:
				h.sante.definir_pv(h.sante.pv_max)
	if Reseau.est_invite():
		porte_prise(heros_actifs())   # seulement les « 1/2 » ; c'est l'hôte qui décide
		return
	if _defaite_dans >= 0.0:
		_defaite_dans -= delta
		if _defaite_dans < 0.0:
			_terminer(false)
		return
	if not is_instance_valid(heros_partenaire) and not heros.est_vivant():
		_defaite_dans = EQ.exp_delai_defaite   # seul et à terre : l'expédition est perdue
		return
	if en_transition:
		return
	var p := porte_prise(heros_actifs())
	if p:
		_prendre_porte(p)
		return
	_verifier_coffre()
	_verifier_chaloupe(delta)


func _verifier_coffre() -> void:
	if salle.coffre == null or salle.coffre_ouvert:
		return
	for h in heros_actifs():
		var d: Vector3 = h.global_position - salle.coffre.global_position
		d.y = 0.0
		if h.est_vivant() and d.length() <= EQ.exp_rayon_coffre:
			salle.ouvrir_coffre()
			for g in heros_actifs():
				if g.est_vivant():
					EventBus.soin.emit(g, g.sante.soigner(g.sante.pv_max * EQ.exp_tresor_soin * Malediction.mult_coffre()))
			if synchro:
				synchro.envoyer_lieu("coffre", [numero])
			_message("Le coffre maudit vous soigne !\n(le butin arrive au jalon 4)", 2.5)
			return


## Quai : la chaloupe part au bout de chaloupe_duree secondes passées avec au moins un héros à bord
## (le compte s'arrête quand personne n'y est, sans rien perdre) ; des vagues de squelettes sortent
## de l'eau à intervalles réguliers de ce compte (choix de Téo : « tenir 45 s à bord »).
func _verifier_chaloupe(delta: float) -> void:
	if salle.zone_chaloupe == Vector3.INF:
		return
	a_bord = false
	for h in heros_actifs():
		if h.est_vivant() and salle.dans_chaloupe(h.global_position):
			a_bord = true
	if chaloupe_restant < 0.0:
		if not a_bord:
			return
		chaloupe_restant = EQ.chaloupe_duree
		_message("La chaloupe se prépare…\nTenez bon à bord !", 2.5)
	elif a_bord:
		chaloupe_restant = maxf(chaloupe_restant - delta, 0.0)
	var ecoule := EQ.chaloupe_duree - chaloupe_restant
	# une vague attend que le quai se vide un peu (instantané de la coop sous un paquet Wi-Fi, téléphone)
	while vagues_lancees < EQ.chaloupe_vagues and ecoule >= vagues_lancees * EQ.chaloupe_duree / EQ.chaloupe_vagues \
			and generateur.vivants() < EQ.chaloupe_max_debout:
		_lancer_vague(vagues_lancees)
		vagues_lancees += 1
	salle.houle = clampf(ecoule / EQ.chaloupe_duree, 0.0, 1.0)
	_afficher_chaloupe()
	if chaloupe_restant <= 0.0:
		_terminer(true)


## Une vague : des squelettes sortent de l'eau le long du quai (et du fond de la salle).
func _lancer_vague(i: int) -> void:
	var coop := is_instance_valid(heros_partenaire)
	var n := (EQ.chaloupe_vague_coop if coop else EQ.chaloupe_vague) + (1 if Malediction.bonus_ennemis() > 0 else 0)
	var points := salle.points_vague()
	var sortis: Array[Vector3] = []
	for k in n:
		var p: Vector3 = points[(i * 3 + k) % points.size()]
		var type := &"arbaletrier" if k == 0 and i + 1 >= EQ.chaloupe_arbaletrier_des else &"matelot"
		generateur._faire_apparaitre(p, type)
		EffetsMagie.eclaboussure(self, p)
		sortis.append(p)
	if synchro:
		synchro.envoyer_lieu("vague", [numero, sortis])   # les gerbes là où ils sortent vraiment


## Le compte à rebours de la chaloupe, en haut de l'écran (hôte et invité).
func _afficher_chaloupe() -> void:
	if chaloupe_restant < 0.0:
		hud.afficher_salle(_texte_salle())
	elif a_bord:
		hud.afficher_salle("La chaloupe part dans %d s" % ceili(chaloupe_restant))
	else:
		hud.afficher_salle("Remontez dans la chaloupe ! (%d s)" % ceili(chaloupe_restant))


## Coop, invité : le compte à rebours de l'hôte.
func caler_chaloupe(restant: float, p_a_bord: bool) -> void:
	if salle == null or salle.zone_chaloupe == Vector3.INF or finie:
		return
	chaloupe_restant = restant
	a_bord = p_a_bord
	if restant >= 0.0:
		salle.houle = clampf((EQ.chaloupe_duree - restant) / EQ.chaloupe_duree, 0.0, 1.0)
	_afficher_chaloupe()


func _on_bosco_vaincu(_e: Ennemi) -> void:
	_bosco_fin_ms = Time.get_ticks_msec()


## Coop, invité : l'horloge de la salle de l'hôte (pièges réglés pareil des deux côtés).
func caler_temps_salle(t: float) -> void:
	temps_salle = t


## Hôte : un tonneau de la salle a explosé ; l'invité le voit exploser aussi.
func _on_explosion(t: Node3D) -> void:
	if synchro and salle and t.get_parent() == salle:
		synchro.envoyer_lieu("tonneau", [numero, String(t.name)])


func _on_tous_a_terre() -> void:
	if _defaite_dans < 0.0 and not finie:
		_defaite_dans = EQ.exp_delai_defaite


# ---------------------------------------------------------------- fin
func _terminer(p_reussite: bool) -> void:
	if finie:
		return
	var lignes := _bilan(p_reussite)
	if synchro:
		synchro.envoyer_lieu("fin", [p_reussite, lignes])
	_afficher_fin(p_reussite, lignes)


## Les lignes de l'écran de fin (l'hôte les envoie telles quelles à l'invité). Écran enrichi (choix
## de Téo) : malédiction et butin prévu, combat contre le Bosco.
func _bilan(p_reussite: bool) -> Array:
	var secondes := (Time.get_ticks_msec() - _debut_ms) / 1000
	var total := EQ.exp_nb_salles + 2
	var n := Malediction.niveau()
	var lignes := [
		"Progression : salle %d sur %d" % [mini(numero, total), total] if not p_reussite else "Toutes les salles traversées",
		"%s — butin prévu %s" % [Malediction.titre(n), Malediction.texte_butin(n)],
	]
	var ligne_bosco := _ligne_bosco()
	if ligne_bosco != "":
		lignes.append(ligne_bosco)
	lignes.append("Squelettes vaincus : %d" % generateur.vaincus)
	if _parades > 0:
		lignes.append("Parades parfaites : %d" % _parades)
	lignes.append("Coups critiques : %d" % _critiques)
	lignes.append("Orbes de vie ramassées : %d" % orbes_ramassees)
	lignes.append("Durée : %d min %02d s" % [secondes / 60, secondes % 60])
	return lignes


## « Bosco vaincu en 1 min 24 s », ou ce qu'il lui restait de PV ; vide si on ne l'a pas affronté.
func _ligne_bosco() -> String:
	if _bosco_debut_ms < 0:
		return ""
	if _bosco_fin_ms >= 0:
		var s := (_bosco_fin_ms - _bosco_debut_ms) / 1000
		return "Bosco vaincu en %d min %02d s" % [s / 60, s % 60]
	if is_instance_valid(bosco) and bosco.sante:
		return "Bosco : il lui restait %d %% de ses PV" % ceili(100.0 * bosco.sante.pv / bosco.sante.pv_max)
	return ""



func _afficher_fin(p_reussite: bool, lignes: Array) -> void:
	finie = true
	reussite = p_reussite
	generateur.reserve = 0
	for e in generateur.get_children():
		e.set_physics_process(false)   # tout s'arrête derrière l'écran de fin
	hud.afficher_salle("")
	hud.afficher_resultats(p_reussite, lignes)


# ---------------------------------------------------------------- coop
## Invité : ce que l'hôte a décidé pour le lieu.
func evenement_lieu(type: String, donnees: Array) -> void:
	match type:
		"salle":
			var n: int = donnees[0]
			if salle and n == numero:
				return   # déjà là (l'hôte renvoie la salle tant que l'invité redit « prêt »)
			var ps: Array = donnees[3].map(func(x): return StringName(x))
			if salle == null:
				_changer_de_salle(n, StringName(donnees[1]), donnees[2], ps)   # première salle : sous l'écran noir
			else:
				_transition(n, StringName(donnees[1]), donnees[2], ps)
		"portes":
			_portes_ouvertes_pour = donnees[0]
			if salle and numero == donnees[0] and not en_transition:
				salle.ouvrir_portes()
				hud.afficher_message("Salle nettoyée !\nChoisissez une porte… ensemble", 2.5)
		"coffre":
			_coffre_ouvert_pour = donnees[0]
			if salle and numero == donnees[0] and not en_transition:
				salle.ouvrir_coffre()
		"fin":
			_afficher_fin(donnees[0], donnees[1])
		"message":
			if numero == donnees[0] or en_transition:
				hud.afficher_message(donnees[1], donnees[2])
		"vague":
			if salle and numero == donnees[0]:
				for p in donnees[1]:
					EffetsMagie.eclaboussure(self, p)
		"tonneau":
			if salle and numero == donnees[0]:
				var t := salle.get_node_or_null(NodePath(donnees[1])) as TonneauPoudre
				if t:
					t.exploser(false)


func _continuer_seul() -> void:
	heros.reapparition_auto = false   # l'expédition continue : tomber seul la perd
	if not finie and generateur.reserve != 0:
		generateur.nombre = _ensemble(false)   # (relecture : la malédiction et la salle piège étaient oubliées)


func _on_partenaire_parti(raison: String) -> void:
	if finie:
		return   # l'écran de fin est déjà là : le partenaire est simplement retourné au menu
	super._on_partenaire_parti(raison)
