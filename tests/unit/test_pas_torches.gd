extends GutTest
## Pas et torches (10/11, choix de Téo) : un pas sonne quand l'animation de course pose un pied (pierre ou bois selon
## le lieu), les squelettes aussi (plus discrets) ; chaque torche a une flamme qui danse.

var monde: Node3D


class LieuBois:
	extends Node3D
	func sol_a(_pos: Vector3) -> String:
		return "bois"


func before_each() -> void:
	Engine.time_scale = 1.0
	Sons.garder_journal = true
	Sons.journal.clear()
	monde = Node3D.new()
	add_child_autofree(monde)
	var sol := StaticBody3D.new()
	sol.collision_layer = Combat.COUCHE_MONDE
	var forme := CollisionShape3D.new()
	var boite := BoxShape3D.new()
	boite.size = Vector3(80, 0.2, 80)
	forme.shape = boite
	sol.add_child(forme)
	sol.position.y = -0.1
	monde.add_child(sol)


func after_each() -> void:
	Sons.garder_journal = false
	Sons.journal.clear()


func _sons(prefixe: String) -> Array:
	return Sons.journal.filter(func(j): return String(j[0]).begins_with(prefixe))


func _courir(h: Heros, images: int) -> void:
	h.commandes.deplacement = Vector3(1, 0, 0)
	await wait_physics_frames(images)
	h.commandes.deplacement = Vector3.ZERO


# ---------------------------------------------------------------- l'instant du pas
func test_un_pied_qui_passe_par_le_sol() -> void:
	assert_true(PasSonores.franchi(0.05, 0.12, 0.10), "Entre deux images")
	assert_false(PasSonores.franchi(0.10, 0.20, 0.10), "Déjà compté à l'image d'avant")
	assert_false(PasSonores.franchi(0.20, 0.50, 0.10), "Pas encore revenu")
	assert_true(PasSonores.franchi(0.95, 0.04, 0.98), "Juste avant que la boucle reparte")
	assert_true(PasSonores.franchi(0.95, 0.04, 0.02), "Juste après")
	assert_false(PasSonores.franchi(0.95, 0.04, 0.5))


# ---------------------------------------------------------------- héros
func test_le_heros_qui_court_fait_des_pas() -> void:
	var h := Heros.creer(&"bretteur")
	monde.add_child(h)
	await wait_physics_frames(30)
	assert_eq(_sons("pas").size(), 0, "Immobile : aucun pas")
	await _courir(h, 120)   # 2 s de course : la boucle (0,79 s) va 1,2 fois plus vite, deux pas par boucle
	var pas := _sons("pas_pierre")
	assert_between(pas.size(), 4, 8, "Deux pas par boucle de course (%d)" % pas.size())
	assert_eq(_sons("pas_os").size(), 0)
	Sons.journal.clear()
	await wait_physics_frames(40)
	assert_eq(_sons("pas").size(), 0, "Arrêté : plus de pas")


func test_sur_le_bois() -> void:
	var lieu := LieuBois.new()
	monde.add_child(lieu)
	var h := Heros.creer(&"occultiste")
	lieu.add_child(h)
	await wait_physics_frames(3)
	await _courir(h, 90)
	assert_gt(_sons("pas_bois").size(), 0, "Sur un lieu en bois : des pas sur le bois")
	assert_eq(_sons("pas_pierre").size(), 0)


func test_une_marionnette_fait_ses_pas_aussi() -> void:
	# (coop : l'invité entend les pas du héros de l'hôte, sans rien recevoir de plus par le réseau)
	var m := Heros.creer(&"bretteur")
	m.marionnette = true
	monde.add_child(m)
	await wait_physics_frames(3)
	m._jouer("Running_A", 1.0)
	await wait_physics_frames(60)
	assert_gt(_sons("pas_pierre").size(), 0)


# ---------------------------------------------------------------- squelettes
func test_les_squelettes_font_des_pas_d_os() -> void:
	var h := Heros.creer(&"bretteur")
	h.position = Vector3(12, 0, 0)
	monde.add_child(h)
	var e := Ennemi.creer(true)
	e.position = Vector3(0, 0, 0)
	monde.add_child(e)
	await wait_physics_frames(150)   # (il sort de terre, puis court vers le héros)
	assert_gt(_sons("pas_os_pierre").size(), 0, "Il court : des pas d'os")
	assert_eq(e.get_node("Pas").hauteur, e._hauteur_pas())
	assert_gt(e._hauteur_pas(), 1.0, "Plus aigus que ceux des héros")


func test_le_bosco_a_le_pas_lourd() -> void:
	var b = Ennemi.creer_type(&"bosco")
	b.position = Vector3(0, 0, 0)
	monde.add_child(b)
	await wait_physics_frames(2)
	assert_lt(b.get_node("Pas").hauteur, 1.0, "Plus grave")


# ---------------------------------------------------------------- les sols des lieux
func test_le_quai_du_repaire_est_en_bois() -> void:
	var r: Node = load("res://game/repaire/repaire.gd").new()
	assert_eq(r.sol_a(Vector3(-5.0, 0, 0)), "bois", "Le quai")
	assert_eq(r.sol_a(Vector3(0.0, 0, 0)), "pierre", "La grotte")
	r.free()


func test_le_quai_de_la_chaloupe() -> void:
	var s := Salle.creer("quai", [])
	monde.add_child(s)
	await wait_process_frames(2)
	assert_eq(s.sol_a(Vector3(-4.8, 0, 0.6)), "bois", "Dans la chaloupe")
	assert_eq(s.sol_a(Vector3(-1.6, 0, 0.0)), "bois", "Sur les planches du quai")
	assert_eq(s.sol_a(Vector3(3.0, 0, 0.0)), "pierre", "Sur les dalles")


func test_l_arene_est_en_pierre() -> void:
	assert_eq(Arene.new().sol_a(Vector3.ZERO), "pierre")


# ---------------------------------------------------------------- torches
func test_chaque_torche_a_sa_flamme() -> void:
	var l := Ambiance.torche(Vector3(0, 2.35, 0), false)
	monde.add_child(l)
	var f: CPUParticles3D = l.get_node("Flamme")
	assert_not_null(f)
	assert_true(f.emitting)
	assert_lt(f.position.y, 0.0, "Elle part du fond du panier")
	var mat: StandardMaterial3D = f.mesh.material
	assert_true(mat.billboard_keep_scale, "Sans cela, chaque tache de feu ferait 60 cm")
	assert_lte(f.scale_amount_max, 0.25)
	assert_eq(mat.blend_mode, BaseMaterial3D.BLEND_MODE_MIX, "En additif, les taches s'empilaient en boule blanche")


func test_les_torches_des_lieux_ont_leur_flamme() -> void:
	Partie.heros_local = &"bretteur"
	var a: Arene = load("res://game/arene/arene.tscn").instantiate()
	a.changer_de_scene = false
	add_child_autofree(a)
	await wait_physics_frames(2)
	assert_gt(a.torches.size(), 0)
	for t in a.torches:
		assert_not_null(t.get_node_or_null("Flamme"))
