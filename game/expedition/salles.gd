class_name Salles
extends RefCounted
## Les salles faites main du Récif des Pendus (jalon 3). Toutes font 12,8 × 12,8 m (de -6,4 à +6,4) ;
## les murs visibles sont au fond (z = -6,8) et à gauche (x = -6,8). On entre côté caméra (en bas à
## droite de l'écran) ; les portes de sortie sont dans le mur du fond (x = 1,6) et dans le mur de
## gauche (z = -1,6). Chaque objet : [modèle, position, rotation en degrés, taille de l'obstacle ou
## Vector3.ZERO s'il ne gêne pas]. Le passage de l'entrée vers les deux portes reste dégagé.

const ENTREE := Vector3(3.6, 0, 4.4)          ## seul
const ENTREE_HOTE := Vector3(2.8, 0, 4.4)     ## coop
const ENTREE_INVITE := Vector3(4.4, 0, 4.4)

const VERT := Color(0.3, 1.0, 0.55)
const TORCHE := Color(1.0, 0.55, 0.2)
const OR := Color(1.0, 0.78, 0.35)
const ROUGE := Color(1.0, 0.3, 0.2)

const MODELES := {
	# ------------------------------------------------------------------ combats
	"salle_gardes": {
		"nom": "Salle des gardes",
		"types": [&"combat"],
		"sol": ["floor_tile_large", "floor_tile_large_rocks"],
		"objets": [
			["pillar", Vector3(-2.6, 0, -3.2), 0, Vector3(1.0, 3.2, 1.0)],
			["pillar", Vector3(4.2, 0, -2.6), 0, Vector3(1.0, 3.2, 1.0)],
			["pillar", Vector3(-2.8, 0, 2.6), 0, Vector3(1.0, 3.2, 1.0)],
			["barrel_large", Vector3(-5.4, 0, -5.4), 0, Vector3(1.3, 1.6, 1.3)],
			["barrel_small", Vector3(-5.6, 0, -4.1), 30, Vector3(0.7, 0.8, 0.7)],
			["crates_stacked", Vector3(5.2, 0, -5.2), 20, Vector3(1.7, 1.8, 1.7)],
			["banner_thin_green", Vector3(-1.6, 0, -6.8), 0, Vector3.ZERO],
			["banner_thin_green", Vector3(-6.8, 0, 1.6), 90, Vector3.ZERO],
		],
		"torches": [Vector3(-4.8, 0, -6.4), Vector3(4.8, 0, -6.4), Vector3(-6.4, 0, 4.8)],
		"lumieres": [[Vector3(-2.6, 1.0, 0.0), VERT, 1.0, 5.0]],
		"apparitions": [Vector3(-4.2, 0, -0.6), Vector3(0.4, 0, -2.2), Vector3(-0.8, 0, -4.8),
				Vector3(3.0, 0, -4.6), Vector3(-4.6, 0, 4.4), Vector3(0.4, 0, 1.2)],
	},
	"refectoire": {
		"nom": "Réfectoire",
		"types": [&"combat"],
		"sol": ["floor_wood_large_dark"],
		"objets": [
			["table_long_broken", Vector3(-2.4, 0, -1.6), 0, Vector3(1.8, 1.0, 3.3)],
			["table_long_broken", Vector3(1.4, 0, 0.8), 90, Vector3(1.8, 1.0, 3.3)],
			["plate_stack", Vector3(-2.3, 0.95, -2.2), 0, Vector3.ZERO],
			["bottle_A_green", Vector3(1.0, 0.95, 0.9), 0, Vector3.ZERO],
			["stool", Vector3(-0.8, 0, -2.4), 0, Vector3.ZERO],
			["stool", Vector3(-4.0, 0, -0.6), 0, Vector3.ZERO],
			["chair", Vector3(2.4, 0, 2.3), 200, Vector3.ZERO],
			["keg_decorated", Vector3(4.4, 0, -5.6), 0, Vector3(2.6, 1.6, 1.4)],
			["barrel_small_stack", Vector3(-5.6, 0, 3.6), 90, Vector3(0.8, 1.4, 1.5)],
			["banner_patternA_red", Vector3(-4.8, 0, -6.8), 0, Vector3.ZERO],
		],
		"torches": [Vector3(-1.6, 0, -6.4), Vector3(4.8, 0, -6.4), Vector3(-6.4, 0, 1.6)],
		"lumieres": [],
		"apparitions": [Vector3(-4.6, 0, -4.4), Vector3(-0.4, 0, -4.4), Vector3(4.6, 0, -2.6),
				Vector3(-4.4, 0, 1.6), Vector3(-0.2, 0, 3.4)],
	},
	"cale_effondree": {
		"nom": "Cale effondrée",
		"types": [&"combat"],
		"sol": ["floor_dirt_large", "floor_tile_large_rocks", "floor_tile_large"],
		"murs_fond": ["wall_broken", "wall", "", "wall_cracked"],
		"murs_gauche": ["wall", "", "wall", "wall_cracked"],
		"objets": [
			["rubble_large", Vector3(-3.6, 0, -5.4), 0, Vector3(6.0, 2.0, 2.2)],
			["rubble_half", Vector3(3.4, 0, 0.4), 0, Vector3.ZERO],
			["box_large", Vector3(0.6, 0, -2.4), 15, Vector3(1.1, 1.2, 1.1)],
			["box_large", Vector3(-2.2, 0, 1.8), -10, Vector3(1.1, 1.2, 1.1)],
			["barrel_small", Vector3(-0.8, 0, 2.8), 0, Vector3(0.7, 0.8, 0.7)],
			["barrel_small", Vector3(-5.6, 0, 5.2), 0, Vector3(0.7, 0.8, 0.7)],
		],
		# (le tas de gravats de droite déborde de son centre : obstacle placé à part)
		"obstacles": [[Vector3(5.0, 1.0, 0.4), Vector3(3.0, 2.0, 2.2)]],
		"torches": [Vector3(-1.6, 0, -6.4), Vector3(-6.4, 0, 1.6)],
		"lumieres": [[Vector3(4.0, 2.0, -3.0), VERT, 1.2, 6.0]],
		"apparitions": [Vector3(-3.0, 0, -2.0), Vector3(1.6, 0, -3.8), Vector3(4.6, 0, -3.4),
				Vector3(-4.6, 0, 2.6), Vector3(0.6, 0, 0.2)],
	},
	"crypte": {
		"nom": "Crypte des noyés",
		"types": [&"combat"],
		"sol": ["floor_tile_large", "floor_tile_large_rocks"],
		"objets": [
			["column", Vector3(0.0, 0, -3.4), 0, Vector3(0.5, 1.1, 0.5)],
			["column", Vector3(2.3, 0, -2.1), 0, Vector3(0.5, 1.1, 0.5)],
			["column", Vector3(2.3, 0, 0.5), 0, Vector3(0.5, 1.1, 0.5)],
			["column", Vector3(0.0, 0, 1.8), 0, Vector3(0.5, 1.1, 0.5)],
			["column", Vector3(-2.3, 0, 0.5), 0, Vector3(0.5, 1.1, 0.5)],
			["column", Vector3(-2.3, 0, -2.1), 0, Vector3(0.5, 1.1, 0.5)],
			["candle_triple", Vector3(0.4, 0, -3.6), 0, Vector3.ZERO],
			["candle_triple", Vector3(-2.6, 0, 0.8), 90, Vector3.ZERO],
			["trunk_large_A", Vector3(-5.5, 0, 2.6), 90, Vector3(1.1, 0.8, 1.2)],
			["trunk_large_A", Vector3(-5.5, 0, 4.4), 90, Vector3(1.1, 0.8, 1.2)],
			["candle_lit", Vector3(-5.6, 0, 3.5), 0, Vector3.ZERO],
			["banner_thin_green", Vector3(-4.8, 0, -6.8), 0, Vector3.ZERO],
			["banner_thin_green", Vector3(4.8, 0, -6.8), 0, Vector3.ZERO],
		],
		"torches": [Vector3(-1.6, 0, -6.4), Vector3(-6.4, 0, -4.8)],
		"lumieres": [[Vector3(0.0, 1.2, -0.8), VERT, 2.2, 6.5]],
		"apparitions": [Vector3(0.0, 0, -0.8), Vector3(-4.4, 0, -4.2), Vector3(4.4, 0, -4.4),
				Vector3(-4.4, 0, -0.2), Vector3(4.6, 0, 0.8)],
	},
	"arsenal": {
		"nom": "Arsenal pillé",
		"types": [&"combat"],
		"sol": ["floor_tile_large", "floor_tile_large_rocks"],
		"objets": [
			["barrier", Vector3(-2.2, 0, 0.6), 0, Vector3(3.2, 0.9, 0.4)],
			["barrier", Vector3(2.8, 0, -2.4), 90, Vector3(3.2, 0.9, 0.4)],
			["box_stacked", Vector3(-5.0, 0, -5.0), 0, Vector3(2.6, 2.6, 2.6)],
			["box_large", Vector3(5.4, 0, -3.8), 0, Vector3(1.1, 1.2, 1.1)],
			["barrel_small", Vector3(5.6, 0, -5.6), 0, Vector3(0.7, 0.8, 0.7)],
			["barrel_small", Vector3(-5.6, 0, 5.4), 0, Vector3(0.7, 0.8, 0.7)],
			["sword_shield_broken", Vector3(4.8, 1.8, -6.4), 0, Vector3.ZERO],
			["sword_shield_broken", Vector3(-6.4, 1.8, 3.2), 90, Vector3.ZERO],
			["banner_patternA_red", Vector3(-1.6, 0, -6.8), 0, Vector3.ZERO],
		],
		"torches": [Vector3(-4.8, 0, -6.4), Vector3(-6.4, 0, 1.6)],
		"lumieres": [],
		"apparitions": [Vector3(-4.0, 0, -2.4), Vector3(0.0, 0, -3.6), Vector3(4.6, 0, -1.2),
				Vector3(-3.6, 0, 3.0), Vector3(0.6, 0, 2.4)],
	},
	"puits": {
		"nom": "Puits maudit",
		"types": [&"combat"],
		"sol": ["floor_tile_large", "floor_tile_large_rocks"],
		"cases": {Vector2i(2, 1): "floor_tile_big_grate"},   # la grille du puits, au centre-droit
		"objets": [
			["column", Vector3(0.1, 0, -3.1), 0, Vector3(0.5, 1.1, 0.5)],
			["column", Vector3(3.1, 0, -3.1), 0, Vector3(0.5, 1.1, 0.5)],
			["column", Vector3(0.1, 0, -0.1), 0, Vector3(0.5, 1.1, 0.5)],
			["column", Vector3(3.1, 0, -0.1), 0, Vector3(0.5, 1.1, 0.5)],
			["crates_stacked", Vector3(-5.2, 0, -5.2), -15, Vector3(1.7, 1.8, 1.7)],
			["barrel_large", Vector3(-5.4, 0, 4.6), 0, Vector3(1.3, 1.6, 1.3)],
			["keyring_hanging", Vector3(-6.4, 2.4, 3.2), 90, Vector3.ZERO],
		],
		"torches": [Vector3(-4.8, 0, -6.4), Vector3(4.8, 0, -6.4), Vector3(-6.4, 0, 1.6)],
		"lumieres": [[Vector3(1.6, -0.2, -1.6), VERT, 2.6, 5.0]],
		"apparitions": [Vector3(1.6, 0, -1.6), Vector3(-3.4, 0, -3.4), Vector3(-3.4, 0, 1.0),
				Vector3(4.8, 0, -4.4), Vector3(-1.0, 0, 3.0)],
	},
	# ------------------------------------------------------------------ trésor
	"tresor": {
		"nom": "Chambre au trésor",
		"types": [&"tresor"],
		"sol": ["floor_tile_large", "floor_tile_large_rocks"],
		"coffre": Vector3(0.0, 0, -1.6),
		"objets": [
			["pillar_decorated", Vector3(-3.6, 0, -4.4), 0, Vector3(1.6, 3.2, 1.2)],
			["pillar_decorated", Vector3(4.0, 0, -4.4), 0, Vector3(1.6, 3.2, 1.2)],
			["coin_stack_large", Vector3(-1.8, 0, -2.6), 20, Vector3.ZERO],
			["coin_stack_medium", Vector3(1.6, 0, -2.8), 0, Vector3.ZERO],
			["coin_stack_medium", Vector3(-1.2, 0, 0.0), 60, Vector3.ZERO],
			["candle_lit", Vector3(-1.0, 0, -3.4), 0, Vector3.ZERO],
			["candle_lit", Vector3(1.2, 0, -0.4), 0, Vector3.ZERO],
			["trunk_large_A", Vector3(-5.4, 0, -1.6), 90, Vector3(1.1, 0.8, 1.2)],
			["banner_patternA_red", Vector3(-1.6, 0, -6.8), 0, Vector3.ZERO],
			["banner_patternA_red", Vector3(4.8, 0, -6.8), 0, Vector3.ZERO],
		],
		"torches": [Vector3(-4.8, 0, -6.4), Vector3(-6.4, 0, 3.2)],
		"lumieres": [[Vector3(0.0, 2.2, -1.2), OR, 2.4, 6.0]],
		"apparitions": [],
	},
	# ------------------------------------------------------------------ Bosco
	"antre_bosco": {
		"nom": "Antre du Bosco",
		"types": [&"bosco"],
		"sol": ["floor_tile_large_rocks", "floor_tile_large"],
		"objets": [
			["pillar_decorated", Vector3(-4.4, 0, -4.4), 0, Vector3(1.6, 3.2, 1.2)],
			["pillar_decorated", Vector3(4.6, 0, -4.4), 0, Vector3(1.6, 3.2, 1.2)],
			["pillar_decorated", Vector3(-4.4, 0, 3.0), 90, Vector3(1.2, 3.2, 1.6)],
			["banner_patternA_red", Vector3(-4.8, 0, -6.8), 0, Vector3.ZERO],
			["banner_patternA_red", Vector3(-1.6, 0, -6.8), 0, Vector3.ZERO],
			["banner_patternA_red", Vector3(4.8, 0, -6.8), 0, Vector3.ZERO],
			["banner_patternA_red", Vector3(-6.8, 0, -4.8), 90, Vector3.ZERO],
			["banner_patternA_red", Vector3(-6.8, 0, 1.6), 90, Vector3.ZERO],
			["sword_shield_broken", Vector3(-6.4, 1.8, 4.8), 90, Vector3.ZERO],
		],
		"torches": [Vector3(-3.2, 0, -6.4), Vector3(3.2, 0, -6.4), Vector3(-6.4, 0, -3.2)],
		"lumieres": [[Vector3(0.0, 2.5, -1.5), ROUGE, 1.6, 8.0]],
		"apparitions": [Vector3(-2.0, 0, -3.0), Vector3(2.4, 0, -3.0), Vector3(-3.4, 0, 0.0),
				Vector3(0.0, 0, -1.0), Vector3(3.4, 0, -0.8), Vector3(-1.0, 0, 2.0)],
	},
	# ------------------------------------------------------------------ chaloupe
	"quai": {
		"nom": "Le quai de la chaloupe",
		"types": [&"chaloupe"],
		"sol": ["floor_tile_large", "floor_tile_large_rocks"],
		"cases_bois": [1],      # colonne de dalles en bois : le quai, au bord de l'eau
		"eau": true,            # la première colonne (x < -3,2) est de l'eau ; la chaloupe y flotte
		"chaloupe": Vector3(-4.8, 0, 0.6),
		"objets": [
			["barrel_small_stack", Vector3(-2.2, 0, -5.4), 0, Vector3(1.4, 1.4, 0.8)],
			["box_large", Vector3(-2.2, 0, 4.6), 10, Vector3(1.1, 1.2, 1.1)],
			["keg_decorated", Vector3(4.4, 0, -5.6), 0, Vector3(2.6, 1.6, 1.4)],
			["crates_stacked", Vector3(5.2, 0, 0.4), 0, Vector3(1.7, 1.8, 1.7)],
		],
		"torches": [Vector3(-1.6, 0, -6.4), Vector3(4.8, 0, -6.4)],
		"lumieres": [[Vector3(-4.0, 2.5, -2.0), VERT, 0.7, 5.0]],
		"apparitions": [Vector3(3.0, 0, -4.0), Vector3(4.4, 0, -1.6), Vector3(0.6, 0, -3.0)],
	},
}


## Modèles de salle qui conviennent à un type de salle.
static func modeles_pour(type: StringName) -> Array:
	var r := []
	for id in MODELES:
		if type in MODELES[id]["types"]:
			r.append(id)
	r.sort()
	return r
