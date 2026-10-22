class_name Heros
extends CharacterBody3D
## Base commune des héros jouables (Bretteur, Occultiste…). Elle obéit aux CommandesHeros (remplies
## par l'interface, plus tard reçues du réseau) et gère ce qui est commun : déplacement, visée assistée,
## temps de recharge, coup reçu, mort et réapparition. Chaque archétype (bretteur.gd, occultiste.gd)
## ajoute son attaque, son esquive et ses deux compétences. Réglages : data/equilibrage.tres.

const EQ: Equilibrage = preload("res://data/equilibrage.tres")
const ARCHETYPES := {
	&"bretteur": "res://game/player/bretteur.gd",
	&"occultiste": "res://game/player/occultiste.gd",
}

## Tous les états possibles ; chaque archétype n'en utilise qu'une partie.
enum Etat { LIBRE, ATTAQUE, ESQUIVE, PARADE, RIPOSTE, FENTE, TOUCHE, MORT, INCANTATION }

signal etat_change(etat: Etat)

var archetype := &""
var modele: PackedScene
var etat: Etat = Etat.LIBRE
var commandes := CommandesHeros.new()
var sante: Sante
var anim: AnimationPlayer
var visuel: Node3D
var recharge_esquive: Recharge
var recharge_competence_1: Recharge
var recharge_competence_2: Recharge
var point_reapparition := Vector3.ZERO
var horloge := 0.0          ## temps de jeu écoulé (sert au tampon des commandes)
## Coop : héros de l'autre téléphone affiché chez soi, sans simulation (positions reçues par le réseau).
var marionnette := false
## Coop : pas de réapparition toute seule (le partenaire relève, ou retour au départ si les deux tombent).
var reapparition_auto := true
## Coop : progression de la réanimation (0 à 1) quand ce héros est à terre.
var progres_reanimation := 0.0
var _zone_reanimation: Node3D

var _t := 0.0               ## temps passé dans l'état courant
var _direction := Vector3.BACK   ## direction de l'action en cours


## Crée le héros d'un archétype (&"bretteur", &"occultiste"), prêt à être placé puis ajouté.
static func creer(nom: StringName) -> Heros:
	return load(ARCHETYPES[nom]).new()


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
	sante.pv_max = pv_max()
	add_child(sante)
	sante.mort.connect(_on_mort)

	point_reapparition = global_position
	_jouer("Idle")
	_pret()


func avant() -> Vector3:
	return global_transform.basis.z


# ---------------------------------------------------------------- à fournir par chaque archétype
func pv_max() -> float:
	return EQ.heros_pv_max


## Textes des 4 boutons de l'interface.
func noms_boutons() -> Dictionary:
	return {&"attaque": "Attaque", &"esquive": "Esquive", &"competence_1": "", &"competence_2": ""}


func _pret() -> void:
	pass


func _commencer_attaque() -> void:
	pass


## Faux tant que l'attaque ne peut pas repartir (ex. cadence de tir) : la demande reste en attente.
func _attaque_possible() -> bool:
	return true


func _commencer_esquive() -> bool:
	return false


func _commencer_competence_1() -> bool:
	return false


func _commencer_competence_2() -> bool:
	return false


## États propres à l'archétype (attaque, esquive, compétences).
func _etat_specifique(_delta: float) -> void:
	_changer(Etat.LIBRE)


## Vrai si l'archétype absorbe ce coup (ex. parade du Bretteur).
func _intercepter_coup(_source: Node3D) -> bool:
	return false


## Remise à zéro des actions propres (combo…) à la réapparition.
func _reinitialiser() -> void:
	pass


# ---------------------------------------------------------------- boucle
func _physics_process(delta: float) -> void:
	if marionnette:
		return
	horloge += delta
	_t += delta
	recharge_esquive.avancer(delta)
	recharge_competence_1.avancer(delta)
	recharge_competence_2.avancer(delta)

	match etat:
		Etat.LIBRE: _etat_libre(delta)
		Etat.TOUCHE: _etat_touche()
		Etat.MORT: _etat_mort()
		_: _etat_specifique(delta)

	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= 25.0 * delta
	move_and_slide()


func _changer(nouvel: Etat) -> void:
	etat = nouvel
	_t = 0.0
	etat_change.emit(etat)


## Essaie de lancer l'esquive ou une compétence demandée ; vrai si l'une est partie.
## Une compétence sans cible possible n'est pas consommée (la demande reste en attente un instant).
func _essayer_actions_prioritaires() -> bool:
	if recharge_esquive.prete() and commandes.en_attente(&"esquive", horloge) and _commencer_esquive():
		commandes.prendre(&"esquive", horloge)
		recharge_esquive.declencher()
		return true
	if recharge_competence_1.prete() and commandes.en_attente(&"competence_1", horloge) and _commencer_competence_1():
		commandes.prendre(&"competence_1", horloge)
		recharge_competence_1.declencher()
		return true
	if recharge_competence_2.prete() and commandes.en_attente(&"competence_2", horloge) and _commencer_competence_2():
		commandes.prendre(&"competence_2", horloge)
		recharge_competence_2.declencher()
		return true
	return false


## Remet les collisions normales (après une esquive ou une ruée qui traverse les ennemis).
func _collisions_normales() -> void:
	collision_mask = Combat.COUCHE_MONDE | Combat.COUCHE_ENNEMIS


# ---------------------------------------------------------------- libre
func _etat_libre(delta: float) -> void:
	if _essayer_actions_prioritaires():
		return
	if _attaque_possible() and commandes.prendre(&"attaque", horloge):
		_commencer_attaque()
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


func _immobile() -> void:
	velocity.x = 0.0
	velocity.z = 0.0


# ---------------------------------------------------------------- visée assistée
## Ennemi visé : sans joystick, le plus proche ; avec le joystick poussé, celui le plus proche de sa
## direction (dans un cône de 60°). Jamais un squelette qui sort encore de terre. Null si aucun.
func cible_visee(portee := EQ.visee_portee) -> Node3D:
	var joy := Vector3(commandes.deplacement.x, 0, commandes.deplacement.z)
	var avec_joystick := joy.length() > 0.25
	var meilleur: Node3D = null
	var meilleur_score := INF
	for e in get_tree().get_nodes_in_group("ennemis"):
		if not (e is Node3D and e.has_method("est_ciblable") and e.est_ciblable()):
			continue
		var d := global_position.distance_to(e.global_position)
		if d > portee:
			continue
		var score := d
		if avec_joystick:
			var angle := rad_to_deg(joy.normalized().angle_to(Combat.direction_plate(global_position, e.global_position)))
			if angle > 60.0:
				continue
			score = angle + d   # surtout l'angle, la distance départage
		if score < meilleur_score:
			meilleur_score = score
			meilleur = e
	return meilleur


## Direction de l'action : le joystick s'il est poussé, sinon l'ennemi ciblable le plus proche
## (s'il est assez près ; pas un squelette qui sort encore de terre), sinon droit devant.
func direction_visee(portee := EQ.visee_portee) -> Vector3:
	var joy := commandes.deplacement
	if joy.length() > 0.25:
		return Vector3(joy.x, 0, joy.z).normalized()
	var cible := cible_visee(portee)
	if cible:
		var v := Combat.direction_plate(global_position, cible.global_position)
		if v != Vector3.ZERO:
			return v
	return Vector3(avant().x, 0, avant().z).normalized()


# ---------------------------------------------------------------- dégâts reçus
## Appelé par Combat.porter_coup. Renvoie les dégâts réellement subis.
func recevoir_coup(degats: float, source: Node3D, _lourd: bool) -> float:
	if etat == Etat.MORT:
		return 0.0
	if _intercepter_coup(source):
		return 0.0
	var reel := sante.subir(degats, source)
	if reel <= 0.0:
		return 0.0
	EventBus.coup_porte.emit(global_position + Vector3.UP * 2.2, reel, true, true, self, source)
	if sante.est_mort:
		return reel
	sante.rendre_invulnerable(EQ.heros_invulnerable_apres_coup)
	_quitter_action()
	_collisions_normales()
	_direction = Combat.direction_plate(source.global_position, global_position) if source else -avant()
	_jouer("Hit_A", 1.3, 0.04, true)
	_changer(Etat.TOUCHE)
	return reel


## Appelé quand une action est coupée (coup reçu, mort) : l'archétype remet son visuel en ordre.
func _quitter_action() -> void:
	pass


func _etat_touche() -> void:
	var v := EQ.heros_recul_quand_touche / EQ.heros_duree_recul if _t < EQ.heros_duree_recul else 0.0
	velocity.x = _direction.x * v
	velocity.z = _direction.z * v
	if _t >= EQ.heros_duree_touche:
		_changer(Etat.LIBRE)


func _on_mort(_source: Node) -> void:
	velocity = Vector3.ZERO
	collision_layer = 0
	_quitter_action()
	_jouer("Death_A", 1.0, 0.05, true)
	_changer(Etat.MORT)
	EventBus.heros_mort.emit(self)


func _etat_mort() -> void:
	_immobile()
	if reapparition_auto and _t >= EQ.heros_delai_reapparition:
		reapparaitre()


func reapparaitre(ou: Variant = null) -> void:
	global_position = ou if ou is Vector3 else point_reapparition
	progres_reanimation = 0.0
	afficher_reanimation(0.0, false)
	collision_layer = Combat.COUCHE_HEROS
	_collisions_normales()
	sante.soigner_completement()
	sante.rendre_invulnerable(EQ.heros_invulnerable_reapparition)
	commandes.vider()
	_reinitialiser()
	_jouer("Idle", 1.0, 0.0, true)
	_changer(Etat.LIBRE)
	EventBus.heros_reapparu.emit(self)


func est_vivant() -> bool:
	return etat != Etat.MORT


func temps_avant_reapparition() -> float:
	return maxf(0.0, EQ.heros_delai_reapparition - _t) if etat == Etat.MORT else 0.0


# ---------------------------------------------------------------- coop
## Ce que l'hôte envoie de ce héros à chaque instantané (voir SynchroArene).
func instantane() -> Array:
	var nom_anim := String(anim.current_animation)
	return [global_position, rotation.y, int(etat), nom_anim, anim.get_playing_speed(), sante.pv, visuel.visible,
			progres_reanimation]


## Marionnette : applique ce que l'hôte a envoyé (la position est posée à part, lissée).
func appliquer_instantane(etat_recu: int, nom_anim: String, vitesse: float, pv: float, visible_recu: bool, progres := 0.0) -> void:
	afficher_reanimation(progres, etat_recu == int(Etat.MORT))
	if etat_recu != int(etat):
		etat = etat_recu as Etat
		_t = 0.0
		if nom_anim != "" and anim.has_animation(nom_anim):
			_jouer(nom_anim, vitesse, 0.08, true)
	elif nom_anim != "" and anim.current_animation != nom_anim and anim.has_animation(nom_anim):
		_jouer(nom_anim, vitesse, 0.1)
	sante.definir_pv(pv)
	if visible_recu != visuel.visible:
		visuel.visible = visible_recu
		EffetsMagie.fumee(get_parent(), global_position)   # téléportation de l'Occultiste


## Coop, invité : l'hôte a décidé de ce qui arrive à notre héros (coup reçu, riposte, mort, retour).
func evenement_autorite(type: String, pv: float, point: Vector3) -> void:
	sante.definir_pv(pv)
	match type:
		"touche":
			if etat == Etat.MORT:
				return
			_quitter_action()
			_collisions_normales()
			_direction = Combat.direction_plate(point, global_position)
			if _direction == Vector3.ZERO:
				_direction = -avant()
			_jouer("Hit_A", 1.3, 0.04, true)
			_changer(Etat.TOUCHE)
		"riposte":
			_riposte_autorite(point)
		"mort":
			if etat != Etat.MORT:
				sante.est_mort = true
				_on_mort(null)
		"reapparu":
			reapparaitre(point)
			sante.definir_pv(pv)   # relevé par le partenaire : seulement une partie des PV


## Coop (hôte) : le partenaire l'a relevé ; il repart avec une partie de ses PV.
func relever(part_pv: float) -> void:
	afficher_reanimation(0.0, false)
	collision_layer = Combat.COUCHE_HEROS
	_collisions_normales()
	sante.soigner_completement()
	sante.definir_pv(sante.pv_max * part_pv)
	sante.rendre_invulnerable(EQ.reanimation_invulnerable)
	commandes.vider()
	_reinitialiser()
	_jouer("Idle", 1.0, 0.2, true)
	_changer(Etat.LIBRE)
	EventBus.heros_reapparu.emit(self)


## Coop : zone verte au sol autour du héros à terre (où se placer pour le relever) qui se remplit.
func afficher_reanimation(progres: float, visible_zone: bool) -> void:
	progres_reanimation = progres
	if not visible_zone:
		if _zone_reanimation:
			_zone_reanimation.visible = false
		return
	if _zone_reanimation == null:
		_zone_reanimation = Node3D.new()
		for i in 2:
			var m := MeshInstance3D.new()
			var disque := CylinderMesh.new()
			disque.top_radius = EQ.reanimation_rayon
			disque.bottom_radius = EQ.reanimation_rayon
			disque.height = 0.02
			disque.radial_segments = 32
			disque.rings = 1
			m.mesh = disque
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color = Color(0.35, 1.0, 0.55, 0.18 if i == 0 else 0.5)
			mat.render_priority = i
			m.material_override = mat
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			m.position.y = 0.09 + 0.004 * i
			m.name = "Zone" if i == 0 else "Remplissage"
			_zone_reanimation.add_child(m)
		add_child(_zone_reanimation)
	_zone_reanimation.visible = true
	var f := maxf(progres, 0.01)
	(_zone_reanimation.get_node("Remplissage") as Node3D).scale = Vector3(f, 1, f)


## La parade du Bretteur a réussi chez l'hôte : on joue la riposte chez soi aussi.
func _riposte_autorite(_point: Vector3) -> void:
	pass


## Anneau coloré au sol sous le héros (coop : doré pour soi, vert pour le partenaire).
func ajouter_anneau(couleur: Color) -> void:
	var m := MeshInstance3D.new()
	var tore := TorusMesh.new()
	tore.inner_radius = 0.5
	tore.outer_radius = 0.62
	tore.rings = 32
	tore.ring_segments = 4
	m.mesh = tore
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(couleur, 0.75)
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.scale = Vector3(1, 0.12, 1)
	m.position.y = 0.07
	m.name = "Anneau"
	add_child(m)


# ---------------------------------------------------------------- animations
## Joue une animation en fondu depuis la pose actuelle ; `rejouer` la reprend au début si c'est
## déjà celle-ci. (Ne pas appeler anim.stop() avant : le fondu partirait de rien et la pose sauterait.)
func _jouer(nom: String, vitesse := 1.0, fondu := 0.12, rejouer := false) -> void:
	var deja := anim.current_animation == nom
	anim.play(nom, fondu, vitesse)
	if deja and rejouer:
		anim.seek(0.0, true)
