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


## Le rapport tête / buste dans la pose dessinée (lu quand le modificateur vient d'agir : Godot remet la pose ensuite).
func _rapport_tete(visuel: Node3D) -> float:
	var sk: Skeleton3D = visuel.find_children("*", "Skeleton3D", true, false)[0]
	var mod := sk.get_children().filter(func(c): return c is OsProportions)
	if mod.is_empty():
		return 1.0
	var mesure := {"r": 1.0}
	var lire := func():
		var t := sk.get_bone_global_pose(sk.find_bone("head")).basis.get_scale().x
		var b := sk.get_bone_global_pose(sk.find_bone("chest")).basis.get_scale().x
		mesure["r"] = t / b
	mod[0].modification_processed.connect(lire)
	await wait_process_frames(2)
	mod[0].modification_processed.disconnect(lire)
	return mesure["r"]


func test_cranes_et_tetes_plus_petits() -> void:
	# (06/11, version rapide : moins « jouets »), après l'animation, pour chaque type de squelette et le héros
	for type in [&"matelot", &"arbaletrier", &"pretre", &"bosco"]:
		var e := Ennemi.creer_type(type, true)
		e.position = Vector3(20, 0, 0)
		add_child_autofree(e)
		await wait_process_frames(2)
		assert_almost_eq(await _rapport_tete(e.visuel), Ennemi.ECHELLE_TETE, 0.01, "Crâne plus petit : %s" % type)
	var h := Heros.creer(&"occultiste")
	add_child_autofree(h)
	await wait_process_frames(2)
	assert_almost_eq(await _rapport_tete(h.visuel), Heros.ECHELLE_TETE, 0.01, "Tête du héros")


func test_les_decors_prennent_les_matieres_realistes() -> void:
	# (06/11, étape 3 : textures Poly Haven posées en mètres du monde)
	assert_eq(Matieres.pour("floor_tile_large").get_shader_parameter("grain"), false, "Sol : pavés (pleine)")
	assert_eq(Matieres.pour("wall").get_shader_parameter("grain"), false, "Mur : pierre (pleine)")
	assert_eq(Matieres.pour("barrel_small").get_shader_parameter("grain"), true, "Bois : sur la couleur KayKit")
	assert_eq(Matieres.pour("chest_gold").get_shader_parameter("grain"), true, "Métal : sur la couleur KayKit")
	assert_null(Matieres.pour("bottle_A_green"), "Les fioles gardent leur matière")
	for cle in ["floor_tile_large", "wall", "barrel_small", "chest_gold"]:
		var m: ShaderMaterial = Matieres.pour(cle)
		for p in ["tex_couleur", "tex_relief", "tex_rugosite"]:
			assert_not_null(m.get_shader_parameter(p), "%s : %s chargée" % [cle, p])
	# une porte : mur de pierre, battant de bois
	var porte: Node3D = load("res://assets/models/decor/wall_doorway.glb").instantiate()
	Matieres.habiller(porte, "wall_doorway")
	for mi in porte.find_children("*", "MeshInstance3D", true, false):
		var attendu := Matieres.pour("chair") if String(mi.name).contains("_door") else Matieres.pour("wall")
		assert_eq(mi.material_override, attendu, String(mi.name))
	porte.free()


func test_une_salle_est_habillee() -> void:
	Partie.destination = &"arene"
	var a: Arene = load("res://game/arene/arene.tscn").instantiate()
	a.changer_de_scene = false
	add_child_autofree(a)
	await wait_physics_frames(2)
	var poses := 0
	for mi in a.find_children("*", "MeshInstance3D", true, false):
		if mi.material_override is ShaderMaterial and mi.material_override.shader == Matieres.SHADER:
			poses += 1
	assert_gt(poses, 20, "Sols, murs, bois et métal de l'arène")
