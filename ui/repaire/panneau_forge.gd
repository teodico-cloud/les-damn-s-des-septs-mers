class_name PanneauForge
extends PanneauRepaire
## La forge (jalon 5, étape 3 : choix de Téo) en trois onglets :
## - Améliorer : une arme Commune ou Rare monte d'une rareté (effet de base plus fort, un effet en plus au hasard).
## - Recycler : un objet devient des matériaux (deux appuis pour confirmer ; porté, il est retiré). Au-delà du
##   plafond de l'entrepôt, le reste est perdu (écrit avant d'appuyer) ; sans aucune place, bouton grisé.
## - Relancer (forge niveau 2) : on touche l'effet en plus qu'on n'aime pas, il est remplacé au hasard.
## Sans le niveau 2, l'onglet Relancer propose d'agrandir la forge.

signal change   ## un achat : le repaire met à jour ses pastilles

const ONGLETS := {"ameliorer": "Améliorer", "recycler": "Recycler", "relancer": "Relancer"}
const NOMS_HEROS := {&"bretteur": "le Bretteur", &"occultiste": "l'Occultiste"}

var onglet := "ameliorer"
var boutons_onglets := {}
var boutons := {}            ## id d'objet -> bouton (améliorer ou recycler)
var boutons_relance := {}    ## "id|effet" -> bouton
var bouton_agrandir: Button
var a_confirmer := ""        ## recycler : l'objet qui attend le second appui
var dernier := ""            ## ce qui vient de se passer (« Recyclé : +4 fer noir »)


func _init() -> void:
	titre = "Forge"


func choisir_onglet(o: String) -> void:
	onglet = o
	a_confirmer = ""
	dernier = ""
	rafraichir()


func _remplir() -> void:
	boutons.clear()
	boutons_relance.clear()
	bouton_agrandir = null
	var parts := ["%d doublons" % Sauvegarde.doublons()]
	for m in Butin.MATIERES:
		parts.append(Butin.texte_tas(m, Sauvegarde.ressource(m)))
	contenu.add_child(StyleRepaire.texte(" · ".join(parts), 24, StyleRepaire.OR_VIF))
	var rangee := HBoxContainer.new()
	rangee.add_theme_constant_override("separation", 12)
	contenu.add_child(rangee)
	for o in ONGLETS:
		var b := StyleRepaire.bouton(ONGLETS[o], Vector2(220, 60), 26)
		b.theme_type_variation = &"BoutonOngletActif" if o == onglet else &"BoutonOnglet"
		b.pressed.connect(choisir_onglet.bind(o))
		rangee.add_child(b)
		boutons_onglets[o] = b
	if dernier != "":
		var l := StyleRepaire.texte(dernier, 22, StyleRepaire.VERT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # (un effet relancé peut faire une longue ligne)
		contenu.add_child(l)
	match onglet:
		"ameliorer":
			_ameliorer()
		"recycler":
			_recycler()
		"relancer":
			_relancer()


# ---------------------------------------------------------------- améliorer
func _ameliorer() -> void:
	var armes := Sauvegarde.objets().filter(func(o): return Forge.ameliorable(o))
	armes.sort_custom(func(a, b): return int(a["rarete"]) > int(b["rarete"]) if int(a["rarete"]) != int(b["rarete"]) else Butin.nom(a) < Butin.nom(b))
	if armes.is_empty():
		contenu.add_child(StyleRepaire.texte("Aucune arme Commune ou Rare dans les coffres.", 22, Color(StyleRepaire.COULEUR_OS, 0.7)))
		return
	for o in armes:
		var p := Forge.prix_amelioration(o)
		var manque := Bateau.manque(p)
		var suivante: String = Butin.NOMS_RARETES[int(o["rarete"]) + 1]
		var b := StyleRepaire.bouton("Améliorer", Vector2(210, 60), 26)
		b.disabled = not manque.is_empty()
		b.pressed.connect(ameliorer.bind(o["id"], int(o["rarete"])))
		boutons[o["id"]] = b
		var lignes := ["→ %s : effet de base plus fort et un effet en plus au hasard" % suivante, _texte_prix(p, manque)]
		contenu.add_child(_ligne(o, lignes, [StyleRepaire.COULEUR_OS, StyleRepaire.COULEUR_OS if manque.is_empty() else StyleRepaire.ROUGE], b))


func ameliorer(id: String, rarete: int) -> void:
	if not appui_accepte():
		return
	if Sauvegarde.ameliorer_objet(id, rarete):
		Sons.jouer(&"enclume")
		var o := Sauvegarde.objet(id)
		dernier = "%s : maintenant %s" % [Butin.nom(o), Butin.NOMS_RARETES[int(o["rarete"])]]
		change.emit()
	rafraichir()


# ---------------------------------------------------------------- recycler
func _recycler() -> void:
	var objets := Sauvegarde.objets().duplicate()
	objets.sort_custom(func(a, b): return int(a["rarete"]) < int(b["rarete"]) if int(a["rarete"]) != int(b["rarete"]) else Butin.nom(a) < Butin.nom(b))
	if objets.is_empty():
		contenu.add_child(StyleRepaire.texte("Les coffres sont vides.", 22, Color(StyleRepaire.COULEUR_OS, 0.7)))
		return
	for o in objets:
		var confirmer: bool = a_confirmer == o["id"]
		var b := StyleRepaire.bouton("Sûr ? Recycler" if confirmer else "Recycler", Vector2(210, 60), 24,
				StyleRepaire.ROUGE if confirmer else StyleRepaire.COULEUR_OS)
		b.pressed.connect(recycler.bind(o["id"]))
		boutons[o["id"]] = b
		var r := Forge.recyclage_range(o)
		var lignes := []
		if not Forge.recyclable(o):
			b.disabled = true
			lignes.append("Rendrait %s : entrepôt plein" % Butin.texte_matieres(Forge.recyclage(o)))
		else:
			lignes.append("Rend : " + Butin.texte_matieres(r["gardees"]))
			if Butin.texte_matieres(r["perdues"]) != "":
				lignes.append(_texte_perdues(r["perdues"]) + " : entrepôt presque plein")
		var ou := Sauvegarde.ou_est_porte(o["id"])
		if not ou.is_empty():
			lignes.append("Porté par %s : il sera retiré" % NOMS_HEROS.get(ou[0], "un héros"))
		var couleurs := [StyleRepaire.ROUGE if b.disabled else StyleRepaire.COULEUR_OS, StyleRepaire.ROUGE]
		contenu.add_child(_ligne(o, lignes, couleurs, b))


## Premier appui : on demande confirmation ; second appui sur le même objet (pas un double appui : au moins
## DELAI_ENTRE_ACTIONS après) : recyclé.
func recycler(id: String) -> void:
	if not appui_accepte():
		return
	if a_confirmer != id:
		a_confirmer = id
		rafraichir()
		return
	a_confirmer = ""
	var o := Sauvegarde.objet(id)
	var r := Sauvegarde.recycler(id)
	if not r.is_empty():
		Sons.jouer(&"marteau")
		dernier = "%s recyclé : +%s" % [Butin.nom(o), Butin.texte_matieres(r["gardees"])]
		if Butin.texte_matieres(r["perdues"]) != "":
			dernier += " (%s : entrepôt plein)" % _texte_perdues(r["perdues"])
		change.emit()
	rafraichir()


# ---------------------------------------------------------------- relancer (forge niveau 2)
func _relancer() -> void:
	if Sauvegarde.niveau_repaire("forge") < 2:
		var p := Forge.prix_niveau_2("forge")
		var manque := Bateau.manque(p)
		contenu.add_child(StyleRepaire.texte("Agrandir la forge (niveau 2) : on pourra relancer un effet en plus d'un objet.", 22))
		contenu.add_child(StyleRepaire.texte(_texte_prix(p, manque), 22, StyleRepaire.COULEUR_OS if manque.is_empty() else StyleRepaire.ROUGE))
		bouton_agrandir = StyleRepaire.bouton("Agrandir la forge", Vector2(320, 70), 28)
		bouton_agrandir.disabled = not manque.is_empty()
		bouton_agrandir.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		bouton_agrandir.pressed.connect(agrandir)
		contenu.add_child(bouton_agrandir)
		return
	var p := Forge.prix_relance()
	var manque := Bateau.manque(p)
	var consigne := StyleRepaire.texte("Touchez l'effet à relancer : il est remplacé au hasard. " + _texte_prix(p, manque), 20,
			StyleRepaire.COULEUR_OS if manque.is_empty() else StyleRepaire.ROUGE)
	consigne.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # (avec « il manque … », la ligne s'allonge)
	contenu.add_child(consigne)
	var objets := Sauvegarde.objets().filter(func(o): return not Forge.effets_relancables(o).is_empty())
	objets.sort_custom(func(a, b): return int(a["rarete"]) > int(b["rarete"]))
	if objets.is_empty():
		contenu.add_child(StyleRepaire.texte("Aucun objet avec un effet en plus (Rare ou Épique).", 22, Color(StyleRepaire.COULEUR_OS, 0.7)))
		return
	for o in objets:
		var cadre := _cadre()
		var colonne := VBoxContainer.new()
		cadre.add_child(colonne)
		colonne.add_child(StyleRepaire.texte(Butin.nom_complet(o), 24, Butin.couleur(o)))
		var rangee := HFlowContainer.new()   # (deux longs effets passent à la ligne au lieu de sortir du cadre)
		rangee.add_theme_constant_override("h_separation", 10)
		rangee.add_theme_constant_override("v_separation", 8)
		colonne.add_child(rangee)
		for e in Forge.effets_relancables(o):
			var b := StyleRepaire.bouton("Relancer : " + Equipement.texte(e, float(o["effets"][e])), Vector2(0, 54), 20)
			b.disabled = not manque.is_empty()
			b.pressed.connect(relancer.bind(o["id"], e))
			rangee.add_child(b)
			boutons_relance["%s|%s" % [o["id"], e]] = b
		contenu.add_child(cadre)


func relancer(id: String, effet: String) -> void:
	if not appui_accepte():
		return
	var o := Sauvegarde.objet(id)
	var avant := Equipement.texte(effet, float(o.get("effets", {}).get(effet, 0.0)))
	var nouveau := Sauvegarde.relancer_effet(id, effet)
	if nouveau != "":
		Sons.jouer(&"enclume")
		dernier = "%s : %s → %s" % [Butin.nom(o), avant, Equipement.texte(nouveau, float(o["effets"][nouveau]))]
		change.emit()
	rafraichir()


func agrandir() -> void:
	if not appui_accepte():
		return
	if Sauvegarde.agrandir("forge"):
		Sons.jouer(&"marteau")
		dernier = "La forge est agrandie : on peut relancer un effet."
		change.emit()
	rafraichir()


# ---------------------------------------------------------------- mise en page
func _cadre() -> PanelContainer:
	return StyleRepaire.cadre()


## Un objet : son nom (à la couleur de sa rareté), des lignes, un bouton à droite.
func _ligne(o: Dictionary, lignes: Array, couleurs: Array, b: Button) -> Control:
	var cadre := _cadre()
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override("separation", 16)
	cadre.add_child(ligne)
	var gauche := VBoxContainer.new()
	gauche.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gauche.add_theme_constant_override("separation", 0)
	ligne.add_child(gauche)
	gauche.add_child(StyleRepaire.texte(Butin.nom_complet(o), 24, Butin.couleur(o)))
	for i in lignes.size():
		gauche.add_child(StyleRepaire.texte(lignes[i], 20, couleurs[mini(i, couleurs.size() - 1)]))
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ligne.add_child(b)
	return cadre


## « 2 fer noir perdus »
static func _texte_perdues(perdues: Dictionary) -> String:
	var n := 0
	for m in perdues:
		n += int(perdues[m])
	return Butin.texte_matieres(perdues) + (" perdus" if n > 1 else " perdu")


static func _texte_prix(p: Dictionary, manque: Dictionary) -> String:
	var t := "Prix : " + Bateau.texte_prix(p)
	if not manque.is_empty():
		t += "  (il manque " + Bateau.texte_prix(manque) + ")"
	return t
