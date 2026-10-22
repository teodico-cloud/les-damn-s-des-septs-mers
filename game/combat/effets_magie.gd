class_name EffetsMagie
extends RefCounted
## Effets visuels de la magie maudite (fumée, éclats, cercles au sol). Purement visuels : ils
## s'effacent seuls et n'ont aucun effet sur les règles. Les matières sont créées une seule fois.

const VERT := Color(0.35, 1.0, 0.55)

static var _mat_lueur: StandardMaterial3D
static var _mat_fumee: StandardMaterial3D
static var _mat_cercle: StandardMaterial3D
static var _mat_rune: StandardMaterial3D


## Matière verte lumineuse (déclenche le halo de l'éclairage).
static func mat_lueur() -> StandardMaterial3D:
	if _mat_lueur == null:
		_mat_lueur = StandardMaterial3D.new()
		_mat_lueur.albedo_color = Color(0.1, 0.35, 0.18)
		_mat_lueur.emission_enabled = true
		_mat_lueur.emission = VERT
		_mat_lueur.emission_energy_multiplier = 3.0
	return _mat_lueur


## Vert plus franc et moins éblouissant (rune de la Marque, chaînes) : reste vert sous le halo.
static func mat_rune() -> StandardMaterial3D:
	if _mat_rune == null:
		_mat_rune = StandardMaterial3D.new()
		_mat_rune.albedo_color = Color(0.15, 0.6, 0.3)
		_mat_rune.emission_enabled = true
		_mat_rune.emission = Color(0.2, 1.0, 0.4)
		_mat_rune.emission_energy_multiplier = 1.4
	return _mat_rune


static func _mat_particules() -> StandardMaterial3D:
	if _mat_fumee == null:
		_mat_fumee = StandardMaterial3D.new()
		_mat_fumee.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat_fumee.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat_fumee.vertex_color_use_as_albedo = true
		_mat_fumee.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	return _mat_fumee


## Bouffée de fumée verte (départ et arrivée de la téléportation).
static func fumee(parent: Node, pos: Vector3) -> void:
	_bouffee(parent, pos + Vector3.UP * 0.9, 26, 0.65, 1.6, Color(0.3, 0.85, 0.5, 0.85), Color(0.08, 0.14, 0.1, 0.0))


## Petit éclat vert (projectile qui touche).
static func eclat(parent: Node, pos: Vector3) -> void:
	_bouffee(parent, pos, 10, 0.3, 0.5, Color(0.6, 1.0, 0.7, 1.0), Color(0.2, 0.9, 0.4, 0.0))


static func _bouffee(parent: Node, pos: Vector3, nombre: int, duree: float, taille: float, debut: Color, fin: Color) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = nombre
	p.lifetime = duree
	var sphere := SphereMesh.new()
	sphere.radius = 0.12 * taille
	sphere.height = 0.24 * taille
	sphere.radial_segments = 8
	sphere.rings = 4
	sphere.material = _mat_particules()
	p.mesh = sphere
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.8 * taille
	p.initial_velocity_max = 2.2 * taille
	p.gravity = Vector3(0, 0.6, 0)
	p.damping_min = 2.0
	p.damping_max = 3.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.2
	var degrade := Gradient.new()
	degrade.set_color(0, debut)
	degrade.set_color(1, fin)
	p.color_ramp = degrade
	p.position = pos
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


## Cercle au sol qui s'élargit puis s'efface (zone des Chaînes spectrales).
static func cercle(parent: Node, pos: Vector3, rayon: float, duree: float) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	if _mat_cercle == null:
		_mat_cercle = StandardMaterial3D.new()
		_mat_cercle.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat_cercle.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat_cercle.albedo_color = Color(VERT, 0.35)
	var m := MeshInstance3D.new()
	var anneau := TorusMesh.new()
	anneau.inner_radius = rayon - 0.18
	anneau.outer_radius = rayon
	anneau.rings = 32
	anneau.ring_segments = 6
	m.mesh = anneau
	m.material_override = _mat_cercle
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.scale = Vector3(0.2, 0.15, 0.2)
	m.position = pos + Vector3.UP * 0.1
	parent.add_child(m)
	var t := m.create_tween()
	t.tween_property(m, "scale", Vector3(1.0, 0.15, 1.0), 0.18).set_ease(Tween.EASE_OUT)
	t.tween_interval(maxf(duree - 0.4, 0.0))
	t.tween_property(m, "scale", Vector3(1.05, 0.15, 1.05), 0.2)
	t.tween_callback(m.queue_free)
