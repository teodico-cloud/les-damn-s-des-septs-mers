extends Node
## État de la partie en cours, partagé entre les écrans : héros choisi, mode (seul, hôte, invité),
## destination (arène d'entraînement ou expédition) et réglages du mode test.

enum Mode { SOLO, HOTE, INVITE }

var heros_local: StringName = &"bretteur"
var mode := Mode.SOLO
var destination: StringName = &"arene"    ## &"arene" ou &"expedition"
# mode test (APK de test, écran titre) : pour essayer un point précis sans refaire toute l'expédition
var debug_sante_infinie := false
var debug_depart: StringName = &""          ## &"" (salle 1), &"tresor", &"bosco" ou &"chaloupe"


const SCENES := {
	&"arene": "res://game/arene/arene.tscn",
	&"expedition": "res://game/expedition/expedition.tscn",
}


func scene_destination() -> String:
	return SCENES.get(destination, SCENES[&"arene"])


## Retour au menu : on repart en solo (la session réseau est fermée par Reseau.quitter()).
func revenir_en_solo() -> void:
	mode = Mode.SOLO
