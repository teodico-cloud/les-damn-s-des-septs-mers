extends GutTest
## Parade du Bretteur (choix de Téo, 30/10) : elle coupe un coup en cours ; parée juste à temps, c'est
## une parade parfaite (riposte critique, étourdissement plus long, Parade rendue aussitôt) ; la zone
## rouge des squelettes devient dorée au moment de parer ; effets et coop.

const EQ: Equilibrage = preload("res://data/equilibrage.tres")

var monde: Node3D
var heros: Bretteur


## Dégâts exacts : pas de coup critique tiré au hasard (la riposte parfaite est critique d'office).
func before_all() -> void:
	Combat.chance_critique = 0.0


func after_all() -> void:
	Combat.chance_critique = -1.0


func before_each() -> void:
	Engine.time_scale = 1.0
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
	heros = Bretteur.new()
	monde.add_child(heros)
	await wait_physics_frames(3)


func _ennemi(pos: Vector3) -> Ennemi:
	var e := Ennemi.creer(true)
	e.position = pos   # avant add_child (voir CLAUDE.md)
	monde.add_child(e)
	e.set_physics_process(false)
	e.sante.pv_max = 500.0
	e.sante.pv = 500.0
	return e


func _secondes(s: float) -> void:
	await wait_physics_frames(int(ceil(s * 60.0)) + 1)


func _demander(action: StringName) -> void:
	heros.commandes.demander(action, heros.horloge)


func _attendre_riposte() -> void:
	await _secondes(EQ.riposte_instant_impact / EQ.riposte_vitesse_animation + 0.1)


# ---------------------------------------------------------------- règles
func test_la_parade_coupe_un_coup_avant_son_impact() -> void:
	var e := _ennemi(Vector3(0, 0, 1.6))
	_demander(&"attaque")
	await wait_physics_frames(2)
	assert_eq(heros.etat, Heros.Etat.ATTAQUE)
	assert_lt(heros._t, EQ.combo_instant_impact[0] / EQ.combo_vitesse_animation - 0.05, "Encore avant l'impact")
	_demander(&"competence_1")
	await wait_physics_frames(2)
	assert_eq(heros.etat, Heros.Etat.PARADE, "La parade coupe le coup sans attendre son impact")
	await _secondes(0.4)
	assert_eq(e.sante.pv, 500.0, "Le coup coupé ne touche pas")


func test_parade_parfaite() -> void:
	var e := _ennemi(Vector3(0, 0, 1.5))
	watch_signals(EventBus)
	_demander(&"competence_1")
	await wait_physics_frames(2)
	assert_eq(heros.etat, Heros.Etat.PARADE)
	assert_lt(heros._t, EQ.parade_parfaite_fenetre)
	assert_false(heros.recharge_competence_1.prete())
	assert_eq(Combat.porter_coup(e, heros, 15.0, false), 0.0, "Le coup est paré")
	assert_signal_emitted(EventBus, "parade_parfaite", "Parade parfaite annoncée (effets, réseau)")
	assert_true(heros.recharge_competence_1.prete(), "La Parade est rendue aussitôt")
	await _attendre_riposte()
	assert_eq(e.sante.pv, 500.0 - EQ.riposte_degats * EQ.critique_multiplicateur, "Riposte critique : dégâts doublés")
	var coup: Array = get_signal_parameters(EventBus, "coup_porte")
	assert_true(coup[6], "Le chiffre de la riposte est un critique")
	assert_eq(e.etat, Ennemi.Etat.ETOURDI)
	assert_almost_eq(e._duree_etat, EQ.riposte_etourdissement_parfaite, 0.01, "Étourdi plus longtemps")


func test_parade_tardive_reste_ordinaire() -> void:
	var e := _ennemi(Vector3(0, 0, 1.5))
	watch_signals(EventBus)
	_demander(&"competence_1")
	await wait_physics_frames(2)
	await _secondes(EQ.parade_parfaite_fenetre + 0.05)
	assert_eq(heros.etat, Heros.Etat.PARADE)
	assert_eq(Combat.porter_coup(e, heros, 15.0, false), 0.0, "Le coup est paré quand même")
	assert_signal_not_emitted(EventBus, "parade_parfaite")
	assert_false(heros.recharge_competence_1.prete(), "La Parade garde sa recharge")
	await _attendre_riposte()
	assert_eq(e.sante.pv, 500.0 - EQ.riposte_degats, "Riposte ordinaire")
	assert_almost_eq(e._duree_etat, EQ.riposte_etourdissement, 0.01)


func test_deux_parades_parfaites_d_affilee() -> void:
	var e1 := _ennemi(Vector3(0, 0, 1.5))
	_demander(&"competence_1")
	await wait_physics_frames(2)
	Combat.porter_coup(e1, heros, 15.0, false)
	await _secondes(EQ.riposte_instant_impact / EQ.riposte_vitesse_animation + 0.6)   # fin de la riposte
	e1.queue_free()
	var e2 := _ennemi(Vector3(0.4, 0, 1.5))   # un autre squelette, devant lui
	_demander(&"competence_1")
	await wait_physics_frames(2)
	assert_eq(heros.etat, Heros.Etat.PARADE, "Parade relancée sans attendre sa recharge")
	assert_eq(Combat.porter_coup(e2, heros, 15.0, false), 0.0, "Le deuxième squelette est paré aussi")


# ---------------------------------------------------------------- signal doré
func test_zone_doree_au_moment_de_parer() -> void:
	assert_gt(EQ.parade_signal_avance, EQ.parade_parfaite_fenetre,
		"Le signal vient un peu avant la fenêtre parfaite : réagir au signal donne une parade parfaite")
	var e := _ennemi(Vector3(0, 0, 1.6))
	e._commencer_preparation(Vector3(0, 0, -1))
	e._t = EQ.squelette_preparation - EQ.parade_signal_avance - 0.05
	e._preparer_visuel()
	assert_false(e.signal_parade())
	assert_lt(e._mat_marque.albedo_color.g, 0.6, "Encore rouge")
	e._t = EQ.squelette_preparation - EQ.parade_signal_avance + 0.05
	e._preparer_visuel()
	assert_true(e.signal_parade())
	assert_gt(e._mat_marque.albedo_color.g, 0.75, "Remplissage doré")
	assert_gt(e._mat_zone.albedo_color.g, 0.6, "Zone dorée")
	# l'annonce suivante recommence en rouge DÈS sa première image (sans attendre l'image de physique
	# suivante : sinon la zone d'avant, pleine et dorée, s'affiche un instant — vu par le relecteur)
	e._changer(Ennemi.Etat.POURSUITE)
	e._commencer_preparation(Vector3(0, 0, -1))
	assert_lt(e._mat_marque.albedo_color.g, 0.6, "Remplissage rouge tout de suite")
	assert_lt(e._remplissage.scale.x, 0.1, "Remplissage vide tout de suite")
	assert_eq(e._mat_zone.albedo_color, Ennemi.COULEUR_ZONE)


func test_zone_doree_aussi_chez_l_invite() -> void:
	var e := Ennemi.creer(true)
	e.marionnette = true
	monde.add_child(e)
	await wait_physics_frames(1)
	e.appliquer_instantane(Ennemi.Etat.PREPARATION, "1H_Melee_Attack_Chop", 1.0, 30.0, false,
		EQ.squelette_preparation - 0.2)
	await wait_physics_frames(1)
	assert_true(e.signal_parade(), "Calée sur l'hôte : dorée dans les derniers instants")
	assert_gt(e._mat_marque.albedo_color.g, 0.75)
	# annonce suivante chez l'invité : rouge et vide dès qu'elle est reçue
	e.appliquer_instantane(Ennemi.Etat.RECUPERATION, "Idle_Combat", 1.0, 30.0, false, 0.0)
	e.appliquer_instantane(Ennemi.Etat.PREPARATION, "1H_Melee_Attack_Chop", 1.0, 30.0, false, 0.0)
	assert_lt(e._mat_marque.albedo_color.g, 0.6, "Rouge dès l'instantané reçu")
	assert_lt(e._remplissage.scale.x, 0.1)


# ---------------------------------------------------------------- coop
func test_invite_recoit_sa_parade_parfaite() -> void:
	heros.recharge_competence_1.declencher()
	var synchro := SynchroArene.new()
	autofree(synchro)
	synchro.arene = monde
	synchro.generateur = Node3D.new()
	autofree(synchro.generateur)
	synchro.heros_local = heros
	watch_signals(EventBus)
	synchro._effet_recu(String(heros.name), "parade_parfaite", Vector3(0, 1.2, 0.7))
	assert_signal_emitted(EventBus, "parade_parfaite", "Effets montrés chez l'invité, même pour son propre héros")
	assert_eq(get_signal_parameters(EventBus, "parade_parfaite"), [heros, Vector3(0, 1.2, 0.7)])
	assert_true(heros.recharge_competence_1.prete(), "Parade rendue chez l'invité aussi")
