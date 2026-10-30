class_name Bretteur
extends Heros
## Le Bretteur : combo de 3 coups au sabre (le 3e est lourd), roulade qui traverse les ennemis,
## Parade-riposte (un coup de face paré déclenche une riposte qui étourdit ; parée juste à temps,
## c'est une parade parfaite), Fente qui traverse.


var _combo := -1            ## coup du combo en cours (0, 1, 2)
var _fin_dernier_coup := -10.0
var _impact_fait := false
var _duree_action := 0.0
var _cible_riposte: Node3D
var _riposte_parfaite := false
var _deja_touches: Array[Node3D] = []


func _init() -> void:
	archetype = &"bretteur"
	modele = preload("res://assets/models/heroes/Bretteur.glb")
	recharge_esquive = Recharge.new(EQ.esquive_recharge)
	recharge_competence_1 = Recharge.new(EQ.parade_recharge)
	recharge_competence_2 = Recharge.new(EQ.fente_recharge)


func noms_boutons() -> Dictionary:
	return {&"attaque": "Attaque", &"esquive": "Roulade", &"competence_1": "Parade", &"competence_2": "Fente"}


func icones_boutons() -> Dictionary:
	return {
		&"attaque": preload("res://assets/ui/icones/sabre.svg"),
		&"esquive": preload("res://assets/ui/icones/roulade.svg"),
		&"competence_1": preload("res://assets/ui/icones/bouclier.svg"),
		&"competence_2": preload("res://assets/ui/icones/fente.svg"),
	}


func _reinitialiser() -> void:
	_combo = -1


func _etat_specifique(delta: float) -> void:
	match etat:
		Etat.ATTAQUE: _etat_attaque(delta)
		Etat.ESQUIVE: _etat_esquive()
		Etat.PARADE: _etat_parade()
		Etat.RIPOSTE: _etat_riposte()
		Etat.FENTE: _etat_fente()
		_: _changer(Etat.LIBRE)


# ---------------------------------------------------------------- combo d'attaque
func _commencer_attaque() -> void:
	var suivant := _combo + 1 if (horloge - _fin_dernier_coup <= EQ.combo_fenetre and _combo < 2) else 0
	_commencer_coup(suivant)


func _commencer_coup(index: int) -> void:
	_combo = index
	_direction = direction_attaque()
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
	if (commandes.en_attente(&"esquive", horloge) and recharge_esquive.prete()) \
			or (commandes.en_attente(&"competence_1", horloge) and recharge_competence_1.prete()):
		_essayer_actions_prioritaires()   # l'esquive et la parade peuvent interrompre un coup à tout moment
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
		if _t >= impact + EQ.combo_annulation and commandes.deplacement.length() > 0.25:
			# le coup a porté : le joystick coupe la fin du geste (on frappe, on bouge, on refrappe) ;
			# le combo reste enchaînable pendant sa fenêtre
			_fin_dernier_coup = horloge
			_changer(Etat.LIBRE)
			return
	if _t >= _duree_action:
		_fin_dernier_coup = horloge
		_changer(Etat.LIBRE)


func _frapper_combo() -> void:
	var centre := global_position + _direction * EQ.combo_portee + Vector3.UP
	var lourd: bool = EQ.combo_lourd[_combo]
	# traînée lumineuse du sabre (aussi montrée chez l'autre joueur en coop)
	EffetsMagie.trainee_sabre(get_parent(), global_position, _direction, _combo)
	EventBus.effet_visuel.emit(self, "trainee_%d" % _combo, global_position + _direction)
	for cible in Combat.cibles_dans_sphere(get_world_3d(), centre, EQ.combo_rayon, Combat.COUCHE_ENNEMIS, [self]):
		Combat.porter_coup(self, cible, EQ.combo_degats[_combo], lourd)


# ---------------------------------------------------------------- esquive (roulade)
func _commencer_esquive() -> bool:
	var joy := commandes.deplacement
	_direction = Vector3(joy.x, 0, joy.z).normalized() if joy.length() > 0.2 else Vector3(avant().x, 0, avant().z).normalized()
	_faire_face(_direction)
	sante.rendre_invulnerable(EQ.esquive_invulnerabilite)
	collision_mask = Combat.COUCHE_MONDE   # on roule à travers les ennemis
	var duree_anim := anim.get_animation("Dodge_Forward").length
	_jouer("Dodge_Forward", duree_anim / EQ.esquive_duree, 0.05, true)
	_changer(Etat.ESQUIVE)
	return true


func _etat_esquive() -> void:
	var v := EQ.esquive_distance / EQ.esquive_duree
	velocity.x = _direction.x * v
	velocity.z = _direction.z * v
	if _t >= EQ.esquive_duree:
		_collisions_normales()
		_immobile()
		_changer(Etat.LIBRE)


# ---------------------------------------------------------------- parade-riposte
func _commencer_competence_1() -> bool:
	_faire_face(direction_visee())
	_immobile()
	_jouer("Block", 1.0, 0.05, true)
	_changer(Etat.PARADE)
	return true


func _etat_parade() -> void:
	_immobile()
	if _t >= EQ.parade_fenetre:
		_changer(Etat.LIBRE)


func _intercepter_coup(source: Node3D) -> bool:
	if etat == Etat.PARADE and source and Combat.est_devant(self, source, EQ.parade_angle):
		# parade parfaite (choix de Téo) : le coup arrive juste après l'appui sur Parade
		_riposter(source, _t <= EQ.parade_parfaite_fenetre)
		return true
	return false


func _riposte_autorite(point: Vector3) -> void:
	# chez l'invité, pas de cible réelle : seulement le geste (l'hôte applique les dégâts)
	_faire_face(Combat.direction_plate(global_position, point))
	_cible_riposte = null
	_riposte_parfaite = false
	_impact_fait = true
	_duree_action = anim.get_animation("Block_Attack").length / EQ.riposte_vitesse_animation
	_jouer("Block_Attack", EQ.riposte_vitesse_animation, 0.04, true)
	_changer(Etat.RIPOSTE)


func _riposter(source: Node3D, parfaite := false) -> void:
	_cible_riposte = source
	_riposte_parfaite = parfaite
	var dir := Combat.direction_plate(global_position, source.global_position)
	_faire_face(dir)
	if parfaite:
		recharge_competence_1.restant = 0.0   # on peut parer le squelette suivant aussitôt
		EventBus.parade_parfaite.emit(self, global_position + dir * 0.7 + Vector3.UP * 1.2)
	_impact_fait = false
	_duree_action = anim.get_animation("Block_Attack").length / EQ.riposte_vitesse_animation
	sante.rendre_invulnerable(_duree_action)
	_jouer("Block_Attack", EQ.riposte_vitesse_animation, 0.04, true)
	_changer(Etat.RIPOSTE)


func _etat_riposte() -> void:
	_immobile()
	if not _impact_fait and _t >= EQ.riposte_instant_impact / EQ.riposte_vitesse_animation:
		_impact_fait = true
		if is_instance_valid(_cible_riposte) and _cible_riposte.has_method("est_vivant") and _cible_riposte.est_vivant() \
				and global_position.distance_to(_cible_riposte.global_position) < EQ.riposte_distance_max:
			Combat.porter_coup(self, _cible_riposte, EQ.riposte_degats, true, _riposte_parfaite)
			if _cible_riposte.has_method("etourdir"):
				_cible_riposte.etourdir(EQ.riposte_etourdissement_parfaite if _riposte_parfaite else EQ.riposte_etourdissement)
	if _t >= _duree_action:
		_changer(Etat.LIBRE)


## Coop, invité : l'hôte a vu une parade parfaite de notre héros ; la Parade est rendue chez nous aussi.
func parade_parfaite_recue() -> void:
	recharge_competence_1.restant = 0.0


# ---------------------------------------------------------------- fente
func _commencer_competence_2() -> bool:
	_direction = direction_visee()
	_faire_face(_direction)
	_deja_touches.clear()
	collision_mask = Combat.COUCHE_MONDE   # la fente traverse les ennemis
	_jouer("1H_Melee_Attack_Stab", 3.0, 0.04, true)
	_changer(Etat.FENTE)
	return true


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
		_immobile()
		_collisions_normales()
		if _t >= EQ.fente_duree + 0.15:
			_changer(Etat.LIBRE)
