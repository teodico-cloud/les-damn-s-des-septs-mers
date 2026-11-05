class_name Forge
extends RefCounted
## La forge (jalon 5, étape 3 : choix de Téo du 04-05/11) et les niveaux 2 du repaire.
## - Améliorer une arme : elle monte d'une rareté (Commun → Rare → Épique) ; son effet de base grandit et
##   elle gagne un effet en plus tiré au hasard. Armes seulement, jamais les objets uniques.
## - Recycler un objet : il disparaît et rend des matériaux (arme : fer noir, relique : essence maudite) ;
##   au-delà du plafond de l'entrepôt, perdus ; sans aucune place, impossible (choix de Téo du 05/11).
## - Forge niveau 2 : relancer un effet en plus choisi par le joueur (remplacé au hasard par un autre).
## - Entrepôt niveau 2 : plafonds plus hauts (Sauvegarde.plafond).
## Les achats eux-mêmes sont dans la sauvegarde (`Sauvegarde.ameliorer_objet`, `recycler`, `relancer_effet`,
## `agrandir`) : ce fichier dit ce qui est possible et ce que ça coûte.

const EQ: Equilibrage = preload("res://data/equilibrage.tres")
const NOMS_INSTALLATIONS := {"forge": "Forge", "entrepot": "Entrepôt"}


## L'objet peut-il monter d'une rareté ? (une arme Commune ou Rare, pas un objet unique)
static func ameliorable(objet: Dictionary) -> bool:
	var def := Butin.definition(objet)
	return not def.is_empty() and def.get("type") == "arme" and not Equipement.est_unique(objet) \
			and int(objet.get("rarete", 0)) < Butin.Rarete.EPIQUE


static func prix_amelioration(objet: Dictionary) -> Dictionary:
	if not ameliorable(objet):
		return {}
	return EQ.forge_prix_rarete[int(objet.get("rarete", 0))]


## Ce que rend un objet recyclé : {"fer": n} pour une arme, {"essence": n} pour une relique.
static func recyclage(objet: Dictionary) -> Dictionary:
	var def := Butin.definition(objet)
	if def.is_empty():
		return {}
	var r := clampi(int(objet.get("rarete", 0)), 0, 4)
	if def.get("type") == "arme":
		return {"fer": EQ.forge_recyclage_arme[r]}
	return {"essence": EQ.forge_recyclage_relique[r]}


## Ce qu'un objet recyclé maintenant laisserait à l'entrepôt ({"gardees", "perdues"} : au-delà du plafond, perdu).
static func recyclage_range(objet: Dictionary) -> Dictionary:
	var r := Sauvegarde.ranger(recyclage(objet))
	return {"gardees": r["gardees"], "perdues": r["surplus"]}


## Peut-on le recycler ? Il faut qu'au moins une partie de ce qu'il rend entre à l'entrepôt (choix de Téo).
static func recyclable(objet: Dictionary) -> bool:
	var g: Dictionary = recyclage_range(objet)["gardees"]
	return g.values().any(func(n): return int(n) > 0)


## Les effets en plus d'un objet qu'on peut relancer (ceux tirés quand il est tombé ou qu'il a été forgé).
static func effets_relancables(objet: Dictionary) -> Array:
	var e = objet.get("effets", {})
	return e.keys() if e is Dictionary else []


static func prix_relance() -> Dictionary:
	return EQ.forge_prix_relance


static func prix_niveau_2(installation: String) -> Dictionary:
	return EQ.repaire_prix_niveau_2.get(installation, {})


## « Agrandir » une installation est-il payable maintenant ? (pastille « ! » de la forge et de l'entrepôt)
static func agrandissement_possible(installation: String) -> bool:
	return Sauvegarde.niveau_repaire(installation) < 2 and Bateau.manque(prix_niveau_2(installation)).is_empty()


## Un effet en plus tiré au hasard, différent de ceux de `existants` (et de `sauf`).
static func effet_au_hasard(rng: RandomNumberGenerator, existants: Dictionary, sauf := "") -> String:
	var possibles: Array = EQ.equip_effets_plus.keys().filter(func(k): return not existants.has(k) and k != sauf)
	if possibles.is_empty():
		return ""
	return possibles[rng.randi() % possibles.size()]
