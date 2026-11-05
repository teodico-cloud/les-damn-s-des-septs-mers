class_name PanneauChantier
extends PanneauRepaire
## Chantier naval (jalon 5, étape 2) : les quatre améliorations du bateau. Pour chacune : son niveau, ce
## qu'elle donne, ce que donnerait le niveau suivant, son prix (en rouge ce qui manque) et « Améliorer ».

signal achete(amelioration: String)

var boutons := {}        ## amélioration -> bouton « Améliorer »


func _init() -> void:
	titre = "Chantier naval"


func _remplir() -> void:
	boutons.clear()
	var argent := StyleRepaire.texte("", 24, Butin.COULEURS_TAS["doublons"])
	var parts := ["%d doublons" % Sauvegarde.doublons()]
	for m in Butin.MATIERES:
		parts.append(Butin.texte_tas(m, Sauvegarde.ressource(m)))
	argent.text = " · ".join(parts)
	contenu.add_child(argent)
	for a in Bateau.AMELIORATIONS:
		contenu.add_child(_ligne(a))


func _ligne(a: String) -> Control:
	var cadre := PanelContainer.new()
	var style := StyleRepaire.style(false, Color(0.2, 0.14, 0.09, 0.95), Color(StyleRepaire.COULEUR_OR, 0.7))
	style.set_content_margin_all(8)
	cadre.add_theme_stylebox_override("panel", style)
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override("separation", 16)
	cadre.add_child(ligne)
	var gauche := VBoxContainer.new()
	gauche.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gauche.add_theme_constant_override("separation", 0)
	ligne.add_child(gauche)
	var n := Sauvegarde.niveau_bateau(a)
	var titre_ligne := StyleRepaire.texte("%s   %s" % [Bateau.NOMS[a], _crans(n)], 26, StyleRepaire.OR_VIF)
	gauche.add_child(titre_ligne)
	var b: Button
	if n >= Bateau.NIVEAU_MAX:
		gauche.add_child(StyleRepaire.texte(Bateau.texte_effet(a, n) + " — au plus haut niveau", 20, StyleRepaire.VERT))
		b = StyleRepaire.bouton("Terminé", Vector2(210, 60), 24)
		b.disabled = true
	else:
		var p := Bateau.prix(a, n + 1)
		var manque := Bateau.manque(p)
		gauche.add_child(StyleRepaire.texte("%s  →  niveau %d : %s" % [Bateau.texte_effet(a, n), n + 1, Bateau.texte_effet(a, n + 1)],
				20, StyleRepaire.COULEUR_OS))
		var texte_prix := "Prix : " + Bateau.texte_prix(p)
		if not manque.is_empty():
			texte_prix += "  (il manque " + Bateau.texte_prix(manque) + ")"
		var prix := StyleRepaire.texte(texte_prix, 20, StyleRepaire.COULEUR_OS if manque.is_empty() else StyleRepaire.ROUGE)
		prix.name = "Prix"
		gauche.add_child(prix)
		b = StyleRepaire.bouton("Améliorer", Vector2(210, 60), 26, StyleRepaire.OR_VIF)
		b.disabled = not manque.is_empty()
		b.pressed.connect(acheter.bind(a, n + 1))
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ligne.add_child(b)
	boutons[a] = b
	return cadre


## « niveau 2 / 3 »
static func _crans(n: int) -> String:
	return "niveau %d / %d" % [n, Bateau.NIVEAU_MAX]


func acheter(a: String, niveau: int) -> void:
	if not appui_accepte():
		return
	if Sauvegarde.ameliorer_bateau(a, niveau):
		achete.emit(a)
	rafraichir()
