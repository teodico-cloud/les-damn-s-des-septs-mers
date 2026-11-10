class_name PasSonores
extends Node
## Bruits de pas (10/11, choix de Téo : « pas et torches ») : quand l'animation de course ou de marche d'un combattant
## pose un pied, un pas sonne, selon le sol du lieu (pierre ou bois : `sol_a(position)` du lieu, Arene par défaut).
## Les instants où chaque pied touche le sol ont été mesurés sur les animations KayKit (part de la boucle, de 0 à 1 :
## `tools/sonde_pas.gd`). Chaque téléphone joue les pas de ce qu'il affiche, marionnettes comprises : rien ne passe
## par le réseau. Un enfant de chaque héros et de chaque squelette (Heros._ready, Ennemi._ready).

const CONTACTS := {
	"Running_A": [0.10, 0.60],             # héros, course du Bosco enragé
	"Running_C": [0.12, 0.63],             # squelettes
	"Walking_D_Skeletons": [0.18, 0.69],   # marche du Bosco
}

var anim: AnimationPlayer
var porteur: Node3D
var son := "pas"      ## « pas » (héros) ou « pas_os » (squelettes) ; le sol complète : pas_pierre, pas_os_bois…
var hauteur := 1.0    ## plus grave pour un gros squelette (Bosco)
var joues := 0        ## pas joués (tests)

var _anim_avant := ""
var _f_avant := 0.0
var _lieu: Node


static func pour(qui: Node3D, lecteur: AnimationPlayer, nom_son := "pas", grave := 1.0) -> PasSonores:
	var p := PasSonores.new()
	p.name = "Pas"
	p.porteur = qui
	p.anim = lecteur
	p.son = nom_son
	p.hauteur = grave
	qui.add_child(p)
	return p


func _process(_delta: float) -> void:
	if anim == null or not anim.is_playing():
		_anim_avant = ""
		return
	var nom := String(anim.current_animation)
	var contacts: Array = CONTACTS.get(nom, [])
	var duree := anim.current_animation_length
	if contacts.is_empty() or duree <= 0.0:
		_anim_avant = ""
		return
	var f := fposmod(anim.current_animation_position / duree, 1.0)
	if nom == _anim_avant:
		for c in contacts:
			if franchi(_f_avant, f, c):
				joues += 1
				Sons.jouer(StringName("%s_%s" % [son, sol()]), porteur, hauteur)
				break
	_anim_avant = nom
	_f_avant = f


## Le pied est-il passé par l'instant `c` entre `avant` et `apres` (la boucle a pu repartir entre les deux) ?
static func franchi(avant: float, apres: float, c: float) -> bool:
	if apres >= avant:
		return avant < c and c <= apres
	return c > avant or c <= apres


## « pierre » ou « bois », d'après le lieu où marche le porteur.
func sol() -> String:
	if _lieu == null or not is_instance_valid(_lieu):
		_lieu = null
		var n := porteur.get_parent()
		while n != null:
			if n.has_method("sol_a"):
				_lieu = n
				break
			n = n.get_parent()
	return _lieu.sol_a(porteur.global_position) if _lieu else "pierre"
