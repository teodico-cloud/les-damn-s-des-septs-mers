class_name GenerateurEnnemis
extends Node3D
## Garde une horde d'ennemis dans l'arène : quand certains tombent, les manquants ressortent de terre
## ensemble, en groupe, un peu plus tard et loin des héros. Chaque ennemi a un nom unique
## (« Squelette_7 ») : en coop, c'est ce nom qui permet à l'invité de retrouver le même squelette.
## Expédition : une salle a une réserve finie (`reserve`) ; quand tout est vaincu, `salle_videe`.
## Sa composition (arbalétriers, prêtre noyé, le reste en matelots) est tirée au hasard dans l'ordre
## d'apparition. Chaque squelette tombé laisse une « tombe » qu'un prêtre noyé peut relever une fois.

signal ennemi_cree(ennemi: Ennemi)
signal salle_videe

const EQ: Equilibrage = preload("res://data/equilibrage.tres")

@export var demi_cote := 5.0   ## zone d'apparition : carré de ce demi-côté autour de l'origine
var nombre := 2                ## ennemis à garder en vie (fixé par l'arène avant add_child)
var demarrage_auto := true     ## faux en coop chez l'hôte : on attend que l'invité soit prêt
var demarre := false

var reserve := -1              ## ennemis qui restent à faire sortir (-1 : sans fin, arène)
var points_apparition: Array[Vector3] = []   ## centres possibles des groupes (salle faite main)
var vaincus := 0
var _compteur := 0
var _renfort_prevu := false
var _generation := 0           ## change à chaque nouvelle salle : un renfort prévu avant est oublié
var a_venir: Array[StringName] = []   ## types des prochains ennemis (vide : des matelots)
var tombes: Array[Dictionary] = []    ## {pos, type, etat : 0 libre, 1 réservée par un prêtre, 2 relevée}
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


## Expédition : nouvelle salle. Les ennemis restants sont retirés ; `total` ennemis à vaincre, dont
## `ensemble` debout en même temps ; groupes autour des `points` (vide : n'importe où).
## Ne démarre pas tout seul : appeler demarrer() (en coop, l'hôte attend que l'invité ait la salle).
## `composition` : {&"arbaletrier": 2, &"pretre": 1} (le reste en matelots).
func preparer_salle(total: int, ensemble: int, points: Array[Vector3], composition := {}) -> void:
	for e in get_children():
		if e is Ennemi:
			e.queue_free()
	_generation += 1
	_renfort_prevu = false
	demarre = false
	reserve = total
	nombre = ensemble
	points_apparition = points
	tombes.clear()
	a_venir.clear()
	for t in composition:
		for i in mini(int(composition[t]), total):
			a_venir.append(StringName(t))
	while a_venir.size() < total:
		a_venir.append(&"matelot")
	a_venir.resize(total)
	# au hasard, mais pas de prêtre dans le tout premier groupe (on le découvre ensuite)
	_melanger(a_venir)
	var premier := mini(total, 4)
	for i in premier:
		if a_venir[a_venir.size() - 1 - i] == &"pretre" and a_venir.size() > premier:
			var j := _rng.randi_range(0, a_venir.size() - 1 - premier)
			var x := a_venir[j]
			a_venir[j] = a_venir[a_venir.size() - 1 - i]
			a_venir[a_venir.size() - 1 - i] = x


func _melanger(liste: Array[StringName]) -> void:
	for i in range(liste.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var x := liste[i]
		liste[i] = liste[j]
		liste[j] = x


## Ennemis encore debout (ou en train de sortir de terre).
func vivants() -> int:
	var n := 0
	for e in get_children():
		if e is Ennemi and e.etat != Ennemi.Etat.MORT and not e.is_queued_for_deletion():
			n += 1
	return n


## Fait sortir `n` ennemis, par groupes de 2 à 4 serrés autour d'un même point (dans la limite de
## la réserve de la salle).
func _groupes(n: int) -> void:
	if reserve >= 0:
		n = mini(n, reserve)
		reserve -= n
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


func _faire_apparaitre(position_voulue := Vector3.INF, type: StringName = &"") -> Ennemi:
	if type == &"":
		type = a_venir.pop_back() if not a_venir.is_empty() else &"matelot"
	var e := Ennemi.creer_type(type)
	_compteur += 1
	e.name = "%s_%d" % [Ennemi.PREFIXES.get(type, "Squelette"), _compteur]
	e.position = _point_libre() if position_voulue == Vector3.INF else position_voulue
	e.vaincu.connect(_on_vaincu)
	add_child(e)
	e.rotation.y = _rng.randf_range(-PI, PI)
	ennemi_cree.emit(e)
	return e


# ---------------------------------------------------------------- tombes (prêtre noyé)
## Tombe libre la plus proche de `pos` à moins de `rayon` (indice), ou -1.
func tombe_proche(pos: Vector3, rayon: float) -> int:
	var meilleure := -1
	var d_min := rayon
	for i in tombes.size():
		var d: float = (tombes[i]["pos"] as Vector3).distance_to(pos)
		if tombes[i]["etat"] == 0 and d <= d_min:
			d_min = d
			meilleure = i
	return meilleure


func reserver_tombe(i: int) -> void:
	if i >= 0 and i < tombes.size():
		tombes[i]["etat"] = 1


func liberer_tombe(i: int) -> void:
	if i >= 0 and i < tombes.size() and tombes[i]["etat"] == 1:
		tombes[i]["etat"] = 0


## Le prêtre a fini son incantation : le mort ressort de terre (une seule fois).
func relever(i: int) -> Ennemi:
	if i < 0 or i >= tombes.size() or tombes[i]["etat"] == 2:
		return null
	tombes[i]["etat"] = 2
	var e := _faire_apparaitre(tombes[i]["pos"], tombes[i]["type"])
	e.releve = true
	return e


## Coop, les deux héros tombés : on repart à zéro (tous les squelettes remplacés).
func reinitialiser() -> void:
	for e in get_children():
		if e is Ennemi:
			e.queue_free()
	tombes.clear()
	_groupes(nombre)


func _point_libre() -> Vector3:
	var heros := get_tree().get_nodes_in_group("heros")
	if not points_apparition.is_empty():
		# salle faite main : le point prévu le plus loin des héros (un peu au hasard entre les bons)
		var bons: Array[Vector3] = []
		for p in points_apparition:
			var ok := true
			for h in heros:
				if (h as Node3D).global_position.distance_to(p) < EQ.arene_distance_apparition_min:
					ok = false
			if ok:
				bons.append(p)
		if bons.is_empty():
			bons = points_apparition.duplicate()
		return bons[_rng.randi() % bons.size()] + Vector3(_rng.randf_range(-0.4, 0.4), 0, _rng.randf_range(-0.4, 0.4))
	for essai in 30:
		var p := Vector3(_rng.randf_range(-demi_cote, demi_cote), 0, _rng.randf_range(-demi_cote, demi_cote))
		var ok := true
		for h in heros:
			if (h as Node3D).global_position.distance_to(p) < EQ.arene_distance_apparition_min:
				ok = false
		if ok:
			return p
	return Vector3(-demi_cote, 0, -demi_cote)


func _on_vaincu(e: Ennemi) -> void:
	vaincus += 1
	if not e.releve and e.type_ennemi() != &"pretre":
		tombes.append({"pos": e.global_position, "type": e.type_ennemi(), "etat": 0})
	if reserve == 0:
		if vivants() == 0:
			salle_videe.emit()
		return   # plus personne à faire sortir dans cette salle
	if _renfort_prevu:
		return   # les morts suivants rejoindront le même renfort
	_renfort_prevu = true
	# branché sur le générateur lui-même : si on quitte l'arène avant la fin du délai, le lien
	# disparaît avec lui (un « await » reprendrait sur un objet détruit)
	get_tree().create_timer(EQ.arene_delai_apparition).timeout.connect(_remplacer.bind(_generation))


## Renfort : tous les manquants ressortent ensemble (rien si la horde est déjà complète, ex. l'hôte
## qui continue seul avec une horde plus petite). Un renfort prévu dans la salle d'avant est oublié.
func _remplacer(generation := -1) -> void:
	if generation != -1 and generation != _generation:
		return
	_renfort_prevu = false
	var manquants := nombre - vivants()
	if manquants > 0:
		_groupes(manquants)
