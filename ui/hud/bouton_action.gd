class_name BoutonAction
extends Control
## Bouton rond tactile (attaque, esquive, compétences) : icône du héros, petit nom dessous, et
## pendant la recharge l'icône s'assombrit sous une part d'ombre qui se vide, avec les secondes restantes.
## Le toucher est géré par le HUD (plusieurs doigts à la fois) ; ce nœud ne fait que s'afficher.

const COULEUR_FOND := Color(0.16, 0.11, 0.08, 0.72)
const COULEUR_BORD := Color("ac8036")
const COULEUR_TEXTE := Color("ecdcb8")

var texte := ""
var icone: Texture2D
var rayon := 60.0
var recharge: Recharge
var appuye := false
var doigt := -1
var compteur := -1      ## jalon 5 (bordée) : tirs restants, dans une pastille ; -1 : pas de pastille (une recharge
                        ## à charges, téléportation : ses charges, mises à jour seules)
var inactif := false    ## plus rien à faire (bordée vide) : icône grisée
var _etait_appuye := false
var _etait_en_recharge := false
var _charge_en_cours := false
static var _sceau: Texture2D


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
	var charge_en_cours := recharge != null and recharge.charges_max > 1 and recharge.restant > 0.0
	if recharge != null and recharge.charges_max > 1 and compteur != recharge.charges:
		compteur = recharge.charges
		queue_redraw()
	if en_recharge or charge_en_cours or charge_en_cours != _charge_en_cours or en_recharge != _etait_en_recharge \
			or appuye != _etait_appuye:
		queue_redraw()
	_charge_en_cours = charge_en_cours
	_etait_en_recharge = en_recharge
	_etait_appuye = appuye


## Refonte de l'interface (05/11) : un médaillon — fond de cuir sombre, anneau de fer et d'or vieilli, quatre
## rivets, un reflet en haut à gauche ; appuyé, il s'assombrit et l'anneau s'éclaire ; en recharge, une part
## d'ombre qui se vide et les secondes ; la pastille (tirs de bordée, charges) est un petit sceau de cire.
func _draw() -> void:
	var c := size / 2.0
	var police: Font = HudCombat.police_grasse()
	var en_recharge := recharge != null and not recharge.prete()
	var or_vieilli := Color("b08a42")
	draw_circle(c + Vector2(0, 4), rayon, Color(0, 0, 0, 0.35))   # ombre portée
	draw_circle(c, rayon, Color(0.11, 0.075, 0.05, 0.9) if not appuye else Color(0.06, 0.04, 0.03, 0.95))
	draw_circle(c - Vector2(rayon, rayon) * 0.12, rayon * 0.78, Color(0.2, 0.14, 0.09, 0.35 if not appuye else 0.15))
	if icone:
		# icône au centre, un peu haute pour laisser la place au nom
		var cote := rayon * 1.2
		var rect := Rect2(c - Vector2(cote, cote) / 2.0 - Vector2(0, rayon * 0.13), Vector2(cote, cote))
		draw_texture_rect(icone, rect, false, Color(0.45, 0.45, 0.45) if en_recharge or inactif else Color.WHITE)
		if not en_recharge:
			var tp := int(rayon * 0.25)
			var tn := police.get_string_size(texte, HORIZONTAL_ALIGNMENT_CENTER, -1, tp)
			var pos := c + Vector2(-tn.x / 2.0, rayon * 0.74)
			draw_string_outline(police, pos, texte, HORIZONTAL_ALIGNMENT_LEFT, -1, tp, 5, Color(0.04, 0.025, 0.015))
			draw_string(police, pos, texte, HORIZONTAL_ALIGNMENT_LEFT, -1, tp, COULEUR_TEXTE)
	if en_recharge:
		# part sombre proportionnelle au temps restant, comme une horloge qui se vide
		var f := recharge.fraction()
		var points := PackedVector2Array([c])
		var pas := 32
		for i in pas + 1:
			var a := -PI / 2.0 + TAU * f * i / pas
			points.append(c + Vector2(cos(a), sin(a)) * (rayon - 3.0))
		draw_colored_polygon(points, Color(0, 0, 0, 0.55))
		# arrondi au dixième supérieur : jamais « 0.0 » tant que ce n'est pas prêt
		var s := "%.1f" % (ceilf(recharge.restant * 10.0) / 10.0) if recharge.restant < 10.0 else str(ceili(recharge.restant))
		var taille := int(rayon * 0.42)
		var ts := police.get_string_size(s, HORIZONTAL_ALIGNMENT_CENTER, -1, taille)
		draw_string_outline(police, c + Vector2(-ts.x / 2.0, ts.y / 3.0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, 6, Color.BLACK)
		draw_string(police, c + Vector2(-ts.x / 2.0, ts.y / 3.0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, COULEUR_TEXTE)
	elif icone == null:
		var taille := int(rayon * 0.34)
		var ts := police.get_string_size(texte, HORIZONTAL_ALIGNMENT_CENTER, -1, taille)
		draw_string_outline(police, c + Vector2(-ts.x / 2.0, ts.y / 3.0), texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, 5, Color.BLACK)
		draw_string(police, c + Vector2(-ts.x / 2.0, ts.y / 3.0), texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, COULEUR_TEXTE)
	# l'anneau : fer sombre, or vieilli, un reflet ; quatre rivets
	draw_arc(c, rayon - 3.0, 0, TAU, 56, Color(0.05, 0.035, 0.02), 7.0, true)
	draw_arc(c, rayon - 3.0, 0, TAU, 56, or_vieilli if not appuye else Color("deba70"), 3.5, true)
	draw_arc(c, rayon - 3.0, PI * 1.05, PI * 1.45, 16, Color(1.0, 0.92, 0.7, 0.55), 2.0, true)
	for i in 4:
		var a := PI / 4.0 + i * PI / 2.0
		var p := c + Vector2(cos(a), sin(a)) * (rayon - 3.0)
		draw_circle(p, 3.6, Color(0.05, 0.035, 0.02))
		draw_circle(p - Vector2(0.6, 0.6), 2.6, Color(0.62, 0.58, 0.5))
	if recharge != null and recharge.charges_max > 1 and not en_recharge and recharge.restant > 0.0:
		# une charge revient : un liseré clair fait le tour du bouton
		var f := 1.0 - recharge.fraction()
		draw_arc(c, rayon - 3.0, -PI / 2.0, -PI / 2.0 + TAU * f, 40, Color(0.95, 0.85, 0.55), 6.0, true)
	if compteur >= 0:   # pastille en haut à droite : un petit sceau de cire avec le nombre
		var p := c + Vector2(rayon * 0.72, -rayon * 0.72)
		var r := rayon * 0.36
		if _sceau == null:
			_sceau = load("res://assets/ui/matieres/sceau_lisse.png")
		draw_texture_rect(_sceau, Rect2(p - Vector2(r, r) * 1.25, Vector2(r, r) * 2.5), false,
				Color.WHITE if compteur > 0 else Color(0.5, 0.45, 0.42))
		var t := str(compteur)
		var tp := int(r * 1.3)
		var ts := police.get_string_size(t, HORIZONTAL_ALIGNMENT_CENTER, -1, tp)
		draw_string_outline(police, p + Vector2(-ts.x / 2.0, ts.y / 3.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, tp, 4, Color(0.25, 0.03, 0.02))
		draw_string(police, p + Vector2(-ts.x / 2.0, ts.y / 3.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, tp, Color("f1d9b0"))
