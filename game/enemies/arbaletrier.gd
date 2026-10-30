class_name Arbaletrier
extends Ennemi
## Arbalétrier squelette (jalon 3) : il garde ses distances (recule si l'on s'approche), vise en
## montrant un trait rouge (annonce), puis tire un carreau visible qu'on peut esquiver — ou renvoyer
## avec la Parade (choix de Téo). Fragile : il faut aller le chercher.

const MODELE_ARB := preload("res://assets/models/enemies/Skeleton_Rogue.glb")
const ARBALETE := preload("res://assets/models/enemies/Skeleton_Crossbow.gltf")
## Bout de l'arbalète dans la pose de visée (repère du squelette : main droite, x < 0) : le trait
## rouge et le carreau en partent. Mesuré avec tools/sonde_arbalete.gd.
const BOUT := Vector3(-0.42, 1.0, 1.1)

static var _mat_visee: StandardMaterial3D
static var _maillage_visee: BoxMesh

var _visee: MeshInstance3D       ## trait rouge pendant la visée
var _requete := PhysicsRayQueryParameters3D.new()


func type_ennemi() -> StringName:
	return &"arbaletrier"


func _modele() -> PackedScene:
	return MODELE_ARB


func _arme() -> PackedScene:
	return ARBALETE


func _prefixe() -> String:
	return "Skeleton_Rogue"


func _pv() -> float:
	return EQ.arb_pv_max


func _boucles() -> Array:
	return ["Idle_Combat", "Running_C", "Walking_Backwards", "2H_Ranged_Aiming"]


## KayKit tient l'arbalète en travers du corps : dans la pose de visée, elle pointait à 90° sur la
## droite du squelette (sonde). Un quart de tour dans la main la remet face à la cible.
func _orienter_arme(arme: Node3D) -> void:
	arme.rotation_degrees = Vector3(0, 90, 0)


func _preparer_modele() -> void:
	if _mat_visee == null:
		_mat_visee = StandardMaterial3D.new()
		_mat_visee.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat_visee.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat_visee.albedo_color = Color(1.0, 0.15, 0.1, 0.7)
		_maillage_visee = BoxMesh.new()
		_maillage_visee.size = Vector3(0.04, 0.04, 1.0)
	_visee = MeshInstance3D.new()
	_visee.mesh = _maillage_visee
	_visee.material_override = _mat_visee
	_visee.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visee.visible = false
	add_child(_visee)
	_requete.collision_mask = Combat.COUCHE_MONDE


## L'annonce de l'arbalétrier : le trait rouge, pas la zone au sol.
func _montrer_annonce(oui: bool) -> void:
	marque.visible = false
	if _visee:
		_visee.visible = oui and etat == Etat.PREPARATION
		if _visee.visible:
			_preparer_visuel()


## Pas de zone dorée : la parade d'un carreau se joue à son arrivée, pas au signal.
func signal_parade() -> bool:
	return false


# ---------------------------------------------------------------- comportement
func _poursuivre(delta: float) -> void:
	var cible := heros_le_plus_proche()
	if cible == null:
		_jouer("Idle_Combat")
		return
	var dir := Combat.direction_plate(global_position, cible.global_position)
	var dist := global_position.distance_to(cible.global_position)
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), clampf(8.0 * delta, 0.0, 1.0))
	if dist < EQ.arb_distance_fuite:
		velocity.x = -dir.x * EQ.arb_vitesse * 0.85   # il recule en gardant l'œil sur le héros
		velocity.z = -dir.z * EQ.arb_vitesse * 0.85
		_jouer("Walking_Backwards", 1.2)
		return
	if dist <= EQ.arb_portee and _recharge_attaque <= 0.0 and _ligne_libre(cible):
		_commencer_preparation(dir)
		return
	if dist > EQ.arb_distance_ideale + 1.0:
		velocity.x = dir.x * EQ.arb_vitesse
		velocity.z = dir.z * EQ.arb_vitesse
		_jouer("Running_C", 0.9)
	else:
		_jouer("Idle_Combat")


## Rien (mur, meuble) entre lui et sa cible ?
func _ligne_libre(cible: Node3D) -> bool:
	_requete.from = global_position + Vector3.UP * 1.2
	_requete.to = cible.global_position + Vector3.UP * 1.2
	return get_world_3d().direct_space_state.intersect_ray(_requete).is_empty()


func _commencer_preparation(dir: Vector3) -> void:
	rotation.y = atan2(dir.x, dir.z)
	_impact_fait = false
	_jouer("2H_Ranged_Aiming", 1.0, 0.1, true)
	_changer(Etat.PREPARATION, EQ.arb_visee)
	_montrer_annonce(true)
	_yeux_rouges(true)


func _preparer() -> void:
	# il suit sa cible au début de la visée, puis bloque : on a le temps de sortir de la ligne
	if _t < EQ.arb_visee * EQ.arb_visee_suivie:
		var cible := heros_le_plus_proche()
		if cible:
			var dir := Combat.direction_plate(global_position, cible.global_position)
			rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), 0.25)
	_preparer_visuel()
	if _t >= EQ.arb_visee:
		_changer(Etat.FRAPPE)
		_tirer()


## Le trait de visée part de l'arbalète, droit devant, jusqu'au premier mur.
func _preparer_visuel() -> void:
	if _visee == null:
		return
	var depart := to_global(BOUT)
	var avant := Vector3(sin(rotation.y), 0, cos(rotation.y))
	var longueur := EQ.carreau_portee
	_requete.from = depart
	_requete.to = depart + avant * longueur
	var touche := get_world_3d().direct_space_state.intersect_ray(_requete)
	if not touche.is_empty():
		longueur = depart.distance_to(touche["position"])
	_visee.global_transform = Transform3D(Basis.looking_at(avant), depart + avant * (longueur * 0.5))
	_visee.scale = Vector3(1, 1, maxf(longueur, 0.1))


func _tirer() -> void:
	_visee.visible = false   # (en FRAPPE, `_changer` laisse l'annonce : celle du matelot dure pendant le coup)
	_jouer("2H_Ranged_Shoot", 1.0, 0.04, true)
	var avant := Vector3(sin(rotation.y), 0, cos(rotation.y))
	Carreau.tirer(get_parent().get_parent() if get_parent() is GenerateurEnnemis else get_parent(), self,
			to_global(BOUT), avant)


func _frapper() -> void:
	if _t >= 0.35:
		_recharge_attaque = EQ.arb_recharge
		_jouer("2H_Ranged_Reload", 1.0, 0.1, true)
		_changer(Etat.RECUPERATION, 0.9)
