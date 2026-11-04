class_name Navire
extends Node3D
## Le navire des héros, amarré au quai du repaire (jalon 5) : coque, pont, château arrière, deux mâts et
## leurs voiles, beaupré, lanternes vertes ; construit par code (la conception : « coque et voiles
## simplifiées » faites à la main), il tangue doucement. Proue vers +z.
## Il change un peu d'aspect avec les améliorations du chantier naval (annexe retenue par Téo) : caisses sur
## le pont (cale), voiles plus sombres qui luisent de vert (voiles), bandes de fer sur la coque (coque),
## canons sur les flancs (bordée). Voir `appliquer`.

const BOIS := Color(0.36, 0.22, 0.12)
const BOIS_SOMBRE := Color(0.2, 0.12, 0.07)
const BOIS_PONT := Color(0.46, 0.32, 0.19)
const TOILE := Color(0.62, 0.58, 0.48)        ## voiles de toile usée
const LUEUR := Color(0.35, 1.0, 0.55)         ## lanternes maudites
const LONGUEUR := 9.0
const LARGEUR := 2.9
const CREUX := 1.7                            ## de la quille au plat-bord (au milieu)

var _corps: Node3D                            ## tout ce qui tangue
var _temps := 0.0
var _voiles: Array[MeshInstance3D] = []
var _ameliorations: Node3D                    ## ce qu'ajoutent les niveaux du bateau (refait par `appliquer`)
var niveaux := {}                             ## les niveaux affichés
static var _mats := {}


func _ready() -> void:
	_corps = Node3D.new()
	_corps.name = "Corps"
	add_child(_corps)
	var coque := MeshInstance3D.new()
	coque.name = "Coque"
	coque.mesh = _maillage_coque()
	coque.material_override = _mat(BOIS, true)
	_corps.add_child(coque)
	var pont := MeshInstance3D.new()
	pont.name = "Pont"
	pont.mesh = _maillage_pont(CREUX - 0.25)
	pont.material_override = _mat(BOIS_PONT)
	_corps.add_child(pont)
	# château arrière (poupe) et sa rambarde
	_boite(Vector3(0, CREUX + 0.25, -LONGUEUR * 0.36), Vector3(LARGEUR * 0.62, 1.0, 2.0), BOIS_SOMBRE)
	_boite(Vector3(0, CREUX + 0.78, -LONGUEUR * 0.36), Vector3(LARGEUR * 0.66, 0.08, 2.1), BOIS)
	for x in [-1.0, 1.0]:
		_boite(Vector3(x * LARGEUR * 0.31, CREUX + 1.0, -LONGUEUR * 0.36), Vector3(0.06, 0.4, 2.0), BOIS_SOMBRE)
	# fenêtres du château qui luisent
	for x in [-0.45, 0.0, 0.45]:
		_boite(Vector3(x, CREUX + 0.3, -LONGUEUR * 0.36 - 1.01), Vector3(0.22, 0.26, 0.04), LUEUR, true)
	# mâts, vergues et voiles
	_mat_et_voiles(Vector3(0, CREUX - 0.25, 1.4), 7.2, [2.6, 4.6], [3.0, 2.4])
	_mat_et_voiles(Vector3(0, CREUX - 0.25, -1.9), 6.0, [2.4, 4.1], [2.6, 2.0])
	# beaupré
	var beaupre := _cylindre(0.08, 3.4, BOIS_SOMBRE)
	beaupre.position = Vector3(0, CREUX + 0.45, LONGUEUR * 0.5 + 0.8)
	beaupre.rotation_degrees.x = 70.0
	# pavillon noir en haut du grand mât
	_boite(Vector3(0, CREUX + 7.0, 1.4 - 0.45), Vector3(0.03, 0.5, 0.8), Color(0.05, 0.05, 0.06))
	# lanternes vertes à la proue et à la poupe
	for z in [LONGUEUR * 0.43, -LONGUEUR * 0.46]:
		_boite(Vector3(0, CREUX + 1.0, z), Vector3(0.2, 0.28, 0.2), LUEUR, true)
		var l := OmniLight3D.new()
		l.light_color = LUEUR
		l.light_energy = 0.9
		l.omni_range = 4.0
		l.position = Vector3(0, CREUX + 1.2, z)
		_corps.add_child(l)
	appliquer(niveaux)


## Montre les améliorations du bateau ({"cale": 0 à 3, "voiles": …, "coque": …, "bordee": …}).
func appliquer(p_niveaux: Dictionary) -> void:
	niveaux = p_niveaux.duplicate()
	if _corps == null:
		return
	if _ameliorations:
		_ameliorations.free()
	_ameliorations = Node3D.new()
	_ameliorations.name = "Ameliorations"
	_corps.add_child(_ameliorations)
	var pont := CREUX - 0.25
	# cale : des caisses arrimées sur le pont, entre les mâts
	for i in int(niveaux.get("cale", 0)):
		var c := _boite(Vector3((i % 2) * 0.7 - 0.35, pont + 0.3, -0.5 + 0.75 * (i / 2)), Vector3(0.6, 0.6, 0.6), Color(0.55, 0.36, 0.2))
		c.reparent(_ameliorations, false)
		c.name = "Caisse%d" % i
	# voiles : de plus en plus sombres, d'une toile maudite qui luit de vert
	var nv := int(niveaux.get("voiles", 0))
	var teintes := [TOILE, Color(0.42, 0.4, 0.36), Color(0.2, 0.21, 0.22), Color(0.08, 0.09, 0.1)]
	var mat := _mat(teintes[clampi(nv, 0, 3)], true, false).duplicate() as StandardMaterial3D
	if nv >= 2:
		mat.emission_enabled = true
		mat.emission = LUEUR
		mat.emission_energy_multiplier = 0.05 if nv == 2 else 0.1   # (une lueur, pas une toile verte)
	for v in _voiles:
		v.material_override = mat
	# coque : des bandes de fer sur les flancs
	var nc := int(niveaux.get("coque", 0))
	for i in nc * 2:
		var z := -2.4 + 4.8 * float(i) / maxf(nc * 2 - 1, 1)
		for cote in [-1.0, 1.0]:
			var bande := _boite(Vector3(cote * LARGEUR * 0.5, CREUX * 0.55, z), Vector3(0.08, 1.1, 0.22), Color(0.22, 0.24, 0.27))
			bande.material_override = _mat_fer()
			bande.reparent(_ameliorations, false)
			bande.name = "Bande%d_%d" % [i, int(cote)]
	# bordée : des canons qui sortent des flancs
	for i in int(niveaux.get("bordee", 0)):
		var z := 1.6 - 1.6 * i
		for cote in [-1.0, 1.0]:
			var canon := _cylindre(0.13, 0.9, Color(0.06, 0.06, 0.07))
			canon.material_override = _mat_fer()
			canon.position = Vector3(cote * (LARGEUR * 0.5 + 0.2), pont + 0.05, z)
			canon.rotation_degrees.z = 90.0
			canon.reparent(_ameliorations, false)
			canon.name = "Canon%d_%d" % [i, int(cote)]


static func _mat_fer() -> StandardMaterial3D:
	if not _mats.has("fer"):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.18, 0.19, 0.22)
		m.metallic = 0.7
		m.roughness = 0.4
		_mats["fer"] = m
	return _mats["fer"]


func _process(delta: float) -> void:
	_temps += delta
	_corps.position.y = 0.06 * sin(_temps * 0.9)
	_corps.rotation_degrees.z = 1.6 * sin(_temps * 0.7)
	_corps.rotation_degrees.x = 0.5 * sin(_temps * 0.55 + 1.0)


func _mat_et_voiles(pied: Vector3, hauteur: float, hauteurs_vergues: Array, largeurs: Array) -> void:
	var mat := _cylindre(0.13, hauteur, BOIS_SOMBRE)
	mat.position = pied + Vector3.UP * hauteur * 0.5
	for i in hauteurs_vergues.size():
		var y: float = hauteurs_vergues[i]
		var l: float = largeurs[i]
		var vergue := _cylindre(0.06, l + 0.4, BOIS_SOMBRE)
		vergue.position = pied + Vector3(0, y, 0.12)
		vergue.rotation_degrees.z = 90.0
		var h := 1.6 if i == 0 else 1.3
		var voile := MeshInstance3D.new()
		voile.name = "Voile"
		voile.mesh = _maillage_voile(l, h)
		voile.material_override = _mat(TOILE, true)
		voile.position = pied + Vector3(0, y - 0.05, 0.16)
		_corps.add_child(voile)
		_voiles.append(voile)


## Voile : une toile gonflée par le vent (bombée vers l'avant, plus au milieu), du haut (y = 0) vers le bas.
func _maillage_voile(largeur: float, hauteur: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx := 8
	var ny := 6
	var pts := []
	for j in ny + 1:
		var ligne := []
		var v := float(j) / ny
		for i in nx + 1:
			var u := float(i) / nx * 2.0 - 1.0
			var bombe := 0.45 * (1.0 - u * u) * sin(v * PI * 0.85 + 0.25)
			ligne.append(Vector3(u * largeur * 0.5 * (1.0 - 0.08 * v), -v * hauteur, bombe))
		pts.append(ligne)
	for j in ny:
		for i in nx:
			var a: Vector3 = pts[j][i]
			var b: Vector3 = pts[j][i + 1]
			var c: Vector3 = pts[j + 1][i + 1]
			var d: Vector3 = pts[j + 1][i]
			for p in [a, b, c, a, c, d]:
				st.add_vertex(p)
	st.generate_normals()
	return st.commit()


## Coque : sections en U le long du navire, fond plus plat qu'une barque, pointue à la proue, plus large à
## la poupe ; le plat-bord remonte aux deux bouts.
func _maillage_coque() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sections := _sections()
	for i in sections.size() - 1:
		for j in sections[i].size() - 1:
			var a: Vector3 = sections[i][j]
			var b: Vector3 = sections[i + 1][j]
			var c: Vector3 = sections[i + 1][j + 1]
			var d: Vector3 = sections[i][j + 1]
			for p in [a, b, c, a, c, d]:
				st.add_vertex(p)
	# tableau arrière (la poupe est fermée)
	var poupe: Array = sections[0]
	var centre := Vector3(0, CREUX * 0.6, poupe[0].z)
	for j in poupe.size() - 1:
		for p in [centre, poupe[j + 1], poupe[j]]:
			st.add_vertex(p)
	st.generate_normals()
	return st.commit()


func _sections() -> Array:
	var n_long := 18
	var n_tour := 10
	var sections := []
	for i in n_long + 1:
		var t := float(i) / n_long * 2.0 - 1.0              # -1 (poupe) → 1 (proue)
		var z := t * LONGUEUR * 0.5
		var forme := 1.0 - absf(t) ** 2.4 if t > 0.0 else 1.0 - absf(t) ** 4.0 * 0.35
		var larg := LARGEUR * 0.5 * pow(maxf(forme, 0.0), 0.55)
		var tonture := 0.35 * t * t + (0.25 * -t if t < 0.0 else 0.0)
		var pts: Array[Vector3] = []
		for j in n_tour + 1:
			var a := PI * float(j) / n_tour
			var fond := CREUX * (0.55 + 0.45 * (1.0 - absf(t) * 0.6))
			var y := CREUX + tonture - pow(sin(a), 0.6) * fond
			pts.append(Vector3(-cos(a) * larg, y, z))
		sections.append(pts)
	return sections


## Pont : une surface plate, à `y`, qui suit la largeur de la coque.
func _maillage_pont(y: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sections := _sections()
	for i in sections.size() - 1:
		var g0: Vector3 = sections[i][0]
		var d0: Vector3 = sections[i][sections[i].size() - 1]
		var g1: Vector3 = sections[i + 1][0]
		var d1: Vector3 = sections[i + 1][sections[i + 1].size() - 1]
		var k := 0.93
		var a := Vector3(g0.x * k, y, g0.z)
		var b := Vector3(g1.x * k, y, g1.z)
		var c := Vector3(d1.x * k, y, d1.z)
		var d := Vector3(d0.x * k, y, d0.z)
		for p in [a, c, b, a, d, c]:
			st.add_vertex(p)
	st.generate_normals()
	return st.commit()


func _cylindre(rayon: float, hauteur: float, c: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = rayon * 0.8
	cyl.bottom_radius = rayon
	cyl.height = hauteur
	cyl.radial_segments = 8
	cyl.rings = 1
	m.mesh = cyl
	m.material_override = _mat(c)
	_corps.add_child(m)
	return m


func _boite(pos: Vector3, taille: Vector3, c: Color, lumineuse := false) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = taille
	m.mesh = b
	m.material_override = _mat(c, false, lumineuse)
	m.position = pos
	_corps.add_child(m)
	return m


static func _mat(c: Color, deux_faces := false, lumineuse := false) -> StandardMaterial3D:
	var cle := "%s_%s_%s" % [c.to_html(), deux_faces, lumineuse]
	if not _mats.has(cle):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.85
		if deux_faces:
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		if lumineuse:
			m.emission_enabled = true
			m.emission = c
			m.emission_energy_multiplier = 2.0
		_mats[cle] = m
	return _mats[cle]
