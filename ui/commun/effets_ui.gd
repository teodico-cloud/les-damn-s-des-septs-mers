class_name EffetsUI
extends RefCounted
## Petits mouvements de l'interface (refonte, 05/11) : un bouton s'enfonce sous le doigt et revient, les éléments
## d'un écran arrivent un à un, l'écran s'assombrit avant d'en changer. Réutilisés par tous les écrans.

const DUREE_FONDU := 0.25


## Le bouton s'enfonce un peu sous le doigt (et la planche s'assombrit : style « pressed » du thème).
static func animer_bouton(b: Control) -> void:
	b.pivot_offset = b.size / 2.0
	b.resized.connect(func(): b.pivot_offset = b.size / 2.0)
	if b is BaseButton:
		b.button_down.connect(func(): _echelle(b, 0.96, 0.05))
		b.button_up.connect(func(): _echelle(b, 1.0, 0.12))


static func _echelle(n: Control, e: float, d: float) -> void:
	var t := n.create_tween()
	t.tween_property(n, "scale", Vector2.ONE * e, d).set_ease(Tween.EASE_OUT)


## Arrivée d'un élément : il glisse depuis `decalage` et apparaît, après `delai` secondes.
static func entree(n: CanvasItem, delai: float, decalage := Vector2(-40, 0), duree := 0.45) -> void:
	var fin: Vector2 = n.position
	n.position = fin + decalage
	n.modulate.a = 0.0
	var t := n.create_tween().set_parallel(true)
	t.tween_property(n, "position", fin, duree).set_delay(delai).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(n, "modulate:a", 1.0, duree * 0.8).set_delay(delai)


## Apparition sur place (un élément accroché à un bord : sa position finale n'est connue qu'une fois rangé).
static func apparition(n: CanvasItem, delai: float, duree := 0.5) -> void:
	n.modulate.a = 0.0
	n.create_tween().tween_property(n, "modulate:a", 1.0, duree).set_delay(delai)


## Voile noir plein écran (au-dessus de tout) : l'écran s'en dégage à l'ouverture.
static func voile(parent: Control) -> ColorRect:
	var v := ColorRect.new()
	v.name = "Voile"
	v.color = Color(0, 0, 0, 1)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(v)
	v.create_tween().tween_property(v, "color:a", 0.0, 0.6).set_delay(0.05)
	return v


## L'écran s'assombrit, puis `appel` (le changement de scène).
static func fondu_puis(v: ColorRect, appel: Callable) -> void:
	v.mouse_filter = Control.MOUSE_FILTER_STOP   # (plus d'appui pendant le fondu)
	var t := v.create_tween()
	t.tween_property(v, "color:a", 1.0, DUREE_FONDU)
	t.tween_callback(appel)
