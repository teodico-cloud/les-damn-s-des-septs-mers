class_name ReglesCoop
extends Node
## Règles de la partie à deux, appliquées par l'hôte seulement (l'invité les voit par les instantanés) :
## - un héros à 0 PV reste à terre ; son partenaire le relève en restant près de lui
##   (zone verte qui se remplit) ; il repart avec la moitié de ses PV ;
## - si les deux sont à terre en même temps : « Vous êtes tombés… », puis retour au départ et
##   squelettes remis à zéro (choix de Téo).

const EQ: Equilibrage = preload("res://data/equilibrage.tres")

var heros_a: Heros
var heros_b: Heros
var generateur: GenerateurEnnemis
var temps_avant_retour := -1.0   ## secondes avant le retour au départ quand les deux sont à terre ; -1 sinon


func configurer(a: Heros, b: Heros, gen: GenerateurEnnemis) -> void:
	heros_a = a
	heros_b = b
	generateur = gen
	heros_a.reapparition_auto = false
	heros_b.reapparition_auto = false


func _physics_process(delta: float) -> void:
	if not (is_instance_valid(heros_a) and is_instance_valid(heros_b)):
		return
	var a_terre := not heros_a.est_vivant()
	var b_terre := not heros_b.est_vivant()
	if a_terre and b_terre:
		if temps_avant_retour < 0.0:
			temps_avant_retour = EQ.coop_delai_retour
		temps_avant_retour -= delta
		if temps_avant_retour <= 0.0:
			_retour_au_depart()
		return
	temps_avant_retour = -1.0
	_reanimer(heros_a, heros_b, delta)
	_reanimer(heros_b, heros_a, delta)


func _reanimer(a_terre: Heros, sauveur: Heros, delta: float) -> void:
	if a_terre.est_vivant():
		return
	var pres := sauveur.est_vivant() and \
			Vector2(a_terre.global_position.x - sauveur.global_position.x, a_terre.global_position.z - sauveur.global_position.z).length() <= EQ.reanimation_rayon
	var p := a_terre.progres_reanimation
	if pres:
		p += delta / EQ.reanimation_duree
	else:
		p = maxf(0.0, p - delta * EQ.reanimation_oubli / EQ.reanimation_duree)
	if p >= 1.0:
		a_terre.relever(EQ.reanimation_pv)
	else:
		a_terre.afficher_reanimation(p, true)


func _retour_au_depart() -> void:
	temps_avant_retour = -1.0
	heros_a.reapparaitre()
	heros_b.reapparaitre()
	generateur.reinitialiser()
