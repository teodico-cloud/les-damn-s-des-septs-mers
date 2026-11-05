class_name Recharge
extends RefCounted
## Temps de recharge d'une action (esquive, compétence). Avancé à la main par son propriétaire,
## ce qui le rend testable et utilisable plus tard par l'hôte d'une partie en coop.
## Avec des charges (`charges_max` > 1, téléportation de l'Occultiste : choix de Téo du 05/11), l'action
## se refait tant qu'il reste une charge ; les charges reviennent une à une, chacune en `duree`.

var duree := 1.0
var base := 1.0          ## durée d'origine (l'équipement peut la raccourcir : duree = base × …)
var restant := 0.0       ## avec des charges : avant la prochaine charge
var charges_max := 1
var charges := 1


func _init(d: float = 1.0, n_charges := 1) -> void:
	duree = d
	base = d
	charges_max = maxi(n_charges, 1)
	charges = charges_max


func prete() -> bool:
	if charges_max > 1:
		return charges > 0
	return restant <= 0.0


func declencher() -> void:
	if charges_max > 1:
		if charges >= charges_max:
			restant = duree   # (la recharge démarre ; déjà en cours, elle continue)
		charges = maxi(charges - 1, 0)
		return
	restant = duree


func avancer(delta: float) -> void:
	if charges_max > 1:
		if charges >= charges_max:
			restant = 0.0
			return
		restant -= delta
		while restant <= 0.0 and charges < charges_max:
			charges += 1
			if charges < charges_max:
				restant += duree
		if charges >= charges_max:
			restant = 0.0
		return
	restant = max(0.0, restant - delta)


## 0 = prête, 1 = vient d'être utilisée (pour l'affichage du cercle de recharge). Avec des charges : la part
## qui manque à la prochaine charge (0 quand elles sont toutes là).
func fraction() -> float:
	return 0.0 if duree <= 0.0 else clampf(restant / duree, 0.0, 1.0)
