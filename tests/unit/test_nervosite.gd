extends GutTest
## Combat « nerveux » (façon Diablo) : coups critiques, squelettes qui éclatent en os, hordes qui
## arrivent en groupes, fin de coup coupée par le joystick, traînée du sabre.

const EQ: Equilibrage = preload("res://data/equilibrage.tres")

var monde: Node3D
var heros: Heros


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


func after_each() -> void:
	Combat.chance_critique = -1.0


func _ennemi(pos: Vector3) -> Ennemi:
	var e := Ennemi.creer(true)
	e.position = pos
	monde.add_child(e)
	e.set_physics_process(false)
	return e


func _secondes(s: float) -> void:
	await wait_physics_frames(int(ceil(s * 60.0)) + 1)


func _debris() -> Array:
	return monde.get_children().filter(func(n): return n is RigidBody3D)


# ---------------------------------------------------------------- critiques
func test_critique_double_les_degats_et_se_signale() -> void:
	Combat.chance_critique = 1.0
	var e := _ennemi(Vector3(0, 0, 3))
	var recus := []
	var relais := func(_p, d, _l, _h, _c, _s, critique): recus.append([d, critique])
	EventBus.coup_porte.connect(relais)
	Combat.porter_coup(heros, e, 10.0, false)
	EventBus.coup_porte.disconnect(relais)
	assert_eq(e.sante.pv, EQ.squelette_pv_max - 10.0 * EQ.critique_multiplicateur)
	assert_eq(recus, [[10.0 * EQ.critique_multiplicateur, true]], "Le coup est signalé critique")


func test_jamais_de_critique_sur_un_heros() -> void:
	Combat.chance_critique = 1.0
	var e := _ennemi(Vector3(0, 0, 3))
	Combat.porter_coup(e, heros, 10.0, false)
	assert_eq(heros.sante.pv, EQ.heros_pv_max - 10.0, "Les ennemis ne font pas de critiques")


func test_sans_chance_pas_de_critique() -> void:
	Combat.chance_critique = 0.0
	var e := _ennemi(Vector3(0, 0, 3))
	Combat.porter_coup(heros, e, 10.0, false)
	assert_eq(e.sante.pv, EQ.squelette_pv_max - 10.0)


# ---------------------------------------------------------------- squelette qui éclate
func test_le_squelette_vaincu_eclate_en_os() -> void:
	var e := _ennemi(Vector3(0, 0, 3))
	Combat.porter_coup(heros, e, 500.0, true)
	assert_false(e.visuel.visible, "Le squelette disparaît d'un coup…")
	var os := _debris()
	assert_gt(os.size(), 4, "…et éclate en os (%d morceaux)" % os.size())
	await _secondes(0.3)
	var loin := 0
	for o in os:
		if is_instance_valid(o) and Vector2(o.global_position.x, o.global_position.z - 3.0).length() > 0.5:
			loin += 1
	assert_gt(loin, 2, "Les os sont projetés")
	e.set_physics_process(true)   # (immobile dans ce test : il faut qu'il compte son temps de mort)
	await _secondes(EQ.squelette_duree_corps)
	assert_false(is_instance_valid(e), "Le nœud du squelette est retiré")
	await _secondes(EQ.debris_duree)
	assert_eq(_debris().size(), 0, "Les os s'effacent ensuite")


func test_la_marionnette_eclate_aussi() -> void:
	var e := Ennemi.creer(true)
	e.marionnette = true
	monde.add_child(e)
	await wait_physics_frames(2)
	e.appliquer_instantane(Ennemi.Etat.MORT, "Idle_Combat", 1.0, 0.0, false)
	assert_false(e.visuel.visible, "Chez l'invité aussi, le squelette éclate")
	assert_gt(_debris().size(), 4)


# ---------------------------------------------------------------- hordes en groupes
func test_horde_et_renfort_en_groupe() -> void:
	var gen := GenerateurEnnemis.new()
	gen.nombre = 5
	monde.add_child(gen)
	assert_eq(gen.vivants(), 5, "La horde complète sort de terre")
	# en groupes : la plupart ont un voisin tout près (un groupe de 1 reste possible pour le reste)
	var entoures := 0
	for a in gen.get_children():
		for b in gen.get_children():
			if a != b and a.position.distance_to(b.position) <= 2.0 * EQ.arene_rayon_groupe + 0.9:
				entoures += 1
				break
	assert_gte(entoures, 4, "Ils sortent en groupes, pas éparpillés")
	# deux morts à des moments différents (la sortie de terre les protège des coups : on passe par la santé)
	var avant: Array = gen.get_children()
	avant[0].sante.subir(500.0)
	await wait_seconds(EQ.arene_delai_apparition * 0.5)
	avant[1].sante.subir(500.0)
	assert_eq(gen.vivants(), 3)
	await wait_seconds(EQ.arene_delai_apparition * 0.5 + 0.2)
	assert_eq(gen.vivants(), 5, "Les deux manquants ressortent ensemble, au délai de la PREMIÈRE mort")
	var nouveaux := gen.get_children().filter(func(n): return not (n in avant) and not n.is_queued_for_deletion())
	assert_eq(nouveaux.size(), 2)
	if nouveaux.size() == 2:
		assert_lte(nouveaux[0].position.distance_to(nouveaux[1].position), 2.0 * EQ.arene_rayon_groupe + 0.9,
			"Ils ressortent en groupe, au même endroit")
	await wait_seconds(EQ.arene_delai_apparition * 0.5 + 0.2)
	assert_eq(gen.get_children().filter(func(n): return not (n in avant)).size(), 2, "Pas de second renfort pour la seconde mort")


# ---------------------------------------------------------------- héros plus vif
func test_le_joystick_coupe_la_fin_du_coup() -> void:
	var e := _ennemi(Vector3(0, 0, 1.6))
	e.sante.pv_max = 500.0
	e.sante.pv = 500.0
	heros.commandes.demander(&"attaque", heros.horloge)
	var impact: float = EQ.combo_instant_impact[0] / EQ.combo_vitesse_animation
	await _secondes(impact + EQ.combo_annulation)
	assert_lt(e.sante.pv, 500.0, "Le coup a porté")
	assert_eq(heros.etat, Heros.Etat.ATTAQUE, "Le geste continue tant qu'on ne bouge pas")
	var restant: float = heros._duree_action - heros._t
	assert_gt(restant, 0.15, "Il restait du geste à couper (%.2f s)" % restant)
	heros.commandes.deplacement = Vector3(1, 0, 0)
	await wait_physics_frames(1)
	assert_eq(heros.etat, Heros.Etat.LIBRE, "Le joystick coupe la fin du coup")


func test_le_joystick_ne_coupe_pas_le_coup_lourd() -> void:
	# choix de Téo : le 3e coup du combo va toujours au bout de son geste
	var e := _ennemi(Vector3(0, 0, 1.6))
	e.sante.pv_max = 500.0
	e.sante.pv = 500.0
	heros._combo = 1
	heros._fin_dernier_coup = heros.horloge
	heros._commencer_coup(2)
	var impact: float = EQ.combo_instant_impact[2] / EQ.combo_vitesse_animation
	await _secondes(impact + EQ.combo_annulation + 0.05)
	assert_eq(heros.etat, Heros.Etat.ATTAQUE)
	heros.commandes.deplacement = Vector3(1, 0, 0)
	await wait_physics_frames(2)
	assert_eq(heros.etat, Heros.Etat.ATTAQUE, "Le coup lourd n'est pas coupé par le joystick")


func test_traînée_du_sabre() -> void:
	var e := _ennemi(Vector3(0, 0, 1.6))
	e.sante.pv_max = 500.0
	e.sante.pv = 500.0
	var traces := [0]
	monde.child_entered_tree.connect(func(n): if n is MeshInstance3D and n.mesh != null \
			and n.mesh == EffetsMagie._ressources.get("arc_sabre"): traces[0] += 1)
	heros.commandes.demander(&"attaque", heros.horloge)
	await _secondes(EQ.combo_instant_impact[0] / EQ.combo_vitesse_animation + 0.05)
	assert_eq(traces[0], 1, "Une traînée lumineuse par coup")
	await _secondes(0.4)
	var restantes := monde.get_children().filter(func(n): return n is MeshInstance3D)
	assert_eq(restantes.size(), 0, "Elle s'efface aussitôt")
