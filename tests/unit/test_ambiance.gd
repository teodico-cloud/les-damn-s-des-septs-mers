extends GutTest
## Lumière façon Diablo IV (06/11, choix de Téo sur planche d'essai) : la lumière qui suit chaque héros, l'ambiance
## commune (arène, salles, repaire) et les annonces qui restent vives malgré l'étalonnage terne.


func test_chaque_heros_a_sa_lumiere_qui_le_suit_sans_tourner() -> void:
	var h := Heros.creer(&"bretteur")
	add_child_autofree(h)
	await wait_process_frames(2)
	var halos := h.get_children().filter(func(c): return c is HaloHeros)
	assert_eq(halos.size(), 1, "Une lumière par héros")
	var halo: HaloHeros = halos[0]
	assert_false(halo.shadow_enabled, "Sans ombre (peu coûteuse)")
	h.global_position = Vector3(3.0, 0.0, -2.0)
	h.rotation.y = 1.3
	await wait_process_frames(2)
	var p := h.global_position   # (sans sol, le héros tombe : on mesure depuis sa vraie place)
	assert_almost_eq(halo.global_position.y, p.y + HaloHeros.HAUTEUR, 0.05, "Au-dessus du héros")
	var a_plat := Vector2(halo.global_position.x - p.x, halo.global_position.z - p.z)
	assert_lt(a_plat.length(), HaloHeros.VERS_CAMERA + 0.01, "Elle l'a suivi")
	assert_almost_eq(halo.global_rotation.y, 0.0, 0.001, "Elle ne tourne pas avec lui")


func test_l_arene_prend_l_ambiance_commune() -> void:
	Partie.destination = &"arene"
	var a: Arene = load("res://game/arene/arene.tscn").instantiate()
	a.changer_de_scene = false
	add_child_autofree(a)
	await wait_physics_frames(3)
	var we: WorldEnvironment = a.find_children("*", "WorldEnvironment", true, false)[0]
	assert_eq(we.environment.tonemap_mode, Environment.TONE_MAPPER_AGX)
	assert_true(we.environment.adjustment_enabled, "Couleurs ternes (étalonnage)")
	assert_lt(we.environment.adjustment_saturation, 1.0)
	assert_gt(a.torches.size(), 0)
	for t in a.torches:
		assert_eq(t.light_color, Ambiance.TORCHE, "Torches orangées")
		assert_gt(t.omni_attenuation, 1.0, "Des taches de lumière")
	assert_eq(a.heros.get_children().filter(func(c): return c is HaloHeros).size(), 1)


func test_les_annonces_restent_vives() -> void:
	# l'étalonnage terne (saturation 0,6) éteignait le rouge des zones : il est « au-delà du blanc »
	assert_gt(Ennemi.COULEUR_ZONE.r, 1.0)
	assert_gt(Ennemi.COULEUR_ZONE_DOREE.g, 1.0)
	assert_gt(Ennemi.COULEUR_MARQUE_DOREE.g, 0.75, "Doré (la parade le reconnaît)")
