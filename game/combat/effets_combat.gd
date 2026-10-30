class_name EffetsCombat
extends Node3D
## Ressenti des coups : chiffres de dégâts, arrêt sur image, secousse de caméra, parade parfaite.
## Écoute EventBus.coup_porte et EventBus.parade_parfaite ; n'a aucun effet sur les règles du combat.
## En coop, l'arrêt sur image ne fige que le frappeur et sa cible (pas tout le jeu, qui ralentirait
## aussi le partenaire), et la caméra ne tremble que pour ses propres coups.

const EQ: Equilibrage = preload("res://data/equilibrage.tres")

var camera: CameraCombat
var heros_local: Node3D        ## coop : le héros de ce téléphone
var en_coop := false
var _ralentis: Array[float] = []   ## vitesses des arrêts et ralentis en cours : la plus lente l'emporte
var _cote := 1.0   ## les chiffres successifs partent une fois à gauche, une fois à droite
var _figes := {}   ## AnimationPlayer -> nombre d'arrêts locaux en cours


func _ready() -> void:
	EventBus.coup_porte.connect(_on_coup_porte)
	EventBus.parade_parfaite.connect(_on_parade_parfaite)


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _on_coup_porte(position_coup: Vector3, degats: float, lourd: bool, cible_est_heros: bool, cible: Node3D, source: Node3D, critique := false) -> void:
	_chiffre(position_coup, degats, lourd, cible_est_heros, critique)
	var me_concerne := not en_coop or cible == heros_local or source == heros_local
	if cible_est_heros:
		if camera and me_concerne:
			camera.secouer(EQ.secousse_touche)
		return
	var duree := EQ.arret_image_lourd if lourd else EQ.arret_image
	if en_coop:
		figer(cible, duree)
		figer(source, duree)
	else:
		arret_sur_image(duree)
	if camera and me_concerne:
		var force := EQ.secousse_coup_lourd if lourd else EQ.secousse_coup
		camera.secouer(maxf(force, EQ.secousse_critique) if critique else force)


## Coop : fige l'animation d'un combattant un court instant (temps réel), sans ralentir le jeu.
func figer(qui: Node3D, duree: float) -> void:
	if qui == null or not is_instance_valid(qui):
		return
	var anim = qui.get("anim")
	if not (anim is AnimationPlayer):
		return
	_figes[anim] = _figes.get(anim, 0) + 1
	anim.speed_scale = 0.0
	get_tree().create_timer(duree, true, false, true).timeout.connect(_defiger.bind(anim))


func _defiger(anim: AnimationPlayer) -> void:
	_figes[anim] = _figes.get(anim, 1) - 1
	if _figes[anim] <= 0:
		_figes.erase(anim)
		if is_instance_valid(anim):
			anim.speed_scale = 1.0


## Fige presque le jeu pendant `duree` secondes réelles.
func arret_sur_image(duree: float) -> void:
	ralentir(duree, EQ.arret_image_vitesse)


## Ralentit le jeu pendant `duree` secondes réelles. Une liste suit les ralentis en cours : le plus
## lent l'emporte, et la vitesse normale revient quand le dernier se termine. (Ne pas comparer à
## l'heure réelle : une minuterie créée pendant l'image de physique se déclenche une image en avance.)
func ralentir(duree: float, vitesse: float) -> void:
	_ralentis.append(vitesse)
	Engine.time_scale = _ralentis.min()
	# minuterie en temps réel (ignore le ralenti), branchée sur ce nœud : rien ne reprend s'il a disparu
	get_tree().create_timer(duree, true, false, true).timeout.connect(_fin_ralenti.bind(vitesse))


func _fin_ralenti(vitesse: float) -> void:
	_ralentis.erase(vitesse)
	Engine.time_scale = _ralentis.min() if not _ralentis.is_empty() else 1.0


## Parade parfaite : gerbe d'étincelles et éclair au point du choc, « PARFAIT ! » doré, court ralenti
## (seul ; en coop, rien n'est figé : le jeu de l'hôte ne ralentit jamais, et figer le héros
## décalerait sa riposte de l'impact), secousse pour celui qui a paré.
func _on_parade_parfaite(heros: Node3D, point: Vector3) -> void:
	EffetsMagie.etincelles(self, point)
	var valide := heros != null and is_instance_valid(heros)
	if valide and heros.get("visuel") is Node3D:
		Combat.flash(heros.visuel)
	_mot("PARFAIT !", (heros.global_position if valide else point) + Vector3.UP * 2.7)
	if not en_coop:
		ralentir(EQ.parade_parfaite_ralenti, EQ.parade_parfaite_ralenti_vitesse)
	if camera and (not en_coop or heros == heros_local):
		camera.secouer(EQ.secousse_coup_lourd)


## Gros mot doré qui saute à l'écran puis monte en s'effaçant.
func _mot(texte: String, pos: Vector3) -> void:
	var l := Label3D.new()
	l.text = texte
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true
	l.pixel_size = 0.0011
	l.font_size = 64
	l.outline_size = 18
	l.modulate = Color(1.0, 0.82, 0.25)
	l.outline_modulate = Color(0.15, 0.06, 0.0, 0.95)
	add_child(l)
	l.global_position = pos
	l.scale = Vector3.ONE * 1.8
	var t := l.create_tween()
	t.set_parallel(true)
	t.tween_property(l, "scale", Vector3.ONE, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(l, "global_position", pos + Vector3(0, 0.7, 0), 0.9).set_ease(Tween.EASE_OUT).set_delay(0.2)
	t.tween_property(l, "modulate:a", 0.0, 0.4).set_delay(0.6)
	t.tween_property(l, "outline_modulate:a", 0.0, 0.4).set_delay(0.6)
	t.chain().tween_callback(l.queue_free)


func _chiffre(pos: Vector3, degats: float, lourd: bool, cible_est_heros: bool, critique := false) -> void:
	var l := Label3D.new()
	l.text = str(roundi(degats)) + ("!" if critique else "")
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true
	l.pixel_size = 0.0011
	l.font_size = 76 if critique else (58 if lourd else 44)
	l.outline_size = 18 if critique else 14
	if cible_est_heros:
		l.modulate = Color(1.0, 0.3, 0.25)
	elif critique:
		l.modulate = Color(1.0, 0.72, 0.1)   # or vif : le « boum » du critique
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
	if critique:   # il « saute » à l'écran avant de monter
		l.scale = Vector3.ONE * 1.7
		t.tween_property(l, "scale", Vector3.ONE, 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(l, "global_position", l.global_position + Vector3(0, 1.1, 0), 0.75).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "modulate:a", 0.0, 0.75).set_delay(0.25)
	t.chain().tween_callback(l.queue_free)
