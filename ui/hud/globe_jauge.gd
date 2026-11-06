class_name GlobeJauge
extends Control
## La jauge façon Diablo à l'écran (06/11, choix de Téo : un globe) : une boule de verre cerclée de fer, à côté du
## bouton de la compétence 2 qui la dépense, avec le nom de la jauge dessous (« Fureur », « Âmes »). Un trait doré
## marque le prix de la compétence ; quand la jauge l'atteint, le globe s'éclaire un instant. Ne prend aucun toucher.

const SHADER := preload("res://ui/hud/globe.gdshader")

var heros: Heros
var rayon := 50.0
var _liquide: ColorRect
var _cadre: Control
var _nom: Label
var _mat: ShaderMaterial
var _affiche := -1.0       ## niveau affiché (il suit la jauge en glissant)
var _suffisait := false
var _eclat := 0.0


func configurer(h: Heros, r: float) -> void:
	heros = h
	rayon = r
	size = Vector2(r * 2.0, r * 2.0)
	custom_minimum_size = size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("couleur", heros.couleur_jauge() if heros else Color.RED)
	_liquide = ColorRect.new()
	_liquide.material = _mat
	_liquide.position = Vector2(4, 4)
	_liquide.size = size - Vector2(8, 8)
	_liquide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_liquide)
	_cadre = Control.new()
	_cadre.size = size
	_cadre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cadre.draw.connect(_dessiner_cadre)
	add_child(_cadre)
	_nom = Label.new()
	_nom.text = heros.nom_jauge() if heros else ""
	_nom.add_theme_font_override("font", HudCombat.police_grasse())
	_nom.add_theme_font_size_override("font_size", 19)
	_nom.add_theme_color_override("font_color", BoutonAction.COULEUR_TEXTE)
	_nom.add_theme_color_override("font_outline_color", Color(0.04, 0.025, 0.015))
	_nom.add_theme_constant_override("outline_size", 6)
	_nom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_nom.position = Vector2(-20, size.y - 2)
	_nom.size = Vector2(size.x + 40, 24)
	_nom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_nom)


func niveau() -> float:
	return clampf(heros.jauge / maxf(heros.jauge_max(), 1.0), 0.0, 1.0) if heros else 0.0


func _process(delta: float) -> void:
	if heros == null or not is_instance_valid(heros):
		return
	var cible := niveau()
	_affiche = cible if _affiche < 0.0 else move_toward(_affiche, cible, delta * 1.6)
	_mat.set_shader_parameter("niveau", _affiche)
	var suffit := heros.jauge_suffit(&"competence_2")
	if suffit and not _suffisait:
		_eclat = 1.0
	_suffisait = suffit
	if _eclat > 0.0:
		_eclat = maxf(_eclat - delta * 2.5, 0.0)
		_mat.set_shader_parameter("eclat", _eclat)


## L'anneau (fer sombre, or vieilli, reflet, quatre rivets, comme les boutons) et le trait du prix de la compétence.
func _dessiner_cadre() -> void:
	var c := size / 2.0
	var or_vieilli := Color("b08a42")
	if heros:
		var part := heros.cout_jauge(&"competence_2") / maxf(heros.jauge_max(), 1.0)
		if part > 0.0 and part < 1.0:
			var y := c.y + rayon - 2.0 * rayon * part
			var demi := sqrt(maxf(rayon * rayon - pow(y - c.y, 2.0), 0.0)) - 6.0
			_cadre.draw_line(Vector2(c.x - demi, y), Vector2(c.x + demi, y), Color(0.05, 0.035, 0.02, 0.8), 4.0, true)
			_cadre.draw_line(Vector2(c.x - demi, y), Vector2(c.x + demi, y), Color("deba70"), 1.6, true)
	_cadre.draw_arc(c, rayon - 3.0, 0, TAU, 56, Color(0.05, 0.035, 0.02), 8.0, true)
	_cadre.draw_arc(c, rayon - 3.0, 0, TAU, 56, or_vieilli, 3.5, true)
	_cadre.draw_arc(c, rayon - 3.0, PI * 1.05, PI * 1.45, 16, Color(1.0, 0.92, 0.7, 0.55), 2.0, true)
	for i in 4:
		var a := PI / 4.0 + i * PI / 2.0
		var p := c + Vector2(cos(a), sin(a)) * (rayon - 3.0)
		_cadre.draw_circle(p, 3.6, Color(0.05, 0.035, 0.02))
		_cadre.draw_circle(p - Vector2(0.6, 0.6), 2.6, Color(0.62, 0.58, 0.5))
