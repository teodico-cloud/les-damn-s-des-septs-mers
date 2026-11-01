class_name Recharge
extends RefCounted
## Temps de recharge d'une action (esquive, compétence). Avancé à la main par son propriétaire,
## ce qui le rend testable et utilisable plus tard par l'hôte d'une partie en coop.

var duree := 1.0
var base := 1.0          ## durée d'origine (l'équipement peut la raccourcir : duree = base × …)
var restant := 0.0


func _init(d: float = 1.0) -> void:
	duree = d
	base = d


func prete() -> bool:
	return restant <= 0.0


func declencher() -> void:
	restant = duree


func avancer(delta: float) -> void:
	restant = max(0.0, restant - delta)


## 0 = prête, 1 = vient d'être utilisée (pour l'affichage du cercle de recharge).
func fraction() -> float:
	return 0.0 if duree <= 0.0 else restant / duree
