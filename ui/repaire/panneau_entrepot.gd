class_name PanneauEntrepot
extends PanneauRepaire
## Entrepôt (jalon 5) : les doublons, les matériaux et leur plafond (choix de Téo : au-delà, le surplus
## rapporté est revendu en doublons), les objets des coffres, et l'écran Équipement.

signal equipement_demande

const LARGEUR_JAUGE := 520.0

var bouton_equipement: Button


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


static func _majuscule(t: String) -> String:
	return t.left(1).to_upper() + t.substr(1)
