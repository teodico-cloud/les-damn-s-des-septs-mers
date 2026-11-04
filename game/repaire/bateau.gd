class_name Bateau
extends RefCounted
## Le bateau et ses quatre améliorations (jalon 5, étape 2 : choix de Téo du 04/11), trois niveaux chacune,
## achetées au chantier naval avec des doublons et des matériaux. Ce qu'elles font pendant l'expédition :
## Cale (objets rapportés), Voiles (moins de temps à tenir dans la chaloupe), Coque renforcée (malédiction
## de départ plus haute), Bordée (tirs de canon). Les niveaux sont dans la sauvegarde (Sauvegarde.niveau_bateau).

const EQ: Equilibrage = preload("res://data/equilibrage.tres")
const AMELIORATIONS: Array[String] = ["cale", "voiles", "coque", "bordee"]
const NOMS := {"cale": "Cale", "voiles": "Voiles", "coque": "Coque renforcée", "bordee": "Bordée"}
const NIVEAU_MAX := 3


# ---------------------------------------------------------------- ce que donne chaque niveau
static func places_cale(niveau: int) -> int:
	return EQ.cale_places if niveau <= 0 else EQ.bateau_cale[mini(niveau, NIVEAU_MAX) - 1]


static func duree_chaloupe(niveau_voiles: int) -> float:
	return EQ.chaloupe_duree if niveau_voiles <= 0 else EQ.bateau_voiles[mini(niveau_voiles, NIVEAU_MAX) - 1]


static func malediction_max(niveau_coque: int) -> int:
	return EQ.bateau_coque[clampi(niveau_coque, 0, NIVEAU_MAX)]


static func tirs_bordee(niveau: int) -> int:
	return EQ.bateau_bordee[clampi(niveau, 0, NIVEAU_MAX)]


## « 12 objets rapportés », « 35 s à tenir dans la chaloupe »…
static func texte_effet(amelioration: String, niveau: int) -> String:
	match amelioration:
		"cale":
			return "%d objets rapportés" % places_cale(niveau)
		"voiles":
			return "%d s à tenir dans la chaloupe" % int(duree_chaloupe(niveau))
		"coque":
			return "Malédiction de départ jusqu'à %d" % malediction_max(niveau)
		"bordee":
			var n := tirs_bordee(niveau)
			return "Aucun tir de canon" if n == 0 else "%d tir%s de canon par expédition" % [n, "s" if n > 1 else ""]
	return ""


# ---------------------------------------------------------------- prix
## Le prix du niveau `niveau` (1 à 3) : {"doublons": …, "bois": …} ; vide au-delà du niveau 3.
static func prix(amelioration: String, niveau: int) -> Dictionary:
	if niveau < 1 or niveau > NIVEAU_MAX:
		return {}
	var table: Array = EQ.bateau_prix.get(amelioration, [])
	return table[niveau - 1] if niveau - 1 < table.size() else {}


## « 120 doublons · 30 bois de coque · 5 essence maudite »
static func texte_prix(p: Dictionary) -> String:
	var parts := []
	if int(p.get("doublons", 0)) > 0:
		parts.append("%d doublons" % int(p["doublons"]))
	var m := Butin.texte_matieres(p)
	if m != "":
		parts.append(m)
	return " · ".join(parts)


## Ce qui manque pour payer `p` avec ce qu'il y a dans la sauvegarde (vide : on peut payer).
static func manque(p: Dictionary) -> Dictionary:
	var r := {}
	var d := int(p.get("doublons", 0)) - Sauvegarde.doublons()
	if d > 0:
		r["doublons"] = d
	for m in Butin.MATIERES:
		var n := int(p.get(m, 0)) - Sauvegarde.ressource(m)
		if n > 0:
			r[m] = n
	return r


## Une amélioration peut-elle être achetée maintenant (pastille « ! » du chantier) ?
static func achat_possible() -> bool:
	for a in AMELIORATIONS:
		var n := Sauvegarde.niveau_bateau(a)
		if n < NIVEAU_MAX and manque(prix(a, n + 1)).is_empty():
			return true
	return false


# ---------------------------------------------------------------- ce qui compte pendant l'expédition
## Places de la cale de ce téléphone (chacun la sienne à deux).
static func ma_cale() -> int:
	return places_cale(Sauvegarde.niveau_bateau("cale"))


## Malédiction de départ la plus haute permise (coque de ce téléphone ; à deux : celle de l'hôte). Le Mode
## test peut tout débloquer.
static func ma_malediction_max() -> int:
	if Partie.debug_tout_debloque:
		return Malediction.MAX
	return malediction_max(Sauvegarde.niveau_bateau("coque"))


## Durée de la chaloupe : seul, ses voiles ; à deux, les meilleures voiles des deux bateaux.
static func duree_chaloupe_partie() -> float:
	var n := Sauvegarde.niveau_bateau("voiles")
	if Reseau.est_en_coop():
		n = maxi(n, int(Reseau.bateau_partenaire.get("voiles", 0)))
	return duree_chaloupe(n)


## Les niveaux du bateau de ce téléphone (envoyés à l'autre à la connexion).
static func niveaux() -> Dictionary:
	var r := {}
	for a in AMELIORATIONS:
		r[a] = Sauvegarde.niveau_bateau(a)
	return r


## Niveaux reçus de l'autre téléphone : seulement les quatre améliorations, de 0 à 3.
static func niveaux_valides(d: Variant) -> Dictionary:
	var r := {}
	for a in AMELIORATIONS:
		r[a] = clampi(int(d.get(a, 0)), 0, NIVEAU_MAX) if d is Dictionary else 0
	return r
