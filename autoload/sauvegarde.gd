extends Node
## Sauvegarde locale (autoload « Sauvegarde », jalon 4) : un fichier JSON sur le téléphone, avec un
## numéro de version. Ce qui est gardé : les doublons, les objets rapportés (les coffres), l'équipement
## de chaque héros, les expéditions déjà encaissées (une même expédition n'est jamais comptée deux fois)
## et l'historique des 20 dernières.
##
## Écriture sûre : on écrit un fichier temporaire, on le relit pour vérifier, on garde une copie de
## secours de l'ancien, puis on remplace. À la lecture : le fichier, sinon la copie de secours, sinon un
## profil neuf. Enregistré au départ et à la fin d'une expédition, à chaque changement d'équipement et
## quand l'appli passe en arrière-plan ou se ferme.

signal changee   ## doublons, objets ou équipement ont changé

const VERSION := 1
const CHEMIN_JEU := "user://sauvegarde.json"
const MAX_EXPEDITIONS := 200    ## identifiants d'expéditions encaissées gardés (anti-doublon)
const MAX_HISTORIQUE := 20

var chemin := CHEMIN_JEU         ## les tests en prennent un autre (tests/pre_run.gd)
var donnees := {}
var restauree := false           ## vrai si le fichier était illisible et que la copie de secours a servi


func _ready() -> void:
	charger()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		enregistrer()


# ---------------------------------------------------------------- lecture et écriture
static func profil_neuf() -> Dictionary:
	return {
		"version": VERSION,
		"doublons": 0,
		"objets": [],
		"equipement": {"bretteur": _vide(), "occultiste": _vide()},
		"expeditions": [],
		"historique": [],
	}


static func _vide() -> Dictionary:
	return {"arme": "", "relique_1": "", "relique_2": ""}


func charger() -> void:
	restauree = false
	var d = _lire(chemin)
	if d == null and not FileAccess.file_exists(chemin):
		d = _lire(chemin + ".tmp")   # (coupure entre les deux renommages : le nouveau fichier, déjà vérifié)
	if d == null:
		d = _lire(chemin + ".bak")
		restauree = d != null and FileAccess.file_exists(chemin)
	donnees = convertir(d) if d is Dictionary else profil_neuf()
	if restauree:
		enregistrer()   # le fichier abîmé est remplacé par la copie de secours
	_finir_tri_en_attente()


## Tri de la cale noté pendant une pause, et l'appli fermée par Android avant la fin du tri : la
## sélection d'alors est encaissée maintenant (une seule fois, comme toute expédition).
func _finir_tri_en_attente() -> void:
	var t = donnees.get("tri_en_attente")
	if t is Dictionary:
		encaisser(t["id"], t["objets"], t["doublons"], t["resume"])


## Pendant le tri de la cale, l'appli passe en arrière-plan : la sélection du moment est notée.
func noter_tri_en_attente(id_expedition: String, gardes: Array, p_doublons: int, resume: Dictionary) -> void:
	donnees["tri_en_attente"] = {"id": id_expedition, "objets": gardes.map(func(o): return normaliser(o)),
			"doublons": p_doublons, "resume": resume.duplicate()}
	enregistrer()


## Repart d'un profil neuf (tests, ou plus tard « effacer la partie »).
func reinitialiser() -> void:
	donnees = profil_neuf()
	restauree = false
	changee.emit()


static func _lire(p: String) -> Variant:
	if not FileAccess.file_exists(p):
		return null
	var texte := FileAccess.get_file_as_string(p)
	if texte == "":
		return null
	var json := JSON.new()   # (pas JSON.parse_string : un fichier abîmé ne doit rien afficher d'alarmant)
	if json.parse(texte) != OK:
		return null
	var d = json.data
	return d if d is Dictionary and d.has("version") else null


## Met une sauvegarde lue (d'une version plus ancienne, ou incomplète) au format actuel.
static func convertir(d: Dictionary) -> Dictionary:
	var r := profil_neuf()
	# (version 1 : la première ; les conversions des versions suivantes s'ajouteront ici, testées)
	r["doublons"] = maxi(int(d.get("doublons", 0)), 0)
	for o in d.get("objets", []):
		if o is Dictionary and o.has("id") and Butin.definition(o).size() > 0:
			r["objets"].append(normaliser(o))
	var eq = d.get("equipement", {})
	if eq is Dictionary:
		for h in ["bretteur", "occultiste"]:
			if eq.get(h) is Dictionary:
				for e in Equipement.EMPLACEMENTS:
					r["equipement"][h][e] = String(eq[h].get(e, ""))
	for i in d.get("expeditions", []):
		r["expeditions"].append(String(i))
	for h in d.get("historique", []):
		if h is Dictionary:
			r["historique"].append(h)
	# un objet porté doit exister, aller à sa place, et n'être porté qu'une fois (fichier abîmé ou modifié)
	var portes := {}
	for h in ["bretteur", "occultiste"]:
		for e in Equipement.EMPLACEMENTS:
			var id: String = r["equipement"][h][e]
			if id == "":
				continue
			var o := {}
			for x in r["objets"]:
				if x["id"] == id:
					o = x
			if o.is_empty() or portes.has(id) or not Equipement.convient(o, StringName(h), e):
				r["equipement"][h][e] = ""
			else:
				portes[id] = true
	var t = d.get("tri_en_attente")
	if t is Dictionary and t.get("objets") is Array and t.has("id"):
		r["tri_en_attente"] = {"id": String(t["id"]), "doublons": maxi(int(t.get("doublons", 0)), 0),
				"objets": t["objets"].filter(func(o): return o is Dictionary and o.has("id")).map(func(o): return normaliser(o)),
				"resume": t.get("resume", {}) if t.get("resume") is Dictionary else {}}
	r["version"] = VERSION
	return r


## Un objet relu du JSON : les nombres entiers redeviennent entiers.
static func normaliser(o: Dictionary) -> Dictionary:
	var effets := {}
	var e = o.get("effets", {})
	if e is Dictionary:
		for cle in e:
			effets[String(cle)] = float(e[cle])
	return {"id": String(o["id"]), "base": String(o.get("base", "")), "rarete": int(o.get("rarete", 0)), "effets": effets}


## Écriture sûre. Renvoie faux si quelque chose a échoué (l'ancien fichier reste alors intact).
func enregistrer() -> bool:
	donnees["version"] = VERSION
	var texte := JSON.stringify(donnees, "\t")
	var temporaire := chemin + ".tmp"
	var f := FileAccess.open(temporaire, FileAccess.WRITE)
	if f == null:
		push_warning("Sauvegarde impossible (%s)" % error_string(FileAccess.get_open_error()))
		return false
	f.store_string(texte)
	f.close()
	var relu = _lire(temporaire)   # vérifié avant de toucher à l'ancien fichier
	if not (relu is Dictionary) or relu.get("objets", []).size() != donnees["objets"].size():
		push_warning("Sauvegarde : relecture ratée, ancien fichier gardé")
		return false
	if FileAccess.file_exists(chemin) and _lire(chemin) != null:
		# l'ancien fichier devient la copie de secours (renommé, pas recopié : rien n'est réécrit, et une
		# coupure de courant ne peut abîmer les deux à la fois ; un fichier abîmé ne la remplace jamais)
		DirAccess.rename_absolute(chemin, chemin + ".bak")
	if DirAccess.rename_absolute(temporaire, chemin) != OK:
		DirAccess.remove_absolute(chemin)
		if DirAccess.rename_absolute(temporaire, chemin) != OK:
			push_warning("Sauvegarde : remplacement raté")
			return false
	return true


# ---------------------------------------------------------------- doublons et objets
func doublons() -> int:
	return int(donnees.get("doublons", 0))


func objets() -> Array:
	return donnees.get("objets", [])


func objet(id: String) -> Dictionary:
	if id == "":
		return {}
	for o in objets():
		if o["id"] == id:
			return o
	return {}


## Fin d'une expédition : son butin rejoint les coffres, une seule fois par expédition (anti-doublon).
## Renvoie faux si cette expédition était déjà encaissée.
func encaisser(id_expedition: String, nouveaux: Array, p_doublons: int, resume := {}) -> bool:
	var attente_finie := false
	if donnees.get("tri_en_attente", {}).get("id", "") == id_expedition:
		donnees.erase("tri_en_attente")   # (le tri noté pendant une pause est fini)
		attente_finie = true
	if id_expedition in donnees["expeditions"]:
		if attente_finie:
			enregistrer()
		return false
	donnees["expeditions"].append(id_expedition)
	while donnees["expeditions"].size() > MAX_EXPEDITIONS:
		donnees["expeditions"].pop_front()
	for o in nouveaux:
		if o is Dictionary and o.has("id") and objet(String(o["id"])).is_empty():
			donnees["objets"].append(normaliser(o))
	donnees["doublons"] = doublons() + maxi(p_doublons, 0)
	var h := resume.duplicate()
	h["id"] = id_expedition
	h["date"] = Time.get_datetime_string_from_system()
	h["objets"] = nouveaux.size()
	h["doublons"] = p_doublons
	donnees["historique"].append(h)
	while donnees["historique"].size() > MAX_HISTORIQUE:
		donnees["historique"].pop_front()
	enregistrer()
	changee.emit()
	return true


# ---------------------------------------------------------------- équipement
## L'objet porté à cet emplacement (« arme », « relique_1 », « relique_2 ») ; vide s'il n'y a rien.
func porte(heros: StringName, emplacement: String) -> Dictionary:
	return objet(String(donnees["equipement"].get(String(heros), {}).get(emplacement, "")))


## Ce que porte le héros, par emplacement.
func portes(heros: StringName) -> Dictionary:
	var r := {}
	for e in Equipement.EMPLACEMENTS:
		r[e] = porte(heros, e)
	return r


## Les objets portés par le héros (ce que reçoit Heros.equiper), arme d'abord.
func equipes(heros: StringName) -> Array:
	var r := []
	for e in Equipement.EMPLACEMENTS:
		var o := porte(heros, e)
		if not o.is_empty():
			r.append(o)
	return r


## Le héros et l'emplacement où cet objet est porté ([] s'il ne l'est pas).
func ou_est_porte(id: String) -> Array:
	for h in donnees["equipement"]:
		for e in Equipement.EMPLACEMENTS:
			if donnees["equipement"][h].get(e, "") == id:
				return [StringName(h), e]
	return []


## Équipe un objet des coffres. Un objet n'est porté qu'à un seul endroit à la fois : déjà porté
## ailleurs (autre relique, autre héros), il y est retiré. Renvoie faux si l'objet ne va pas là.
func equiper(heros: StringName, emplacement: String, id: String) -> bool:
	var o := objet(id)
	if o.is_empty() or not Equipement.convient(o, heros, emplacement):
		return false
	var ancien := ou_est_porte(id)
	if not ancien.is_empty():
		donnees["equipement"][String(ancien[0])][ancien[1]] = ""
	donnees["equipement"][String(heros)][emplacement] = id
	enregistrer()
	changee.emit()
	return true


func retirer(heros: StringName, emplacement: String) -> void:
	donnees["equipement"][String(heros)][emplacement] = ""
	enregistrer()
	changee.emit()
