extends Node
## État de la partie en cours, partagé entre les écrans : héros choisi et mode (seul, hôte, invité).

enum Mode { SOLO, HOTE, INVITE }

var heros_local: StringName = &"bretteur"
var mode := Mode.SOLO


## Retour au menu : on repart en solo (la session réseau est fermée par Reseau.quitter()).
func revenir_en_solo() -> void:
	mode = Mode.SOLO
