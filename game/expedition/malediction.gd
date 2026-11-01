class_name Malediction
extends RefCounted
## La malédiction de l'expédition (choix de Téo) : un niveau de 0 à 5 choisi avant le départ (écran du
## héros en solo, écran « Jouer à deux » pour l'hôte, transmis à l'invité). Les effets se cumulent : le
## niveau 3 contient aussi les effets 1 et 2. Plus le niveau est haut, meilleur sera le butin (+20 % par
## niveau : plus d'objets, et plus rares). Seulement en expédition (l'arène reste
## au niveau 0). Les deux téléphones connaissent le niveau : chacun calcule les mêmes PV maximum.

const EQ: Equilibrage = preload("res://data/equilibrage.tres")
const MAX := 5
const NOMS: Array[String] = ["Aucune", "Os durcis", "Équipage nombreux", "Lames maudites", "Mer avare", "Bosco enragé"]
const EFFETS: Array[String] = [
	"",
	"Squelettes +25 % PV",
	"+2 squelettes par salle, 1 de plus debout",
	"Squelettes +25 % de dégâts",
	"Orbes de vie 2 fois plus rares, coffre moitié moins",
	"Bosco enragé dès le début, pièges plus rapides",
]


## Niveau en cours (0 hors de l'expédition).
static func niveau() -> int:
	if Partie.destination != &"expedition":
		return 0
	return clampi(Partie.malediction, 0, MAX)


## 1 « Os durcis » : PV maximum des squelettes (Bosco compris).
static func mult_pv() -> float:
	return 1.0 + EQ.mal_pv if niveau() >= 1 else 1.0


## 2 « Équipage nombreux » : squelettes en plus dans une salle (et à chaque vague de la chaloupe).
static func bonus_ennemis() -> int:
	return EQ.mal_ennemis_salle if niveau() >= 2 else 0


static func bonus_ensemble() -> int:
	return EQ.mal_ensemble if niveau() >= 2 else 0


## 3 « Lames maudites » : dégâts reçus par un héros, venant d'un squelette (coup, carreau, flaque) ;
## pas les pièges.
static func mult_degats_recus(source: Node) -> float:
	if niveau() < 3 or source == null:
		return 1.0
	if source is Ennemi or source is FlaqueMaudite or (source is Carreau and not source.renvoye):
		return 1.0 + EQ.mal_degats
	return 1.0


## 4 « Mer avare » : chance d'orbe de vie et soin du coffre.
static func mult_orbes() -> float:
	return EQ.mal_orbes if niveau() >= 4 else 1.0


static func mult_coffre() -> float:
	return EQ.mal_coffre if niveau() >= 4 else 1.0


## 5 « Bosco enragé » : enragé dès le début ; pièges plus rapides.
static func bosco_enrage() -> bool:
	return niveau() >= 5


static func vitesse_pieges() -> float:
	return EQ.mal_vitesse_pieges if niveau() >= 5 else 1.0


## Bonus de butin (×1,0 à ×2,0) : multiplie la chance qu'un squelette lâche un objet.
static func mult_butin(n := -1) -> float:
	return 1.0 + EQ.mal_butin * (niveau() if n < 0 else n)


## « Malédiction 3 — Lames maudites » ; niveau 0 : « Aucune malédiction ».
static func titre(n: int) -> String:
	return "Aucune malédiction" if n <= 0 else "Malédiction %d — %s" % [n, NOMS[n]]


## Les effets actifs à ce niveau, un par ligne (cumulés).
static func effets(n: int) -> String:
	var lignes: Array[String] = []
	for i in range(1, clampi(n, 0, MAX) + 1):
		lignes.append(EFFETS[i])
	return "\n".join(lignes) if not lignes.is_empty() else "Le Récif tel qu'il est"


## « ×1,6 » (virgule à la française).
static func texte_butin(n: int) -> String:
	return ("×%.1f" % mult_butin(n)).replace(".", ",")
