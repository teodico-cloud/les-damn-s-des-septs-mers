class_name EffetsCombat
extends Node3D
## Ressenti des coups : chiffres de dégâts, arrêt sur image, secousse de caméra.
## Écoute EventBus.coup_porte ; n'a aucun effet sur les règles du combat.
## En coop, l'arrêt sur image ne fige que le frappeur et sa cible (pas tout le jeu, qui ralentirait
## aussi le partenaire), et la caméra ne tremble que pour ses propres coups.

const EQ: Equilibrage = preload("res://data/equilibrage.tres")

var camera: CameraCombat
var heros_local: Node3D        ## coop : le héros de ce téléphone
var en_coop := false
var _arrets_en_cours := 0
var _cote := 1.0   ## les chiffres successifs partent une fois à gauche, une fois à droite
var _figes := {}   ## AnimationPlayer -> nombre d'arrêts locaux en cours


func _ready() -> void:
	EventBus.coup_porte.connect(_on_coup_porte)


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _on_coup_porte(position_coup: Vector3, degats: float, lourd: bool, cible_est_heros: bool, cible: Node3D, source: Node3D) -> void:
	_chiffre(position_coup, degats, lourd, cible_est_heros)
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
		camera.secouer(EQ.secousse_coup_lourd if lourd else EQ.secousse_coup)


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


## Fige presque le jeu pendant `duree` secondes réelles. Un compteur suit les arrêts en cours :
## la vitesse normale revient quand le dernier se termine. (Ne pas comparer à l'heure réelle :
## une minuterie créée pendant l'image de physique se déclenche une image en avance.)
func arret_sur_image(duree: float) -> void:
	_arrets_en_cours += 1
	Engine.time_scale = EQ.arret_image_vitesse
	# minuterie en temps réel (ignore le ralenti), branchée sur ce nœud : rien ne reprend s'il a disparu
	get_tree().create_timer(duree, true, false, true).timeout.connect(_fin_arret_sur_image)


func _fin_arret_sur_image() -> void:
	_arrets_en_cours = maxi(_arrets_en_cours - 1, 0)
	if _arrets_en_cours == 0:
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
