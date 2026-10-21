extends GutTest
## Vérifie la vitrine des héros : chargement, animations au repos, enchaînement des actions.

var vitrine


func before_each() -> void:
	vitrine = load("res://game/vitrine/vitrine.tscn").instantiate()
	add_child_autofree(vitrine)
	await wait_process_frames(2)


func test_les_deux_heros_sont_presents_au_repos() -> void:
	assert_eq(vitrine.joueurs.size(), 2)
	for cle in vitrine.joueurs:
		var anim: AnimationPlayer = vitrine.joueurs[cle]["anim"]
		assert_eq(anim.current_animation, "Idle", "%s doit être au repos" % cle)


func test_toucher_lance_une_action_par_heros() -> void:
	vitrine.action_suivante()
	assert_eq(vitrine.joueurs["bretteur"]["anim"].current_animation, "1H_Melee_Attack_Slice_Diagonal")
	assert_eq(vitrine.joueurs["occultiste"]["anim"].current_animation, "Spellcast_Shoot")
	assert_string_contains(vitrine.label_action.text, "Taille")


func test_les_actions_tournent_en_boucle() -> void:
	var nb: int = vitrine.HEROS["bretteur"]["actions"].size()
	for i in nb + 1:
		vitrine.action_suivante()
	# après un tour complet, on revient à la première action
	assert_eq(vitrine.joueurs["bretteur"]["anim"].current_animation, "1H_Melee_Attack_Slice_Diagonal")


func test_la_lanterne_eclaire() -> void:
	var lanterne: Node = vitrine.joueurs["occultiste"]["noeud"].find_child("Occultiste_Lanterne", true, false)
	assert_not_null(lanterne)
	assert_eq(lanterne.find_children("*", "OmniLight3D", false, false).size(), 1, "Une lumière verte suit la lanterne")
