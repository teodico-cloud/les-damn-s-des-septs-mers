class_name Salle
extends Node3D
## Une salle d'expédition construite par code depuis son modèle fait main (voir Salles) : sol, murs,
## portes de sortie, meubles et leurs volumes, torches qui vacillent, lumières d'ambiance ; et selon
## le type : le coffre (trésor) ou le quai, l'eau et la chaloupe (fin de l'expédition).

const DECOR := "res://assets/models/decor/"
const ECHELLE := 0.8
const DEMI := 6.4
const PAS := 3.2

var modele := ""
var donnees: Dictionary
var types_portes: Array = []
var portes: Array[Porte] = []
var coffre: Node3D                  ## salle trésor
var coffre_ouvert := false
var chaloupe: Node3D                ## quai : la chaloupe qui ramène au navire
var zone_chaloupe := Vector3.INF    ## quai : où se tenir pour monter dans la chaloupe
var _torches: Array[OmniLight3D] = []
var _temps := 0.0


static func creer(p_modele: String, p_types_portes: Array) -> Salle:
	var s := Salle.new()
	s.name = "Salle"
	s.modele = p_modele
	s.donnees = Salles.MODELES[p_modele]
	s.types_portes = p_types_portes
	return s


func _ready() -> void:
	_sol()
	_murs()
	for o in donnees.get("objets", []):
		_objet(o[0], o[1], o[2])   # (y > 0 : posé sur une table ou accroché au mur)
		if o[3] != Vector3.ZERO:
			_obstacle(Vector3(o[1].x, o[3].y * 0.5, o[1].z), o[3], o[2])
	for ob in donnees.get("obstacles", []):
		_obstacle(ob[0], ob[1], 0.0)
	var premiere := true
	for p in donnees.get("torches", []):
		var gauche: bool = p.x <= -DEMI + 0.01
		_objet("torch_mounted", Vector3(p.x, 1.8, p.z), 90 if gauche else 0)
		var dir := Vector3(0.45, 0, 0) if gauche else Vector3(0, 0, 0.45)
		_torche(Vector3(p.x, 2.35, p.z) + dir, premiere)
		premiere = false
	for l in donnees.get("lumieres", []):
		var lum := OmniLight3D.new()
		lum.position = l[0]
		lum.light_color = l[1]
		lum.light_energy = l[2]
		lum.omni_range = l[3]
		add_child(lum)
	if donnees.has("coffre"):
		_coffre(donnees["coffre"])
	if donnees.has("chaloupe"):
		_quai(donnees["chaloupe"])


func _process(delta: float) -> void:
	_temps += delta
	for i in _torches.size():
		_torches[i].light_energy = 2.2 + 0.35 * sin(_temps * 9.0 + i * 2.1) + 0.2 * sin(_temps * 23.0 + i)


## Points de départ des héros dans cette salle.
static func entree(nom_heros: StringName, coop: bool) -> Vector3:
	if not coop:
		return Salles.ENTREE
	return Salles.ENTREE_HOTE if nom_heros == &"HerosHote" else Salles.ENTREE_INVITE


func apparitions() -> Array[Vector3]:
	var r: Array[Vector3] = []
	for p in donnees.get("apparitions", []):
		r.append(p)
	return r


func ouvrir_portes() -> void:
	for p in portes:
		p.ouvrir()


## Salle trésor : le couvercle s'ouvre (une seule fois).
func ouvrir_coffre() -> void:
	if coffre == null or coffre_ouvert:
		return
	coffre_ouvert = true
	var couvercle := coffre.find_child("chest_lid", true, false) as Node3D
	if couvercle:
		create_tween().tween_property(couvercle, "rotation_degrees:x", -110.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	EffetsMagie.etincelles(self, coffre.global_position + Vector3.UP * 0.9)


# ---------------------------------------------------------------- construction
func _sol() -> void:
	var dalles: Array = donnees.get("sol", ["floor_tile_large"])
	var cases: Dictionary = donnees.get("cases", {})
	var bois: Array = donnees.get("cases_bois", [])
	var eau: bool = donnees.get("eau", false)
	# 4 × 4 dalles de jeu, plus 2 rangées hors jeu côté caméra pour ne pas voir le vide
	for ix in 6:
		for iz in 6:
			if eau and ix == 0:
				continue
			var p := Vector3(-DEMI + PAS * (ix + 0.5), 0, -DEMI + PAS * (iz + 0.5))
			var nom: String = dalles[(ix * 7 + iz * 3) % dalles.size()]
			if ix in bois:
				nom = "floor_wood_large"
			nom = cases.get(Vector2i(ix, iz), nom)
			_objet(nom, p, 0)
	# sol et limites de la salle (les côtés vers la caméra n'ont pas de mur visible)
	var x0 := -DEMI - 1.0 if not eau else -DEMI + PAS
	_obstacle(Vector3((x0 + DEMI + 1.0) * 0.5, -0.1, 0), Vector3(DEMI + 1.0 - x0, 0.2, DEMI * 2 + 2), 0.0)
	# (hauts de 8 m : les os projetés ne passent pas par-dessus)
	_obstacle(Vector3(0, 4, -DEMI - 0.2), Vector3(DEMI * 2 + 2, 8, 0.4), 0.0)
	_obstacle(Vector3(0, 4, DEMI + 0.2), Vector3(DEMI * 2 + 2, 8, 0.4), 0.0)
	_obstacle(Vector3(DEMI + 0.2, 4, 0), Vector3(0.4, 8, DEMI * 2 + 2), 0.0)
	if eau:
		_obstacle(Vector3(-DEMI + PAS - 0.1, 4, 0), Vector3(0.2, 8, DEMI * 2 + 2), 0.0)   # bord du quai
	else:
		_obstacle(Vector3(-DEMI - 0.2, 4, 0), Vector3(0.4, 8, DEMI * 2 + 2), 0.0)


func _murs() -> void:
	var fond: Array = donnees.get("murs_fond", ["wall", "wall", "wall", "wall"])
	var gauche: Array = donnees.get("murs_gauche", ["wall", "wall", "wall", "wall"])
	for i in 4:
		var c := -DEMI + PAS * (i + 0.5)
		# emplacements des portes : mur du fond en x = 1,6 (case 2), mur de gauche en z = -1,6 (case 1)
		if i == 2 and types_portes.size() >= 1:
			_porte(types_portes[0], 0, Vector3(c, 0, -DEMI - 0.4), 0.0)
		else:
			_objet(fond[i] if fond[i] != "" else "wall", Vector3(c, 0, -DEMI - 0.4), 0)
		if i == 1 and types_portes.size() >= 2:
			_porte(types_portes[1], 1, Vector3(-DEMI - 0.4, 0, c), 90.0)
		else:
			_objet(gauche[i] if gauche[i] != "" else "wall", Vector3(-DEMI - 0.4, 0, c), 90)
	_objet("pillar", Vector3(-DEMI - 0.2, 0, -DEMI - 0.2), 0)


func _porte(type: StringName, index: int, pos: Vector3, rot: float) -> void:
	var p := Porte.new()
	p.name = "Porte%d" % index
	p.configurer(type, index, pos, rot)
	add_child(p)
	portes.append(p)


func _coffre(pos: Vector3) -> void:
	coffre = _objet("chest_gold", pos, 0)
	_obstacle(pos + Vector3(0, 0.5, 0.15), Vector3(1.3, 1.0, 1.3), 0.0)


func _quai(pos: Vector3) -> void:
	var eau := MeshInstance3D.new()
	var plan := PlaneMesh.new()
	plan.size = Vector2(PAS + 0.4, DEMI * 2 + 6.4)
	eau.mesh = plan
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.04, 0.16, 0.2)
	mat.metallic = 0.5
	mat.roughness = 0.15
	mat.emission_enabled = true
	mat.emission = Color(0.01, 0.07, 0.09)
	eau.material_override = mat
	eau.position = Vector3(-DEMI + PAS * 0.5, -0.45, 3.2)
	add_child(eau)
	chaloupe = Chaloupe.creer()
	chaloupe.position = pos + Vector3(0, -0.2, 0)
	add_child(chaloupe)
	zone_chaloupe = Vector3(-DEMI + PAS + 1.0, 0, pos.z)
	# repère sur le quai : un cercle vert qui palpite, et le mot « Chaloupe »
	var anneau := MeshInstance3D.new()
	var tore := TorusMesh.new()
	tore.inner_radius = Expedition.EQ.exp_rayon_chaloupe - 0.25
	tore.outer_radius = Expedition.EQ.exp_rayon_chaloupe
	tore.rings = 40
	tore.ring_segments = 6
	anneau.mesh = tore
	var mat_anneau := StandardMaterial3D.new()
	mat_anneau.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_anneau.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_anneau.albedo_color = Color(0.4, 1.0, 0.6, 0.6)
	anneau.material_override = mat_anneau
	anneau.scale = Vector3(1, 0.1, 1)
	anneau.position = zone_chaloupe + Vector3.UP * 0.08
	anneau.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(anneau)
	var t := anneau.create_tween().set_loops()
	t.tween_property(mat_anneau, "albedo_color:a", 0.25, 0.8)
	t.tween_property(mat_anneau, "albedo_color:a", 0.6, 0.8)
	var mot := Label3D.new()
	mot.text = "Chaloupe"
	mot.font_size = 44
	mot.outline_size = 12
	mot.pixel_size = 0.006
	mot.modulate = Color("6cffa0")
	mot.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	mot.no_depth_test = true
	mot.position = zone_chaloupe + Vector3.UP * 1.6
	add_child(mot)


func _objet(nom: String, pos: Vector3, rot_y: float) -> Node3D:
	var scene: PackedScene = load(DECOR + nom + ".glb")
	if scene == null:
		push_error("Décor introuvable : " + nom)
		return null
	var n: Node3D = scene.instantiate()
	n.position = pos
	n.rotation_degrees.y = rot_y
	n.scale = Vector3.ONE * ECHELLE
	add_child(n)
	return n


func _obstacle(centre: Vector3, taille: Vector3, rot_y: float) -> void:
	var corps := StaticBody3D.new()
	corps.collision_layer = Combat.COUCHE_MONDE
	corps.collision_mask = 0
	var forme := CollisionShape3D.new()
	var boite := BoxShape3D.new()
	boite.size = taille
	forme.shape = boite
	corps.position = centre
	corps.rotation_degrees.y = rot_y
	corps.add_child(forme)
	add_child(corps)


func _torche(pos: Vector3, ombre: bool) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = Salles.TORCHE
	l.light_energy = 2.4
	l.omni_range = 8.0
	l.shadow_enabled = ombre
	l.omni_shadow_mode = OmniLight3D.SHADOW_DUAL_PARABOLOID
	add_child(l)
	_torches.append(l)
