extends GutTest
## Lumière façon Diablo IV (06/11, choix de Téo sur planche d'essai) : la lumière qui suit chaque héros, l'ambiance
## commune (arène, salles, repaire) et les annonces qui restent vives malgré l'étalonnage terne.


func test_chaque_heros_a_sa_lumiere_qui_le_suit_sans_tourner() -> void:
	var h := Heros.creer(&"bretteur")
	add_child_autofree(h)
	# (sans sol, le héros tomberait ; sa chute pouvait avoir lieu entre le suivi de la lumière et la mesure : le test
	#  échouait au hasard sur GitHub — APK 0.5.28 et 0.5.30. Le héros reste donc immobile.)
	h.set_physics_process(false)
	await wait_process_frames(2)
	var halos := h.get_children().filter(func(c): return c is HaloHeros)
	assert_eq(halos.size(), 1, "Une lumière par héros")
	var halo: HaloHeros = halos[0]
	assert_false(halo.shadow_enabled, "Sans ombre (peu coûteuse)")
	h.global_position = Vector3(3.0, 0.0, -2.0)
	h.rotation.y = 1.3
	await wait_process_frames(2)
	var p := h.global_position
	assert_eq(p, Vector3(3.0, 0.0, -2.0), "Le héros n'a pas bougé")
	assert_almost_eq(halo.global_position.y, p.y + HaloHeros.HAUTEUR, 0.01, "Au-dessus du héros")
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


## Hauteur du crâne / hauteur du corps, dans la pose de repos du modèle (KayKit : 0,39 ; refaits : 0,24).
func _rapport_crane(visuel: Node) -> float:
	var haut := 0.0
	var tete := 0.0
	for mi in visuel.find_children("*", "MeshInstance3D", true, false):
		var a: AABB = mi.mesh.get_aabb()
		var e: float = mi.transform.basis.get_scale().x
		if String(mi.name).ends_with("_Head") or String(mi.name).ends_with("_Skull"):
			tete = a.size.y * e
		haut = maxf(haut, (a.position.y + a.size.y) * e)
	return tete / maxf(haut, 0.001)


func test_squelettes_et_heros_refaits() -> void:
	# (06/11, étape 4 : refaits dans Blender, « variante 3 + usure » ; plus aucune retouche d'os en jeu)
	var mat: StandardMaterial3D = load("res://assets/materials/kaykit_squelette.tres")
	assert_true(mat.vertex_color_use_as_albedo, "La matière des squelettes prend les ombres des creux")
	for type in [&"matelot", &"arbaletrier", &"pretre", &"bosco"]:
		var e := Ennemi.creer_type(type, true)
		e.position = Vector3(20, 0, 0)
		add_child_autofree(e)
		await wait_process_frames(2)
		assert_lt(_rapport_crane(e.visuel), 0.3, "Crâne plus petit : %s" % type)
		var sk: Skeleton3D = e.visuel.find_children("*", "Skeleton3D", true, false)[0]
		assert_eq(sk.get_children().filter(func(c): return c is SkeletonModifier3D).size(), 0, "Pas de retouche en jeu")
		assert_true(e.anim.has_animation("Spawn_Ground_Skeletons") and e.anim.has_animation("Idle"), "Animations gardées")
		var colores := 0
		for mi in e.visuel.find_children("*", "MeshInstance3D", true, false):
			var c = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
			if c != null and c.size() > 0:
				colores += 1
		assert_gt(colores, 6, "Ombres des creux dans les sommets : %s" % type)
	# les héros : ombres des creux prises par toutes leurs pièces
	for arch in [&"bretteur", &"occultiste"]:
		var h := Heros.creer(arch)
		add_child_autofree(h)
		await wait_process_frames(2)
		var skh: Skeleton3D = h.visuel.find_children("*", "Skeleton3D", true, false)[0]
		assert_eq(skh.get_children().filter(func(c): return c is SkeletonModifier3D).size(), 0, "Pas de retouche en jeu")
		var pieces := 0
		for mi in h.visuel.find_children("*", "MeshInstance3D", true, false):
			for k in mi.mesh.get_surface_count():
				var m := mi.mesh.surface_get_material(k) as BaseMaterial3D
				if m:
					pieces += 1
					assert_true(m.vertex_color_use_as_albedo, "%s : %s" % [arch, mi.name])
		assert_gt(pieces, 8)


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


func test_brume_au_ras_du_sol_et_poussiere() -> void:
	# (06/11, choix de Téo avec les sons)
	Partie.destination = &"arene"
	var a: Arene = load("res://game/arene/arene.tscn").instantiate()
	a.changer_de_scene = false
	add_child_autofree(a)
	await wait_physics_frames(3)
	var brumes := a.find_children("Brume", "Node3D", true, false)
	assert_eq(brumes.size(), 1, "Une brume dans la salle")
	var nappes := brumes[0].find_children("*", "MeshInstance3D", true, false)
	assert_eq(nappes.size(), 2, "Deux nappes l'une au-dessus de l'autre")
	for n in nappes:
		assert_lt(n.position.y, 0.8, "Au ras du sol")
		assert_eq(n.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		assert_lt(n.material_override.render_priority, 0, "Dessinée avant les annonces au sol : elle ne cache aucun danger")
	for t in a.torches:
		assert_eq(t.find_children("*", "CPUParticles3D", true, false).size(), 1, "De la poussière dans la lumière de chaque torche")
	var halo: HaloHeros = a.heros.get_children().filter(func(c): return c is HaloHeros)[0]
	var p: CPUParticles3D = halo.find_children("*", "CPUParticles3D", true, false)[0]
	assert_false(p.local_coords, "Celle du héros reste où elle flotte quand il bouge")
	# qualité Économie : sans brume, moins de poussière ; et retour
	var avant := Reglages.qualite
	var chemin := Reglages.chemin
	Reglages.chemin = "user://reglages_test_brume.json"
	Reglages.choisir_qualite(Reglages.Qualite.ECONOMIE)
	assert_false(brumes[0].visible, "Économie : sans brume")
	assert_lt(p.amount, int(p.get_meta(&"nombre_voulu")), "Économie : moins de poussière")
	Reglages.choisir_qualite(Reglages.Qualite.NORMALE)
	assert_true(brumes[0].visible)
	assert_eq(p.amount, int(p.get_meta(&"nombre_voulu")))
	Reglages.choisir_qualite(avant)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Reglages.chemin))
	Reglages.chemin = chemin
