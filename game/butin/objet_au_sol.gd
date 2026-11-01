class_name ObjetAuSol
extends Node3D
## Un objet ou des doublons tombés au sol (jalon 4, façon Diablo) : le modèle flotte et tourne, une
## colonne de lumière à la couleur de la rareté le signale de loin, son nom flotte au-dessus. Il saute
## hors du squelette vaincu jusqu'à sa place. Il appartient à un joueur (`proprietaire`, nom de son
## héros) : à deux, chacun ne voit que le sien (l'hôte garde ceux de l'invité, invisibles, pour décider
## du ramassage).

const EQ: Equilibrage = preload("res://data/equilibrage.tres")
const PIECES := "res://assets/models/decor/coin_stack_medium.glb"

static var _mat_colonnes := {}       ## rareté -> matière (partagées)
static var _maillage_colonne: CylinderMesh
static var _maillage_disque: CylinderMesh

var objet := {}                      ## l'objet (voir Butin) ; vide pour des doublons
var doublons := 0
var proprietaire := ""               ## nom du héros à qui il revient
var id := ""
var pose := false                    ## retombé à sa place : on peut le ramasser (pas en plein vol)
var etage := 0                       ## son nom monte d'un cran par objet déjà tombé tout près (lisible)
var _modele: Node3D
var _temps := 0.0
var _depart := Vector3.ZERO
var _arrivee := Vector3.ZERO


## `depart` : d'où il saute (le squelette vaincu) ; `pos` : où il retombe.
static func creer(p_objet: Dictionary, p_doublons: int, p_proprietaire: String, depart: Vector3, pos: Vector3) -> ObjetAuSol:
	var o := ObjetAuSol.new()
	o.objet = p_objet
	o.doublons = p_doublons
	o.proprietaire = p_proprietaire
	o.id = p_objet.get("id", "") if not p_objet.is_empty() else "d%d_%d" % [Time.get_ticks_usec(), randi() % 100000]
	o.name = "Butin_" + o.id
	o.position = Vector3(pos.x, 0.0, pos.z)
	o.set_meta("depart", depart)
	return o


func est_doublons() -> bool:
	return objet.is_empty()


func _ready() -> void:
	var pivot := Node3D.new()
	add_child(pivot)
	if est_doublons():
		_modele = load(PIECES).instantiate()
		_modele.scale = Vector3.ONE * 0.55
		pivot.add_child(_modele)
		_etiquette("%d doublons" % doublons, Color("e0b04a"), 0.9 + 0.24 * etage)
	else:
		var def := Butin.definition(objet)
		var rarete := int(objet.get("rarete", 0))
		var couleur := Butin.couleur(objet)
		_modele = load(def.get("modele", PIECES)).instantiate()
		_modele.scale = Vector3.ONE * def.get("echelle", 0.9 if def.get("type") == "arme" else 0.7)
		_modele.rotation_degrees = Vector3(0, 0, 70) if def.get("type") == "arme" else Vector3.ZERO   # arme couchée
		pivot.add_child(_modele)
		if def.has("teinte"):   # objet unique : il luit de sa couleur
			var lueur := StandardMaterial3D.new()
			lueur.albedo_color = Color(def["teinte"], 0.0)
			lueur.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			lueur.emission_enabled = true
			lueur.emission = def["teinte"]
			lueur.emission_energy_multiplier = 0.6
			for m in _modele.find_children("*", "MeshInstance3D", true, false):
				m.material_overlay = lueur
		_colonne(rarete, couleur)
		_etiquette(Butin.nom(objet), couleur, 1.3 + 0.24 * etage)
		if rarete >= Butin.Rarete.EPIQUE:   # (une lumière seulement pour les belles raretés : téléphone)
			var l := OmniLight3D.new()
			l.light_color = couleur
			l.light_energy = 1.2
			l.omni_range = 2.6
			l.position.y = 0.6
			add_child(l)
	pivot.position.y = 0.35
	set_meta("pivot", pivot)
	# il saute hors du squelette jusqu'à sa place (un petit arc)
	_depart = get_meta("depart", position)
	_arrivee = position
	var t := create_tween()
	t.tween_method(_sauter, 0.0, 1.0, 0.35)
	t.tween_callback(func(): pose = true)


func _sauter(f: float) -> void:
	position = _depart.lerp(_arrivee, f) + Vector3.UP * (1.6 * f * (1.0 - f))


func _process(delta: float) -> void:
	_temps += delta
	var pivot: Node3D = get_meta("pivot")
	pivot.rotation.y += 1.4 * delta
	pivot.position.y = 0.35 + 0.08 * sin(_temps * 2.6)


func _colonne(rarete: int, couleur: Color) -> void:
	if _maillage_colonne == null:
		_maillage_colonne = CylinderMesh.new()
		_maillage_colonne.top_radius = 0.05
		_maillage_colonne.bottom_radius = 0.09
		_maillage_colonne.height = 2.8
		_maillage_colonne.radial_segments = 8
		_maillage_colonne.rings = 1
		_maillage_disque = CylinderMesh.new()
		_maillage_disque.top_radius = 0.45
		_maillage_disque.bottom_radius = 0.45
		_maillage_disque.height = 0.02
		_maillage_disque.radial_segments = 20
		_maillage_disque.rings = 1
	if not _mat_colonnes.has(rarete):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(couleur, 0.4)
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mat_colonnes[rarete] = m
	var colonne := MeshInstance3D.new()
	colonne.mesh = _maillage_colonne
	colonne.material_override = _mat_colonnes[rarete]
	colonne.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	colonne.position.y = 1.4
	add_child(colonne)
	var disque := MeshInstance3D.new()
	disque.mesh = _maillage_disque
	disque.material_override = _mat_colonnes[rarete]
	disque.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	disque.position.y = 0.09
	add_child(disque)


func _etiquette(texte: String, couleur: Color, hauteur: float) -> void:
	var l := Label3D.new()
	l.text = texte
	l.font_size = 40
	l.outline_size = 10
	l.pixel_size = 0.005
	l.modulate = couleur
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position.y = hauteur
	add_child(l)


## Le héros est-il assez près pour le ramasser (une fois l'objet retombé) ?
func a_portee(pos_heros: Vector3) -> bool:
	if not pose:
		return false
	var d := pos_heros - global_position
	d.y = 0.0
	return d.length() <= EQ.butin_rayon
