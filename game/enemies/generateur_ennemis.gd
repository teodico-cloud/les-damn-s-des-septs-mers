class_name GenerateurEnnemis
extends Node3D
## Garde un nombre fixe d'ennemis en vie dans l'arène : quand l'un meurt, un autre sort de terre
## un peu plus tard, loin du héros.

const EQ: Equilibrage = preload("res://data/equilibrage.tres")

@export var demi_cote := 5.0   ## zone d'apparition : carré de ce demi-côté autour de l'origine

var vaincus := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	for i in EQ.arene_nb_ennemis:
		_faire_apparaitre()


func _faire_apparaitre() -> void:
	var e := Ennemi.creer()
	e.position = _point_libre()
	e.vaincu.connect(_on_vaincu)
	add_child(e)
	e.rotation.y = _rng.randf_range(-PI, PI)


func _point_libre() -> Vector3:
	var heros := get_tree().get_nodes_in_group("heros")
	for essai in 30:
		var p := Vector3(_rng.randf_range(-demi_cote, demi_cote), 0, _rng.randf_range(-demi_cote, demi_cote))
		var ok := true
		for h in heros:
			if (h as Node3D).global_position.distance_to(p) < EQ.arene_distance_apparition_min:
				ok = false
		if ok:
			return p
	return Vector3(-demi_cote, 0, -demi_cote)


func _on_vaincu(_e: Ennemi) -> void:
	vaincus += 1
	# branché sur le générateur lui-même : si on quitte l'arène avant la fin du délai, le lien
	# disparaît avec lui (un « await » reprendrait sur un objet détruit)
	get_tree().create_timer(EQ.arene_delai_apparition).timeout.connect(_faire_apparaitre)
