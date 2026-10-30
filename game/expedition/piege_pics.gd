class_name PiegePics
extends Node3D
## Dalle à pics (salle piège) : au repos les pics sont cachés ; avant de sortir, la dalle tremble et
## rougeoie (annonce) ; puis ils jaillissent et blessent héros ET squelettes qui sont dessus. Le cycle
## est calé sur l'horloge de la salle (`regler`) : en coop, l'invité suit celle de l'hôte, et seul
## l'hôte compte les dégâts (`actif`).

const EQ: Equilibrage = preload("res://data/equilibrage.tres")
const DEMI := 1.5   ## mètres : moitié de la dalle (3,2 m), un peu moins pour ne pas punir le bord
const CACHES := -1.75
const SORTIS := -0.85

static var _mat_alerte: StandardMaterial3D

var decalage := 0.0       ## part de la période (0 à 1) : les dalles voisines alternent
var _pics: Node3D
var _alerte: MeshInstance3D
var _cycle_touche := -1   ## n° du cycle où les dégâts ont déjà été portés


func _ready() -> void:
	var modele: Node3D = load("res://assets/models/decor/floor_tile_big_spikes.glb").instantiate()
	modele.scale = Vector3.ONE * 0.8
	add_child(modele)
	_pics = modele.find_child("spikes", true, false) as Node3D
	if _pics:
		_pics.position.y = CACHES / 0.8
	if _mat_alerte == null:
		_mat_alerte = StandardMaterial3D.new()
		_mat_alerte.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat_alerte.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat_alerte.albedo_color = Color(1.0, 0.2, 0.1, 0.35)
	_alerte = MeshInstance3D.new()
	var plaque := BoxMesh.new()
	plaque.size = Vector3(3.1, 0.02, 3.1)
	_alerte.mesh = plaque
	_alerte.material_override = _mat_alerte
	_alerte.position.y = 0.11
	_alerte.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_alerte.visible = false
	add_child(_alerte)


## Où en est le cycle à l'heure `t` de la salle : 0 repos, 1 alerte, 2 pics sortis.
func phase(t: float) -> int:
	var local := fposmod(t + decalage * EQ.pics_periode, EQ.pics_periode)
	if local >= EQ.pics_periode - EQ.pics_sortis:
		return 2
	if local >= EQ.pics_periode - EQ.pics_sortis - EQ.pics_alerte:
		return 1
	return 0


## Règle les pics à l'heure `t` de la salle ; `actif` : c'est ce téléphone qui porte les coups.
func regler(t: float, actif: bool) -> void:
	var p := phase(t)
	_alerte.visible = p == 1
	if _pics:
		var y := CACHES
		if p == 1:
			y = CACHES + 0.15 + 0.06 * sin(t * 60.0)   # la dalle tremble : les pics affleurent
		elif p == 2:
			y = SORTIS
		_pics.position.y = lerpf(_pics.position.y, y / 0.8, 0.5 if p == 2 else 0.3)
	if p == 2 and actif:
		var cycle := floori((t + decalage * EQ.pics_periode) / EQ.pics_periode)
		if cycle != _cycle_touche:
			_cycle_touche = cycle
			_blesser()


func _blesser() -> void:
	for groupe in ["heros", "ennemis"]:
		for c in get_tree().get_nodes_in_group(groupe):
			if not (c is Node3D) or not c.has_method("recevoir_coup"):
				continue
			if c.get("marionnette") == true:
				continue
			var d: Vector3 = (c as Node3D).global_position - global_position
			if absf(d.x) <= DEMI and absf(d.z) <= DEMI:
				Combat.porter_coup(self, c, EQ.pics_degats, true)


## Le point est-il sur cette dalle ? (tests, placement)
func couvre(p: Vector3) -> bool:
	var d := p - global_position
	return absf(d.x) <= DEMI and absf(d.z) <= DEMI
