class_name Equilibrage
extends Resource
## Toutes les valeurs de réglage du jeu, au même endroit (fichier data/equilibrage.tres).
## Pour changer une sensation de jeu (« esquive plus longue », « squelette moins résistant »),
## on modifie une valeur ici : le code n'a pas à être touché.

@export_group("Héros")
@export var heros_pv_max := 100.0
@export var heros_vitesse := 6.2               ## mètres par seconde (5,2 avant le combat « nerveux »)
@export var heros_vitesse_rotation := 14.0     ## plus c'est haut, plus il se tourne vite
@export var heros_delai_reapparition := 2.5    ## secondes entre la mort et le retour
@export var heros_invulnerable_apres_coup := 0.5   ## évite d'être enchaîné sans pouvoir réagir
@export var heros_invulnerable_reapparition := 1.5
@export var heros_recul_quand_touche := 0.6    ## mètres
@export var heros_duree_recul := 0.2           ## secondes pour parcourir ce recul
@export var heros_duree_touche := 0.4          ## secondes sans pouvoir agir après un coup reçu

@export_group("Attaque du Bretteur (combo de 3 coups)")
@export var combo_animations: PackedStringArray = ["1H_Melee_Attack_Slice_Diagonal", "1H_Melee_Attack_Slice_Horizontal", "1H_Melee_Attack_Chop"]
@export var combo_instant_impact: PackedFloat32Array = [0.40, 0.26, 0.57]  ## secondes dans l'animation
@export var combo_degats: PackedFloat32Array = [10.0, 12.0, 22.0]
@export var combo_lourd: Array[bool] = [false, false, true]  ## un coup lourd interrompt l'ennemi
@export var combo_vitesse_animation := 1.65   ## coups 25 % plus rapides qu'au jalon 1 (1,3)
@export var combo_annulation := 0.05      ## secondes après l'impact où le joystick peut couper la fin du coup
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
@export var esquive_recharge := 0.6

@export_group("Compétence : Parade-riposte")
@export var parade_fenetre := 0.75      ## durée pendant laquelle un coup de face est paré
@export var parade_angle := 75.0        ## degrés de part et d'autre de l'avant
@export var parade_recharge := 4.0
@export var riposte_degats := 30.0
@export var riposte_etourdissement := 1.4
@export var riposte_instant_impact := 0.36     ## secondes dans l'animation (avant accélération)
@export var riposte_vitesse_animation := 1.2
@export var riposte_distance_max := 3.0        ## au-delà, la riposte frappe dans le vide
## Parade parfaite (choix de Téo) : le coup arrive au plus tant de secondes après l'appui sur Parade.
## Riposte critique (dégâts doublés), étourdissement plus long, recharge rendue aussitôt.
@export var parade_parfaite_fenetre := 0.25
@export var riposte_etourdissement_parfaite := 2.2
## La zone rouge au sol devient dorée tant de secondes avant le coup : c'est le moment de parer.
## Plus tôt que la fenêtre parfaite, pour laisser le temps de réagir (≈ 0,2 s + le délai de l'écran).
@export var parade_signal_avance := 0.4
@export var parade_parfaite_ralenti := 0.35         ## secondes réelles de ralenti (seul ; en coop : arrêt local)
@export var parade_parfaite_ralenti_vitesse := 0.25 ## vitesse du jeu pendant ce ralenti

@export_group("Compétence : Fente")
@export var fente_distance := 5.0
@export var fente_duree := 0.26
@export var fente_degats := 18.0
@export var fente_rayon := 1.2
@export var fente_recharge := 3.5

@export_group("Occultiste")
@export var occ_pv_max := 80.0                 ## plus fragile : il doit garder ses distances
@export var occ_tir_animation := "Spellcast_Shoot"
@export var occ_tir_vitesse_animation := 2.0
@export var occ_tir_instant := 0.27            ## secondes dans l'animation (baguette tendue)
@export var occ_tir_cadence := 0.32            ## secondes minimum entre deux tirs (≈ 3 par seconde)
@export var occ_tir_degats := 9.0
@export var occ_tir_portee := 9.0              ## mètres (aussi la portée de la visée assistée)
@export var occ_tir_vitesse := 14.0            ## m/s
@export var occ_tir_rayon := 0.35              ## taille de la zone qui touche
@export var occ_tele_distance := 4.0
@export var occ_tele_duree := 0.12             ## secondes « disparu » pendant le saut
@export var occ_tele_invulnerabilite := 0.3
@export var occ_tele_recharge := 0.9
@export var occ_marque_duree := 6.0
@export var occ_marque_bonus_partenaire := 0.4 ## +40 % de dégâts du partenaire sur la cible
@export var occ_marque_bonus_soi := 0.15       ## +15 % pour l'Occultiste lui-même
@export var occ_marque_portee := 9.0
@export var occ_marque_recharge := 8.0
@export var occ_marque_instant := 0.15         ## secondes après l'appui où la marque se pose
@export var occ_marque_duree_geste := 0.35     ## secondes immobile pendant le geste
@export var occ_chaines_rayon := 2.5
@export var occ_chaines_duree := 2.0           ## secondes d'immobilisation
@export var occ_chaines_portee := 8.0          ## distance max du centre de la zone
@export var occ_chaines_recharge := 10.0
@export var occ_chaines_instant := 0.28
@export var occ_chaines_duree_geste := 0.55

@export_group("Matelot squelette")
@export var squelette_pv_max := 30.0          ## hordes : plus nombreux, plus fragiles (60 au jalon 1)
@export var squelette_vitesse := 2.9
@export var squelette_portee_attaque := 1.8
@export var squelette_preparation := 0.7       ## durée de l'annonce avant le coup
@export var squelette_impact_animation := 0.59 ## instant d'impact dans l'animation d'attaque
@export var squelette_degats := 10.0          ## 15 au jalon 1, quand ils n'étaient que 2
@export var squelette_zone_avant := 1.3
@export var squelette_zone_rayon := 1.0
@export var squelette_recuperation := 0.7      ## moment vulnérable après son coup
@export var squelette_recharge_attaque := 1.6
@export var squelette_recul_quand_touche := 0.45   ## mètres
@export var squelette_recul_coup_lourd := 1.6      ## mètres (aussi pour la riposte)
@export var squelette_freinage_recul := 12.0       ## m/s² : plus c'est haut, plus le recul est sec
@export var squelette_duree_frappe := 0.12         ## secondes où la zone reste affichée après le coup
@export var squelette_duree_touche := 0.35         ## secondes interrompu par un coup reçu
@export var squelette_duree_touche_lourd := 0.55
@export var squelette_duree_corps := 0.6           ## secondes avant que le nœud disparaisse (il a éclaté en os)
@export var debris_duree := 2.2                     ## secondes avant que les os s'effacent
@export var debris_force := 4.5                     ## vitesse des os projetés (m/s)

@export_group("Arène d'entraînement")
@export var arene_nb_ennemis := 5            ## hordes (2 au jalon 1)
@export var arene_nb_ennemis_coop := 8         ## à deux

@export_group("Coop : réanimation")
@export var reanimation_rayon := 1.8           ## mètres : le partenaire doit rester aussi près
@export var reanimation_duree := 3.0           ## secondes près du héros à terre pour le relever
@export var reanimation_pv := 0.5              ## part des PV rendus (0,5 = la moitié)
@export var reanimation_invulnerable := 1.5    ## secondes intouchable en se relevant
@export var reanimation_oubli := 0.5           ## la progression redescend à cette vitesse s'il s'éloigne
@export var coop_delai_retour := 3.0           ## les deux à terre : secondes avant le retour au départ
@export var arene_delai_apparition := 2.0     ## après une mort, les manquants ressortent ensemble, en groupe
@export var arene_rayon_groupe := 1.6         ## mètres : écart des squelettes d'un même groupe
@export var arene_distance_apparition_min := 4.5

@export_group("Ressenti des impacts")
@export var arret_image := 0.055        ## arrêt sur image à chaque coup porté (secondes)
@export var arret_image_lourd := 0.09
@export var arret_image_vitesse := 0.05 ## vitesse du jeu pendant l'arrêt (0,05 = presque figé)
@export var secousse_coup := 0.12
@export var secousse_coup_lourd := 0.25
@export var secousse_touche := 0.3
@export var secousse_critique := 0.35

@export_group("Coups critiques")
@export var critique_chance := 0.1           ## 1 chance sur 10 (coups des héros sur les ennemis)
@export var critique_multiplicateur := 2.0

@export_group("Expédition")
@export var exp_nb_salles := 4                ## salles avant l'antre du Bosco (choix de Téo : expédition courte)
@export var exp_ennemis_salle := 9            ## squelettes à vaincre dans une salle de combat (seul)
@export var exp_ennemis_salle_coop := 13      ## … à deux
@export var exp_ennemis_bosco := 14           ## antre du Bosco (en attendant le Bosco, étape 3 : une grosse horde)
@export var exp_ennemis_bosco_coop := 20
@export var exp_ensemble := 5                 ## squelettes debout en même temps dans une salle (seul)
@export var exp_ensemble_coop := 7            ## … à deux
@export var exp_tresor_soin := 0.5            ## salle trésor : part des PV max rendue en ouvrant le coffre
@export var exp_rayon_porte := 1.5            ## mètres : se tenir devant une porte pour la prendre
@export var exp_rayon_coffre := 1.6           ## mètres : ouvrir le coffre en s'en approchant
@export var exp_rayon_chaloupe := 2.2         ## mètres : monter dans la chaloupe
@export var exp_fondu := 0.4                  ## secondes de fondu au noir entre deux salles
@export var exp_delai_defaite := 2.5          ## secondes entre la chute et l'écran de fin

@export_group("Orbes de vie")
@export var orbe_chance := 0.3                ## chance qu'un squelette vaincu lâche une orbe (choix de Téo)
@export var orbe_soin := 0.2                  ## part des PV max rendue
@export var orbe_rayon := 0.9                 ## mètres : on la ramasse en passant dessus (si l'on est blessé)
@export var orbe_duree := 25.0                ## secondes avant qu'elle s'efface
