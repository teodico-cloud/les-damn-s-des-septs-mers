class_name ChoixMalediction
extends PanelContainer
## Choix du niveau de malédiction avant une expédition (choix de Téo : 0 à 5, choisi au départ) :
## « < Malédiction 3 — Lames maudites > », les effets cumulés et le bonus de butin. Écrit dans
## Partie.malediction (l'hôte l'envoie à l'invité au lancement). Tous les niveaux sont ouverts
## jusqu'à la sauvegarde (jalon 4).

signal change(niveau: int)

const COULEUR_OS := Color("e2d6ba")
const COULEUR_OR := Color("ac8036")
const VIOLET := Color("b48cff")

var label_titre: Label
var label_effets: Label
var label_butin: Label
var bouton_moins: Button
var bouton_plus: Button


func _ready() -> void:
	var fond := StyleBoxFlat.new()
	fond.bg_color = Color(0.08, 0.05, 0.1, 0.85)
	fond.border_color = Color(VIOLET, 0.8)
	fond.set_border_width_all(3)
	fond.set_corner_radius_all(14)
	fond.set_content_margin_all(10)
	add_theme_stylebox_override("panel", fond)
	var colonne := VBoxContainer.new()
	colonne.alignment = BoxContainer.ALIGNMENT_CENTER
	colonne.add_theme_constant_override("separation", 2)
	add_child(colonne)
	var ligne := HBoxContainer.new()
	ligne.alignment = BoxContainer.ALIGNMENT_CENTER
	ligne.add_theme_constant_override("separation", 18)
	colonne.add_child(ligne)
	bouton_moins = _fleche("<")
	bouton_moins.pressed.connect(choisir.bind(-1, true))
	ligne.add_child(bouton_moins)
	label_titre = Label.new()
	label_titre.custom_minimum_size = Vector2(500, 0)
	label_titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_titre.add_theme_font_size_override("font_size", 30)
	label_titre.add_theme_color_override("font_color", VIOLET)
	ligne.add_child(label_titre)
	bouton_plus = _fleche(">")
	bouton_plus.pressed.connect(choisir.bind(1, true))
	ligne.add_child(bouton_plus)
	label_effets = Label.new()
	label_effets.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_effets.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label_effets.custom_minimum_size = Vector2(700, 0)
	label_effets.add_theme_font_size_override("font_size", 20)
	label_effets.add_theme_color_override("font_color", Color(COULEUR_OS, 0.9))
	colonne.add_child(label_effets)
	label_butin = Label.new()
	label_butin.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_butin.add_theme_font_size_override("font_size", 22)
	label_butin.add_theme_color_override("font_color", Color("e0b04a"))
	colonne.add_child(label_butin)
	choisir(Partie.malediction, false)


## Change le niveau : `relatif` vrai → ajoute `n` au niveau actuel ; sinon le règle à `n`.
func choisir(n: int, relatif: bool) -> void:
	var niveau := clampi(Partie.malediction + n if relatif else n, 0, Malediction.MAX)
	Partie.malediction = niveau
	label_titre.text = Malediction.titre(niveau)
	label_effets.text = Malediction.effets(niveau).replace("\n", " · ")   # (une ou deux lignes : compact)
	label_butin.text = "Butin %s : plus d'objets, et plus rares" % Malediction.texte_butin(niveau)
	bouton_moins.disabled = niveau <= 0
	bouton_plus.disabled = niveau >= Malediction.MAX
	change.emit(niveau)


func _fleche(texte: String) -> Button:
	var b := Button.new()
	b.text = texte
	b.custom_minimum_size = Vector2(76, 60)
	b.add_theme_font_size_override("font_size", 36)
	b.add_theme_color_override("font_color", COULEUR_OS)
	b.add_theme_color_override("font_disabled_color", Color(COULEUR_OS, 0.25))
	for etat in ["normal", "hover", "pressed", "focus", "disabled"]:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.1, 0.07, 0.05, 0.92) if etat == "pressed" else Color(0.16, 0.11, 0.08, 0.82)
		s.border_color = COULEUR_OR if etat != "disabled" else Color(COULEUR_OR, 0.3)
		s.set_border_width_all(3)
		s.set_corner_radius_all(12)
		b.add_theme_stylebox_override(etat, s)
	return b
