class_name SqueletteAllie
extends Ennemi
## Grimoire du Pendu (objet légendaire de l'Occultiste) : un squelette tué par ses sorts ressort de terre
## à ses côtés, spectral et vert, et frappe les squelettes pendant quelques secondes avant de retomber
## en poussière. Il n'est ni visé ni frappé (pas de collision), ne compte pas dans la salle et ne lâche
## rien. En coop, l'hôte le fait agir ; l'invité le recrée d'après son nom (« Allie_12 »).

static var _mat_spectre: StandardMaterial3D
static var _mat_yeux: StandardMaterial3D

var maitre: Node3D               ## l'Occultiste qui l'a relevé
var _vie := 0.0


func _init() -> void:
	allie = true


func type_ennemi() -> StringName:
	return &"allie"


func _ready() -> void:
	super()
	remove_from_group("ennemis")   # ni visé par les héros, ni compté
	add_to_group("allies")
	collision_layer = 0


func _couche_vivant() -> int:
	return 0


func _masque_cibles() -> int:
	return Combat.COUCHE_ENNEMIS


func _degats_frappe() -> float:
	return EQ.pendu_degats


## Spectral : voile vert sur tout le corps, yeux verts.
func _preparer_modele() -> void:
	if _mat_spectre == null:
		_mat_spectre = StandardMaterial3D.new()
		_mat_spectre.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat_spectre.albedo_color = Color(0.3, 1.0, 0.55, 0.35)
		_mat_spectre.emission_enabled = true
		_mat_spectre.emission = Color(0.25, 0.95, 0.5)
		_mat_spectre.emission_energy_multiplier = 0.7
		_mat_yeux = StandardMaterial3D.new()
		_mat_yeux.albedo_color = Color(0.2, 1.0, 0.45)
		_mat_yeux.emission_enabled = true
		_mat_yeux.emission = Color(0.3, 1.0, 0.5)
		_mat_yeux.emission_energy_multiplier = 4.0
	for m in visuel.find_children("*", "MeshInstance3D", true, false):
		m.material_overlay = _mat_spectre
	if _yeux:
		_yeux.material_override = _mat_yeux


## Pas de zone rouge au sol : il ne menace pas les héros.
func _montrer_annonce(_oui: bool) -> void:
	marque.visible = false


func _yeux_rouges(_actif: bool) -> void:
	pass   # (ses yeux restent verts)


## Il poursuit le squelette le plus proche (pas les héros).
func heros_le_plus_proche() -> Node3D:
	var meilleur: Node3D = null
	var dmin := INF
	for e in get_tree().get_nodes_in_group("ennemis"):
		if e is Ennemi and e.est_ciblable():
			var d := global_position.distance_to(e.global_position)
			if d < dmin:
				dmin = d
				meilleur = e
	return meilleur


func _physics_process(delta: float) -> void:
	super(delta)
	if marionnette or etat == Etat.MORT:
		return
	_vie += delta
	if _vie >= EQ.pendu_duree:
		retomber()


## Son temps est fini : il retombe en os, sans rien lâcher (ni butin, ni « squelette vaincu »).
func retomber() -> void:
	if etat == Etat.MORT:
		return
	collision_layer = 0
	_changer(Etat.MORT)
	_eclater(null)


func _on_mort(_source: Node) -> void:
	retomber()


## (Rien ne l'atteint : pas de collision ; mais un coup direct ne lui fait rien non plus.)
func recevoir_coup(_degats: float, _source: Node3D, _lourd: bool, _critique := false) -> float:
	return 0.0


func etourdir(_duree: float) -> void:
	pass


func immobiliser(_duree: float) -> void:
	pass


func marquer(_par: Node3D, _duree: float) -> void:
	pass
