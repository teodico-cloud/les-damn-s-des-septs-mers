extends GutTest
## Jalon 6 (refonte de l'interface, choix de Téo) : l'écran Réglages avec la qualité graphique (économie, normale,
## belle), gardée dans un fichier à part de la sauvegarde ; appliquée à chaud aux lumières et à l'image.

const CHEMIN_TEST := "user://reglages_test.json"

var _chemin_avant := ""
var _qualite_avant := 1


func before_all() -> void:
	_chemin_avant = Reglages.chemin
	_qualite_avant = Reglages.qualite
	Reglages.chemin = CHEMIN_TEST


func before_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CHEMIN_TEST))
	Reglages.qualite = Reglages.Qualite.NORMALE
	Reglages.appliquer()


func after_all() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CHEMIN_TEST))
	Reglages.chemin = _chemin_avant
	Reglages.qualite = _qualite_avant
	Reglages.appliquer()
	Partie.destination = &"arene"


func _ecrire(texte: String) -> void:
	var f := FileAccess.open(CHEMIN_TEST, FileAccess.WRITE)
	f.store_string(texte)
	f.close()


# ---------------------------------------------------------------- le fichier
func test_le_choix_est_garde_a_part_de_la_sauvegarde() -> void:
	Reglages.choisir_qualite(Reglages.Qualite.ECONOMIE)
	assert_true(FileAccess.file_exists(CHEMIN_TEST), "Écrit tout de suite")
	assert_string_contains(FileAccess.get_file_as_string(CHEMIN_TEST), "economie")
	Reglages.qualite = Reglages.Qualite.NORMALE
	Reglages.charger()
	assert_eq(Reglages.qualite, Reglages.Qualite.ECONOMIE, "Relu au prochain lancement")
	assert_ne(_chemin_avant, Sauvegarde.chemin, "Un fichier à part de la sauvegarde")
	Reglages.choisir_qualite(Reglages.Qualite.BELLE)
	Reglages.charger()
	assert_eq(Reglages.qualite, Reglages.Qualite.BELLE)


func test_sans_fichier_ou_fichier_abime_reglages_de_depart() -> void:
	Reglages.qualite = Reglages.Qualite.BELLE
	Reglages.charger()
	assert_eq(Reglages.qualite, Reglages.Qualite.NORMALE, "Sans fichier : Normale")
	_ecrire("{{{ abîmé")
	Reglages.qualite = Reglages.Qualite.BELLE
	Reglages.charger()
	assert_eq(Reglages.qualite, Reglages.Qualite.NORMALE, "Fichier abîmé : Normale, sans planter")
	_ecrire('{"version": 1, "qualite": "ultra"}')
	Reglages.charger()
	assert_eq(Reglages.qualite, Reglages.Qualite.NORMALE, "Valeur inconnue : Normale")
	Reglages.choisir_qualite(7)
	assert_eq(Reglages.qualite, Reglages.Qualite.BELLE, "Hors limites : ramené au plus proche")


# ---------------------------------------------------------------- ce que change la qualité
func test_economie_sans_ombres_ni_halo_puis_retour() -> void:
	var lune := DirectionalLight3D.new()
	lune.shadow_enabled = true
	var lanterne := OmniLight3D.new()   # (une lumière sans ombre voulue)
	var we := WorldEnvironment.new()
	we.environment = Environment.new()
	we.environment.glow_enabled = true
	add_child_autofree(lune)
	add_child_autofree(lanterne)
	add_child_autofree(we)
	await wait_process_frames(2)
	assert_true(lune.shadow_enabled, "Normale : l'ombre voulue par la scène")
	assert_eq(get_tree().root.scaling_3d_scale, 1.0)
	Reglages.choisir_qualite(Reglages.Qualite.ECONOMIE)
	assert_false(lune.shadow_enabled, "Économie : sans ombres")
	assert_false(we.environment.glow_enabled, "Économie : sans halo")
	assert_eq(get_tree().root.scaling_3d_scale, Reglages.ECHELLE_ECONOMIE, "Économie : image un peu moins fine")
	assert_eq(get_tree().root.msaa_3d, Viewport.MSAA_DISABLED)
	Reglages.choisir_qualite(Reglages.Qualite.NORMALE)
	assert_true(lune.shadow_enabled, "De retour en Normale : l'ombre revient")
	assert_false(lanterne.shadow_enabled, "Pas d'ombre là où la scène n'en voulait pas")
	assert_true(we.environment.glow_enabled, "Le halo revient")
	assert_eq(get_tree().root.scaling_3d_scale, 1.0)
	Reglages.choisir_qualite(Reglages.Qualite.BELLE)
	assert_eq(get_tree().root.msaa_3d, Viewport.MSAA_2X, "Belle : bords lissés")
	assert_true(lune.shadow_enabled)
	assert_false(lanterne.shadow_enabled, "Belle n'ajoute pas d'ombres (seulement plus douces)")
	assert_eq(get_tree().root.scaling_3d_scale, 1.0)


func test_une_lumiere_reglee_apres_son_ajout() -> void:
	Reglages.choisir_qualite(Reglages.Qualite.ECONOMIE)
	var l := OmniLight3D.new()
	add_child_autofree(l)
	l.shadow_enabled = true   # (certaines scènes règlent la lumière après l'avoir ajoutée)
	await wait_process_frames(2)
	assert_false(l.shadow_enabled, "Économie : coupée quand même")
	Reglages.choisir_qualite(Reglages.Qualite.NORMALE)
	assert_true(l.shadow_enabled, "Et rendue en Normale")


func test_une_lumiere_qui_disparait_aussitot() -> void:
	# (un éclair de lumière ajouté puis retiré dans la même image : vu par la suite complète, une erreur par éclair)
	var l := OmniLight3D.new()
	add_child(l)
	l.free()
	var l2 := OmniLight3D.new()
	add_child(l2)
	l2.queue_free()
	await wait_process_frames(3)
	pass_test("Aucune erreur (GUT compterait une erreur du moteur comme un échec)")


func test_une_vraie_scene_en_economie() -> void:
	Reglages.choisir_qualite(Reglages.Qualite.ECONOMIE)
	Partie.destination = &"arene"
	var a: Arene = load("res://game/arene/arene.tscn").instantiate()
	a.changer_de_scene = false
	add_child_autofree(a)
	await wait_physics_frames(3)
	var lumieres := a.find_children("*", "Light3D", true, false)
	assert_gt(lumieres.size(), 2, "L'arène a ses lumières")
	assert_eq(lumieres.filter(func(l): return l.shadow_enabled).size(), 0, "Aucune ombre dans l'arène")
	Reglages.choisir_qualite(Reglages.Qualite.NORMALE)
	assert_gt(lumieres.filter(func(l): return l.shadow_enabled).size(), 0, "En Normale, l'arène retrouve ses ombres")


# ---------------------------------------------------------------- l'écran
func test_l_ecran_reglages() -> void:
	var p := PanneauReglages.new()
	add_child_autofree(p)
	await wait_process_frames(2)
	assert_eq(p.boutons_qualite.size(), 3)
	assert_eq(p.boutons_qualite[Reglages.Qualite.NORMALE].theme_type_variation, &"BoutonOngletActif", "Le choix en cours")
	p.boutons_qualite[Reglages.Qualite.ECONOMIE].pressed.emit()
	assert_eq(Reglages.qualite, Reglages.Qualite.ECONOMIE)
	await wait_process_frames(1)
	assert_eq(p.boutons_qualite[Reglages.Qualite.ECONOMIE].theme_type_variation, &"BoutonOngletActif", "Le nouveau choix se voit")
	assert_eq(p.boutons_qualite[Reglages.Qualite.NORMALE].theme_type_variation, &"BoutonOnglet")
	assert_eq(p.label_description.text, PanneauReglages.DESCRIPTIONS[Reglages.Qualite.ECONOMIE])
	var textes: Array = p.contenu.find_children("*", "Label", true, false) \
			.filter(func(l): return not l.is_queued_for_deletion()).map(func(l): return l.text)
	assert_has(textes, "◆  Ombres : non")
	assert_has(textes, "◆  Finesse de l'image : 75 %")


func test_l_ecran_titre_ouvre_les_reglages() -> void:
	var ecran = load("res://ui/screens/demarrage.tscn").instantiate()
	ecran.changer_de_scene = false
	add_child_autofree(ecran)
	await wait_process_frames(2)
	assert_eq(ecran.bouton_reglages.text, "Réglages")
	ecran.bouton_reglages.pressed.emit()
	assert_true(ecran.panneau_reglages is PanneauReglages)
	ecran.bouton_reglages.pressed.emit()
	assert_eq(ecran.find_children("*", "PanneauReglages", true, false).size(), 1, "Un seul écran, même en appuyant deux fois")
	ecran._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_null(ecran.panneau_reglages, "Le retour d'Android referme les réglages")
	assert_eq(ecran.scene_demandee, "", "Sans quitter l'écran titre")
	ecran.bouton_reglages.pressed.emit()
	ecran.panneau_reglages.bouton_fermer.pressed.emit()
	assert_null(ecran.panneau_reglages, "« Fermer »")
	await wait_process_frames(1)
	assert_true(get_tree().is_quit_on_go_back(), "Fermé : le retour d'Android quitte de nouveau le jeu depuis l'écran titre")
