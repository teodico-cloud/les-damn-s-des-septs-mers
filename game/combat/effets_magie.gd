class_name EffetsMagie
extends RefCounted
## Effets visuels de la magie maudite (fumée, éclats, cercles au sol). Purement visuels : ils
## s'effacent seuls et n'ont aucun effet sur les règles. Les matières sont créées une seule fois.

const VERT := Color(0.35, 1.0, 0.55)

static var _mat_lueur: StandardMaterial3D
static var _mat_fumee: StandardMaterial3D
static var _mat_cercle: StandardMaterial3D
static var _mat_rune: StandardMaterial3D
static var _ressources := {}   ## clé -> maillage ou dégradé déjà créé (une seule fois)


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
	var cle_maillage := "boule_%s" % taille
	if not _ressources.has(cle_maillage):
		var sphere := SphereMesh.new()
		sphere.radius = 0.12 * taille
		sphere.height = 0.24 * taille
		sphere.radial_segments = 8
		sphere.rings = 4
		sphere.material = _mat_particules()
		_ressources[cle_maillage] = sphere
	p.mesh = _ressources[cle_maillage]
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.8 * taille
	p.initial_velocity_max = 2.2 * taille
	p.gravity = Vector3(0, 0.6, 0)
	p.damping_min = 2.0
	p.damping_max = 3.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.2
	var cle_degrade := "degrade_%s_%s" % [debut, fin]
	if not _ressources.has(cle_degrade):
		var degrade := Gradient.new()
		degrade.set_color(0, debut)
		degrade.set_color(1, fin)
		_ressources[cle_degrade] = degrade
	p.color_ramp = _ressources[cle_degrade]
	p.position = pos
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


## Gerbe d'étincelles dorées (parade parfaite : lame contre lame) et un éclair de lumière bref.
static func etincelles(parent: Node, pos: Vector3) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 32
	p.lifetime = 0.4
	if not _ressources.has("etincelle"):
		var trait_ := BoxMesh.new()
		trait_.size = Vector3(0.06, 0.3, 0.06)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.vertex_color_use_as_albedo = true
		trait_.material = mat
		_ressources["etincelle"] = trait_
		var degrade := Gradient.new()
		degrade.set_color(0, Color(1.0, 0.8, 0.22, 1.0))   # or franc : le blanc se perd sur le sol clair
		degrade.set_color(1, Color(1.0, 0.42, 0.05, 0.0))
		_ressources["degrade_etincelle"] = degrade
	p.mesh = _ressources["etincelle"]
	p.color_ramp = _ressources["degrade_etincelle"]
	p.particle_flag_align_y = true   # chaque étincelle file dans le sens de sa course
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 8.5
	p.gravity = Vector3(0, -14.0, 0)
	p.damping_min = 1.0
	p.damping_max = 3.0
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.4
	p.position = pos
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
	var lumiere := OmniLight3D.new()
	lumiere.light_color = Color(1.0, 0.85, 0.45)
	lumiere.omni_range = 4.0
	lumiere.light_energy = 5.0
	lumiere.shadow_enabled = false
	lumiere.position = pos
	parent.add_child(lumiere)
	var t := lumiere.create_tween()
	t.tween_property(lumiere, "light_energy", 0.0, 0.3).set_ease(Tween.EASE_OUT)
	t.tween_callback(lumiere.queue_free)


## Explosion d'un tonneau de poudre : boule de feu, fumée noire, étincelles.
static func explosion(parent: Node, pos: Vector3) -> void:
	_bouffee(parent, pos, 30, 0.55, 2.4, Color(1.0, 0.62, 0.18, 1.0), Color(0.5, 0.12, 0.05, 0.0))
	_bouffee(parent, pos + Vector3.UP * 0.6, 16, 1.3, 2.8, Color(0.22, 0.2, 0.18, 0.85), Color(0.08, 0.08, 0.08, 0.0))
	etincelles(parent, pos)


## Cercle au sol qui s'élargit puis s'efface (zone des Chaînes spectrales).
static func cercle(parent: Node, pos: Vector3, rayon: float, duree: float) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	if _mat_cercle == null:
		_mat_cercle = StandardMaterial3D.new()
		_mat_cercle.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat_cercle.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat_cercle.albedo_color = Color(VERT, 0.35)
	var cle := "anneau_%s" % rayon
	if not _ressources.has(cle):
		var anneau := TorusMesh.new()
		anneau.inner_radius = rayon - 0.18
		anneau.outer_radius = rayon
		anneau.rings = 32
		anneau.ring_segments = 6
		_ressources[cle] = anneau
	var m := MeshInstance3D.new()
	m.mesh = _ressources[cle]
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


## Traînée lumineuse d'un coup de sabre : un arc qui s'efface en une fraction de seconde devant le
## héros. `coup` : 0 = diagonal, 1 = horizontal, 2 = de haut en bas (le coup lourd, plus large).
static func trainee_sabre(parent: Node, pos: Vector3, direction: Vector3, coup: int) -> void:
	if parent == null or not parent.is_inside_tree() or direction.length() < 0.01:
		return
	var cle := "arc_sabre"
	if not _ressources.has(cle):
		_ressources[cle] = _maillage_arc(1.0, 1.65, deg_to_rad(150.0), 18)
	var cle_mat := "mat_trainee_%d" % (1 if coup == 2 else 0)
	if not _ressources.has(cle_mat):
		var mat := StandardMaterial3D.new()   # partagée : chaque traînée s'efface par sa transparence
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.vertex_color_use_as_albedo = true
		# mélange plutôt qu'addition : sur le sol clair, l'addition virait au blanc éblouissant
		mat.albedo_color = Color(1.0, 0.8, 0.3, 0.95) if coup < 2 else Color(1.0, 0.55, 0.15, 1.0)
		_ressources[cle_mat] = mat
	var m := MeshInstance3D.new()
	m.mesh = _ressources[cle]
	m.material_override = _ressources[cle_mat]
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var lacet := atan2(direction.x, direction.z)
	var roulis: float = [deg_to_rad(-35.0), 0.0, deg_to_rad(90.0)][clampi(coup, 0, 2)]
	m.basis = Basis(Vector3.UP, lacet) * Basis(Vector3(0, 0, 1), roulis)
	m.position = pos + Vector3.UP * 1.05
	parent.add_child(m)
	var t := m.create_tween()
	t.set_parallel(true)
	var grand := 1.15 if coup == 2 else 1.0
	m.scale = Vector3.ONE * 0.85 * grand
	t.tween_property(m, "scale", Vector3.ONE * 1.1 * grand, 0.18).set_ease(Tween.EASE_OUT)
	t.tween_property(m, "transparency", 1.0, 0.18).set_delay(0.04)
	t.chain().tween_callback(m.queue_free)


## Bande en arc dans le plan horizontal, centrée sur l'avant (+z) : un voile qui se fond vers
## l'intérieur, un liseré net au bord extérieur (le chemin de la lame), plus marqué vers la fin du geste.
static func _maillage_arc(r_int: float, r_ext: float, ouverture: float, pas: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rayons := [r_int, r_ext - 0.14, r_ext]
	var opacites := [0.0, 0.45, 1.0]
	for i in pas:
		var a0 := -ouverture / 2.0 + ouverture * i / pas
		var a1 := -ouverture / 2.0 + ouverture * (i + 1) / pas
		var f0 := float(i) / pas
		var f1 := float(i + 1) / pas
		for b in 2:   # deux bandes : voile puis liseré
			var p := [Vector3(sin(a0), 0, cos(a0)) * rayons[b], Vector3(sin(a0), 0, cos(a0)) * rayons[b + 1],
					Vector3(sin(a1), 0, cos(a1)) * rayons[b], Vector3(sin(a1), 0, cos(a1)) * rayons[b + 1]]
			var c := [Color(1, 1, 1, opacites[b] * f0), Color(1, 1, 1, opacites[b + 1] * f0),
					Color(1, 1, 1, opacites[b] * f1), Color(1, 1, 1, opacites[b + 1] * f1)]
			for k in [0, 1, 2, 2, 1, 3]:
				st.set_color(c[k])
				st.add_vertex(p[k])
	return st.commit()


## Squelette vaincu : il éclate en os qui volent et rebondissent au sol, puis s'effacent.
## `parties` : maillages du squelette (crâne, mâchoire, bras, jambes, buste) en pose de repos.
static func eclater(parent: Node, parties: Array, origine: Transform3D, depuis: Vector3, force: float, duree: float) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	for partie in parties:
		var mi := partie as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var boite := mi.mesh.get_aabb()
		var corps := RigidBody3D.new()
		corps.collision_layer = 0                      # personne ne s'y cogne…
		corps.collision_mask = Combat.COUCHE_MONDE      # …mais ils tombent sur le sol et les murs
		corps.mass = 0.4
		var forme := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = (boite.size * 0.8).max(Vector3.ONE * 0.08)
		forme.shape = b
		corps.add_child(forme)
		var vue := MeshInstance3D.new()
		vue.mesh = mi.mesh
		vue.material_override = mi.get_active_material(0)
		vue.position = -boite.get_center()            # tourne autour de son propre centre
		vue.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		corps.add_child(vue)
		corps.transform = Transform3D(origine.basis, origine * boite.get_center())
		parent.add_child(corps)
		var sortie := (corps.global_position - depuis)
		sortie.y = 0.0
		sortie = sortie.normalized() if sortie.length() > 0.01 else Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
		# (pas trop haut : quelques os passaient par-dessus les murs invisibles côté caméra)
		corps.linear_velocity = (sortie + Vector3(randf_range(-0.6, 0.6), randf_range(0.6, 1.15), randf_range(-0.6, 0.6))) * force
		corps.angular_velocity = Vector3(randf_range(-12, 12), randf_range(-12, 12), randf_range(-12, 12))
		# (on rétrécit l'image, pas le corps : la physique n'accepte pas un corps mis à l'échelle)
		var t := corps.create_tween()
		t.tween_interval(duree * 0.75)
		t.tween_property(vue, "scale", Vector3.ONE * 0.01, duree * 0.25)
		t.tween_callback(corps.queue_free)
	_bouffee(parent, origine.origin + Vector3.UP * 0.8, 14, 0.5, 1.0, Color(0.85, 0.82, 0.72, 0.7), Color(0.3, 0.3, 0.3, 0.0))
