extends GutTest
## Jauge façon Diablo (06/11, choix de Téo) : l'attaque la remplit (et la parade parfaite, beaucoup), la Fente et
## les Chaînes la dépensent (avec une courte recharge), elle baisse doucement hors combat ; un globe dans le HUD.

const EQ: Equilibrage = preload("res://data/equilibrage.tres")

var monde: Node3D


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


func _heros(archetype: StringName) -> Heros:
	var h := Heros.creer(archetype)
	monde.add_child(h)
	await wait_physics_frames(3)
	return h


func _squelette(pos: Vector3) -> Ennemi:
	var e := Ennemi.creer(true)
	e.position = pos
	monde.add_child(e)
	e.set_physics_process(false)
	e.sante.pv_max = 500.0
	e.sante.pv = 500.0
	return e


## La jauge à `v`, comme en combat (une jauge posée à la main hors combat baisserait aussitôt).
func _remplir(h: Heros, v: float) -> void:
	h.jauge = 0.0
	h.gagner_jauge(v)


func _secondes(s: float) -> void:
	await wait_physics_frames(int(ceil(s * 60.0)) + 1)


# ---------------------------------------------------------------- se remplir
func test_l_attaque_remplit_la_fureur() -> void:
	var h := await _heros(&"bretteur")
	assert_eq(h.jauge, 0.0, "Vide au départ")
	assert_eq(h.nom_jauge(), "Fureur")
	_squelette(Vector3(0, 0, 1.6))
	h.commandes.demander(&"attaque", h.horloge)
	await _secondes(0.5)
	assert_almost_eq(h.jauge, EQ.jauge_gain_coup, 0.01, "Un squelette touché : un peu de Fureur")


func test_un_geste_dans_la_horde_est_plafonne() -> void:
	var h := await _heros(&"bretteur")
	for x in [-0.6, 0.0, 0.6]:
		_squelette(Vector3(x, 0, 1.4))
	h.commandes.demander(&"attaque", h.horloge)
	await _secondes(0.5)
	assert_almost_eq(h.jauge, minf(3 * EQ.jauge_gain_coup, EQ.jauge_gain_geste_max), 0.01, "Trois touchés, mais plafonné")
	assert_lt(h.jauge, 3 * EQ.jauge_gain_coup)


func test_le_tir_de_l_occultiste_remplit_les_ames() -> void:
	var h := await _heros(&"occultiste")
	assert_eq(h.nom_jauge(), "Âmes")
	_squelette(Vector3(0, 0, 3.0))
	h.commandes.demander(&"attaque", h.horloge)
	await _secondes(0.7)
	assert_almost_eq(h.jauge, EQ.jauge_gain_coup, 0.01, "Le tir qui touche")


func test_l_explosion_du_tir_remplit_aussi_les_ames() -> void:
	# (choix de Téo du 07/11 : chaque voisin pris dans l'explosion compte, avec le plafond du geste)
	var h := await _heros(&"occultiste")
	var cible := _squelette(Vector3(0, 0, 4.0))
	var voisin := _squelette(Vector3(0.9, 0, 4.4))
	Projectile.tirer(monde, h, Vector3(0, 1.25, 0.6), Vector3(0, 0, 1), EQ)
	await _secondes(0.6)
	assert_lt(cible.sante.pv, 500.0, "La cible est touchée")
	assert_lt(voisin.sante.pv, 500.0, "Son voisin aussi, par l'explosion")
	assert_almost_eq(h.jauge, 2 * EQ.jauge_gain_coup, 0.01, "Deux squelettes touchés : deux parts d'Âmes")
	# de l'autre côté, une cible au milieu de trois voisins : le geste est plafonné
	var groupe := [_squelette(Vector3(0, 0, -4.0))]
	for p in [Vector3(0.9, 0, -4.4), Vector3(-0.9, 0, -4.4), Vector3(0.0, 0, -4.9)]:
		groupe.append(_squelette(p))
	var avant := h.jauge
	Projectile.tirer(monde, h, Vector3(0, 1.25, -0.6), Vector3(0, 0, -1), EQ)
	await _secondes(0.6)
	for e in groupe:
		assert_lt(e.sante.pv, 500.0, "Pris dans l'explosion : %s" % e.position)
	assert_almost_eq(h.jauge - avant, minf(4 * EQ.jauge_gain_coup, EQ.jauge_gain_geste_max), 0.01, "Plafonné")
	assert_lt(h.jauge - avant, 4 * EQ.jauge_gain_coup)


func test_la_parade_parfaite_remplit_beaucoup() -> void:
	var h := await _heros(&"bretteur")
	var e := _squelette(Vector3(0, 0, 1.5))
	h.commandes.demander(&"competence_1", h.horloge)
	await wait_physics_frames(2)
	h.sante.invulnerable_jusqua = 0.0
	Combat.porter_coup(e, h, 10.0, false)   # le coup arrive juste après l'appui : parfaite
	assert_almost_eq(h.jauge, EQ.jauge_gain_parade_parfaite, 0.01)
	await _secondes(0.6)   # la riposte touche aussi
	assert_almost_eq(h.jauge, EQ.jauge_gain_parade_parfaite + EQ.jauge_gain_coup, 0.01, "Et la riposte qui touche")


# ---------------------------------------------------------------- se dépenser
func test_pas_de_fente_sans_fureur() -> void:
	var h := await _heros(&"bretteur")
	_remplir(h, EQ.fente_cout - 1.0)
	h.commandes.demander(&"competence_2", h.horloge)
	await wait_physics_frames(3)
	assert_ne(h.etat, Heros.Etat.FENTE, "Pas assez de Fureur : pas de Fente")
	assert_true(h.recharge_competence_2.prete(), "Rien n'est dépensé")
	assert_eq(h.jauge, EQ.fente_cout - 1.0)
	_remplir(h, EQ.fente_cout + 10.0)
	h.commandes.demander(&"competence_2", h.horloge)
	await wait_physics_frames(3)
	assert_eq(h.etat, Heros.Etat.FENTE, "Assez : elle part")
	assert_almost_eq(h.jauge, 10.0, 0.01, "Elle a coûté son prix")
	assert_false(h.recharge_competence_2.prete(), "Une courte recharge…")
	assert_lt(h.recharge_competence_2.duree, 1.5, "… d'environ une seconde")


func test_chaines_coupees_rendent_les_ames() -> void:
	var h := await _heros(&"occultiste")
	var e := _squelette(Vector3(0, 0, 3))
	_remplir(h, EQ.occ_chaines_cout)
	h.commandes.demander(&"competence_2", h.horloge)
	await wait_physics_frames(2)
	assert_eq(h.etat, Heros.Etat.INCANTATION)
	assert_almost_eq(h.jauge, 0.0, 0.01, "Dépensées au lancer")
	Combat.porter_coup(e, h, 15.0, false)   # coupé avant que les chaînes partent
	assert_almost_eq(h.jauge, EQ.occ_chaines_cout, 0.01, "Le sort coupé rend ses Âmes")


# ---------------------------------------------------------------- baisser, se vider
func test_elle_baisse_doucement_hors_combat() -> void:
	var h := await _heros(&"bretteur")
	h.gagner_jauge(50.0)
	await _secondes(EQ.jauge_baisse_apres - 1.0)
	assert_almost_eq(h.jauge, 50.0, 0.01, "Pas tout de suite")
	await _secondes(2.0)
	assert_lt(h.jauge, 50.0, "Puis elle baisse")
	assert_gt(h.jauge, 50.0 - 3.0 * EQ.jauge_baisse, "Doucement")


func test_a_terre_un_tir_en_vol_ne_la_remplit_pas() -> void:
	# (relecture du jalon 6 : l'Occultiste tombe pendant que son tir vole ; le tir touche, sa jauge restait à 9)
	var h := await _heros(&"occultiste")
	_squelette(Vector3(0, 0, 8.0))
	h.commandes.demander(&"attaque", h.horloge)
	var n := 0
	while not h._effet_fait and n < 120:
		await wait_physics_frames(1)
		n += 1
	assert_true(h._effet_fait, "Le tir est parti")
	h.sante.invulnerable_jusqua = 0.0
	h.recevoir_coup(9999.0, null, true)
	await _secondes(1.0)
	assert_eq(h.jauge, 0.0, "À terre, elle reste vide")


func test_a_terre_elle_se_vide() -> void:
	var h := await _heros(&"bretteur")
	h.gagner_jauge(60.0)
	h.sante.invulnerable_jusqua = 0.0
	h.recevoir_coup(9999.0, null, true)
	assert_eq(h.etat, Heros.Etat.MORT)
	assert_eq(h.jauge, 0.0)


# ---------------------------------------------------------------- coop
func test_coop_la_jauge_voyage_dans_l_instantane() -> void:
	var h := await _heros(&"bretteur")
	h.gagner_jauge(42.0)
	var inst := h.instantane()
	assert_almost_eq(float(inst[9]), 42.0, 0.05, "L'hôte l'envoie")
	var m := Heros.creer(&"bretteur")
	m.marionnette = true
	m.position = Vector3(5, 0, 0)
	monde.add_child(m)
	await wait_physics_frames(2)
	m.appliquer_instantane(inst[2], inst[3], inst[4], inst[5], inst[6], inst[7], inst[8], inst[9])
	assert_almost_eq(m.jauge, 42.0, 0.05, "Le héros de l'autre l'affiche")
	m.gagner_jauge(30.0)
	assert_almost_eq(m.jauge, 42.0, 0.05, "Une marionnette ne décide de rien")
	# l'invité : sa propre dépense compte tout de suite ; l'hôte, qui ne la connaît pas encore, ne la défait pas
	h._jauge_predite_jusqua = h.horloge + 0.4
	h.jauge = 7.0
	h.definir_jauge(42.0)
	assert_eq(h.jauge, 7.0, "Juste après une dépense : la valeur d'ici")
	h._jauge_predite_jusqua = -1.0
	h.definir_jauge(30.0)
	assert_eq(h.jauge, 30.0, "Ensuite : celle de l'hôte")


# ---------------------------------------------------------------- à l'écran
func test_le_globe_et_le_bouton_de_la_fente() -> void:
	Partie.destination = &"arene"
	Partie.heros_local = &"bretteur"
	var a: Arene = load("res://game/arene/arene.tscn").instantiate()
	a.changer_de_scene = false
	add_child_autofree(a)
	await wait_physics_frames(3)
	var hud: HudCombat = a.hud
	assert_not_null(hud.globe, "Un globe dans le HUD")
	assert_eq(hud.globe.mouse_filter, Control.MOUSE_FILTER_IGNORE, "Il ne prend aucun toucher")
	_remplir(a.heros, EQ.fente_cout * 0.5)
	await wait_process_frames(2)
	assert_almost_eq(hud.bouton_competence_2.jauge_part, 0.5, 0.01, "Le bouton montre la part du prix")
	assert_almost_eq(hud.globe.niveau(), EQ.fente_cout * 0.5 / EQ.jauge_max, 0.01)
	_remplir(a.heros, EQ.fente_cout)
	await wait_process_frames(2)
	assert_gte(hud.bouton_competence_2.jauge_part, 1.0, "Assez : le bouton s'allume")
	assert_lt(hud.bouton_esquive.jauge_part, 0.0, "La roulade ne coûte rien")
	# il ne recouvre aucun bouton
	var c := hud.globe.get_global_rect().get_center()
	for b in [hud.bouton_attaque, hud.bouton_esquive, hud.bouton_competence_1, hud.bouton_competence_2]:
		assert_gt(c.distance_to(b.centre_ecran()), b.rayon + hud.globe.rayon, "Pas sur %s" % b.texte)
