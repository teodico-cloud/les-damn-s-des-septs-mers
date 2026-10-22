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


func _draw() -> void:
	if actif:
		draw_circle(origine, RAYON_BASE, Color(0.05, 0.08, 0.1, 0.35))
		draw_arc(origine, RAYON_BASE, 0, TAU, 48, Color(0.89, 0.84, 0.73, 0.55), 3.0, true)
		draw_circle(poignee, RAYON_POIGNEE, Color(0.89, 0.84, 0.73, 0.75))
	else:
		draw_arc(position_repos, RAYON_BASE * 0.8, 0, TAU, 48, Color(0.89, 0.84, 0.73, 0.18), 3.0, true)
		draw_circle(position_repos, RAYON_POIGNEE * 0.8, Color(0.89, 0.84, 0.73, 0.12))
