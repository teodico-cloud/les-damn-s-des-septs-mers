class_name Ennemi
extends CharacterBody3D
## Ennemi de corps-à-corps (jalon 1 : le Matelot squelette). Il sort de terre, poursuit le héros le
## plus proche, annonce son coup (marque au sol), frappe, puis reste un instant vulnérable.
## En coop, seul l'hôte fera tourner cette logique ; l'autre téléphone recevra les positions.

const EQ: Equilibrage = preload("res://data/equilibrage.tres")
const MODELE := preload("res://assets/models/enemies/Skeleton_Minion.glb")
const LAME := preload("res://assets/models/enemies/Skeleton_Blade.gltf")

enum Etat { APPARITION, POURSUITE, PREPARATION, FRAPPE, RECUPERATION, TOUCHE, ETOURDI, MORT }

signal vaincu(ennemi: Ennemi)

var etat: Etat = Etat.APPARITION
var sante: Sante
var anim: AnimationPlayer
var visuel: Node3D
var marque: MeshInstance3D      ## annonce du coup au sol : zone entière, pâle dès le début…
var _remplissage: MeshInstance3D ## … et remplissage rouge qui grandit jusqu'au coup
var _mat_marque: StandardMaterial3D
var _t := 0.0
var _duree_etat := 0.0
var _recharge_attaque := 0.0
var _impact_fait := false
var _recul := Vector3.ZERO
var _apparition_rapide := false


## Crée un ennemi prêt à être ajouté à la scène. `rapide` saute l'animation de sortie de terre (tests).
static func creer(rapide := false) -> Ennemi:
	var e := Ennemi.new()
	e._apparition_rapide = rapide
	return e


func _ready() -> void:
	add_to_group("ennemis")
	collision_layer = Combat.COUCHE_ENNEMIS
	# pas la couche des héros : sinon un héros qui roule ou fend à travers lui le pousserait devant lui
	# (c'est le héros qui se heurte aux ennemis quand il marche, pas l'inverse)
	collision_mask = Combat.COUCHE_MONDE | Combat.COUCHE_ENNEMIS

	var forme := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.45
	capsule.height = 1.9
	forme.shape = capsule
	forme.position.y = 0.95
	add_child(forme)

	visuel = MODELE.instantiate()
	add_child(visuel)
	anim = visuel.find_child("AnimationPlayer", true, false)
	for boucle in ["Idle_Combat", "Running_C"]:
		anim.get_animation(boucle).loop_mode = Animation.LOOP_LINEAR
	_attacher_lame()
	_creer_marque()

	sante = Sante.new()
	sante.pv_max = EQ.squelette_pv_max
	add_child(sante)
	sante.mort.connect(_on_mort)

	if _apparition_rapide:
		_changer(Etat.POURSUITE)
	else:
		collision_layer = 0
		var duree := anim.get_animation("Spawn_Ground_Skeletons").length / 1.6
		_jouer("Spawn_Ground_Skeletons", 1.6, 0.0)
		_changer(Etat.APPARITION, duree)


func _attacher_lame() -> void:
	var sk: Skeleton3D = visuel.find_child("Skeleton3D", true, false)
	var attache := BoneAttachment3D.new()
	attache.bone_name = "handslot.r"
	sk.add_child(attache)
	attache.add_child(LAME.instantiate())


func _creer_marque() -> void:
	# La zone entière est visible dès le début de l'annonce (sinon le petit disque du début reste
	# caché sous les pieds des personnages) ; le remplissage montre le temps qu'il reste.
	marque = _disque(Color(1.0, 0.25, 0.1, 0.22), 0)
	marque.position = Vector3(0, 0.09, EQ.squelette_zone_avant)   # au-dessus des dalles (dessus à ~0,05)
	marque.visible = false
	add_child(marque)
	_remplissage = _disque(Color(1.0, 0.3, 0.1, 0.0), 1)
	_remplissage.position.y = 0.004
	marque.add_child(_remplissage)
	_mat_marque = _remplissage.material_override as StandardMaterial3D


func _disque(couleur: Color, priorite: int) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var disque := CylinderMesh.new()
	disque.top_radius = EQ.squelette_zone_rayon
	disque.bottom_radius = EQ.squelette_zone_rayon
	disque.height = 0.02
	disque.radial_segments = 32
	disque.rings = 1
	m.mesh = disque
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = couleur
	mat.render_priority = priorite   # le remplissage se dessine par-dessus la zone pâle
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m


func est_vivant() -> bool:
	return etat != Etat.MORT


## Vrai si on peut le viser et le toucher (pas mort, ni encore en train de sortir de terre).
func est_ciblable() -> bool:
	return etat != Etat.MORT and etat != Etat.APPARITION


func _changer(nouvel: Etat, duree := 0.0) -> void:
	etat = nouvel
	_t = 0.0
	_duree_etat = duree
	if nouvel != Etat.PREPARATION and nouvel != Etat.FRAPPE:
		marque.visible = false


# ---------------------------------------------------------------- boucle
func _physics_process(delta: float) -> void:
	_t += delta
	_recharge_attaque = max(0.0, _recharge_attaque - delta)
	velocity.x = 0.0
	velocity.z = 0.0
	match etat:
		Etat.APPARITION:
			if _t >= _duree_etat:
				collision_layer = Combat.COUCHE_ENNEMIS
				_changer(Etat.POURSUITE)
		Etat.POURSUITE: _poursuivre(delta)
		Etat.PREPARATION: _preparer()
		Etat.FRAPPE: _frapper()
		Etat.RECUPERATION, Etat.TOUCHE, Etat.ETOURDI:
			if _t >= _duree_etat:
				_changer(Etat.POURSUITE)
		Etat.MORT:
			if _t >= EQ.squelette_duree_corps:
				queue_free()
	# recul après un coup reçu
	if _recul.length() > 0.01:
		velocity.x += _recul.x
		velocity.z += _recul.z
		_recul = _recul.move_toward(Vector3.ZERO, EQ.squelette_freinage_recul * delta)
	velocity.y = -0.5 if is_on_floor() else velocity.y - 25.0 * delta
	move_and_slide()


func heros_le_plus_proche() -> Node3D:
	var meilleur: Node3D = null
	var dmin := INF
	for h in get_tree().get_nodes_in_group("heros"):
		if h is Node3D and h.has_method("est_vivant") and h.est_vivant():
			var d := global_position.distance_to(h.global_position)
			if d < dmin:
				dmin = d
				meilleur = h
	return meilleur


func _poursuivre(delta: float) -> void:
	var cible := heros_le_plus_proche()
	if cible == null:
		_jouer("Idle_Combat")
		return
	var dir := Combat.direction_plate(global_position, cible.global_position)
	var dist := global_position.distance_to(cible.global_position)
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), clampf(8.0 * delta, 0.0, 1.0))
	if dist <= EQ.squelette_portee_attaque:
		if _recharge_attaque <= 0.0:
			_commencer_preparation(dir)
		else:
			_jouer("Idle_Combat")
		return
	velocity.x = dir.x * EQ.squelette_vitesse
	velocity.z = dir.z * EQ.squelette_vitesse
	_jouer("Running_C", 0.9)


func _commencer_preparation(dir: Vector3) -> void:
	rotation.y = atan2(dir.x, dir.z)
	_impact_fait = false
	# l'animation est ralentie pour que son impact tombe à la fin de l'annonce
	var vitesse := EQ.squelette_impact_animation / EQ.squelette_preparation
	_jouer("1H_Melee_Attack_Chop", vitesse, 0.08, true)
	marque.visible = true
	_changer(Etat.PREPARATION, EQ.squelette_preparation)


func _preparer() -> void:
	var p := clampf(_t / EQ.squelette_preparation, 0.0, 1.0)
	_remplissage.scale = Vector3(maxf(p, 0.01), 1.0, maxf(p, 0.01))
	_mat_marque.albedo_color = Color(1.0, 0.3 + 0.2 * p, 0.1, 0.3 + 0.35 * p)
	if _t >= EQ.squelette_preparation:
		_changer(Etat.FRAPPE)
		marque.visible = true


func _frapper() -> void:
	if not _impact_fait:
		_impact_fait = true
		var centre := global_position + global_transform.basis.z * EQ.squelette_zone_avant + Vector3.UP
		for cible in Combat.cibles_dans_sphere(get_world_3d(), centre, EQ.squelette_zone_rayon, Combat.COUCHE_HEROS, [self]):
			Combat.porter_coup(self, cible, EQ.squelette_degats, false)
	if _t >= EQ.squelette_duree_frappe:
		marque.visible = false
		_recharge_attaque = EQ.squelette_recharge_attaque
		_changer(Etat.RECUPERATION, EQ.squelette_recuperation)


# ---------------------------------------------------------------- dégâts reçus
## Appelé par Combat.porter_coup. Un coup léger n'interrompt pas un squelette qui prépare ou porte
## son coup ; un coup lourd (3e coup du combo, fente, riposte) interrompt tout. Un squelette étourdi
## (riposte) le reste jusqu'au bout, même s'il est frappé : c'est le moment de le punir.
func recevoir_coup(degats: float, source: Node3D, lourd: bool) -> float:
	if etat == Etat.MORT or etat == Etat.APPARITION:
		return 0.0
	var reel := sante.subir(degats, source)
	if reel <= 0.0:
		return 0.0
	EventBus.coup_porte.emit(global_position + Vector3.UP * 2.1, reel, lourd, false)
	Combat.flash(visuel)
	if source:
		var distance := EQ.squelette_recul_coup_lourd if lourd else EQ.squelette_recul_quand_touche
		# vitesse de départ pour parcourir exactement `distance` mètres en freinant
		var vitesse := sqrt(2.0 * EQ.squelette_freinage_recul * distance)
		_recul = Combat.direction_plate(source.global_position, global_position) * vitesse
	if sante.est_mort or etat == Etat.ETOURDI:
		return reel
	var en_attaque := etat == Etat.PREPARATION or etat == Etat.FRAPPE
	if lourd or not en_attaque:
		_jouer("Hit_A", 1.4, 0.04, true)
		_changer(Etat.TOUCHE, EQ.squelette_duree_touche_lourd if lourd else EQ.squelette_duree_touche)
	return reel


func etourdir(duree: float) -> void:
	if etat == Etat.MORT:
		return
	_jouer("Hit_B", 0.8, 0.04, true)
	_changer(Etat.ETOURDI, duree)


func _on_mort(_source: Node) -> void:
	collision_layer = 0
	collision_mask = Combat.COUCHE_MONDE
	_jouer("Death_C_Skeletons", 1.0, 0.05, true)
	_changer(Etat.MORT)
	remove_from_group("ennemis")
	vaincu.emit(self)
	EventBus.ennemi_vaincu.emit(self)


## Joue une animation en fondu depuis la pose actuelle ; `rejouer` la reprend au début si c'est
## déjà celle-ci. (Ne pas appeler anim.stop() avant : le fondu partirait de rien et la pose sauterait.)
func _jouer(nom: String, vitesse := 1.0, fondu := 0.12, rejouer := false) -> void:
	var deja := anim.current_animation == nom
	anim.play(nom, fondu, vitesse)
	if deja and rejouer:
		anim.seek(0.0, true)
