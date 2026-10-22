class_name EffetsCombat
extends Node3D
## Ressenti des coups : chiffres de dégâts, arrêt sur image, secousse de caméra.
## Écoute EventBus.coup_porte ; n'a aucun effet sur les règles du combat.

const EQ: Equilibrage = preload("res://data/equilibrage.tres")

var camera: CameraCombat
var _fin_arret := 0.0
var _cote := 1.0   ## les chiffres successifs partent une fois à gauche, une fois à droite


func _ready() -> void:
	EventBus.coup_porte.connect(_on_coup_porte)


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _on_coup_porte(position_coup: Vector3, degats: float, lourd: bool, cible_est_heros: bool) -> void:
	_chiffre(position_coup, degats, lourd, cible_est_heros)
	if cible_est_heros:
		if camera:
			camera.secouer(EQ.secousse_touche)
	else:
		arret_sur_image(EQ.arret_image_lourd if lourd else EQ.arret_image)
		if camera:
			camera.secouer(EQ.secousse_coup_lourd if lourd else EQ.secousse_coup)


func arret_sur_image(duree: float) -> void:
	var maintenant := Time.get_ticks_msec() / 1000.0
	_fin_arret = max(_fin_arret, maintenant + duree)
	Engine.time_scale = 0.05
	# minuterie en temps réel (ignore le ralenti), branchée sur ce nœud : rien ne reprend s'il a disparu
	get_tree().create_timer(duree, true, false, true).timeout.connect(_fin_arret_sur_image)


func _fin_arret_sur_image() -> void:
	if Time.get_ticks_msec() / 1000.0 >= _fin_arret - 0.001:
		Engine.time_scale = 1.0


func _chiffre(pos: Vector3, degats: float, lourd: bool, cible_est_heros: bool) -> void:
	var l := Label3D.new()
	l.text = str(roundi(degats))
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true
	l.pixel_size = 0.0011
	l.font_size = 58 if lourd else 44
	l.outline_size = 14
	if cible_est_heros:
		l.modulate = Color(1.0, 0.3, 0.25)
	elif lourd:
		l.modulate = Color(1.0, 0.8, 0.3)
	else:
		l.modulate = Color(1.0, 0.97, 0.9)
	l.outline_modulate = Color(0, 0, 0, 0.9)
	add_child(l)
	# décalage vers la droite / la gauche de l'écran, en alternance, pour que deux chiffres
	# rapprochés (coup puis fente…) ne se chevauchent pas
	_cote = -_cote
	var droite := camera.global_transform.basis.x if camera else Vector3.RIGHT
	l.global_position = pos + droite * _cote * randf_range(0.25, 0.45)
	var t := l.create_tween()
	t.set_parallel(true)
	t.tween_property(l, "global_position", l.global_position + Vector3(0, 1.1, 0), 0.75).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "modulate:a", 0.0, 0.75).set_delay(0.25)
	t.chain().tween_callback(l.queue_free)
