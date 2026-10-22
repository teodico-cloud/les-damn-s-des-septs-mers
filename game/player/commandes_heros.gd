class_name CommandesHeros
extends RefCounted
## Ce que le joueur demande à son héros : une direction de déplacement (dans le monde) et des
## actions ponctuelles. L'interface remplit cet objet ; en coop, il sera envoyé à l'hôte.

const TAMPON := 0.25   ## une action demandée un peu trop tôt est gardée ce temps-là (secondes)

var deplacement := Vector3.ZERO   ## direction au sol, longueur 0 à 1
var _demandes := {}               ## action -> instant de la demande


func demander(action: StringName, instant: float) -> void:
	_demandes[action] = instant


## Vrai si l'action a été demandée récemment ; la demande est alors consommée.
func prendre(action: StringName, instant: float) -> bool:
	if not _demandes.has(action):
		return false
	var t: float = _demandes[action]
	_demandes.erase(action)
	return instant - t <= TAMPON


func en_attente(action: StringName, instant: float) -> bool:
	return _demandes.has(action) and instant - float(_demandes[action]) <= TAMPON


func vider() -> void:
	_demandes.clear()
	deplacement = Vector3.ZERO
