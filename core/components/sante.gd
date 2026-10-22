class_name Sante
extends Node
## Points de vie d'un combattant (héros, ennemi, boss). Toujours passer par subir() pour infliger
## des dégâts : c'est ici que sont gérées l'invulnérabilité et la mort.

signal touche(degats: float, source: Node)
signal mort(source: Node)
signal change(pv: float, pv_max: float)

@export var pv_max := 100.0
var pv := 100.0
var invulnerable_jusqua := 0.0   ## horloge (secondes) jusqu'à laquelle on ne peut pas être touché
var est_mort := false
var _horloge := 0.0              ## temps de JEU écoulé : ralentit avec l'arrêt sur image, comme le reste


func _ready() -> void:
	pv = pv_max
	# avance avant les combattants : une invulnérabilité donnée pendant une image dure exactement
	# le nombre d'images voulu
	process_physics_priority = -10


func _physics_process(delta: float) -> void:
	_horloge += delta


func maintenant() -> float:
	return _horloge


func est_invulnerable() -> bool:
	return maintenant() < invulnerable_jusqua


func rendre_invulnerable(duree: float) -> void:
	invulnerable_jusqua = maxf(invulnerable_jusqua, maintenant() + duree)


## Inflige des dégâts. Renvoie les dégâts réellement subis (0 si invulnérable ou déjà mort).
func subir(degats: float, source: Node = null) -> float:
	if est_mort or degats <= 0.0 or est_invulnerable():
		return 0.0
	var reel: float = min(degats, pv)
	pv -= reel
	touche.emit(reel, source)
	change.emit(pv, pv_max)
	if pv <= 0.0:
		est_mort = true
		mort.emit(source)
	return reel


func soigner_completement() -> void:
	pv = pv_max
	est_mort = false
	change.emit(pv, pv_max)
