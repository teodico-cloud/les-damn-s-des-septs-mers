extends GutTest
## Héros Meshy (07/11, essai de Téo) : les héros qu'il a faits sur Meshy, posés sur l'ossature et les animations des
## héros KayKit, à la place de ceux-ci quand le Mode test le demande (`Partie.debug_heros_meshy`).

const KAYKIT := {
	&"bretteur": "res://assets/models/heroes/Bretteur.glb",
	&"occultiste": "res://assets/models/heroes/Occultiste.glb",
}

var monde: Node3D


func before_each() -> void:
	Partie.debug_heros_meshy = false
	monde = Node3D.new()
	add_child_autofree(monde)


func after_each() -> void:
	Partie.debug_heros_meshy = false


func _instance(chemin: String) -> Node3D:
	var n: Node3D = load(chemin).instantiate()
	add_child_autofree(n)
	return n


func _triangles(modele: Node) -> int:
	var t := 0
	for mi in modele.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			t += mi.mesh.surface_get_array_index_len(s) / 3
	return t


# ---------------------------------------------------------------- les modèles
func test_memes_animations_dans_le_meme_ordre() -> void:
	# en coop, une animation voyage par son numéro dans la liste du modèle : un téléphone avec les héros Meshy et
	# l'autre sans doivent avoir la même liste, dans le même ordre
	for cle in KAYKIT:
		var a: AnimationPlayer = _instance(KAYKIT[cle]).find_child("AnimationPlayer", true, false)
		var b: AnimationPlayer = _instance(Heros.MODELES_MESHY[cle]).find_child("AnimationPlayer", true, false)
		assert_not_null(b, "%s Meshy : des animations" % cle)
		assert_eq(b.get_animation_list().size(), 76, "%s Meshy : les 76 animations" % cle)
		assert_eq(b.get_animation_list(), a.get_animation_list(), "%s : même liste, même ordre" % cle)


func test_arme_et_lanterne_aux_memes_attaches() -> void:
	for cle in KAYKIT:
		var m := _instance(Heros.MODELES_MESHY[cle])
		var main := m.find_child("handslot_r", true, false)
		assert_not_null(main, "%s : l'attache de l'arme" % cle)
		assert_gt(main.find_children("*", "MeshInstance3D", true, false).size(), 0, "%s : l'arme de départ en main" % cle)
		var squelette: Skeleton3D = m.find_child("Skeleton3D", true, false)
		assert_gte(squelette.find_bone("handslot.r"), 0, "%s : l'os de la main (le tir de l'Occultiste en part)" % cle)
	var occ := _instance(Heros.MODELES_MESHY[&"occultiste"])
	var gauche := occ.find_child("handslot_l", true, false)
	assert_not_null(gauche, "La lanterne de l'Occultiste")
	assert_gt(gauche.find_children("*", "MeshInstance3D", true, false).size(), 0)


func test_le_baton_et_la_lanterne_meshy_luisent() -> void:
	# (10/11 : faits par Téo sur Meshy ; leurs parties vertes luisent, comme le bâton et la lanterne KayKit)
	var occ := _instance(Heros.MODELES_MESHY[&"occultiste"])
	for nom in ["Occultiste_Baton", "Occultiste_Lanterne"]:
		var mi: MeshInstance3D = occ.find_child(nom, true, false)
		assert_not_null(mi, nom)
		assert_gt(mi.mesh.get_faces().size() / 3, 1000, "%s : celui de Meshy (KayKit : moins de 300 triangles)" % nom)
		var mat: StandardMaterial3D = mi.mesh.surface_get_material(0)
		assert_true(mat.emission_enabled, "%s : sa lueur" % nom)
		assert_not_null(mat.emission_texture, "%s : seulement là où l'image est verte" % nom)


func test_assez_legers_pour_un_telephone() -> void:
	for cle in KAYKIT:
		var t := _triangles(_instance(Heros.MODELES_MESHY[cle]))
		assert_lt(t, 32000, "%s Meshy : %d triangles (le maillage allégé, pas l'original)" % [cle, t])


# ---------------------------------------------------------------- l'interrupteur
func test_sans_le_mode_test_les_heros_kaykit() -> void:
	for cle in KAYKIT:
		assert_eq(Heros.modele_meshy(cle), "")
		var h := Heros.creer(cle)
		monde.add_child(h)
		assert_eq(h.visuel.scene_file_path, KAYKIT[cle], "%s : le modèle habituel" % cle)


func test_avec_le_mode_test_les_heros_meshy() -> void:
	Partie.debug_heros_meshy = true
	for cle in KAYKIT:
		var h := Heros.creer(cle)
		h.position = Vector3(3.0 * KAYKIT.keys().find(cle), 0, 0)
		monde.add_child(h)
		assert_eq(h.visuel.scene_file_path, Heros.MODELES_MESHY[cle], "%s : le modèle Meshy" % cle)
		assert_eq(h.anim.current_animation, "Idle", "%s : il joue ses animations" % cle)
		assert_true(h.anim.get_animation("Idle").loop_mode == Animation.LOOP_LINEAR, "%s : le repos boucle" % cle)
	await wait_physics_frames(2)


func test_le_bretteur_meshy_frappe() -> void:
	Combat.chance_critique = 0.0
	Partie.debug_heros_meshy = true
	var sol := StaticBody3D.new()
	sol.collision_layer = Combat.COUCHE_MONDE
	var forme := CollisionShape3D.new()
	var boite := BoxShape3D.new()
	boite.size = Vector3(20, 0.2, 20)
	forme.shape = boite
	sol.add_child(forme)
	sol.position.y = -0.1
	monde.add_child(sol)
	var h := Heros.creer(&"bretteur")
	monde.add_child(h)
	var e := Ennemi.creer(true)
	e.position = Vector3(0, 0, 1.6)
	monde.add_child(e)
	e.set_physics_process(false)
	await wait_physics_frames(3)
	var pv := e.sante.pv
	h.commandes.demander(&"attaque", h.horloge)
	await wait_physics_frames(40)
	assert_lt(e.sante.pv, pv, "Même ossature, mêmes gestes : le coup porte")
	Combat.chance_critique = -1.0


func test_le_bouton_du_mode_test() -> void:
	var ecran = load("res://ui/screens/demarrage.tscn").instantiate()
	ecran.changer_de_scene = false
	add_child_autofree(ecran)
	await wait_process_frames(2)
	assert_eq(ecran.bouton_meshy.text, "Héros Meshy : non")
	assert_eq(ecran.label_test.text, "")
	ecran.bouton_meshy.pressed.emit()
	assert_true(Partie.debug_heros_meshy)
	assert_true(Reglages.heros_meshy, "Gardé pour le prochain lancement (choix de Téo du 10/11)")
	assert_eq(ecran.bouton_meshy.text, "Héros Meshy : oui")
	assert_eq(ecran.label_test.text, "Mode test actif")
	ecran.bouton_meshy.pressed.emit()
	assert_false(Partie.debug_heros_meshy)


func test_le_choix_du_heros_les_montre_aussi() -> void:
	Partie.debug_heros_meshy = true
	var ecran = load("res://ui/screens/choix_heros.tscn").instantiate()
	ecran.changer_de_scene = false
	add_child_autofree(ecran)
	await wait_process_frames(2)
	var chemins: Array = ecran.get_children().map(func(n): return n.scene_file_path)
	for cle in KAYKIT:
		assert_has(chemins, Heros.MODELES_MESHY[cle], "%s Meshy sur l'écran du choix" % cle)
		assert_does_not_have(chemins, KAYKIT[cle])
