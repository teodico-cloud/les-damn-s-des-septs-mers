class_name GenerateurEnnemis
extends Node3D
## Garde une horde d'ennemis dans l'arène : quand certains tombent, les manquants ressortent de terre
## ensemble, en groupe, un peu plus tard et loin des héros. Chaque ennemi a un nom unique
## (« Squelette_7 ») : en coop, c'est ce nom qui permet à l'invité de retrouver le même squelette.

signal ennemi_cree(ennemi: Ennemi)

const EQ: Equilibrage = preload("res://data/equilibrage.tres")

@export var demi_cote := 5.0   ## zone d'apparition : carré de ce demi-côté autour de l'origine
var nombre := 2                ## ennemis à garder en vie (fixé par l'arène avant add_child)
var demarrage_auto := true     ## faux en coop chez l'hôte : on attend que l'invité soit prêt
var demarre := false

var vaincus := 0
var _compteur := 0
var _renfort_prevu := false
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
	_groupes(nombre)


## Ennemis encore debout (ou en train de sortir de terre).
func vivants() -> int:
	var n := 0
	for e in get_children():
		if e is Ennemi and e.etat != Ennemi.Etat.MORT and not e.is_queued_for_deletion():
			n += 1
	return n


## Fait sortir `n` ennemis, par groupes de 2 à 4 serrés autour d'un même point.
func _groupes(n: int) -> void:
	while n > 0:
		var taille := mini(n, _rng.randi_range(2, 4))
		var centre := _point_libre()
		for i in taille:
			var a := TAU * i / taille + _rng.randf_range(-0.3, 0.3)
			var p := centre + Vector3(cos(a), 0, sin(a)) * (EQ.arene_rayon_groupe if taille > 1 else 0.0)
			p.x = clampf(p.x, -demi_cote, demi_cote)
			p.z = clampf(p.z, -demi_cote, demi_cote)
			_faire_apparaitre(p)
		n -= taille


func _faire_apparaitre(position_voulue := Vector3.INF) -> void:
	var e := Ennemi.creer()
	_compteur += 1
	e.name = "Squelette_%d" % _compteur
	e.position = _point_libre() if position_voulue == Vector3.INF else position_voulue
	e.vaincu.connect(_on_vaincu)
	add_child(e)
	e.rotation.y = _rng.randf_range(-PI, PI)
	ennemi_cree.emit(e)


## Coop, les deux héros tombés : on repart à zéro (tous les squelettes remplacés).
func reinitialiser() -> void:
	for e in get_children():
		if e is Ennemi:
			e.queue_free()
	_groupes(nombre)


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
	if _renfort_prevu:
		return   # les morts suivants rejoindront le même renfort
	_renfort_prevu = true
	# branché sur le générateur lui-même : si on quitte l'arène avant la fin du délai, le lien
	# disparaît avec lui (un « await » reprendrait sur un objet détruit)
	get_tree().create_timer(EQ.arene_delai_apparition).timeout.connect(_remplacer)


## Renfort : tous les manquants ressortent ensemble (rien si la horde est déjà complète, ex. l'hôte
## qui continue seul avec une horde plus petite).
func _remplacer() -> void:
	_renfort_prevu = false
	var manquants := nombre - vivants()
	if manquants > 0:
		_groupes(manquants)
