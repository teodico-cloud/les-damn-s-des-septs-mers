class_name Butin
extends RefCounted
## Le butin (jalon 4) : catalogue des objets et tirage au hasard. Un objet est un petit dictionnaire,
## facile à envoyer à l'invité et à sauvegarder :
##   {"id": "3fa9…", "base": "sabre", "rarete": 1, "effets": []}
## Raretés : Commun (statistiques), Rare (+1 effet), Épique (+2 effets), Légendaire (un objet unique qui
## change la façon de jouer), Maudit (un objet unique puissant, avec une contrepartie). Les effets se
## branchent sur le combat à l'étape 2 (liste à faire valider par Téo) ; ici, l'objet existe, tombe,
## se ramasse et se perd. Les armes sont tirées pour le héros du joueur ; les reliques vont aux deux.

const EQ: Equilibrage = preload("res://data/equilibrage.tres")
const ARMES := "res://assets/models/armes/"
const DECOR := "res://assets/models/decor/"

enum Rarete { COMMUN, RARE, EPIQUE, LEGENDAIRE, MAUDIT }
const NOMS_RARETES: Array[String] = ["Commun", "Rare", "Épique", "Légendaire", "Maudit"]
## Couleurs des raretés (colonne de lumière, nom) : blanc, bleu, violet, or, vert de la malédiction.
const COULEURS: Array[Color] = [Color(0.88, 0.86, 0.8), Color(0.35, 0.62, 1.0), Color(0.78, 0.42, 1.0),
		Color(1.0, 0.66, 0.15), Color(0.32, 1.0, 0.5)]

## Objets de base (Commun, Rare, Épique). « heros » vide : une relique, pour les deux héros. « echelle » :
## taille au sol des petits objets (sinon 0,9 pour une arme, 0,7 pour une relique).
const BASES := {
	# armes du Bretteur
	"sabre": {"nom": "Sabre d'abordage", "type": "arme", "heros": "bretteur", "modele": ARMES + "sword_1handed.gltf"},
	"hache": {"nom": "Hache d'abordage", "type": "arme", "heros": "bretteur", "modele": ARMES + "axe_1handed.gltf"},
	"coutelas": {"nom": "Coutelas du quartier-maître", "type": "arme", "heros": "bretteur", "modele": ARMES + "dagger.gltf"},
	# armes de l'Occultiste
	"baguette": {"nom": "Baguette d'os", "type": "arme", "heros": "occultiste", "modele": ARMES + "wand.gltf"},
	"baton": {"nom": "Bâton de corail", "type": "arme", "heros": "occultiste", "modele": ARMES + "staff.gltf"},
	"grimoire": {"nom": "Grimoire noyé", "type": "arme", "heros": "occultiste", "modele": ARMES + "spellbook_open.gltf"},
	# reliques
	"cle": {"nom": "Clé du geôlier", "type": "relique", "heros": "", "modele": DECOR + "key.glb", "echelle": 1.1},
	"fiole": {"nom": "Fiole d'eau noire", "type": "relique", "heros": "", "modele": DECOR + "bottle_A_green.glb"},
	"chandelle": {"nom": "Chandelle de veille", "type": "relique", "heros": "", "modele": DECOR + "candle_lit.glb"},
	"doublon": {"nom": "Doublon terni", "type": "relique", "heros": "", "modele": DECOR + "coin.glb", "echelle": 1.5},
	"trousseau": {"nom": "Trousseau du pendu", "type": "relique", "heros": "", "modele": DECOR + "keyring_hanging.glb", "echelle": 1.2},
	"flasque": {"nom": "Flasque de rhum", "type": "relique", "heros": "", "modele": DECOR + "bottle_C_brown.glb"},
}

## Objets uniques : légendaires (changent la façon de jouer) et maudits (puissants, avec une contrepartie).
## Leur effet arrive à l'étape 2 ; « effet » le décrit déjà (affiché dans l'inventaire).
const UNIQUES := {
	"lame_du_noye": {"nom": "Lame du Noyé", "type": "arme", "heros": "bretteur", "rarete": Rarete.LEGENDAIRE,
			"modele": ARMES + "sword_1handed.gltf", "teinte": Color(0.3, 1.0, 0.6),
			"effet": "La roulade laisse une traînée d'eau maudite qui blesse les squelettes"},
	"grimoire_du_pendu": {"nom": "Grimoire du Pendu", "type": "arme", "heros": "occultiste", "rarete": Rarete.LEGENDAIRE,
			"modele": ARMES + "spellbook_closed.gltf", "teinte": Color(1.0, 0.75, 0.3),
			"effet": "Un squelette tué par tes sorts se relève à tes côtés quelques secondes"},
	"sablier_maree": {"nom": "Sablier de la Marée", "type": "relique", "heros": "", "rarete": Rarete.LEGENDAIRE,
			"modele": DECOR + "bottle_B_green.glb", "teinte": Color(1.0, 0.75, 0.3),
			"effet": "Une esquive au dernier moment fige les squelettes autour de toi"},
	"talisman_pendu": {"nom": "Talisman du Pendu", "type": "relique", "heros": "", "rarete": Rarete.MAUDIT,
			"modele": DECOR + "keyring_hanging.glb", "echelle": 1.2, "teinte": Color(0.4, 1.0, 0.5),
			"effet": "Dégâts +40 %, mais les orbes de vie ne te soignent plus"},
	"coeur_kraken": {"nom": "Cœur de Kraken", "type": "relique", "heros": "", "rarete": Rarete.MAUDIT,
			"modele": DECOR + "bottle_A_labeled_green.glb", "teinte": Color(0.4, 1.0, 0.5),
			"effet": "PV max +50 %, mais tu te déplaces 20 % moins vite"},
}


## Définition de l'objet (base ou unique) d'après son dictionnaire.
static func definition(objet: Dictionary) -> Dictionary:
	var cle: String = objet.get("base", "")
	return UNIQUES.get(cle, BASES.get(cle, {}))


static func nom(objet: Dictionary) -> String:
	return definition(objet).get("nom", "Objet inconnu")


static func couleur(objet: Dictionary) -> Color:
	return COULEURS[clampi(int(objet.get("rarete", 0)), 0, COULEURS.size() - 1)]


## « Sabre d'abordage (Rare) »
static func nom_complet(objet: Dictionary) -> String:
	return "%s (%s)" % [nom(objet), NOMS_RARETES[clampi(int(objet.get("rarete", 0)), 0, 4)]]


## Une rareté au hasard (au moins `minimum`), les poids poussés vers le haut par la malédiction.
static func tirer_rarete(rng: RandomNumberGenerator, malediction: int, minimum := 0) -> int:
	var poids: Array[float] = []
	var total := 0.0
	for r in 5:
		var p: float = EQ.butin_poids_raretes[r] * (1.0 + EQ.butin_malediction_raretes[r] * malediction) if r >= minimum else 0.0
		poids.append(p)
		total += p
	var x := rng.randf() * total
	for r in 5:
		x -= poids[r]
		if x < 0.0:
			return r
	return minimum


## Un objet au hasard pour un joueur qui joue `heros` (&"bretteur" ou &"occultiste").
static func tirer_objet(rng: RandomNumberGenerator, heros: StringName, malediction: int, rarete_min := 0) -> Dictionary:
	var rarete := tirer_rarete(rng, malediction, rarete_min)
	var cle := ""
	if rarete >= Rarete.LEGENDAIRE:
		var choix := UNIQUES.keys().filter(func(k): return UNIQUES[k]["rarete"] == rarete and UNIQUES[k]["heros"] in ["", String(heros)])
		cle = choix[rng.randi() % choix.size()]
	else:
		var arme := rng.randf() < EQ.butin_arme
		var choix := BASES.keys().filter(func(k): return BASES[k]["type"] == ("arme" if arme else "relique") \
				and BASES[k]["heros"] in ["", String(heros)])
		cle = choix[rng.randi() % choix.size()]
	return {"id": nouvel_id(rng), "base": cle, "rarete": rarete, "effets": []}


## Identifiant unique d'un objet (pour la sauvegarde et l'anti-doublon).
static func nouvel_id(rng: RandomNumberGenerator) -> String:
	return "%08x%08x" % [rng.randi(), int(Time.get_unix_time_from_system() * 1000.0) & 0xffffffff]


## Chance qu'un squelette vaincu lâche un objet (pour chaque joueur), malédiction comprise.
static func chance_objet(type_ennemi: StringName) -> float:
	var base := EQ.butin_objet_matelot
	match type_ennemi:
		&"arbaletrier": base = EQ.butin_objet_arbaletrier
		&"pretre": base = EQ.butin_objet_pretre
	return base * Malediction.mult_butin()
