class_name Heros
extends CharacterBody3D
## Héros jouable (jalon 1 : le Bretteur). Il obéit à ses CommandesHeros (remplies par l'interface,
## plus tard reçues du réseau) et gère ses états : libre, attaque en combo, esquive, parade, riposte,
## fente, touché, mort. Les valeurs de réglage viennent de data/equilibrage.tres.

const EQ: Equilibrage = preload("res://data/equilibrage.tres")

enum Etat { LIBRE, ATTAQUE, ESQUIVE, PARADE, RIPOSTE, FENTE, TOUCHE, MORT }

signal etat_change(etat: Etat)

@export var modele: PackedScene = preload("res://assets/models/heroes/Bretteur.glb")

var etat: Etat = Etat.LIBRE
var commandes := CommandesHeros.new()
var sante: Sante
var anim: AnimationPlayer
var visuel: Node3D
var recharge_esquive := Recharge.new(EQ.esquive_recharge)
var recharge_parade := Recharge.new(EQ.parade_recharge)
var recharge_fente := Recharge.new(EQ.fente_recharge)
var point_reapparition := Vector3.ZERO
var horloge := 0.0          ## temps de jeu écoulé (sert au tampon des commandes)

var _t := 0.0               ## temps passé dans l'état courant
var _direction := Vector3.BACK   ## direction de l'action en cours
var _combo := -1            ## coup du combo en cours (0, 1, 2)
var _fin_dernier_coup := -10.0
var _impact_fait := false
var _duree_action := 0.0
var _cible_riposte: Node3D
var _deja_touches: Array[Node3D] = []


func _ready() -> void:
	add_to_group("heros")
	collision_layer = Combat.COUCHE_HEROS
	collision_mask = Combat.COUCHE_MONDE | Combat.COUCHE_ENNEMIS

	var forme := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.45
	capsule.height = 2.0
	forme.shape = capsule
	forme.position.y = 1.0
	add_child(forme)

	visuel = modele.instantiate()
	add_child(visuel)
	anim = visuel.find_child("AnimationPlayer", true, false)
	for boucle in ["Idle", "Running_A"]:
		anim.get_animation(boucle).loop_mode = Animation.LOOP_LINEAR

	sante = Sante.new()
	sante.pv_max = EQ.heros_pv_max
	add_child(sante)
	sante.mort.connect(_on_mort)

	point_reapparition = global_position
	_jouer("Idle")


func avant() -> Vector3:
	return global_transform.basis.z


# ---------------------------------------------------------------- boucle
func _physics_process(delta: float) -> void:
	horloge += delta
	_t += delta
	recharge_esquive.avancer(delta)
	recharge_parade.avancer(delta)
	recharge_fente.avancer(delta)

	match etat:
		Etat.LIBRE: _etat_libre(delta)
		Etat.ATTAQUE: _etat_attaque(delta)
		Etat.ESQUIVE: _etat_esquive()
		Etat.PARADE: _etat_parade()
		Etat.RIPOSTE: _etat_riposte()
		Etat.FENTE: _etat_fente()
		Etat.TOUCHE: _etat_touche()
		Etat.MORT: _etat_mort()

	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= 25.0 * delta
	move_and_slide()


func _changer(nouvel: Etat) -> void:
	etat = nouvel
	_t = 0.0
	etat_change.emit(etat)


## Essaie de lancer une action défensive ou une compétence demandée ; vrai si l'une est partie.
func _essayer_actions_prioritaires() -> bool:
	if recharge_esquive.prete() and commandes.prendre(&"esquive", horloge):
		_commencer_esquive()
		return true
	if recharge_parade.prete() and commandes.prendre(&"competence_1", horloge):
		_commencer_parade()
		return true
	if recharge_fente.prete() and commandes.prendre(&"competence_2", horloge):
		_commencer_fente()
		return true
	return false


# ---------------------------------------------------------------- libre
func _etat_libre(delta: float) -> void:
	if _essayer_actions_prioritaires():
		return
	if commandes.prendre(&"attaque", horloge):
		var suivant := _combo + 1 if (horloge - _fin_dernier_coup <= EQ.combo_fenetre and _combo < 2) else 0
		_commencer_coup(suivant)
		return
	var dir := commandes.deplacement
	if dir.length() > 1.0:
		dir = dir.normalized()
	velocity.x = dir.x * EQ.heros_vitesse
	velocity.z = dir.z * EQ.heros_vitesse
	if dir.length() > 0.1:
		_tourner_vers(dir, delta)
		_jouer("Running_A", clampf(dir.length() * 1.2, 0.6, 1.2))
	else:
		_jouer("Idle")


func _tourner_vers(dir: Vector3, delta: float) -> void:
	var cible := atan2(dir.x, dir.z)
	rotation.y = lerp_angle(rotation.y, cible, clampf(EQ.heros_vitesse_rotation * delta, 0.0, 1.0))


func _faire_face(dir: Vector3) -> void:
	if dir.length() > 0.01:
		rotation.y = atan2(dir.x, dir.z)


# ---------------------------------------------------------------- visée assistée
## Direction de l'action : le joystick s'il est poussé, sinon l'ennemi vivant le plus proche
## (s'il est assez près), sinon droit devant.
func direction_visee() -> Vector3:
	var joy := commandes.deplacement
	if joy.length() > 0.25:
		return Vector3(joy.x, 0, joy.z).normalized()
	var meilleur: Node3D = null
	var meilleure_dist := EQ.visee_portee
	for e in get_tree().get_nodes_in_group("ennemis"):
		if e is Node3D and e.has_method("est_vivant") and e.est_vivant():
			var d := global_position.distance_to(e.global_position)
			if d < meilleure_dist:
				meilleure_dist = d
				meilleur = e
	if meilleur:
		var v := Combat.direction_plate(global_position, meilleur.global_position)
		if v != Vector3.ZERO:
			return v
	return Vector3(avant().x, 0, avant().z).normalized()


# ---------------------------------------------------------------- combo d'attaque
func _commencer_coup(index: int) -> void:
	_combo = index
	_direction = direction_visee()
	_faire_face(_direction)
	_impact_fait = false
	var nom: String = EQ.combo_animations[index]
	_duree_action = anim.get_animation(nom).length / EQ.combo_vitesse_animation
	_jouer(nom, EQ.combo_vitesse_animation, 0.08, true)
	_changer(Etat.ATTAQUE)


func _etat_attaque(_delta: float) -> void:
	var impact: float = EQ.combo_instant_impact[_combo] / EQ.combo_vitesse_animation
	# petit pas en avant jusqu'à l'impact, puis immobile
	var pas := EQ.combo_pas_en_avant / maxf(impact, 0.05) if _t < impact else 0.0
	velocity.x = _direction.x * pas
	velocity.z = _direction.z * pas
	if commandes.en_attente(&"esquive", horloge) and recharge_esquive.prete():
		_essayer_actions_prioritaires()   # l'esquive peut interrompre un coup à tout moment
		return
	if not _impact_fait and _t >= impact:
		_impact_fait = true
		_frapper_combo()
	if _impact_fait:
		if _essayer_actions_prioritaires():
			return
		if _combo < 2 and _t >= impact + 0.08 and commandes.prendre(&"attaque", horloge):
			_commencer_coup(_combo + 1)
			return
	if _t >= _duree_action:
		_fin_dernier_coup = horloge
		_changer(Etat.LIBRE)


func _frapper_combo() -> void:
	var centre := global_position + _direction * EQ.combo_portee + Vector3.UP
	var lourd: bool = EQ.combo_lourd[_combo]
	for cible in Combat.cibles_dans_sphere(get_world_3d(), centre, EQ.combo_rayon, Combat.COUCHE_ENNEMIS, [self]):
		Combat.porter_coup(self, cible, EQ.combo_degats[_combo], lourd)


# ---------------------------------------------------------------- esquive
func _commencer_esquive() -> void:
	recharge_esquive.declencher()
	var joy := commandes.deplacement
	_direction = Vector3(joy.x, 0, joy.z).normalized() if joy.length() > 0.2 else Vector3(avant().x, 0, avant().z).normalized()
	_faire_face(_direction)
	sante.rendre_invulnerable(EQ.esquive_invulnerabilite)
	collision_mask = Combat.COUCHE_MONDE   # on roule à travers les ennemis
	var duree_anim := anim.get_animation("Dodge_Forward").length
	_jouer("Dodge_Forward", duree_anim / EQ.esquive_duree, 0.05, true)
	_changer(Etat.ESQUIVE)


func _etat_esquive() -> void:
	var v := EQ.esquive_distance / EQ.esquive_duree
	velocity.x = _direction.x * v
	velocity.z = _direction.z * v
	if _t >= EQ.esquive_duree:
		collision_mask = Combat.COUCHE_MONDE | Combat.COUCHE_ENNEMIS
		velocity.x = 0
		velocity.z = 0
		_changer(Etat.LIBRE)


# ---------------------------------------------------------------- parade-riposte
func _commencer_parade() -> void:
	recharge_parade.declencher()
	_faire_face(direction_visee())
	velocity.x = 0
	velocity.z = 0
	_jouer("Block", 1.0, 0.05, true)
	_changer(Etat.PARADE)


func _etat_parade() -> void:
	velocity.x = 0
	velocity.z = 0
	if _t >= EQ.parade_fenetre:
		_changer(Etat.LIBRE)


func _riposter(source: Node3D) -> void:
	_cible_riposte = source
	_faire_face(Combat.direction_plate(global_position, source.global_position))
	_impact_fait = false
	_duree_action = anim.get_animation("Block_Attack").length / 1.2
	sante.rendre_invulnerable(_duree_action)
	_jouer("Block_Attack", 1.2, 0.04, true)
	_changer(Etat.RIPOSTE)


func _etat_riposte() -> void:
	velocity.x = 0
	velocity.z = 0
	if not _impact_fait and _t >= EQ.riposte_instant_impact / 1.2:
		_impact_fait = true
		if is_instance_valid(_cible_riposte) and _cible_riposte.has_method("est_vivant") and _cible_riposte.est_vivant() \
				and global_position.distance_to(_cible_riposte.global_position) < 3.0:
			Combat.porter_coup(self, _cible_riposte, EQ.riposte_degats, true)
			if _cible_riposte.has_method("etourdir"):
				_cible_riposte.etourdir(EQ.riposte_etourdissement)
	if _t >= _duree_action:
		_changer(Etat.LIBRE)


# ---------------------------------------------------------------- fente
func _commencer_fente() -> void:
	recharge_fente.declencher()
	_direction = direction_visee()
	_faire_face(_direction)
	_deja_touches.clear()
	collision_mask = Combat.COUCHE_MONDE   # la fente traverse les ennemis
	_jouer("1H_Melee_Attack_Stab", 3.0, 0.04, true)
	_changer(Etat.FENTE)


func _etat_fente() -> void:
	var v := EQ.fente_distance / EQ.fente_duree
	if _t < EQ.fente_duree:
		velocity.x = _direction.x * v
		velocity.z = _direction.z * v
		var centre := global_position + Vector3.UP + _direction * 0.4
		for cible in Combat.cibles_dans_sphere(get_world_3d(), centre, EQ.fente_rayon, Combat.COUCHE_ENNEMIS, [self]):
			if not _deja_touches.has(cible):
				_deja_touches.append(cible)
				Combat.porter_coup(self, cible, EQ.fente_degats, true)
	else:
		velocity.x = 0
		velocity.z = 0
		collision_mask = Combat.COUCHE_MONDE | Combat.COUCHE_ENNEMIS
		if _t >= EQ.fente_duree + 0.15:
			_changer(Etat.LIBRE)


# ---------------------------------------------------------------- dégâts reçus
## Appelé par Combat.porter_coup. Renvoie les dégâts réellement subis.
func recevoir_coup(degats: float, source: Node3D, _lourd: bool) -> float:
	if etat == Etat.MORT:
		return 0.0
	if etat == Etat.PARADE and source and Combat.est_devant(self, source, EQ.parade_angle):
		_riposter(source)
		return 0.0
	var reel := sante.subir(degats, source)
	if reel <= 0.0:
		return 0.0
	EventBus.coup_porte.emit(global_position + Vector3.UP * 2.2, reel, true, true)
	if sante.est_mort:
		return reel
	sante.rendre_invulnerable(EQ.heros_invulnerable_apres_coup)
	collision_mask = Combat.COUCHE_MONDE | Combat.COUCHE_ENNEMIS
	_direction = Combat.direction_plate(source.global_position, global_position) if source else -avant()
	_jouer("Hit_A", 1.3, 0.04, true)
	_changer(Etat.TOUCHE)
	return reel


func _etat_touche() -> void:
	var v := EQ.heros_recul_quand_touche / 0.2 if _t < 0.2 else 0.0
	velocity.x = _direction.x * v
	velocity.z = _direction.z * v
	if _t >= 0.4:
		_changer(Etat.LIBRE)


func _on_mort(_source: Node) -> void:
	velocity = Vector3.ZERO
	collision_layer = 0
	_jouer("Death_A", 1.0, 0.05, true)
	_changer(Etat.MORT)
	EventBus.heros_mort.emit(self)


func _etat_mort() -> void:
	velocity.x = 0
	velocity.z = 0
	if _t >= EQ.heros_delai_reapparition:
		reapparaitre()


func reapparaitre() -> void:
	global_position = point_reapparition
	collision_layer = Combat.COUCHE_HEROS
	collision_mask = Combat.COUCHE_MONDE | Combat.COUCHE_ENNEMIS
	sante.soigner_completement()
	sante.rendre_invulnerable(EQ.heros_invulnerable_reapparition)
	commandes.vider()
	_combo = -1
	_jouer("Idle", 1.0, 0.0, true)
	_changer(Etat.LIBRE)
	EventBus.heros_reapparu.emit(self)


func est_vivant() -> bool:
	return etat != Etat.MORT


func temps_avant_reapparition() -> float:
	return maxf(0.0, EQ.heros_delai_reapparition - _t) if etat == Etat.MORT else 0.0


# ---------------------------------------------------------------- animations
func _jouer(nom: String, vitesse := 1.0, fondu := 0.12, rejouer := false) -> void:
	if rejouer or anim.current_animation != nom:
		anim.stop()
		anim.play(nom, fondu, vitesse)
	else:
		anim.speed_scale = 1.0
		anim.play(nom, fondu, vitesse)
