class_name Chaloupe
extends Node3D
## La chaloupe qui ramène les héros au navire : une barque en bois construite par code (coque,
## bancs, rames, lanterne verte), qui tangue doucement sur l'eau.

const BOIS := Color(0.5, 0.31, 0.17)
const BOIS_SOMBRE := Color(0.28, 0.17, 0.09)
const LONGUEUR := 4.4
const LARGEUR := 1.5
const CREUX := 0.6

var _temps := 0.0
var _coque: Node3D


static func creer() -> Chaloupe:
	var c := Chaloupe.new()
	c.name = "Chaloupe"
	return c


func _ready() -> void:
	_coque = Node3D.new()
	add_child(_coque)
	var m := MeshInstance3D.new()
	m.mesh = _maillage_coque()
	m.material_override = _mat(BOIS)
	_coque.add_child(m)
	for z in [-0.8, 0.7]:
		_boite(Vector3(0, CREUX - 0.18, z), Vector3(LARGEUR * 0.8, 0.07, 0.32), BOIS_SOMBRE)
	_boite(Vector3(0, CREUX - 0.02, 0), Vector3(0.08, 0.06, LONGUEUR * 0.82), BOIS_SOMBRE)   # quille du haut
	for cote in [-1.0, 1.0]:
		var rame := Node3D.new()
		rame.position = Vector3(cote * LARGEUR * 0.45, CREUX - 0.05, 0.0)
		rame.rotation_degrees = Vector3(0, cote * 15.0, cote * -35.0)
		_coque.add_child(rame)
		var manche := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.035
		cyl.bottom_radius = 0.035
		cyl.height = 2.2
		manche.mesh = cyl
		manche.material_override = _mat(BOIS_SOMBRE)
		manche.rotation_degrees.z = 90
		manche.position.x = cote * 0.8
		rame.add_child(manche)
		var pale := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.5, 0.03, 0.18)
		pale.mesh = bm
		pale.material_override = _mat(BOIS)
		pale.position.x = cote * 1.85
		rame.add_child(pale)
	var lanterne := OmniLight3D.new()
	lanterne.light_color = Color(0.35, 1.0, 0.55)
	lanterne.light_energy = 0.7
	lanterne.omni_range = 2.5
	lanterne.position = Vector3(0, CREUX + 0.7, LONGUEUR * 0.38)
	_coque.add_child(lanterne)
	_boite(Vector3(0, CREUX + 0.3, LONGUEUR * 0.38), Vector3(0.16, 0.22, 0.16), Color(0.4, 1.0, 0.6), true)


func _process(delta: float) -> void:
	_temps += delta
	_coque.position.y = 0.04 * sin(_temps * 1.6)
	_coque.rotation_degrees.z = 2.5 * sin(_temps * 1.1)
	_coque.rotation_degrees.x = 1.2 * sin(_temps * 0.8 + 1.0)


## Coque : sections en U le long de la barque, plus étroites et plus hautes aux deux pointes.
func _maillage_coque() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n_long := 14
	var n_tour := 9
	var sections: Array = []
	for i in n_long + 1:
		var t := float(i) / n_long * 2.0 - 1.0           # -1 (poupe) → 1 (proue)
		var z := t * LONGUEUR * 0.5
		var larg := LARGEUR * 0.5 * pow(maxf(1.0 - absf(t) ** 2.2, 0.0), 0.55)
		var tonture := 0.12 * t * t                      # les pointes remontent un peu
		var pts: Array[Vector3] = []
		for j in n_tour + 1:
			var a := PI * float(j) / n_tour              # de bâbord à tribord, par le fond
			pts.append(Vector3(-cos(a) * larg, CREUX + tonture - sin(a) * CREUX * (0.35 + 0.65 * (1.0 - absf(t) * 0.5)), z))
		sections.append(pts)
	for i in n_long:
		for j in n_tour:
			var a: Vector3 = sections[i][j]
			var b: Vector3 = sections[i + 1][j]
			var c: Vector3 = sections[i + 1][j + 1]
			var d: Vector3 = sections[i][j + 1]
			for p in [a, b, c, a, c, d]:
				st.add_vertex(p)
	st.generate_normals()
	return st.commit()


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.85
	m.cull_mode = BaseMaterial3D.CULL_DISABLED   # on voit l'intérieur de la coque
	return m


func _boite(pos: Vector3, taille: Vector3, c: Color, lumineuse := false) -> void:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = taille
	m.mesh = b
	var mat := _mat(c)
	if lumineuse:
		mat.emission_enabled = true
		mat.emission = c
		mat.emission_energy_multiplier = 2.0
	m.material_override = mat
	m.position = pos
	_coque.add_child(m)
