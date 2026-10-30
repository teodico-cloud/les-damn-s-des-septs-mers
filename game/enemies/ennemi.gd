class_name Ennemi
extends CharacterBody3D
## Ennemi de corps-à-corps (jalon 1 : le Matelot squelette). Il sort de terre, poursuit le héros le
## plus proche, annonce son coup (marque au sol), frappe, puis reste un instant vulnérable.
## En coop, seul l'hôte fait tourner cette logique ; chez l'invité, l'ennemi est une « marionnette » qui
## affiche ce que l'hôte envoie (position, état, animation, marque) et n'agit sur rien.

const EQ: Equilibrage = preload("res://data/equilibrage.tres")
const MODELE := preload("res://assets/models/enemies/Skeleton_Minion.glb")
const LAME := preload("res://assets/models/enemies/Skeleton_Blade.gltf")

enum Etat { APPARITION, POURSUITE, PREPARATION, FRAPPE, RECUPERATION, TOUCHE, ETOURDI, MORT, ENCHAINE }

static var _mat_yeux_rouges: StandardMaterial3D
static var _mat_chaine: StandardMaterial3D
static var _maillon: CylinderMesh

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
var _yeux: MeshInstance3D           ## yeux du squelette : rougeoient pendant l'annonce du coup
var _marque_par: Node3D             ## Occultiste qui l'a marqué (Marque maudite)
var _marque_restant := 0.0
var _rune: Node3D                   ## rune verte au-dessus de la tête quand il est marqué
var _chaines: Node3D                ## chaînes spectrales visibles quand il est immobilisé
var marionnette := false            ## coop, invité : affiché d'après l'hôte, sans IA ni règles
var _vitesse_anim := 1.0            ## vitesse demandée (pas celle figée un instant par l'arrêt sur image)


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
	_yeux = visuel.find_child("Skeleton_Minion_Eyes", true, false) as MeshInstance3D

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
		_yeux_rouges(false)
	if nouvel != Etat.ENCHAINE and _chaines:
		_chaines.queue_free()
		_chaines = null


# ---------------------------------------------------------------- boucle
func _physics_process(delta: float) -> void:
	if marionnette:
		_t += delta
		if etat == Etat.PREPARATION:
			_preparer_visuel()
		if _rune and _rune.visible:
			_rune.rotate_y(3.0 * delta)
		return
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
		Etat.RECUPERATION, Etat.TOUCHE, Etat.ETOURDI, Etat.ENCHAINE:
			if _t >= _duree_etat:
				_changer(Etat.POURSUITE)
		Etat.MORT:
			if _t >= EQ.squelette_duree_corps:
				queue_free()
	if _marque_restant > 0.0:
		_marque_restant -= delta
		if _rune:
			_rune.rotate_y(3.0 * delta)
		if _marque_restant <= 0.0:
			_effacer_marque()
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
	_yeux_rouges(true)
	_changer(Etat.PREPARATION, EQ.squelette_preparation)


func _preparer() -> void:
	_preparer_visuel()
	if _t >= EQ.squelette_preparation:
		_changer(Etat.FRAPPE)
		marque.visible = true


## Zone au sol qui se remplit pendant l'annonce (aussi chez l'invité).
func _preparer_visuel() -> void:
	var p := clampf(_t / EQ.squelette_preparation, 0.0, 1.0)
	_remplissage.scale = Vector3(maxf(p, 0.01), 1.0, maxf(p, 0.01))
	_mat_marque.albedo_color = Color(1.0, 0.3 + 0.2 * p, 0.1, 0.3 + 0.35 * p)


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
	if marionnette:
		return 0.0
	if etat == Etat.MORT or etat == Etat.APPARITION:
		return 0.0
	var reel := sante.subir(degats * multiplicateur_degats(source), source)
	if reel <= 0.0:
		return 0.0
	EventBus.coup_porte.emit(global_position + Vector3.UP * 2.1, reel, lourd, false, self, source)
	Combat.flash(visuel)
	if source and etat != Etat.ENCHAINE:   # enchaîné : il ne bouge pas, même frappé
		var distance := EQ.squelette_recul_coup_lourd if lourd else EQ.squelette_recul_quand_touche
		# vitesse de départ pour parcourir exactement `distance` mètres en freinant
		var vitesse := sqrt(2.0 * EQ.squelette_freinage_recul * distance)
		_recul = Combat.direction_plate(source.global_position, global_position) * vitesse
	if sante.est_mort or etat == Etat.ETOURDI or etat == Etat.ENCHAINE:
		return reel
	var en_attaque := etat == Etat.PREPARATION or etat == Etat.FRAPPE
	if lourd or not en_attaque:
		_jouer("Hit_A", 1.4, 0.04, true)
		_changer(Etat.TOUCHE, EQ.squelette_duree_touche_lourd if lourd else EQ.squelette_duree_touche)
	return reel


## Bonus de dégâts de la Marque maudite : +40 % pour les coups du partenaire, +15 % pour ceux de
## l'Occultiste qui l'a posée (réglages occ_marque_bonus_*).
func multiplicateur_degats(source: Node) -> float:
	if _marque_restant <= 0.0:
		return 1.0
	if source != null and source == _marque_par:
		return 1.0 + EQ.occ_marque_bonus_soi
	return 1.0 + EQ.occ_marque_bonus_partenaire


func est_marque() -> bool:
	return _marque_restant > 0.0


## Marque maudite posée par un Occultiste.
func marquer(par: Node3D, duree: float) -> void:
	if marionnette:
		return
	if etat == Etat.MORT:
		return
	_marque_par = par
	_marque_restant = duree
	if _rune == null:
		_rune = Node3D.new()
		var anneau := MeshInstance3D.new()
		var tore := TorusMesh.new()
		tore.inner_radius = 0.26
		tore.outer_radius = 0.38
		tore.rings = 20
		tore.ring_segments = 6
		anneau.mesh = tore
		anneau.material_override = EffetsMagie.mat_rune()
		anneau.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		anneau.rotation.x = PI / 2.0   # debout, face à la caméra quand il tourne
		_rune.add_child(anneau)
		var coeur := MeshInstance3D.new()
		var losange := SphereMesh.new()
		losange.radius = 0.11
		losange.height = 0.34
		losange.radial_segments = 4
		losange.rings = 2
		coeur.mesh = losange
		coeur.material_override = EffetsMagie.mat_rune()
		coeur.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_rune.add_child(coeur)
		_rune.position = Vector3(0, 2.55, 0)
		add_child(_rune)
	_rune.visible = true


func _effacer_marque() -> void:
	_marque_restant = 0.0
	_marque_par = null
	if _rune:
		_rune.visible = false


## Chaînes spectrales : immobilisé (ni déplacement ni attaque) ; coupe un coup en préparation.
func immobiliser(duree: float) -> void:
	if marionnette:
		return
	if etat == Etat.MORT or etat == Etat.APPARITION:
		return
	_recul = Vector3.ZERO
	if etat == Etat.ETOURDI:
		duree = maxf(duree, _duree_etat - _t)   # on garde le plus long des deux
	_jouer("Idle_Combat", 0.25, 0.1)
	_changer(Etat.ENCHAINE, duree)
	if _chaines:   # déjà enchaîné : on remplace les anciennes chaînes
		_chaines.queue_free()
	_chaines = _creer_chaines()
	add_child(_chaines)


func _creer_chaines() -> Node3D:
	if _mat_chaine == null:
		_mat_chaine = StandardMaterial3D.new()
		_mat_chaine.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat_chaine.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat_chaine.albedo_color = Color(0.4, 1.0, 0.55, 0.8)
	if _maillon == null:
		_maillon = CylinderMesh.new()
		_maillon.top_radius = 0.06
		_maillon.bottom_radius = 0.06
		_maillon.height = 1.5
		_maillon.radial_segments = 6
		_maillon.rings = 1
	var groupe := Node3D.new()
	for i in 6:
		var c := MeshInstance3D.new()
		c.mesh = _maillon
		c.material_override = _mat_chaine
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a := TAU * i / 6.0 + PI / 6.0
		# du sol à 0,8 m autour de lui jusqu'à sa taille : penchée vers lui
		c.position = Vector3(cos(a) * 0.45, 0.65, sin(a) * 0.45)
		c.rotation = Vector3(sin(a) * 0.55, 0, -cos(a) * 0.55)
		groupe.add_child(c)
	return groupe


func _yeux_rouges(actif: bool) -> void:
	if _yeux == null:
		return
	if actif and _mat_yeux_rouges == null:
		_mat_yeux_rouges = StandardMaterial3D.new()
		_mat_yeux_rouges.albedo_color = Color(0.6, 0.02, 0.0)
		_mat_yeux_rouges.emission_enabled = true
		_mat_yeux_rouges.emission = Color(1.0, 0.08, 0.02)
		_mat_yeux_rouges.emission_energy_multiplier = 4.0
	_yeux.material_override = _mat_yeux_rouges if actif else null


func etourdir(duree: float) -> void:
	if marionnette:
		return
	if etat == Etat.MORT:
		return
	if etat == Etat.ENCHAINE:   # déjà enchaîné : il le reste, au moins aussi longtemps
		_duree_etat = maxf(_duree_etat, _t + duree)
		return
	_jouer("Hit_B", 0.8, 0.04, true)
	_changer(Etat.ETOURDI, duree)


func _on_mort(_source: Node) -> void:
	_effacer_marque()
	collision_layer = 0
	collision_mask = Combat.COUCHE_MONDE
	_jouer("Death_C_Skeletons", 1.0, 0.05, true)
	_changer(Etat.MORT)
	remove_from_group("ennemis")
	vaincu.emit(self)
	EventBus.ennemi_vaincu.emit(self)


## Joue une animation en fondu depuis la pose actuelle ; `rejouer` la reprend au début si c'est
## déjà celle-ci. (Ne pas appeler anim.stop() avant : le fondu partirait de rien et la pose sauterait.)
# ---------------------------------------------------------------- coop
## Ce que l'hôte envoie de cet ennemi à chaque instantané (voir SynchroArene). La vitesse envoyée est
## celle demandée : pendant l'arrêt sur image local, l'animation est figée (vitesse 0) chez l'hôte.
func instantane() -> Array:
	return [global_position, rotation.y, int(etat), String(anim.current_animation), _vitesse_anim,
			sante.pv, _marque_restant > 0.0, _t]


## Marionnette : applique l'état reçu de l'hôte (la position est posée à part, lissée). `t_etat` :
## temps passé dans cet état chez l'hôte, estimé à maintenant ; il cale l'annonce au sol et l'animation.
func appliquer_instantane(etat_recu: int, nom_anim: String, vitesse: float, pv: float, marque_recue: bool, t_etat := 0.0) -> void:
	var reentre := etat_recu == int(etat) and t_etat + 0.05 < _t   # même état recommencé chez l'hôte
	if etat_recu != int(etat) or reentre:
		var nouvel := etat_recu as Etat
		_changer(nouvel)
		match nouvel:
			Etat.PREPARATION:
				marque.visible = true
				_yeux_rouges(true)
			Etat.FRAPPE:
				marque.visible = true
				_yeux_rouges(true)
			Etat.ENCHAINE:
				if _chaines:
					_chaines.queue_free()
				_chaines = _creer_chaines()
				add_child(_chaines)
			Etat.MORT:
				remove_from_group("ennemis")
		collision_layer = 0 if nouvel == Etat.APPARITION or nouvel == Etat.MORT else Combat.COUCHE_ENNEMIS
		if nom_anim != "" and anim.has_animation(nom_anim) and (reentre or anim.current_animation != nom_anim):
			_jouer_cale(nom_anim, vitesse, t_etat)
	elif nom_anim != "" and anim.current_animation != nom_anim and anim.has_animation(nom_anim):
		_jouer_cale(nom_anim, vitesse, t_etat)
	_t = t_etat
	sante.definir_pv(pv)
	if marque_recue and _marque_restant <= 0.0:
		var vrai := marionnette
		marionnette = false        # marquer() ne fait rien sur une marionnette
		marquer(null, 3600.0)      # durée : c'est l'hôte qui dira quand elle s'efface
		marionnette = vrai
	elif not marque_recue and _marque_restant > 0.0:
		_effacer_marque()


## Joue une animation reçue de l'hôte, à l'endroit où elle en est chez lui.
func _jouer_cale(nom: String, vitesse: float, t_etat: float) -> void:
	_jouer(nom, vitesse, 0.06, true)
	var duree := anim.get_animation(nom).length
	var pos := t_etat * vitesse
	if anim.get_animation(nom).loop_mode != Animation.LOOP_NONE:
		pos = fmod(pos, duree)
	anim.seek(clampf(pos, 0.0, maxf(duree - 0.01, 0.0)), true)


## Coop, invité : l'hôte signale un coup reçu (éclair blanc).
func flash_coup() -> void:
	Combat.flash(visuel)


func _jouer(nom: String, vitesse := 1.0, fondu := 0.12, rejouer := false) -> void:
	_vitesse_anim = vitesse
	var deja := anim.current_animation == nom
	anim.play(nom, fondu, vitesse)
	if deja and rejouer:
		anim.seek(0.0, true)
