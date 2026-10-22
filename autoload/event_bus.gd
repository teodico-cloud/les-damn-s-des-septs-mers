extends Node
## Signaux partagés entre systèmes (combat, effets, interface), pour qu'ils ne dépendent pas
## directement les uns des autres. Chargé au démarrage sous le nom EventBus.

## Un coup a touché quelqu'un : sert aux chiffres de dégâts, à l'arrêt sur image, à la secousse.
signal coup_porte(position: Vector3, degats: float, lourd: bool, cible_est_heros: bool)
## Un ennemi vient de mourir.
signal ennemi_vaincu(ennemi: Node)
## Un héros vient de mourir / de réapparaître.
signal heros_mort(heros: Node)
signal heros_reapparu(heros: Node)
