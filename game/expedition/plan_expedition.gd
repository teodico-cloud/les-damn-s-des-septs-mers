class_name PlanExpedition
extends RefCounted
## La suite des salles d'une expédition (règles fixes, tirage au hasard depuis une graine) :
## - salles 1 à N (N = exp_nb_salles, 4 : expédition courte, choix de Téo) ; la première est un combat ;
## - après chaque salle, deux portes annoncent le type de la suivante (combat, trésor, piège) ;
##   au plus un trésor et deux pièges par expédition ;
## - après la salle N : une seule porte, l'antre du Bosco ; après le Bosco : la chaloupe.
## Seul l'hôte tire le plan ; il envoie chaque salle à l'invité (voir SynchroArene).

const COMBAT := &"combat"
const TRESOR := &"tresor"
const PIEGE := &"piege"
const PIEGES_MAX := 2
const BOSCO := &"bosco"
const CHALOUPE := &"chaloupe"
const TRESORS_MAX := 1

var graine := 0
var nb_salles := 4
var _rng := RandomNumberGenerator.new()
var _tresors := 0
var _pieges := 0
var _derniers_modeles: Array[String] = []   ## pour ne pas revoir la même salle deux fois de suite


func _init(p_graine: int = 0, p_nb_salles: int = 4) -> void:
	graine = p_graine
	nb_salles = p_nb_salles
	_rng.seed = p_graine


## Numéro de la salle du Bosco et de la chaloupe (après les salles ordinaires).
func numero_bosco() -> int:
	return nb_salles + 1


func numero_chaloupe() -> int:
	return nb_salles + 2


## Type d'une salle imposé par son numéro (vide : décidé par la porte choisie).
func type_impose(numero: int) -> StringName:
	if numero <= 1:
		return COMBAT
	if numero == numero_bosco():
		return BOSCO
	if numero >= numero_chaloupe():
		return CHALOUPE
	return &""


## Types annoncés par les portes à la sortie de la salle `numero` (à appeler une fois par salle,
## dans l'ordre). Vide : fin de l'expédition.
func portes_apres(numero: int) -> Array[StringName]:
	if numero >= numero_chaloupe():
		return []
	var suivante := numero + 1
	if type_impose(suivante) != &"":
		return [type_impose(suivante)]
	var choix: Array[StringName] = [COMBAT]
	if _tresors < TRESORS_MAX:
		choix.append(TRESOR)
	if _pieges < PIEGES_MAX:
		choix.append(PIEGE)
	var a := choix[_rng.randi() % choix.size()]
	var b := COMBAT
	if choix.size() > 1:
		choix.erase(a)
		b = choix[_rng.randi() % choix.size()]
	var portes: Array[StringName] = [a, b]
	if _rng.randf() < 0.5:
		portes.reverse()
	return portes


## La salle `type` est choisie : le compte des trésors avance.
func noter_choix(type: StringName) -> void:
	if type == TRESOR:
		_tresors += 1
	elif type == PIEGE:
		_pieges += 1


## Un modèle de salle fait main pour ce type, différent des deux derniers vus si possible.
func modele_pour(type: StringName) -> String:
	var possibles := Salles.modeles_pour(type)
	var frais := possibles.filter(func(m): return not (m in _derniers_modeles))
	if frais.is_empty():
		frais = possibles
	var m: String = frais[_rng.randi() % frais.size()]
	_derniers_modeles.append(m)
	if _derniers_modeles.size() > 2:
		_derniers_modeles.pop_front()
	return m


## Nom affiché d'une salle (HUD, portes).
static func nom_type(type: StringName) -> String:
	match type:
		COMBAT: return "Combat"
		TRESOR: return "Trésor"
		PIEGE: return "Piège"
		BOSCO: return "Antre du Bosco"
		CHALOUPE: return "La chaloupe"
	return String(type)
