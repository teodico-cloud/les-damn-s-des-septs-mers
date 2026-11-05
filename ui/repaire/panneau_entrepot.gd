class_name PanneauEntrepot
extends PanneauRepaire
## Entrepôt (jalon 5) : les doublons, les matériaux et leur plafond (choix de Téo : au-delà, le surplus
## rapporté est revendu en doublons), les objets des coffres, et l'écran Équipement.

signal equipement_demande
signal agrandi   ## jalon 5, étape 3 : l'entrepôt est passé au niveau 2

const LARGEUR_JAUGE := 520.0
const EQ_PLAFONDS_2: Dictionary = preload("res://data/equilibrage.tres").mat_plafonds_niveau_2

var bouton_equipement: Button
var bouton_agrandir: Button


func _init() -> void:
	titre = "Entrepôt"


func _remplir() -> void:
	contenu.add_child(StyleRepaire.texte("%d doublons" % Sauvegarde.doublons(), 32, Butin.COULEURS_TAS["doublons"]))
	contenu.add_child(StyleRepaire.texte("Matériaux (entrepôt niveau %d)" % Sauvegarde.niveau_repaire("entrepot"),
			24, Color(StyleRepaire.COULEUR_OS, 0.7)))
	for m in Butin.MATIERES:
		contenu.add_child(_ligne_matiere(m))
	contenu.add_child(StyleRepaire.texte("Au-delà du plafond, ce que vous rapportez est revendu en doublons.", 20,
			Color(StyleRepaire.COULEUR_OS, 0.6)))
	if Sauvegarde.niveau_repaire("entrepot") < 2:   # (étape 3 : agrandir l'entrepôt)
		var p := Forge.prix_niveau_2("entrepot")
		var manque := Bateau.manque(p)
		var ligne := HBoxContainer.new()
		ligne.add_theme_constant_override("separation", 16)
		var textes := VBoxContainer.new()
		textes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var plafonds := []
		for m in Butin.MATIERES:
			plafonds.append(str(int(EQ_PLAFONDS_2.get(m, 0))))
		textes.add_child(StyleRepaire.texte("Niveau 2 : plafonds %s" % " / ".join(plafonds), 22))
		var t := "Prix : " + Bateau.texte_prix(p)
		if not manque.is_empty():
			t += "  (il manque " + Bateau.texte_prix(manque) + ")"
		textes.add_child(StyleRepaire.texte(t, 20, StyleRepaire.COULEUR_OS if manque.is_empty() else StyleRepaire.ROUGE))
		ligne.add_child(textes)
		bouton_agrandir = StyleRepaire.bouton("Agrandir", Vector2(210, 60), 26, StyleRepaire.OR_VIF)
		bouton_agrandir.disabled = not manque.is_empty()
		bouton_agrandir.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bouton_agrandir.pressed.connect(agrandir)
		ligne.add_child(bouton_agrandir)
		contenu.add_child(ligne)
	var objets := Sauvegarde.objets()
	var portes := objets.filter(func(o): return not Sauvegarde.ou_est_porte(o["id"]).is_empty()).size()
	contenu.add_child(StyleRepaire.texte("Coffres : %d objet%s, dont %d porté%s" % [objets.size(), "s" if objets.size() > 1 else "",
			portes, "s" if portes > 1 else ""], 26))
	bouton_equipement = StyleRepaire.bouton("Équipement", Vector2(320, 80), 30, StyleRepaire.OR_VIF)
	bouton_equipement.pressed.connect(func(): equipement_demande.emit())
	bouton_equipement.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	contenu.add_child(bouton_equipement)


## « Bois de coque   12 / 150 » et sa jauge.
func _ligne_matiere(m: String) -> Control:
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override("separation", 18)
	var nom := StyleRepaire.texte(_majuscule(Butin.NOMS_MATIERES[m]), 28, Butin.COULEURS_TAS[m])
	nom.custom_minimum_size = Vector2(260, 0)
	ligne.add_child(nom)
	var n := Sauvegarde.ressource(m)
	var plafond := Sauvegarde.plafond(m)
	var jauge := Control.new()
	jauge.custom_minimum_size = Vector2(LARGEUR_JAUGE, 26)
	jauge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fond := ColorRect.new()
	fond.color = Color(0.0, 0.0, 0.0, 0.5)
	fond.size = Vector2(LARGEUR_JAUGE, 26)
	jauge.add_child(fond)
	var plein := ColorRect.new()
	plein.color = Color(Butin.COULEURS_TAS[m], 0.85)
	plein.size = Vector2(LARGEUR_JAUGE * clampf(float(n) / maxf(plafond, 1.0), 0.0, 1.0), 26)
	jauge.add_child(plein)
	ligne.add_child(jauge)
	var compte := StyleRepaire.texte("%d / %d" % [n, plafond], 26, StyleRepaire.ROUGE if n >= plafond else StyleRepaire.COULEUR_OS)
	compte.name = "Compte"
	ligne.add_child(compte)
	return ligne


func agrandir() -> void:
	if not appui_accepte():
		return
	if Sauvegarde.agrandir("entrepot"):
		agrandi.emit()
	rafraichir()


static func _majuscule(t: String) -> String:
	return t.left(1).to_upper() + t.substr(1)
