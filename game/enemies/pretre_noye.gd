class_name PretreNoye
extends Ennemi
## Prêtre noyé (jalon 3) : il garde ses distances et
## - relève un squelette tombé (une fois chacun) : un cercle vert se remplit sur la tombe pendant son
##   incantation ; un coup l'interrompt (choix de Téo) ;
## - maudit le sol : un cercle vert annonce une flaque qui blesse tant qu'on reste dedans.
## Il faut le tuer en premier. En coop, l'invité voit les cercles par EventBus.effet_visuel.

const MODELE_PRETRE := preload("res://assets/models/enemies/Skeleton_Mage.glb")
const BATON := preload("res://assets/models/enemies/Skeleton_Staff.gltf")
const VERT := Color(0.3, 1.0, 0.5)

static var _mat_noye: StandardMaterial3D
static var _mat_yeux_verts: StandardMaterial3D

var _tombe := -1
var _releve_fait := false
var _point := Vector3.ZERO        ## où tombe la flaque, ou la tombe qu'il relève
var _recharge_relever := 1.5
var _cercle: Node3D               ## cercle vert qui se remplit (incantation ou annonce de flaque)
var _disque_cercle: MeshInstance3D


func type_ennemi() -> StringName:
	return &"pretre"


func _modele() -> PackedScene:
	return MODELE_PRETRE


func _arme() -> PackedScene:
	return BATON


func _prefixe() -> String:
	return "Skeleton_Mage"


func _pv() -> float:
	return EQ.pretre_pv_max


func _boucles() -> Array:
	return ["Idle_Combat", "Walking_D_Skeletons", "Walking_Backwards", "Spellcasting"]


## Noyé : os verdis, yeux verts qui luisent, une petite lueur autour de lui.
func _preparer_modele() -> void:
	if _mat_noye == null:
		var base: StandardMaterial3D = load("res://assets/materials/kaykit_squelette.tres")
		_mat_noye = base.duplicate()
		_mat_noye.albedo_color = Color(0.55, 0.82, 0.62)
		_mat_yeux_verts = StandardMaterial3D.new()
		_mat_yeux_verts.albedo_color = Color(0.1, 0.5, 0.2)
		_mat_yeux_verts.emission_enabled = true
		_mat_yeux_verts.emission = VERT
		_mat_yeux_verts.emission_energy_multiplier = 4.0
	for m in visuel.find_children(_prefixe() + "_*", "MeshInstance3D", true, false):
		if not String(m.name).ends_with("Eyes"):
			m.material_override = _mat_noye
	_yeux_rouges(false)
	var lueur := OmniLight3D.new()
	lueur.light_color = VERT
	lueur.light_energy = 0.9
	lueur.omni_range = 3.0
	lueur.position = Vector3(0, 1.6, 0)
	add_child(lueur)


## Ses yeux restent verts (pas rouges : il n'attaque pas au corps-à-corps).
func _yeux_rouges(_actif: bool) -> void:
	if _yeux and _mat_yeux_verts:
		_yeux.material_override = _mat_yeux_verts


func _montrer_annonce(_oui: bool) -> void:
	marque.visible = false   # pas de zone devant lui : ses cercles sont sur la tombe ou sous le héros


func signal_parade() -> bool:
	return false


func _generateur() -> GenerateurEnnemis:
	return get_parent() as GenerateurEnnemis


func _monde() -> Node:
	return get_parent().get_parent() if get_parent() is GenerateurEnnemis else get_parent()


# ---------------------------------------------------------------- comportement (hôte)
func _poursuivre(delta: float) -> void:
	_recharge_relever = maxf(0.0, _recharge_relever - delta)
	var gen := _generateur()
	if gen and _recharge_relever <= 0.0:
		var i := gen.tombe_proche(global_position, EQ.pretre_rayon_relever)
		if i >= 0:
			_commencer_incantation(i)
			return
	var cible := heros_le_plus_proche()
	if cible == null:
		_jouer("Idle_Combat")
		return
	var dir := Combat.direction_plate(global_position, cible.global_position)
	var dist := global_position.distance_to(cible.global_position)
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), clampf(6.0 * delta, 0.0, 1.0))
	if _recharge_attaque <= 0.0 and dist <= EQ.pretre_portee_flaque:
		_maudire(cible.global_position)
		return
	if dist < EQ.pretre_distance - 1.0:
		velocity.x = -dir.x * EQ.pretre_vitesse
		velocity.z = -dir.z * EQ.pretre_vitesse
		_jouer("Walking_Backwards", 1.0)
	elif dist > EQ.pretre_distance + 1.5:
		velocity.x = dir.x * EQ.pretre_vitesse
		velocity.z = dir.z * EQ.pretre_vitesse
		_jouer("Walking_D_Skeletons", 1.1)
	else:
		_jouer("Idle_Combat")


func _commencer_incantation(i: int) -> void:
	var gen := _generateur()
	gen.reserver_tombe(i)
	_tombe = i
	_releve_fait = false
	_point = gen.tombes[i]["pos"]
	var dir := Combat.direction_plate(global_position, _point)
	if dir != Vector3.ZERO:
		rotation.y = atan2(dir.x, dir.z)
	_jouer("Spellcasting", 1.0, 0.1, true)
	_changer(Etat.INCANTATION, EQ.pretre_incantation)
	_montrer_cercle(_point, 0.9)
	EventBus.effet_visuel.emit(self, "relever", _point)


func _incanter() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	_incanter_visuel()
	if _t >= EQ.pretre_incantation:
		_releve_fait = true
		var gen := _generateur()
		if gen:
			gen.relever(_tombe)
		EffetsMagie.fumee(_monde(), _point)
		_recharge_relever = EQ.pretre_recharge_relever
		_jouer("Idle_Combat", 1.0, 0.2)
		_changer(Etat.RECUPERATION, 0.6)


## Maudire le sol sous le héros : un cercle vert l'annonce, puis la flaque.
func _maudire(point: Vector3) -> void:
	_point = Vector3(point.x, 0.0, point.z)
	_jouer("Spellcast_Shoot", 0.9, 0.08, true)
	_changer(Etat.PREPARATION, EQ.pretre_annonce_flaque)
	_montrer_cercle(_point, EQ.flaque_rayon)
	EventBus.effet_visuel.emit(self, "flaque_annonce", _point)


func _preparer() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	_preparer_visuel()
	if _t >= EQ.pretre_annonce_flaque:
		FlaqueMaudite.creer(_monde(), _point, true)
		EventBus.effet_visuel.emit(self, "flaque", _point)
		_recharge_attaque = EQ.pretre_recharge_flaque
		_changer(Etat.RECUPERATION, 0.5)


func _frapper() -> void:
	_changer(Etat.POURSUITE)


## Un coup (même léger) coupe son incantation : le mort reste à terre (choix de Téo). La tombe
## redevient libre : il pourra réessayer plus tard.
func _quitter_etat(ancien: Etat, _nouvel: Etat) -> void:
	if ancien == Etat.INCANTATION:
		if not _releve_fait and not marionnette and _generateur():
			_generateur().liberer_tombe(_tombe)
		_tombe = -1
		_retirer_cercle()
	elif ancien == Etat.PREPARATION:
		_retirer_cercle()


# ---------------------------------------------------------------- cercles (aussi chez l'invité)
func _montrer_cercle(pos: Vector3, r: float) -> void:
	_retirer_cercle()
	_cercle = Node3D.new()
	var anneau := MeshInstance3D.new()
	var tore := TorusMesh.new()
	tore.inner_radius = r - 0.12
	tore.outer_radius = r
	tore.rings = 32
	tore.ring_segments = 6
	anneau.mesh = tore
	anneau.scale = Vector3(1, 0.15, 1)
	anneau.material_override = EffetsMagie.mat_rune()
	anneau.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cercle.add_child(anneau)
	_disque_cercle = MeshInstance3D.new()
	var disque := CylinderMesh.new()
	disque.top_radius = r
	disque.bottom_radius = r
	disque.height = 0.02
	disque.radial_segments = 32
	disque.rings = 1
	_disque_cercle.mesh = disque
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(VERT, 0.45)
	_disque_cercle.material_override = mat
	_disque_cercle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_disque_cercle.scale = Vector3(0.01, 1, 0.01)
	_cercle.add_child(_disque_cercle)
	_cercle.position = Vector3(pos.x, 0.1, pos.z)
	_monde().add_child(_cercle)


func _retirer_cercle() -> void:
	if _cercle and is_instance_valid(_cercle):
		_cercle.queue_free()
	_cercle = null
	_disque_cercle = null


func _remplir(duree: float) -> void:
	if _disque_cercle and is_instance_valid(_disque_cercle):
		var p := clampf(_t / maxf(duree, 0.01), 0.01, 1.0)
		_disque_cercle.scale = Vector3(p, 1, p)


func _preparer_visuel() -> void:
	_remplir(EQ.pretre_annonce_flaque)


func _incanter_visuel() -> void:
	_remplir(EQ.pretre_incantation)


## Coop, invité : l'hôte a lancé une incantation ou une malédiction de ce prêtre.
func effet_recu(type: String, pos: Vector3) -> void:
	if type == "relever":
		_montrer_cercle(pos, 0.9)
	elif type == "flaque_annonce":
		_montrer_cercle(pos, EQ.flaque_rayon)


func _exit_tree() -> void:
	_retirer_cercle()
