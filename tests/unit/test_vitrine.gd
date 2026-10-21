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
	vitrine.action_suivante()
	vitrine.action_suivante()
	assert_eq(vitrine.joueurs["bretteur"]["anim"].current_animation, "1H_Melee_Attack_Chop", "La 2e action doit suivre la 1re")
	var nb: int = vitrine.HEROS["bretteur"]["actions"].size()
	for i in nb - 1:
		vitrine.action_suivante()
	# après un tour complet, on revient à la première action
	assert_eq(vitrine.joueurs["bretteur"]["anim"].current_animation, "1H_Melee_Attack_Slice_Diagonal")


# ---------------------------------------------------------------- toucher
func _toucher(index: int, pos: Vector2, appuye: bool, annule := false) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = appuye
	e.canceled = annule
	vitrine._unhandled_input(e)


func _glisser(index: int, pos: Vector2, relatif: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = pos
	e.relative = relatif
	vitrine._unhandled_input(e)


func _anim_bretteur() -> String:
	return vitrine.joueurs["bretteur"]["anim"].current_animation


func test_une_tape_lance_une_action() -> void:
	_toucher(0, Vector2(600, 300), true)
	_toucher(0, Vector2(602, 301), false)
	assert_eq(_anim_bretteur(), "1H_Melee_Attack_Slice_Diagonal")


func test_glisser_tourne_la_camera_sans_action() -> void:
	var avant: float = vitrine.lacet
	_toucher(0, Vector2(600, 300), true)
	_glisser(0, Vector2(700, 300), Vector2(100, 0))
	_toucher(0, Vector2(700, 300), false)
	assert_ne(vitrine.lacet, avant, "La caméra doit avoir tourné")
	assert_eq(_anim_bretteur(), "Idle", "Glisser ne doit pas lancer d'action")


func test_toucher_annule_ne_lance_rien() -> void:
	_toucher(0, Vector2(600, 300), true)
	_toucher(0, Vector2(600, 300), false, true)
	assert_eq(_anim_bretteur(), "Idle")


func test_second_doigt_ignore_pendant_la_rotation() -> void:
	_toucher(0, Vector2(600, 300), true)
	_glisser(0, Vector2(700, 300), Vector2(100, 0))
	_toucher(1, Vector2(200, 500), true)
	_toucher(1, Vector2(200, 500), false)
	assert_eq(_anim_bretteur(), "Idle", "Une tape d'un second doigt ne doit rien lancer")
	var avant: float = vitrine.lacet
	_glisser(0, Vector2(760, 300), Vector2(60, 0))
	assert_ne(vitrine.lacet, avant, "La rotation du premier doigt doit continuer")


func test_la_lanterne_eclaire() -> void:
	var lanterne: Node = vitrine.joueurs["occultiste"]["noeud"].find_child("Occultiste_Lanterne", true, false)
	assert_not_null(lanterne)
	assert_eq(lanterne.find_children("*", "OmniLight3D", false, false).size(), 1, "Une lumière verte suit la lanterne")
