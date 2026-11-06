class_name Matieres
extends RefCounted
## Les matières réalistes des décors KayKit (06/11, identité visuelle façon Diablo IV, étape 3 ; choisies par Téo sur
## la planche d'essai). Textures Poly Haven (CC0) dans assets/textures/polyhaven/ ; posées en mètres du monde par
## game/commun/matiere_monde.gdshader. Chaque décor KayKit reçoit la sienne d'après son nom (`habiller`) :
##   sols -> pavés (pleine) ; murs, piliers, éboulis -> pierre taillée (pleine) ;
##   bois -> veines de planches sur la couleur KayKit (grain) ; métal -> rouille sur la couleur KayKit (grain).
## Les décors absents de ces listes (fioles, bannières, pièces…) gardent leur matière KayKit.

const DOSSIER := "res://assets/textures/polyhaven/"
const SHADER := preload("res://game/commun/matiere_monde.gdshader")

const SOL := ["floor_tile_large", "floor_tile_large_rocks", "floor_dirt_large", "floor_tile_small_weeds_A", "stairs"]
const MUR := ["wall", "wall_arched", "wall_broken", "wall_corner", "wall_cracked", "wall_doorway", "wall_gated",
		"column", "pillar", "pillar_decorated", "rubble_half", "rubble_large"]
const BOIS := ["barrel_large", "barrel_small", "barrel_small_stack", "box_large", "box_stacked", "crates_stacked",
		"chair", "stool", "table_long_broken", "table_medium", "table_medium_broken", "shelf_large", "shelves",
		"trunk_large_A", "trunk_large_B", "keg_decorated", "barrier", "barrier_column", "floor_wood_large",
		"floor_wood_large_dark", "wall_scaffold"]
const METAL := ["chest", "chest_gold", "sword_shield", "sword_shield_broken", "torch_mounted", "keyring_hanging",
		"floor_tile_big_grate", "floor_tile_big_spikes"]

static var _cache := {}


## La matière d'un décor KayKit d'après son nom (sans extension), ou null s'il garde la sienne.
static func pour(nom: String) -> Material:
	if nom in SOL:
		return _matiere(&"sol", "cobblestone_floor_001", false, 2.4, Color(0.75, 0.72, 0.68))
	if nom in MUR:
		return _matiere(&"mur", "stone_brick_wall_001", false, 2.6, Color(0.8, 0.78, 0.74))
	if nom in BOIS:
		return _matiere(&"bois", "weathered_brown_planks", true, 1.45, Color(0.85, 0.82, 0.78))
	if nom in METAL:
		return _matiere(&"metal", "rust_coarse_01", true, 1.1, Color(0.85, 0.82, 0.78))
	return null


## Pose la matière de `nom` sur tous les maillages du décor `n` (sans effet s'il garde la sienne).
static func habiller(n: Node, nom: String) -> void:
	var m := pour(nom)
	if m == null or n == null:
		return
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		# (le battant d'une porte est en bois, même dans un mur de pierre)
		mi.material_override = pour("chair") if String(mi.name).contains("_door") else m
	if n is MeshInstance3D:
		n.material_override = m


static func _matiere(cle: StringName, texture: String, grain: bool, taille: float, teinte: Color) -> ShaderMaterial:
	if _cache.has(cle):
		return _cache[cle]
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("tex_couleur", load(DOSSIER + texture + ("_grain.jpg" if grain else "_diff.jpg")))
	m.set_shader_parameter("tex_relief", load(DOSSIER + texture + "_nor_gl.png"))
	m.set_shader_parameter("tex_rugosite", load(DOSSIER + texture + "_rough.jpg"))
	m.set_shader_parameter("grain", grain)
	m.set_shader_parameter("taille", taille)
	m.set_shader_parameter("teinte", teinte)
	if grain:
		m.set_shader_parameter("tex_palette", load("res://assets/models/decor/dungeon_texture.png"))
	_cache[cle] = m
	return m
