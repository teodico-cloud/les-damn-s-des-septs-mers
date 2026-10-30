class_name Occultiste
extends Heros
## L'Occultiste : combattant à distance, fragile. Projectile maudit (attaque, tir continu si on garde
## le doigt), téléportation courte (esquive), Marque maudite (la cible subit plus de dégâts, surtout du
## partenaire) et Chaînes spectrales (immobilisent les ennemis d'une zone).

enum Sort { AUCUN, MARQUE, CHAINES }

var _effet_fait := false
var _dernier_tir := -10.0
var _sort := Sort.AUCUN
var _cible_sort: Node3D
var _point_sort := Vector3.ZERO
var _squelette: Skeleton3D
var _os_baguette := -1


func _init() -> void:
	archetype = &"occultiste"
	modele = preload("res://assets/models/heroes/Occultiste.glb")
	recharge_esquive = Recharge.new(EQ.occ_tele_recharge)
	recharge_competence_1 = Recharge.new(EQ.occ_marque_recharge)
	recharge_competence_2 = Recharge.new(EQ.occ_chaines_recharge)


func pv_max() -> float:
	return EQ.occ_pv_max


func noms_boutons() -> Dictionary:
	return {&"attaque": "Attaque", &"esquive": "Esquive", &"competence_1": "Marque", &"competence_2": "Chaînes"}


func _pret() -> void:
	_squelette = visuel.find_child("Skeleton3D", true, false)
	if _squelette:
		_os_baguette = _squelette.find_bone("handslot.r")
	anim.get_animation("Spellcasting").loop_mode = Animation.LOOP_NONE


func _etat_specifique(_delta: float) -> void:
	match etat:
		Etat.ATTAQUE: _etat_tir()
		Etat.ESQUIVE: _etat_teleportation()
		Etat.INCANTATION: _etat_incantation()
		_: _changer(Etat.LIBRE)


## Action coupée (coup reçu, mort). Un sort interrompu avant son effet rend sa recharge
## (choix de Téo : il peut le relancer aussitôt).
func _quitter_action() -> void:
	visuel.visible = true
	if etat == Etat.INCANTATION and not _effet_fait:
		_rendre_recharge()
	_sort = Sort.AUCUN


func _rendre_recharge() -> void:
	if _sort == Sort.MARQUE:
		recharge_competence_1.restant = 0.0
	elif _sort == Sort.CHAINES:
		recharge_competence_2.restant = 0.0


# ---------------------------------------------------------------- projectile maudit
func _attaque_possible() -> bool:
	return horloge - _dernier_tir >= EQ.occ_tir_cadence


func _commencer_attaque() -> void:
	_direction = direction_tir()
	_faire_face(_direction)
	_effet_fait = false
	_jouer(EQ.occ_tir_animation, EQ.occ_tir_vitesse_animation, 0.06, true)
	_changer(Etat.ATTAQUE)


func _etat_tir() -> void:
	_immobile()
	if commandes.en_attente(&"esquive", horloge) and recharge_esquive.prete():
		_essayer_actions_prioritaires()   # la téléportation coupe un tir à tout moment
		return
	if not _effet_fait and _t >= EQ.occ_tir_instant / EQ.occ_tir_vitesse_animation:
		_effet_fait = true
		_tirer()
	if _effet_fait:
		if _essayer_actions_prioritaires():
			return
		if _attaque_possible() and commandes.prendre(&"attaque", horloge):
			_commencer_attaque()   # doigt gardé sur Attaque : tir suivant
			return
		if commandes.deplacement.length() > 0.25:
			_changer(Etat.LIBRE)   # le projectile est parti : le joystick coupe la fin du geste
			return
	if _t >= anim.get_animation(EQ.occ_tir_animation).length / EQ.occ_tir_vitesse_animation:
		_changer(Etat.LIBRE)


func _tirer() -> void:
	# la cible a pu bouger depuis le début du geste : on revise au moment du tir
	_direction = direction_tir()
	_faire_face(_direction)
	_dernier_tir = horloge
	Projectile.tirer(get_parent(), self, point_de_tir(), _direction, EQ)


## Direction du tir (choix de Téo) : l'ennemi le plus proche de la direction du joystick (cône de
## 60°), ou le plus proche sans joystick ; s'il n'y a personne, la direction du joystick ou devant.
func direction_tir() -> Vector3:
	var cible := cible_visee(EQ.occ_tir_portee)
	if cible:
		var v := Combat.direction_plate(global_position, cible.global_position)
		if v != Vector3.ZERO:
			return v
	return direction_visee(EQ.occ_tir_portee)


## Bout de la baguette, ramené à hauteur de poitrine (le projectile vole à l'horizontale).
func point_de_tir() -> Vector3:
	var p := global_position + _direction * 0.6
	if _squelette and _os_baguette >= 0:
		p = (_squelette.global_transform * _squelette.get_bone_global_pose(_os_baguette)).origin + _direction * 0.3
	return Vector3(p.x, global_position.y + 1.25, p.z)


# ---------------------------------------------------------------- téléportation courte
func _commencer_esquive() -> bool:
	var joy := commandes.deplacement
	# sans joystick : en arrière, loin de ce qu'il regarde (choix de Téo) ; il garde son regard
	_direction = Vector3(joy.x, 0, joy.z).normalized() if joy.length() > 0.2 else -Vector3(avant().x, 0, avant().z).normalized()
	if joy.length() > 0.2:
		_faire_face(_direction)
	_effet_fait = false
	sante.rendre_invulnerable(EQ.occ_tele_invulnerabilite)
	collision_mask = Combat.COUCHE_MONDE   # traverse les ennemis, pas les murs
	EffetsMagie.fumee(get_parent(), global_position)
	visuel.visible = false
	_changer(Etat.ESQUIVE)
	return true


func _etat_teleportation() -> void:
	if _t < EQ.occ_tele_duree:
		var v := EQ.occ_tele_distance / EQ.occ_tele_duree
		velocity.x = _direction.x * v
		velocity.z = _direction.z * v
		return
	_immobile()
	visuel.visible = true
	EffetsMagie.fumee(get_parent(), global_position)
	_collisions_normales()
	_jouer("Idle", 1.0, 0.0, true)
	_changer(Etat.LIBRE)


# ---------------------------------------------------------------- Marque maudite
func _commencer_competence_1() -> bool:
	var cible := cible_visee(EQ.occ_marque_portee)
	if cible == null or not cible.has_method("marquer"):
		return false   # personne à marquer : la compétence n'est pas consommée
	_cible_sort = cible
	_faire_face(Combat.direction_plate(global_position, cible.global_position))
	_commencer_sort(Sort.MARQUE, "Spellcasting", 1.5)
	return true


# ---------------------------------------------------------------- Chaînes spectrales
func _commencer_competence_2() -> bool:
	var cible := cible_visee(EQ.occ_chaines_portee)
	if cible:
		_point_sort = cible.global_position
	else:
		_point_sort = global_position + direction_visee(EQ.occ_chaines_portee) * 4.0
	_point_sort.y = global_position.y
	_faire_face(Combat.direction_plate(global_position, _point_sort))
	_commencer_sort(Sort.CHAINES, "Spellcast_Raise", 1.8)
	return true


func _commencer_sort(sort: Sort, animation: String, vitesse: float) -> void:
	_sort = sort
	_effet_fait = false
	_immobile()
	_jouer(animation, vitesse, 0.05, true)
	_changer(Etat.INCANTATION)


func _etat_incantation() -> void:
	_immobile()
	var instant := EQ.occ_marque_instant if _sort == Sort.MARQUE else EQ.occ_chaines_instant
	var duree := EQ.occ_marque_duree_geste if _sort == Sort.MARQUE else EQ.occ_chaines_duree_geste
	if not _effet_fait and _t >= instant:
		_effet_fait = true
		if _sort == Sort.MARQUE:
			if is_instance_valid(_cible_sort) and _cible_sort.est_ciblable():
				_cible_sort.marquer(self, EQ.occ_marque_duree)
			else:
				_rendre_recharge()   # la cible est morte entre-temps : rien n'est perdu
		else:
			_enchainer()
	if _t >= duree:
		_sort = Sort.AUCUN
		_changer(Etat.LIBRE)


func _enchainer() -> void:
	EffetsMagie.cercle(get_parent(), _point_sort, EQ.occ_chaines_rayon, 0.8)
	EventBus.effet_visuel.emit(self, "cercle_chaines", _point_sort)
	var centre := _point_sort + Vector3.UP
	for cible in Combat.cibles_dans_sphere(get_world_3d(), centre, EQ.occ_chaines_rayon, Combat.COUCHE_ENNEMIS, [self]):
		if cible.has_method("immobiliser"):
			cible.immobiliser(EQ.occ_chaines_duree)
