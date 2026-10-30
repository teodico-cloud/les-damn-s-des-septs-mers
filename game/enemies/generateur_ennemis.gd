class_name GenerateurEnnemis
extends Node3D
## Garde un nombre fixe d'ennemis en vie dans l'arène : quand l'un meurt, un autre sort de terre
## un peu plus tard, loin des héros. Chaque ennemi a un nom unique (« Squelette_7 ») : en coop, c'est
## ce nom qui permet à l'invité de retrouver le même squelette.

signal ennemi_cree(ennemi: Ennemi)

const EQ: Equilibrage = preload("res://data/equilibrage.tres")

@export var demi_cote := 5.0   ## zone d'apparition : carré de ce demi-côté autour de l'origine
var nombre := 2                ## ennemis à garder en vie (fixé par l'arène avant add_child)
var demarrage_auto := true     ## faux en coop chez l'hôte : on attend que l'invité soit prêt
var demarre := false

var vaincus := 0
var _compteur := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	if demarrage_auto:
		demarrer()


## Fait sortir de terre les premiers ennemis (une seule fois).
func demarrer() -> void:
	if demarre:
		return
	demarre = true
	for i in nombre:
		_faire_apparaitre()


## Ennemis encore debout (ou en train de sortir de terre).
func vivants() -> int:
	var n := 0
	for e in get_children():
		if e is Ennemi and e.etat != Ennemi.Etat.MORT and not e.is_queued_for_deletion():
			n += 1
	return n


func _faire_apparaitre() -> void:
	var e := Ennemi.creer()
	_compteur += 1
	e.name = "Squelette_%d" % _compteur
	e.position = _point_libre()
	e.vaincu.connect(_on_vaincu)
	add_child(e)
	e.rotation.y = _rng.randf_range(-PI, PI)
	ennemi_cree.emit(e)


## Coop, les deux héros tombés : on repart à zéro (tous les squelettes remplacés).
func reinitialiser() -> void:
	for e in get_children():
		if e is Ennemi:
			e.queue_free()
	for i in nombre:
		_faire_apparaitre()


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
	get_tree().create_timer(EQ.arene_delai_apparition).timeout.connect(_remplacer)


## Un ennemi est tombé : un autre sort de terre, sauf s'il y en a déjà assez (ex. l'hôte continue seul).
func _remplacer() -> void:
	if vivants() < nombre:
		_faire_apparaitre()
