class_name Porte
extends Node3D
## Porte de sortie d'une salle d'expédition. Fermée pendant le combat ; quand la salle est nettoyée,
## elle s'ouvre (le battant pivote, une lueur l'éclaire). Une icône au-dessus annonce le type de la
## salle suivante (combat, trésor, Bosco, chaloupe). Pour la prendre, se tenir devant (exp_rayon_porte) ;
## en coop, les deux héros doivent être devant la même porte (choix de Téo) : un compteur « 1/2 ».

const EQ: Equilibrage = preload("res://data/equilibrage.tres")
const ICONES := {
	&"combat": preload("res://assets/ui/portes/porte_combat.svg"),
	&"tresor": preload("res://assets/ui/portes/porte_tresor.svg"),
	&"bosco": preload("res://assets/ui/portes/porte_bosco.svg"),
	&"chaloupe": preload("res://assets/ui/portes/porte_chaloupe.svg"),
}

var type: StringName = &"combat"
var index := 0                   ## 0 : porte du fond ; 1 : porte de gauche
var ouverte := false
var _battant: Node3D
var _lueur: OmniLight3D
var _compteur: Label3D
var _icone: Sprite3D


## `pos` : centre du mur ; `rot_y` : 0 (mur du fond) ou 90 (mur de gauche), en degrés.
func configurer(p_type: StringName, p_index: int, pos: Vector3, rot_y: float) -> void:
	type = p_type
	index = p_index
	position = pos
	rotation_degrees.y = rot_y


func _ready() -> void:
	var modele: Node3D = load("res://assets/models/decor/wall_doorway.glb").instantiate()
	modele.scale = Vector3.ONE * 0.8
	add_child(modele)
	_battant = modele.find_child("wall_doorway_door", true, false) as Node3D
	_icone = Sprite3D.new()
	_icone.texture = ICONES.get(type, ICONES[&"combat"])
	_icone.pixel_size = 0.0055
	_icone.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_icone.no_depth_test = true
	_icone.render_priority = 2
	_icone.position = Vector3(0, 3.55, 0.6)
	add_child(_icone)
	var nom := Label3D.new()
	nom.text = PlanExpedition.nom_type(type)
	nom.font_size = 40
	nom.outline_size = 12
	nom.pixel_size = 0.006
	nom.modulate = Color("e2d6ba")
	nom.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	nom.no_depth_test = true
	nom.position = Vector3(0, 2.75, 0.6)
	add_child(nom)
	_compteur = Label3D.new()
	_compteur.font_size = 72
	_compteur.outline_size = 16
	_compteur.pixel_size = 0.006
	_compteur.modulate = Color("6cffa0")
	_compteur.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_compteur.no_depth_test = true
	_compteur.position = Vector3(0, 2.3, 1.3)   # au-dessus de la tête du héros qui attend
	add_child(_compteur)
	_lueur = OmniLight3D.new()
	_lueur.light_color = Color(1.0, 0.75, 0.4)
	_lueur.omni_range = 4.5
	_lueur.light_energy = 0.0
	_lueur.position = Vector3(0, 1.6, 0.8)
	add_child(_lueur)
	_icone.modulate = Color(0.55, 0.55, 0.55)   # éteinte tant que la porte est fermée


## Point devant la porte (dans la salle) où se tenir pour la prendre.
func devant() -> Vector3:
	return global_position + global_transform.basis.z * 1.3


func heros_devant(h: Node3D) -> bool:
	if h == null or not is_instance_valid(h):
		return false
	var d := h.global_position - devant()
	d.y = 0.0
	return d.length() <= EQ.exp_rayon_porte


func ouvrir() -> void:
	if ouverte:
		return
	ouverte = true
	_icone.modulate = Color.WHITE
	var t := create_tween().set_parallel(true)
	if _battant:
		t.tween_property(_battant, "rotation_degrees:y", -105.0, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_lueur, "light_energy", 1.8, 0.7)
	t.tween_property(_icone, "scale", Vector3.ONE * 1.25, 0.25).set_trans(Tween.TRANS_BACK)
	t.chain().tween_property(_icone, "scale", Vector3.ONE, 0.2)


## Coop : nombre de héros devant (« 1/2 » quand on attend l'autre).
func afficher_attente(devant_nb: int, total: int) -> void:
	_compteur.text = "%d/%d" % [devant_nb, total] if total > 1 and devant_nb > 0 and devant_nb < total else ""
