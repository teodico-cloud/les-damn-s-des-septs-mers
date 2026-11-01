class_name Equipement
extends RefCounted
## Ce que font les objets portés (jalon 4, étape 2 ; liste validée par Téo le 01/11). Chaque héros porte
## une arme et deux reliques ; `bonus()` additionne leurs effets en un dictionnaire {effet: valeur}
## que le héros lit (`Heros.b("degats")`…). `textes()` et `comparer()` servent à l'écran Équipement.
##
## Effets (valeurs : 0,10 = 10 %) : degats, vitesse_attaque, critique, pv (PV en plus), pv_pourcent,
## vitesse (déplacement), recharges (les 3), recharge_sorts (Marque et Chaînes), recharge_esquive
## (roulade, téléportation), vol_de_vie, doublons, orbes (soin des orbes), epines (corps-à-corps),
## geolier (dégâts sur un squelette étourdi ou enchaîné), flasque (PV rendus à chaque salle nettoyée),
## orbes_nulles (Talisman du Pendu) ; objets uniques : lame_du_noye, grimoire_du_pendu, sablier_maree.

const EQ: Equilibrage = preload("res://data/equilibrage.tres")
const EMPLACEMENTS: Array[String] = ["arme", "relique_1", "relique_2"]
const NOMS_EMPLACEMENTS := {"arme": "Arme", "relique_1": "Relique", "relique_2": "Relique"}
## Effets dont « plus » est un défaut (pour les flèches ▲▼ de la comparaison).
const DEFAUTS: Array[String] = ["orbes_nulles"]
const MOINS := "−"   ## vrai signe moins (plus lisible que le trait d'union)
## Ordre d'affichage des effets.
const ORDRE: Array[String] = ["degats", "vitesse_attaque", "critique", "pv", "pv_pourcent", "vitesse", "recharges",
		"recharge_sorts", "recharge_esquive", "vol_de_vie", "epines", "geolier", "orbes", "flasque", "doublons",
		"orbes_nulles", "lame_du_noye", "grimoire_du_pendu", "sablier_maree"]


## Effets d'un objet : son effet de base (× la rareté pour un objet de base ; un défaut ne grossit
## jamais), plus ses effets en plus tirés quand il est tombé.
static func effets(objet: Dictionary) -> Dictionary:
	var r := {}
	if objet.is_empty():
		return r
	var cle_base: String = objet.get("base", "")
	var def := Butin.definition(objet)
	var mult := 1.0
	if not Butin.UNIQUES.has(cle_base):
		mult = EQ.equip_mult_raretes[clampi(int(objet.get("rarete", 0)), 0, EQ.equip_mult_raretes.size() - 1)]
	var base: Dictionary = def.get("effets", {})
	for cle in base:
		var v := float(base[cle])
		r[cle] = float(r.get(cle, 0.0)) + (v * mult if v > 0.0 else v)
	var plus = objet.get("effets", {})
	if plus is Dictionary:
		for cle in plus:
			r[cle] = float(r.get(cle, 0.0)) + float(plus[cle])
	return r


## Tous les effets des objets portés, additionnés.
static func bonus(objets: Array) -> Dictionary:
	var r := {}
	for o in objets:
		if o is Dictionary:
			var e := effets(o)
			for cle in e:
				r[cle] = float(r.get(cle, 0.0)) + e[cle]
	return r


## L'objet va-t-il à cet emplacement de ce héros ? (arme : celles du héros ; reliques : toutes)
static func convient(objet: Dictionary, heros: StringName, emplacement: String) -> bool:
	var def := Butin.definition(objet)
	if def.is_empty():
		return false
	if emplacement == "arme":
		return def.get("type") == "arme" and def.get("heros") == String(heros)
	return def.get("type") == "relique"


## Les lignes d'effets d'un objet, dans l'ordre : [[texte, bon?], …].
static func textes(objet: Dictionary) -> Array:
	var e := effets(objet)
	var r := []
	for cle in _ordonner(e.keys()):
		r.append([texte(cle, e[cle]), _bon(cle, e[cle])])
	return r


## « +10 % de dégâts », « −15 % de vitesse d'attaque », « +15 PV max »…
static func texte(cle: String, v: float) -> String:
	var p := _pourcent(v)
	match cle:
		"degats": return "%s de dégâts" % p
		"vitesse_attaque": return "%s de vitesse d'attaque" % p
		"critique": return "%s de coups critiques" % p
		"pv": return "%s PV max" % _signe(roundi(v))
		"pv_pourcent": return "%s de PV max" % p
		"vitesse": return "%s de vitesse de déplacement" % p
		"recharges": return "Recharges %s" % _pourcent(-v)
		"recharge_sorts": return "Marque et Chaînes : recharge %s" % _pourcent(-v)
		"recharge_esquive": return "Roulade, téléportation : recharge %s" % _pourcent(-v)
		"vol_de_vie": return "Vol de vie %s" % _pourcent(v, false)
		"doublons": return "%s de doublons" % p
		"orbes": return "Orbes de vie : soin %s" % p
		"epines": return "Épines %s (coups au corps-à-corps renvoyés)" % _pourcent(v, false)
		"geolier": return "%s de dégâts sur un squelette étourdi ou enchaîné" % p
		"flasque": return "%s des PV rendus à chaque salle nettoyée" % _pourcent(v, false)
		"orbes_nulles": return "Les orbes de vie ne vous soignent plus"
	for u in Butin.UNIQUES:   # lame_du_noye… : la phrase de l'objet unique
		if Butin.UNIQUES[u].get("effets", {}).has(cle) and Butin.UNIQUES[u]["effets"][cle] == 1.0:
			return Butin.UNIQUES[u]["effet"]
	return cle


## Comparaison (annexe retenue par Téo) : ce qui change en passant des effets `avant` aux effets
## `apres` : [[« ▲ +10 % de dégâts », vrai], [« ▼ −15 % de vitesse d'attaque », faux], …].
static func comparer(avant: Dictionary, apres: Dictionary) -> Array:
	var cles := avant.keys()
	for c in apres:
		if not c in cles:
			cles.append(c)
	var r := []
	for cle in _ordonner(cles):
		var d := float(apres.get(cle, 0.0)) - float(avant.get(cle, 0.0))
		if absf(d) < 0.0005:
			continue
		var bon := _bon(cle, d)
		var t: String
		if cle == "orbes_nulles":
			t = texte(cle, 1.0) if d > 0.0 else "Les orbes de vie vous soignent de nouveau"
		elif not _est_valeur(cle):   # un effet tout ou rien : gagné ou perdu
			t = texte(cle, 1.0) if d > 0.0 else "Perdu : " + texte(cle, 1.0)
		else:
			t = texte(cle, d)
		r.append([("▲ " if bon else "▼ ") + t, bon])
	return r


## Les effets du héros avec `objet` à la place de ce qu'il porte à `emplacement`.
static func avec(portes: Dictionary, emplacement: String, objet: Dictionary) -> Dictionary:
	var copie := portes.duplicate()
	copie[emplacement] = objet
	return bonus(copie.values())


static func _est_valeur(cle: String) -> bool:
	for u in Butin.UNIQUES:
		if Butin.UNIQUES[u].get("effets", {}).get(cle, 0.0) == 1.0 and cle != "degats":
			return false
	return true


static func _bon(cle: String, v: float) -> bool:
	return (v < 0.0) if cle in DEFAUTS else (v > 0.0)


static func _ordonner(cles: Array) -> Array:
	var r := []
	for c in ORDRE:
		if c in cles:
			r.append(c)
	for c in cles:
		if not c in r:
			r.append(c)
	return r


static func _pourcent(v: float, signe := true) -> String:
	var n := roundi(v * 100.0)
	return (_signe(n) if signe else str(absi(n))) + " %"


static func _signe(n: int) -> String:
	return ("+%d" % n) if n >= 0 else (MOINS + str(-n))
