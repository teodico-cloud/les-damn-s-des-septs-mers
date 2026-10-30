class_name BoutonAction
extends Control
## Bouton rond tactile (attaque, esquive, compétences) : icône du héros, petit nom dessous, et
## pendant la recharge l'icône s'assombrit sous une part d'ombre qui se vide, avec les secondes restantes.
## Le toucher est géré par le HUD (plusieurs doigts à la fois) ; ce nœud ne fait que s'afficher.

const COULEUR_FOND := Color(0.16, 0.11, 0.08, 0.72)
const COULEUR_BORD := Color("ac8036")
const COULEUR_TEXTE := Color("e2d6ba")

var texte := ""
var icone: Texture2D
var rayon := 60.0
var recharge: Recharge
var appuye := false
var doigt := -1
var _etait_appuye := false
var _etait_en_recharge := false


func configurer(t: String, r: float, rec: Recharge = null) -> void:
	texte = t
	rayon = r
	recharge = rec
	custom_minimum_size = Vector2(r * 2, r * 2)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func centre_ecran() -> Vector2:
	return global_position + size / 2.0


func contient(point: Vector2) -> bool:
	return point.distance_to(centre_ecran()) <= rayon * 1.15


## Ne redessine que si l'affichage change : pendant une recharge, ou quand l'état bascule.
func _process(_delta: float) -> void:
	var en_recharge := recharge != null and not recharge.prete()
	if en_recharge or en_recharge != _etait_en_recharge or appuye != _etait_appuye:
		queue_redraw()
	_etait_en_recharge = en_recharge
	_etait_appuye = appuye


func _draw() -> void:
	var c := size / 2.0
	var fond := COULEUR_FOND.lightened(0.15) if appuye else COULEUR_FOND
	draw_circle(c, rayon, fond)
	var police := ThemeDB.fallback_font
	var taille_police := int(rayon * 0.34)
	var en_recharge := recharge != null and not recharge.prete()
	if icone:
		# icône au centre, un peu haute pour laisser la place au nom
		var cote := rayon * 1.22
		var rect := Rect2(c - Vector2(cote, cote) / 2.0 - Vector2(0, rayon * 0.13), Vector2(cote, cote))
		draw_texture_rect(icone, rect, false, Color(0.45, 0.45, 0.45) if en_recharge else Color.WHITE)
		if not en_recharge:
			var tp := int(rayon * 0.24)
			var tn := police.get_string_size(texte, HORIZONTAL_ALIGNMENT_CENTER, -1, tp)
			var pos := c + Vector2(-tn.x / 2.0, rayon * 0.72)
			draw_string_outline(police, pos, texte, HORIZONTAL_ALIGNMENT_LEFT, -1, tp, 5, Color.BLACK)
			draw_string(police, pos, texte, HORIZONTAL_ALIGNMENT_LEFT, -1, tp, COULEUR_TEXTE)
	if en_recharge:
		# part sombre proportionnelle au temps restant, comme une horloge qui se vide
		var f := recharge.fraction()
		var points := PackedVector2Array([c])
		var pas := 32
		for i in pas + 1:
			var a := -PI / 2.0 + TAU * f * i / pas
			points.append(c + Vector2(cos(a), sin(a)) * rayon)
		draw_colored_polygon(points, Color(0, 0, 0, 0.55))
		# arrondi au dixième supérieur : jamais « 0.0 » tant que ce n'est pas prêt
		var s := "%.1f" % (ceilf(recharge.restant * 10.0) / 10.0) if recharge.restant < 10.0 else str(ceili(recharge.restant))
		var ts := police.get_string_size(s, HORIZONTAL_ALIGNMENT_CENTER, -1, taille_police + 6)
		draw_string_outline(police, c + Vector2(-ts.x / 2.0, ts.y / 3.0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, taille_police + 6, 6, Color.BLACK)
		draw_string(police, c + Vector2(-ts.x / 2.0, ts.y / 3.0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, taille_police + 6, Color.WHITE)
	elif icone == null:
		var ts := police.get_string_size(texte, HORIZONTAL_ALIGNMENT_CENTER, -1, taille_police)
		draw_string_outline(police, c + Vector2(-ts.x / 2.0, ts.y / 3.0), texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille_police, 5, Color.BLACK)
		draw_string(police, c + Vector2(-ts.x / 2.0, ts.y / 3.0), texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille_police, COULEUR_TEXTE)
	draw_arc(c, rayon - 2.0, 0, TAU, 48, COULEUR_BORD, 4.0, true)
