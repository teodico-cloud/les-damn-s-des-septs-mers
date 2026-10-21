extends GutTest
## Vérifie que les modèles des héros sont complets : animations et accessoires.

const HEROS := {
	"res://assets/models/heroes/Bretteur.glb": ["Bretteur_Tricorne", "Bretteur_Sabre", "Bretteur_Pistolet", "Bretteur_Bandeau"],
	"res://assets/models/heroes/Occultiste.glb": ["Occultiste_Capuche", "Occultiste_Baton", "Occultiste_Lanterne", "Occultiste_Barbe"],
}
const ANIMATIONS_UTILISEES := [
	"Idle", "1H_Melee_Attack_Slice_Diagonal", "1H_Melee_Attack_Chop", "Block", "Dodge_Forward",
	"Spellcast_Shoot", "Spellcast_Raise", "Spellcast_Long", "Dodge_Backward", "Running_A",
]


func _charger(chemin: String) -> Node3D:
	var scene = load(chemin)
	assert_true(scene is PackedScene, "Le modèle doit se charger : %s" % chemin)
	var n: Node3D = scene.instantiate()
	add_child_autofree(n)
	return n


func test_les_heros_ont_76_animations() -> void:
	for chemin in HEROS:
		var anim: AnimationPlayer = _charger(chemin).find_child("AnimationPlayer", true, false)
		assert_not_null(anim, "AnimationPlayer présent dans %s" % chemin)
		assert_eq(anim.get_animation_list().size(), 76, "Nombre d'animations de %s" % chemin)
		for nom in ANIMATIONS_UTILISEES:
			assert_true(anim.has_animation(nom), "%s doit avoir l'animation %s" % [chemin, nom])


func test_les_heros_ont_leurs_accessoires() -> void:
	for chemin in HEROS:
		var n := _charger(chemin)
		for piece in HEROS[chemin]:
			assert_not_null(n.find_child(piece, true, false), "%s doit contenir %s" % [chemin, piece])


func test_les_heros_tiennent_debout_sur_le_sol() -> void:
	# Le bas des pieds doit être au niveau du sol (y ≈ 0) : sinon ils flottent ou s'enfoncent.
	for chemin in HEROS:
		var n := _charger(chemin)
		var bas := INF
		for m in n.find_children("*", "MeshInstance3D", true, false):
			var aabb: AABB = (m as MeshInstance3D).global_transform * (m as MeshInstance3D).get_aabb()
			bas = min(bas, aabb.position.y)
		assert_almost_eq(bas, 0.0, 0.08, "Bas du modèle %s" % chemin)
