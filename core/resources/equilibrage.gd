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

@export_group("Attaque du Bretteur (combo de 3 coups ; façon Diablo, choix de Téo du 05/11)")
## coups 1 et 2 : deux taillades en arc ; coup 3 : le moulinet (un tour complet, il touche tout autour)
@export var combo_animations: PackedStringArray = ["1H_Melee_Attack_Slice_Diagonal", "1H_Melee_Attack_Slice_Horizontal", "2H_Melee_Attack_Spin"]
@export var combo_instant_impact: PackedFloat32Array = [0.40, 0.26, 0.90]  ## secondes dans l'animation (moulinet : à mi-tour)
## fin du geste dans l'animation (0 : toute l'animation) ; le moulinet se termine à 1,71 s (la suite est immobile)
@export var combo_fin_geste: PackedFloat32Array = [0.0, 0.0, 1.71]
@export var combo_degats: PackedFloat32Array = [10.0, 12.0, 22.0]
@export var combo_lourd: Array[bool] = [false, false, true]  ## un coup lourd interrompt l'ennemi
@export var combo_vitesse_animation := 1.65   ## coups 25 % plus rapides qu'au jalon 1 (1,3)
## le moulinet va au bout (choix de Téo du 30/10) mais plus vite (05/11) : 0,45 s au lieu de 0,63 s
@export var combo_vitesse_moulinet := 2.3
@export var combo_annulation := 0.05      ## secondes après l'impact où le joystick peut couper la fin du coup (pas le 3e)
@export var combo_arc_portee := 2.3       ## mètres : jusqu'où une taillade touche, devant le héros…
@export var combo_arc_angle := 150.0      ## … dans cet arc (degrés, en tout)
@export var combo_moulinet_rayon := 2.4   ## mètres : le moulinet touche tout ce qui est à cette distance, tout autour
@export var combo_aimant_portee := 4.0    ## un squelette visé à cette distance ou moins : le héros bondit sur lui
@export var combo_aimant_contact := 1.1   ## … et s'arrête à cette distance de lui (mètres, centre à centre)
@export var combo_aimant_vitesse_max := 20.0  ## m/s
@export var combo_pas_en_avant := 0.35  ## sans squelette à portée : petit pas en avant à chaque coup
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
@export var parade_parfaite_fenetre := 0.35   ## (0,25 au début : parer dès le doré donnait une parade normale)
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
@export var fente_recharge := 1.0       ## (3,5 avant la jauge : c'est elle qui décide, 06/11)
@export var fente_cout := 35.0          ## de jauge

@export_group("Jauge façon Diablo (06/11, choix de Téo)")
## L'attaque remplit la jauge (Fureur du Bretteur, Âmes de l'Occultiste), la compétence 2 (Fente, Chaînes) la dépense.
@export var jauge_max := 100.0
@export var jauge_gain_coup := 9.0          ## par squelette touché par l'attaque (taillades, moulinet, tir) ou la riposte
@export var jauge_gain_geste_max := 22.0    ## au plus par geste : un moulinet dans la horde ne remplit pas tout
@export var jauge_gain_parade_parfaite := 30.0
@export var jauge_baisse_apres := 5.0       ## secondes sans coup porté ni reçu : la jauge baisse doucement…
@export var jauge_baisse := 6.0             ## … de tant par seconde

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
@export var occ_tir_guidage := 180.0           ## degrés par seconde : le projectile s'incurve vers sa cible (05/11)…
@export var occ_tir_guidage_angle := 35.0      ## … choisie au départ dans ce cône (degrés de chaque côté)
@export var occ_tir_explosion_rayon := 1.2     ## mètres : à l'impact, il blesse aussi ce qui est autour (choix de Téo du 05/11)
@export var occ_tir_explosion_degats := 9.0    ## dégâts de l'explosion aux voisins de la cible
@export var occ_tele_distance := 4.0
@export var occ_tele_duree := 0.12             ## secondes « disparu » pendant le saut
@export var occ_tele_invulnerabilite := 0.3
@export var occ_tele_recharge := 3.0           ## par charge (choix de Téo du 05/11 : 0,9 s, c'était une fuite permanente)…
@export var occ_tele_charges := 2              ## … deux sauts d'affilée, puis attendre
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
@export var occ_chaines_recharge := 1.2   ## (10 avant la jauge, 06/11)
@export var occ_chaines_cout := 40.0     ## de jauge
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

@export_group("Arbalétrier squelette")
@export var arb_pv_max := 22.0
@export var arb_vitesse := 2.6
@export var arb_distance_ideale := 6.0       ## mètres : il se tient à cette distance du héros
@export var arb_distance_fuite := 3.5        ## plus près : il recule
@export var arb_portee := 10.0               ## il vise d'ici
@export var arb_visee := 0.8                 ## secondes de visée (trait rouge) avant le tir
@export var arb_visee_suivie := 0.65         ## part de la visée où il suit encore sa cible (puis il bloque)
@export var arb_recharge := 2.4              ## secondes entre deux tirs
@export var carreau_vitesse := 13.0          ## m/s : visible, on peut l'esquiver
@export var carreau_degats := 12.0
@export var carreau_portee := 14.0
@export var carreau_renvoi_degats := 24.0    ## carreau renvoyé par la Parade (choix de Téo)

@export_group("Prêtre noyé")
@export var pretre_pv_max := 45.0
@export var pretre_vitesse := 2.0
@export var pretre_distance := 6.5           ## il garde ses distances
@export var pretre_rayon_relever := 9.0      ## il relève un squelette tombé à moins de cette distance
@export var pretre_incantation := 1.6        ## secondes pour relever un mort (un coup l'interrompt : choix de Téo)
@export var pretre_recharge_relever := 4.0
@export var pretre_portee_flaque := 9.0
@export var pretre_annonce_flaque := 0.9     ## secondes de cercle vert avant la flaque
@export var pretre_recharge_flaque := 5.5
@export var flaque_duree := 5.0
@export var flaque_rayon := 1.5
@export var flaque_degats_seconde := 8.0     ## tant qu'on reste dedans

@export_group("Pièges")
@export var pics_degats := 18.0
@export var pics_periode := 3.2              ## secondes entre deux sorties des pics
@export var pics_alerte := 0.7               ## la dalle tremble et rougeoie avant
@export var pics_sortis := 0.8               ## secondes où les pics restent sortis
@export var tonneau_degats := 45.0           ## aux squelettes seulement (les héros sont épargnés)
@export var tonneau_rayon := 3.0
@export var tonneau_meche := 0.35            ## secondes entre le coup et l'explosion

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
@export var exp_ensemble := 5                 ## squelettes debout en même temps dans une salle (seul)
@export var exp_ensemble_coop := 7            ## … à deux
@export var exp_ennemis_piege := 5            ## salle piège : peu de squelettes (les pièges font le reste)
@export var exp_ennemis_piege_coop := 7
@export var exp_arbaletriers := 2             ## par salle de combat, à partir de la 2e salle (à deux : +1)
@export var exp_pretres := 1                  ## par salle de combat, à partir de la 3e salle, et dans l'antre
@export var exp_tresor_soin := 0.5            ## salle trésor : part des PV max rendue en ouvrant le coffre
@export var exp_rayon_porte := 1.5            ## mètres : se tenir devant une porte pour la prendre
@export var exp_rayon_coffre := 1.6           ## mètres : ouvrir le coffre en s'en approchant
@export var exp_rayon_chaloupe := 2.2         ## mètres : monter dans la chaloupe
@export var exp_fondu := 0.4                  ## secondes de fondu au noir entre deux salles
@export var exp_delai_defaite := 2.5          ## secondes entre la chute et l'écran de fin

@export_group("Bosco Maudit (mini-boss de l'antre)")
@export var bosco_pv := 1400.0                ## ~1 min 30 de combat en solo (choix de Téo), pour un bon joueur
@export var bosco_pv_coop := 1.8              ## à deux : PV ×1,8 pour garder la même durée
@export var bosco_taille := 1.6               ## grand squelette guerrier (×1,6) ; sa hache encore ×1,4
@export var bosco_vitesse := 2.6              ## m/s en marchant vers le héros
@export var bosco_pause := 1.1                ## secondes entre deux attaques
@export var bosco_etourdissement := 0.5       ## part de la durée d'un étourdissement ou des chaînes qu'il subit
# coup de hache au sol, droit devant (le seul qui se pare : zone dorée à la fin)
@export var bosco_coup_annonce := 1.0
@export var bosco_coup_degats := 22.0
@export var bosco_coup_longueur := 4.6        ## mètres devant lui
@export var bosco_coup_largeur := 1.8
@export var bosco_coup_portee := 4.0          ## il le lance si le héros est plus près que ça
@export var bosco_coup_recuperation := 0.9
# tourbillon de hache (imparable : rouge sombre, il faut s'éloigner ou rouler)
@export var bosco_tourbillon_annonce := 1.1
@export var bosco_tourbillon_degats := 30.0
@export var bosco_tourbillon_rayon := 3.2
@export var bosco_tourbillon_duree := 0.8     ## secondes à tourner
@export var bosco_tourbillon_recuperation := 1.0
@export var bosco_tourbillon_portee := 2.6    ## il le préfère quand le héros est tout près
# charge (imparable) : en ligne droite ; contre un mur, il reste sonné
@export var bosco_charge_annonce := 1.0
@export var bosco_charge_degats := 26.0
@export var bosco_charge_vitesse := 14.0
@export var bosco_charge_longueur := 12.0     ## mètres au plus
@export var bosco_charge_largeur := 1.6
@export var bosco_charge_distance := 5.0      ## il charge si le héros est plus loin que ça
@export var bosco_charge_recharge := 5.0      ## secondes entre deux charges
@export var bosco_charge_sonne := 2.0         ## secondes sonné contre un mur (choix de Téo)
@export var bosco_charge_recuperation := 0.8  ## sans mur : il s'arrête et repart
# rage à mi-vie (choix de Téo)
@export var bosco_rage_seuil := 0.5
@export var bosco_rage_cri := 1.6             ## secondes de cri (il appelle son équipage)
@export var bosco_rage_renforts := 3          ## matelots appelés
@export var bosco_rage_vitesse := 1.25        ## plus rapide : marche, annonces et pauses (÷1,25)

@export_group("Malédiction (choisie au départ, de 0 à 5, effets cumulés)")
@export var mal_pv := 0.25                    ## 1 Os durcis : squelettes +25 % PV
@export var mal_ennemis_salle := 2            ## 2 Équipage nombreux : +2 squelettes par salle…
@export var mal_ensemble := 1                 ## … et 1 de plus debout à la fois
@export var mal_degats := 0.25                ## 3 Lames maudites : squelettes +25 % de dégâts
@export var mal_orbes := 0.5                  ## 4 Mer avare : orbes 2 fois plus rares…
@export var mal_coffre := 0.5                 ## … et coffre qui soigne moitié moins
@export var mal_vitesse_pieges := 1.3         ## 5 Bosco enragé dès le début, pièges plus rapides
@export var mal_butin := 0.2                  ## +20 % de chance d'objet par niveau

@export_group("Chaloupe sous les vagues (sortie de l'expédition)")
@export var chaloupe_duree := 45.0            ## secondes à tenir à bord (choix de Téo) ; le compte s'arrête si personne n'y est
@export var chaloupe_vagues := 5              ## vagues de squelettes qui sortent de l'eau pendant ce temps
@export var chaloupe_vague := 3               ## squelettes par vague (seul)
@export var chaloupe_vague_coop := 4
@export var chaloupe_arbaletrier_des := 3     ## à partir de la 3e vague, l'un d'eux est un arbalétrier
@export var chaloupe_max_debout := 8          ## une vague attend tant qu'il y a déjà ce nombre de squelettes debout

@export_group("Butin (jalon 4 : au sol, façon Diablo ; chacun le sien à deux)")
@export var butin_objet_matelot := 0.06       ## chance qu'un matelot lâche un objet (pour chaque joueur)
@export var butin_objet_arbaletrier := 0.1
@export var butin_objet_pretre := 0.15
@export var butin_doublons_chance := 0.35     ## chance de lâcher des doublons (pièces)
@export var butin_doublons_min := 2
@export var butin_doublons_max := 6
@export var butin_bosco_objets := 2           ## le Bosco : 2 objets pour chacun, au moins un Épique
@export var butin_bosco_doublons := 40
@export var butin_coffre_objets := 2          ## le coffre de la salle trésor : 2 objets au moins Rares
@export var butin_coffre_doublons := 25
@export var butin_rayon := 1.1                ## mètres : on ramasse en passant dessus
@export var butin_arme := 0.5                 ## part des objets qui sont des armes (le reste : reliques)
## Poids des raretés : Commun, Rare, Épique, Légendaire, Maudit
@export var butin_poids_raretes: PackedFloat32Array = [62.0, 26.0, 9.0, 2.0, 1.0]
## Malédiction : chaque niveau multiplie ces poids par (1 + valeur × niveau) — raretés meilleures
@export var butin_malediction_raretes: PackedFloat32Array = [0.0, 0.15, 0.3, 0.5, 0.5]

@export_group("Cale (jalon 4, étape 3 : choix de Téo du 03/11)")
@export var cale_places := 8                    ## objets rapportés au plus à la fin d'une expédition (les doublons : sans limite)
## Objets non gardés au tri de la cale : revendus, en doublons selon leur rareté (Commun … Maudit)
@export var cale_prix_raretes: PackedInt32Array = [2, 5, 10, 15, 20]

@export_group("Matériaux (jalon 5 : choix de Téo du 04/11)")
## Chance qu'un squelette vaincu lâche son matériau (pour chaque joueur) : matelot → bois de coque,
## arbalétrier → fer noir, prêtre noyé → essence maudite ; la malédiction grossit les tas (comme les doublons)
@export var mat_chance := {"bois": 0.3, "fer": 0.4, "essence": 0.5}
@export var mat_min := 1
@export var mat_max := 2
@export var mat_bosco := {"bois": 6, "fer": 4, "essence": 3}     ## le Bosco : un peu des trois
@export var mat_coffre := {"bois": 4, "fer": 2, "essence": 1}    ## le coffre de la salle trésor
## Entrepôt : ce qu'il garde au plus (niveau 1, niveau 2) ; au-delà, le surplus est revendu (choix de Téo)
@export var mat_plafonds := {"bois": 150, "fer": 80, "essence": 40}
@export var mat_plafonds_niveau_2 := {"bois": 400, "fer": 200, "essence": 100}
@export var mat_prix_surplus := {"bois": 1, "fer": 2, "essence": 3}   ## doublons par unité revendue

@export_group("Bateau (jalon 5, étape 2 : choix de Téo du 04/11)")
## Ce que donne chaque niveau (1, 2, 3) ; le niveau 0 est la base (cale_places, chaloupe_duree…)
@export var bateau_cale: PackedInt32Array = [10, 12, 15]          ## objets rapportés
@export var bateau_voiles: PackedFloat32Array = [40.0, 35.0, 30.0]  ## secondes à tenir dans la chaloupe
@export var bateau_coque: PackedInt32Array = [2, 3, 4, 5]          ## malédiction de départ la plus haute (niveaux 0 à 3)
@export var bateau_bordee: PackedInt32Array = [0, 1, 2, 3]         ## tirs de bordée par expédition (niveaux 0 à 3)
## Prix de chaque niveau (1, 2, 3) : doublons et matériaux (une quinzaine d'expéditions réussies pour tout)
@export var bateau_prix := {
	"cale": [{"doublons": 60, "bois": 15}, {"doublons": 120, "bois": 30}, {"doublons": 180, "bois": 45, "fer": 5}],
	"voiles": [{"doublons": 60, "bois": 12}, {"doublons": 120, "bois": 25, "essence": 5}, {"doublons": 180, "bois": 35, "essence": 10}],
	"coque": [{"doublons": 80, "bois": 20, "fer": 5}, {"doublons": 150, "bois": 30, "fer": 15}, {"doublons": 220, "bois": 40, "fer": 25, "essence": 10}],
	"bordee": [{"doublons": 70, "fer": 15}, {"doublons": 140, "fer": 25, "essence": 5}, {"doublons": 200, "fer": 35, "essence": 15}],
}
@export_subgroup("Forge et niveaux 2 du repaire (étape 3 : prix proposés à Téo le 04/11)")
## Monter une arme d'une rareté : [Commun → Rare, Rare → Épique]
@export var forge_prix_rarete := [{"doublons": 80, "fer": 10}, {"doublons": 160, "fer": 25, "essence": 5}]
## Recycler : une arme rend du fer noir, une relique de l'essence maudite, selon la rareté (Commun … Maudit)
@export var forge_recyclage_arme: PackedInt32Array = [2, 4, 8, 12, 12]
@export var forge_recyclage_relique: PackedInt32Array = [1, 2, 4, 6, 6]
## Relancer un effet en plus (forge niveau 2) : l'effet choisi est remplacé au hasard par un autre
@export var forge_prix_relance := {"doublons": 40, "essence": 4}
## Agrandir une installation au niveau 2
@export var repaire_prix_niveau_2 := {"forge": {"doublons": 300, "bois": 40, "fer": 20}, "entrepot": {"doublons": 250, "bois": 60}}
@export_subgroup("Bordée (tir du navire, visé au joystick)")
@export var bordee_boulets := 5               ## boulets par tir
@export var bordee_dispersion := 2.0          ## mètres : autour du point visé
@export var bordee_rayon := 1.6               ## mètres : chaque boulet blesse les squelettes à cette distance
@export var bordee_degats := 45.0             ## par boulet ; le Bosco en prend la moitié (choix de Téo)
@export var bordee_mult_bosco := 0.5
@export var bordee_annonce := 0.9             ## secondes de cercle rouge avant l'impact
@export var bordee_ecart := 0.12              ## secondes entre deux boulets
@export var bordee_portee := 10.0             ## mètres : le plus loin qu'on vise depuis le héros
@export var bordee_portee_min := 2.5          ## sans glisser le pouce : la zone devant le héros

@export_group("Équipement (jalon 4, étape 2 : effets validés par Téo le 01/11)")
## Rareté d'un objet de base : son effet de base est multiplié par (Commun, Rare, Épique) ; jamais un défaut
## (la lenteur de la hache reste la même)
@export var equip_mult_raretes: PackedFloat32Array = [1.0, 1.25, 1.5]
## Effets en plus des objets Rares (1) et Épiques (2), tirés au hasard (deux différents)
@export var equip_effets_plus := {
	"degats": 0.08, "pv": 10.0, "critique": 0.06, "vitesse": 0.06, "recharges": 0.08,
	"vol_de_vie": 0.03, "doublons": 0.15, "epines": 0.2,
}
@export var equip_max_recharges := 0.5         ## les recharges ne raccourcissent jamais de plus de moitié
@export var equip_max_vitesse_attaque := 0.5
@export var equip_portee_epines := 3.2         ## mètres : seuls les coups au corps-à-corps sont renvoyés
@export var noyee_intervalle := 0.08           ## Lame du Noyé : une flaque d'eau maudite tous les … pendant la roulade
@export var noyee_rayon := 0.75
@export var noyee_duree := 2.5
@export var noyee_degats_seconde := 16.0       ## aux squelettes qui y restent
@export var pendu_duree := 6.0                 ## Grimoire du Pendu : le squelette relevé reste à vos côtés …
@export var pendu_max := 2                     ## … au plus 2 à la fois
@export var pendu_degats := 14.0
@export var pendu_delai := 0.5                 ## secondes entre l'éclatement et son retour
@export var sablier_rayon := 4.0               ## Sablier de la Marée : squelettes figés autour de vous…
@export var sablier_duree := 1.5               ## … pendant 1,5 s (le Bosco : moitié moins)

@export_group("Orbes de vie")
@export var orbe_chance := 0.3                ## chance qu'un squelette vaincu lâche une orbe (choix de Téo)
@export var orbe_soin := 0.2                  ## part des PV max rendue
@export var orbe_rayon := 0.9                 ## mètres : on la ramasse en passant dessus (si l'on est blessé)
@export var orbe_duree := 25.0                ## secondes avant qu'elle s'efface
