class_name JoystickFlottant
extends Control
## Joystick flottant : il apparaît là où le pouce se pose (moitié gauche de l'écran) et donne une
## direction de -1 à 1. Au repos, un cercle discret montre où poser le pouce.

const RAYON_BASE := 115.0
const RAYON_POIGNEE := 48.0
const ZONE_MORTE := 0.15

var actif := false
var doigt := -1
var origine := Vector2.ZERO
var poignee := Vector2.ZERO
var valeur := Vector2.ZERO
var position_repos := Vector2(210, 520)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func commencer(index: int, pos: Vector2) -> void:
	actif = true
	doigt = index
	origine = pos
	poignee = pos
	valeur = Vector2.ZERO
	queue_redraw()


func deplacer(pos: Vector2) -> void:
	var d := pos - origine
	if d.length() > RAYON_BASE:
		d = d.normalized() * RAYON_BASE
	poignee = origine + d
	var v := d / RAYON_BASE
	valeur = Vector2.ZERO if v.length() < ZONE_MORTE else v.normalized() * inverse_lerp(ZONE_MORTE, 1.0, v.length())
	queue_redraw()


func relacher() -> void:
	actif = false
	doigt = -1
	valeur = Vector2.ZERO
	queue_redraw()


## Refonte de l'interface (05/11) : un anneau d'or vieilli gravé de huit crans (une boussole), une poignée de
## laiton ; au repos, l'anneau seul, très discret.
func _draw() -> void:
	var or_vieilli := Color("b08a42")
	var sombre := Color(0.06, 0.04, 0.02)
	if actif:
		draw_circle(origine, RAYON_BASE, Color(0.03, 0.025, 0.02, 0.4))
		draw_arc(origine, RAYON_BASE, 0, TAU, 64, Color(sombre, 0.7), 7.0, true)
		draw_arc(origine, RAYON_BASE, 0, TAU, 64, Color(or_vieilli, 0.75), 3.0, true)
		draw_arc(origine, RAYON_BASE - 10, 0, TAU, 64, Color(or_vieilli, 0.3), 1.5, true)
		for i in 8:
			var a := TAU * i / 8.0
			var long := 16.0 if i % 2 == 0 else 9.0
			var d := Vector2(cos(a), sin(a))
			draw_line(origine + d * (RAYON_BASE - long), origine + d * RAYON_BASE, Color(or_vieilli, 0.8), 2.5, true)
		draw_circle(poignee + Vector2(0, 4), RAYON_POIGNEE, Color(0, 0, 0, 0.35))
		draw_circle(poignee, RAYON_POIGNEE, Color("6e5326"))
		draw_circle(poignee - Vector2(6, 6), RAYON_POIGNEE * 0.72, Color("b08a42"))
		draw_circle(poignee - Vector2(10, 10), RAYON_POIGNEE * 0.3, Color("deba70", 0.6))
		draw_arc(poignee, RAYON_POIGNEE, 0, TAU, 40, sombre, 3.0, true)
	else:
		draw_arc(position_repos, RAYON_BASE * 0.8, 0, TAU, 64, Color(or_vieilli, 0.22), 3.0, true)
		for i in 4:
			var a := TAU * i / 4.0
			var d := Vector2(cos(a), sin(a))
			draw_line(position_repos + d * (RAYON_BASE * 0.8 - 12), position_repos + d * RAYON_BASE * 0.8, Color(or_vieilli, 0.3), 2.0, true)
		draw_circle(position_repos, RAYON_POIGNEE * 0.8, Color(or_vieilli, 0.12))
