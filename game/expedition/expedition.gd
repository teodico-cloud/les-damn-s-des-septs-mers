class_name Expedition
extends Arene
## L'expédition (jalon 3) : une suite de salles faites main du Récif des Pendus (voir PlanExpedition,
## Salles). Dans chaque salle de combat, une réserve de squelettes ; quand tout est vaincu, les portes
## s'ouvrent et annoncent la salle suivante. Choix de Téo : expédition courte (4 salles, l'antre du
## Bosco, la chaloupe) ; PV gardés d'une salle à l'autre (orbes de vie) ; en coop, la porte se prend
## quand les deux héros sont devant. Tomber seul, ou tomber tous les deux : l'expédition est perdue.
## Monter dans la chaloupe : réussie. L'hôte décide de tout et envoie chaque salle à l'invité.

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
	if salle:
		remove_child(salle)
		salle.queue_free()
	if orbes:   # (pas encore créées pour la toute première salle)
		for o in orbes.get_children():
			o.queue_free()
	for c in get_children():
		if c is RigidBody3D:
			c.queue_free()   # os des squelettes de la salle d'avant
	salle = Salle.creer(m, portes)
	add_child(salle)
	move_child(salle, 0)


## Hôte (ou seul) : la salle commence (squelettes, ou coffre et portes ouvertes).
func _demarrer_salle() -> void:
	_salle_demarree = true
	var coop := Reseau.est_en_coop()
	var ensemble := EQ.exp_ensemble_coop if coop else EQ.exp_ensemble
	match type_salle:
		PlanExpedition.COMBAT, PlanExpedition.BOSCO:
			var bosco := type_salle == PlanExpedition.BOSCO
			var total := (EQ.exp_ennemis_bosco_coop if coop else EQ.exp_ennemis_bosco) if bosco \
					else (EQ.exp_ennemis_salle_coop if coop else EQ.exp_ennemis_salle)
			generateur.preparer_salle(total, ensemble, salle.apparitions(), composition(numero, type_salle, coop))
			generateur.demarrer()
			if bosco:
				hud.afficher_message("L'antre du Bosco…\n(le Bosco arrive à la prochaine étape)", 3.0)
		PlanExpedition.PIEGE:
			var total := EQ.exp_ennemis_piege_coop if coop else EQ.exp_ennemis_piege
			generateur.preparer_salle(total, maxi(ensemble - 2, 3), salle.apparitions(), composition(numero, type_salle, coop))
			generateur.demarrer()
			hud.afficher_message("Attention aux dalles qui rougeoient…\net frappez les tonneaux de poudre !", 3.0)
		PlanExpedition.TRESOR:
			generateur.preparer_salle(0, 0, AUCUN_POINT)
			_ouvrir_portes()
			hud.afficher_message("Un coffre maudit…", 2.0)
		PlanExpedition.CHALOUPE:
			generateur.preparer_salle(0, 0, AUCUN_POINT)
			hud.afficher_message("La chaloupe vous attend : montez à bord !", 3.0)


## Qui sort de terre dans une salle (le reste en matelots) : des arbalétriers à partir de la 2e salle,
## un prêtre noyé à partir de la 3e et dans l'antre.
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
		PlanExpedition.BOSCO:
			c[&"arbaletrier"] = arb + 1
			c[&"pretre"] = EQ.exp_pretres
	return c


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
	salle.regler_pieges(temps_salle, not Reseau.est_invite())
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
	_verifier_chaloupe()


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
					EventBus.soin.emit(g, g.sante.soigner(g.sante.pv_max * EQ.exp_tresor_soin))
			if synchro:
				synchro.envoyer_lieu("coffre", [numero])
			hud.afficher_message("Le coffre maudit vous soigne !\n(le butin arrive au jalon 4)", 2.5)
			return


func _verifier_chaloupe() -> void:
	if salle.zone_chaloupe == Vector3.INF:
		return
	for h in heros_actifs():
		var d: Vector3 = h.global_position - salle.zone_chaloupe
		d.y = 0.0
		if not h.est_vivant() or d.length() > EQ.exp_rayon_chaloupe:
			return
	_terminer(true)


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


func _bilan(p_reussite: bool) -> Array:
	var secondes := (Time.get_ticks_msec() - _debut_ms) / 1000
	var total := EQ.exp_nb_salles + 2
	var lignes := [
		"Progression : salle %d sur %d" % [mini(numero, total), total] if not p_reussite else "Toutes les salles traversées",
		"Squelettes vaincus : %d" % generateur.vaincus,
		"Coups critiques : %d" % _critiques,
		"Orbes de vie ramassées : %d" % orbes_ramassees,
		"Durée : %d min %02d s" % [secondes / 60, secondes % 60],
	]
	if _parades > 0:
		lignes.insert(3, "Parades parfaites : %d" % _parades)
	return lignes


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
		"tonneau":
			if salle and numero == donnees[0]:
				var t := salle.get_node_or_null(NodePath(donnees[1])) as TonneauPoudre
				if t:
					t.exploser(false)


func _continuer_seul() -> void:
	heros.reapparition_auto = false   # l'expédition continue : tomber seul la perd
	if not finie and generateur.reserve != 0:
		generateur.nombre = EQ.exp_ensemble


func _on_partenaire_parti(raison: String) -> void:
	if finie:
		return   # l'écran de fin est déjà là : le partenaire est simplement retourné au menu
	super._on_partenaire_parti(raison)
