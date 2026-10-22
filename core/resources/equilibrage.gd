class_name Equilibrage
extends Resource
## Toutes les valeurs de réglage du jeu, au même endroit (fichier data/equilibrage.tres).
## Pour changer une sensation de jeu (« esquive plus longue », « squelette moins résistant »),
## on modifie une valeur ici : le code n'a pas à être touché.

@export_group("Héros")
@export var heros_pv_max := 100.0
@export var heros_vitesse := 5.2               ## mètres par seconde
@export var heros_vitesse_rotation := 14.0     ## plus c'est haut, plus il se tourne vite
@export var heros_delai_reapparition := 2.5    ## secondes entre la mort et le retour
@export var heros_invulnerable_apres_coup := 0.5   ## évite d'être enchaîné sans pouvoir réagir
@export var heros_invulnerable_reapparition := 1.5
@export var heros_recul_quand_touche := 0.6    ## mètres

@export_group("Attaque du Bretteur (combo de 3 coups)")
@export var combo_animations: PackedStringArray = ["1H_Melee_Attack_Slice_Diagonal", "1H_Melee_Attack_Slice_Horizontal", "1H_Melee_Attack_Chop"]
@export var combo_instant_impact: PackedFloat32Array = [0.40, 0.26, 0.57]  ## secondes dans l'animation
@export var combo_degats: PackedFloat32Array = [10.0, 12.0, 22.0]
@export var combo_lourd: Array[bool] = [false, false, true]  ## un coup lourd interrompt l'ennemi
@export var combo_vitesse_animation := 1.3
@export var combo_portee := 1.5         ## distance du centre de la zone de coup devant le héros
@export var combo_rayon := 1.15
@export var combo_pas_en_avant := 0.35  ## petit pas en avant à chaque coup
@export var combo_fenetre := 0.45       ## secondes après la fin du coup pour enchaîner le suivant

@export_group("Visée assistée")
@export var visee_portee := 7.0         ## un ennemi plus loin n'attire pas la visée

@export_group("Esquive")
@export var esquive_distance := 4.0
@export var esquive_duree := 0.36
@export var esquive_invulnerabilite := 0.32   ## secondes sans pouvoir être touché (réglable)
@export var esquive_recharge := 0.9

@export_group("Compétence : Parade-riposte")
@export var parade_fenetre := 0.75      ## durée pendant laquelle un coup de face est paré
@export var parade_angle := 75.0        ## degrés de part et d'autre de l'avant
@export var parade_recharge := 6.0
@export var riposte_degats := 30.0
@export var riposte_etourdissement := 1.4
@export var riposte_instant_impact := 0.36

@export_group("Compétence : Fente")
@export var fente_distance := 5.0
@export var fente_duree := 0.26
@export var fente_degats := 18.0
@export var fente_rayon := 1.2
@export var fente_recharge := 5.0

@export_group("Matelot squelette")
@export var squelette_pv_max := 60.0
@export var squelette_vitesse := 2.9
@export var squelette_portee_attaque := 1.8
@export var squelette_preparation := 0.7       ## durée de l'annonce avant le coup
@export var squelette_impact_animation := 0.59 ## instant d'impact dans l'animation d'attaque
@export var squelette_degats := 15.0
@export var squelette_zone_avant := 1.3
@export var squelette_zone_rayon := 1.0
@export var squelette_recuperation := 0.7      ## moment vulnérable après son coup
@export var squelette_recharge_attaque := 1.6
@export var squelette_recul_quand_touche := 0.45
@export var squelette_recul_coup_lourd := 1.1

@export_group("Arène d'entraînement")
@export var arene_nb_ennemis := 2
@export var arene_delai_apparition := 1.6
@export var arene_distance_apparition_min := 4.5

@export_group("Ressenti des impacts")
@export var arret_image := 0.055        ## arrêt sur image à chaque coup porté (secondes)
@export var arret_image_lourd := 0.09
@export var secousse_coup := 0.12
@export var secousse_coup_lourd := 0.25
@export var secousse_touche := 0.3
