extends Node
## Signaux partagés entre systèmes (combat, effets, interface), pour qu'ils ne dépendent pas
## directement les uns des autres. Chargé au démarrage sous le nom EventBus.

## Un coup a touché quelqu'un : sert aux chiffres de dégâts, à l'arrêt sur image, à la secousse.
## `cible` et `source` peuvent être nuls (source inconnue, coup reçu par le réseau…).
signal coup_porte(position: Vector3, degats: float, lourd: bool, cible_est_heros: bool, cible: Node3D, source: Node3D)
## Un projectile vient d'être tiré (en coop, l'hôte le fait voir à l'invité).
signal projectile_tire(tireur: Node3D, depart: Vector3, direction: Vector3)
## Effet visuel ponctuel lancé par un héros (ex. cercle des Chaînes) : en coop, l'invité le voit aussi.
signal effet_visuel(lanceur: Node3D, type: String, position: Vector3)
## Un ennemi vient de mourir.
signal ennemi_vaincu(ennemi: Node)
## Un héros vient de mourir / de réapparaître.
signal heros_mort(heros: Node)
signal heros_reapparu(heros: Node)
