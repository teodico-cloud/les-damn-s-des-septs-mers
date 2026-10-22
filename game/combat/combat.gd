class_name Combat
extends RefCounted
## Règles communes du combat : couches de collision, recherche des cibles dans une zone,
## application d'un coup. Tout coup passe par porter_coup() : en coop, seul l'hôte l'appellera.

const COUCHE_MONDE := 1
const COUCHE_HEROS := 2
const COUCHE_ENNEMIS := 4

static var _sphere := SphereShape3D.new()


## Renvoie les combattants (nœuds ayant recevoir_coup) dont la collision touche la sphère.
static func cibles_dans_sphere(monde: World3D, centre: Vector3, rayon: float, masque: int, exclure: Array = []) -> Array[Node3D]:
	_sphere.radius = rayon
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _sphere
	q.transform = Transform3D(Basis.IDENTITY, centre)
	q.collision_mask = masque
	q.collide_with_areas = false
	q.collide_with_bodies = true
	var rids: Array[RID] = []
	for e in exclure:
		if e is CollisionObject3D:
			rids.append(e.get_rid())
	q.exclude = rids
	var resultat: Array[Node3D] = []
	for hit in monde.direct_space_state.intersect_shape(q, 16):
		var c = hit.get("collider")
		if c is Node3D and c.has_method("recevoir_coup") and not resultat.has(c):
			resultat.append(c)
	return resultat


## Applique un coup : renvoie les dégâts réellement infligés.
static func porter_coup(attaquant: Node3D, cible: Node3D, degats: float, lourd: bool) -> float:
	return cible.recevoir_coup(degats, attaquant, lourd)


## Vrai si `source` est devant `qui` (dans un cône de ± angle_deg autour de son regard).
static func est_devant(qui: Node3D, source: Node3D, angle_deg: float) -> bool:
	var avant := qui.global_transform.basis.z
	avant.y = 0.0
	var vers := source.global_position - qui.global_position
	vers.y = 0.0
	if vers.length() < 0.01 or avant.length() < 0.01:
		return true
	return rad_to_deg(avant.normalized().angle_to(vers.normalized())) <= angle_deg


## Direction horizontale normalisée de a vers b.
static func direction_plate(a: Vector3, b: Vector3) -> Vector3:
	var d := b - a
	d.y = 0.0
	return d.normalized() if d.length() > 0.001 else Vector3.ZERO


## Rend un modèle tout blanc un instant (retour visuel d'un coup reçu).
static func flash(modele: Node, duree := 0.08) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1, 1, 1, 0.75)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var maillages := modele.find_children("*", "MeshInstance3D", true, false)
	for m in maillages:
		(m as MeshInstance3D).material_overlay = mat
	await modele.get_tree().create_timer(duree, true, false, true).timeout
	for m in maillages:
		if is_instance_valid(m):
			(m as MeshInstance3D).material_overlay = null
