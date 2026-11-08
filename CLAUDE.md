# Les Damnés des Sept Mers — contexte pour Claude

## Le projet
Jeu mobile Android : action-RPG roguelite pirate, 3D isométrique, coopération à 2 joueurs.
Moteur : Godot 4.7.2 (version figée jusqu'à la fin du MVP), GDScript, rendu Mobile.
Aucun serveur au MVP. Le projet Godot du jeu est à la racine du dépôt (`project.godot`).
APK de test toujours au même lien :
https://github.com/teodico-cloud/les-damn-s-des-septs-mers/releases/download/apk-test/damnes-des-sept-mers.apk

- Conception complète (phase A, validée) : `docs/conception.md`
- Avancement, décisions datées et travail en cours : `docs/avancement.md` — à lire en début de session et à tenir à jour.

## Travailler avec Téo
- Téo n'est pas développeur : expliquer simplement, en français, sans jargon inutile.
- Avant chaque implémentation : présenter ce qui va être fait + des propositions annexes utiles.
  Aucune initiative sans son accord. En cas de doute sur ce qu'il veut pour le jeu : lui poser la question.
- Ne jamais annoncer un fichier, un test ou un résultat qui n'existe pas ou n'a pas été exécuté.
- Montrer le visuel par des captures réelles (outil d'aperçu), regardées avant d'être envoyées.
- Fin de jalon : relecture par un agent relecteur (qui n'a pas fait le travail), puis APK.

## Décisions verrouillées
- Un téléphone est l'hôte et décide de tout (dégâts, ennemis, butin). Coop en Wi-Fi local au MVP,
  puis WebRTC + Firebase au jalon 7.
- Sauvegarde locale JSON versionnée, écriture sûre, anti-doublon par identifiant d'expédition.
- Archétypes du MVP : Bretteur et Occultiste. Héros masculins.
- Style : packs KayKit (CC0) retravaillés : proportions élancées, visages durs, palette « pirates maudits »,
  ambiance sombre donnée par l'éclairage (torches, brume, lueurs vertes). Depuis le 06/11 (Téo, sur planche
  d'essai) : direction « façon Diablo IV », moins cartoon — lumière (fait), personnages, textures réalistes.
- Assets : une seule famille (KayKit) pour les formes ; depuis le 06/11 (choix de Téo), des textures réalistes
  Poly Haven (CC0) pour les matières des décors ; crédits dans `assets/CREDITS.md`.

## Arborescence actuelle
- `project.godot`, `export_presets.cfg` (Android arm64, paquet `fr.teodico.damnes`), `icon.svg`.
- `ui/screens/` : écrans (écran titre `demarrage.tscn` = scène principale : « Le repaire », combat d'entraînement,
  « Jouer à deux », vitrine ; « Mode test » : santé infinie, salle de départ, héros Meshy, coffres et ressources de test ;
  `choix_heros.tscn` avant l'arène (et pour l'hôte à deux) ; `coop.tscn` « Jouer à deux » :
  héberger / rejoindre, parties trouvées sur le Wi-Fi, code de secours, lancer l'expédition ou l'arène ;
  `choix_malediction.gd` : le choix du niveau de malédiction, sur l'écran du héros en solo et pour l'hôte).
- `game/vitrine/` : vitrine des héros (jalon 0) : héros, salle, actions au toucher, compteur d'images.
- Combat (jalon 1) :
  - `autoload/event_bus.gd` : signaux globaux (`coup_porte`, `ennemi_vaincu`, `heros_mort`, `heros_reapparu`).
  - `autoload/partie.gd` : état de la partie partagé entre écrans (héros choisi, mode solo / hôte / invité,
    destination arène / expédition, réglages du mode test).
  - `autoload/reseau.gd` (Reseau) : session de coop (ENet, port 34778 ; annonces UDP 34779 ; code = dernier
    nombre de l'adresse de l'hôte). Les messages de l'invité pendant le combat passent par lui. L'équipement
    des héros s'échange à la connexion (`_bonjour` / `_bienvenue` → `equipement_partenaire`).
  - `autoload/sauvegarde.gd` (Sauvegarde, jalon 4 ; version 2 au jalon 5) : JSON versionné, écriture sûre, copie de
    secours, anti-doublon par identifiant d'expédition ; doublons, objets des coffres, équipement (`equipes(heros)`),
    matériaux plafonnés par l'entrepôt (`ressource`, `plafond`, `ranger` : le surplus est revendu), niveaux du bateau
    (`niveau_bateau`) et du repaire (`niveau_repaire`). Une conversion par version, testée (`convertir`).
  - `data/equilibrage.tres` (+ `core/resources/equilibrage.gd`) : **toutes** les valeurs de réglage du combat.
  - `core/components/` : `Sante` (PV, invulnérabilité), `Recharge` (temps de recharge).
  - `game/combat/` : `Combat` (couches de collision, zones de coup, `porter_coup` qui tire aussi les coups
    critiques), `CameraCombat`, `EffetsCombat` (chiffres, arrêts sur image et ralentis, secousse, effets
    de la parade parfaite), `Projectile` (tir de l'Occultiste), `Carreau` (arbalétrier ; renvoyé par la
    Parade), `FlaqueMaudite` (prêtre noyé), `EffetsMagie` (fumée, éclats, cercle au sol, traînée du sabre,
    squelette qui éclate en os, étincelles, explosion ; purement visuels).
  - `game/player/` : `Heros` (base commune : déplacement, visée, recharges, coup reçu, mort), un script
    par archétype (`Bretteur`, `Occultiste` ; `Heros.creer(&"occultiste")`) et `CommandesHeros` (ce que
    le joueur demande : seule entrée du héros, pour que le réseau puisse la remplir plus tard).
  - `game/enemies/` : `Ennemi` (Matelot squelette, et base des autres : points d'extension `_modele`,
    `_arme`, `_orienter_arme`, `_taille`, `coup_parable`, `_montrer_annonce`, `_quitter_etat`, `_incanter`…),
    `Arbaletrier`, `PretreNoye`, `Bosco` (mini-boss : coup au sol parable, tourbillon et charge imparables,
    sonné contre un mur, rage à mi-vie) ; `Ennemi.creer_type(&"arbaletrier")` ; `GenerateurEnnemis` (horde :
    groupes de 2 à 4, les manquants ressortent ensemble ; composition d'une salle ; tombes que le prêtre relève).
  - `game/arene/` : arène d'entraînement (`Arene`), tout construit par code, en étapes que l'expédition
    remplace (lieu, départ, horde) ; orbes de vie ; `regles_coop.gd` (hôte) : réanimation du partenaire,
    retour au départ si les deux tombent (en expédition : défaite).
- Expédition (jalon 3) : `game/expedition/`
  - `expedition.gd` (`Expedition extends Arene`) : salle en cours, portes, coffre, antre du Bosco, chaloupe
    (45 s à tenir à bord, vagues de squelettes), défaite, écran de fin ; l'hôte décide et envoie chaque
    événement à l'invité (`SynchroArene.envoyer_lieu` → `evenement_lieu`).
  - `malediction.gd` (`Malediction`) : niveau 0 à 5 choisi au départ (`Partie.malediction`, envoyé à l'invité
    par `Reseau._lancer`), effets cumulés ; tous les effets passent par ses fonctions (`mult_pv`…).
  - `eau.gdshader` : l'eau du quai, dont la houle grossit pendant le départ de la chaloupe.
  - `plan_expedition.gd` : règles de la suite des salles (graine) ; `salles.gd` : les salles faites main
    (données) ; `salle.gd` : construction d'une salle ; `porte.gd` ; `chaloupe.gd` (barque faite par code).
  - Salles piège : `piege_pics.gd` (`PiegePics`, dalle à pics calée sur l'horloge de la salle,
    `Expedition.temps_salle`) et `tonneau_poudre.gd` (`TonneauPoudre`, explose et blesse les squelettes).
  - `assets/ui/portes/*.svg` : icônes des portes (combat, trésor, piège, Bosco, chaloupe).
- Butin (jalon 4) : `game/butin/`
  - `butin.gd` (`Butin`) : catalogue (armes par héros, reliques, objets uniques), raretés et couleurs, tirage
    (malédiction comprise). Un objet = un petit dictionnaire `{"id", "base", "rarete", "effets"}`.
  - `objet_au_sol.gd` (`ObjetAuSol`) : objet ou doublons au sol (saut, colonne de lumière, nom), à un joueur.
  - Dans `expedition.gd` : `_on_ennemi_vaincu_butin` (hôte : tirage pour chaque joueur), `_lacher`,
    `_ramasser_butin`, `sacs` (nom du héros → objets et doublons ; perdus en cas de défaite).
  - Modèles : `assets/models/armes/` (armes KayKit Adventurers, 4 textures partagées) et `assets/models/decor/`.
  - `equipement.gd` (`Equipement`) : ce que font les objets (`effets`, `bonus`), textes et comparaison ▲▼.
    Le héros les lit par `Heros.b("degats")` (après `Heros.equiper(objets)`) ; `Combat.porter_coup` applique
    dégâts, critiques et vol de vie. Objets uniques : `FlaqueNoyee` (game/combat), `SqueletteAllie`
    (game/enemies, relevé par `Arene._relever_pour_le_pendu`), Sablier dans `Heros.recevoir_coup`.
  - `ui/screens/equipement.tscn` : écran Équipement (ouvert depuis l'entrepôt du repaire ; son retour y ramène).
  - Matériaux (jalon 5) : `Butin.MATIERES` (bois, fer, essence), `MATIERE_ENNEMI` (qui lâche quoi) ; au sol, un tas
    `ObjetAuSol` (`matiere`, `quantite`) ; dans le sac, les clés "bois", "fer", "essence" (`Expedition._sac_vide`).
  - `game/reseau/synchro_arene.gd` (nœud « Synchro » de l'arène) : l'hôte simule tout et envoie 30
    instantanés/s + les événements ; l'invité prédit son héros et affiche le reste en « marionnettes »
    (`marionnette = true` sur Heros et Ennemi : affichés d'après l'hôte, sans règles).
  - `ui/hud/` : `HudCombat`, `JoystickFlottant`, `BoutonAction` (icône du héros + petit nom).
  - `assets/ui/icones/*.svg` : icônes des boutons de compétence (dessinées à la main en SVG ; importées à
    `svg/scale=2.0` pour rester nettes sur téléphone) ; chaque archétype les donne par `icones_boutons()`.
  - `assets/models/enemies/` : squelettes (refaits par `tools/blender/build_squelettes.py`) et armes KayKit ;
    `assets/materials/` : matières partagées.
- Repaire (jalon 5) : `game/repaire/repaire.gd` (`Repaire` : grotte, quai, lieux `LIEUX`, héros au joystick, ouvre les
  lieux ; arrivée selon `Partie.lieu_repaire`) ; `navire.gd` (`Navire`, fait par code) ; `ui/repaire/` : `HudRepaire`
  (joystick, ressources, raccourcis, « Ouvrir »), `PanneauRepaire` (cadre d'un lieu) et ses lieux (`PanneauCartes`,
  `PanneauEntrepot` (et son niveau 2), `PanneauChantier`, `PanneauForge`), `StyleRepaire` (couleurs, boutons).
  L'expédition revient au repaire (`_scene_retour`). `bateau.gd` (`Bateau`) : les 4 améliorations (effets par niveau, prix, ce qui manque, ce qui
  compte en expédition : `ma_cale`, `duree_chaloupe_partie`, `ma_malediction_max`, `tirs_bordee`) ; achat :
  `Sauvegarde.ameliorer_bateau`. Bordée : `HudCombat` (bouton, visée), `Expedition.tirer_bordee`, `game/combat/boulet.gd`.
  `forge.gd` (`Forge`, étape 3) : ce qui est possible et ce que ça coûte (monter une arme d'une rareté, recycler, relancer
  un effet, agrandir la forge ou l'entrepôt) ; les achats eux-mêmes : `Sauvegarde.ameliorer_objet`, `recycler`,
  `relancer_effet`, `agrandir` (journal `achats`).
- Interface (refonte du 05/11) : `assets/ui/theme_damnes.tres` (thème du projet, `gui/theme/custom`) fabriqué par
  `tools/ui/fabriquer_theme.gd` ; matières `assets/ui/matieres/*.png` fabriquées par `tools/ui/matieres.py textures`
  (et `planches` : planches de direction artistique) ; polices `assets/ui/polices/` (OFL) ; `ui/commun/effets_ui.gd`
  (`EffetsUI` : bouton qui s'enfonce, arrivées, fondus) ; `ui/screens/decor_menu.gd` (`DecorMenu` : navire au ponton,
  fond de l'écran titre et de « Jouer à deux ») ; `StyleRepaire` : l'encre sur parchemin (`encre()`, `texte()`,
  `titre()`, `cadre()`, `separateur()`).
- Lumière façon Diablo IV (06/11) : `game/commun/ambiance.gd` (`Ambiance` : environnement, lune, torches ; partagé
  par l'arène, les salles et le repaire), `game/player/halo_heros.gd` (`HaloHeros` : la lumière qui suit chaque héros),
  bords sombres (`EffetsUI.vignette` dans les HUD). Planche d'essai du style : `tools/capture_style.gd`.
  Personnages refaits dans Blender (06/11, « variante 3 + usure ») : héros par `tools/blender/build_heroes.py`,
  squelettes par `tools/blender/build_squelettes.py` (sortie dans `assets/models/enemies/`, mêmes noms, mêmes
  animations ; la matière reste `kaykit_squelette.tres` par le `.import`).
  Matières réalistes : `game/commun/matieres.gd` (`Matieres.habiller(decor, nom)` d'après le nom KayKit : sols en
  pavés, murs en pierre, bois et métal en « grain » sur la palette KayKit) et `matiere_monde.gdshader` (texture posée en
  mètres du monde, un tirage par carte) ; textures `assets/textures/polyhaven/` (préparées par `tools/style_textures.py`).
- Réglages (jalon 6) : `autoload/reglages.gd` (Reglages) : qualité graphique économie / normale / belle, rangée dans
  `user://reglages.json` (à part de la sauvegarde) ; appliquée à l'image (finesse, bords lissés, ombres douces) et à
  chaque lumière ou environnement qui entre en scène (ce que la scène voulait est gardé en méta `ombre_voulue` /
  `halo_voulu`). Écran `ui/commun/panneau_reglages.gd` (PanneauReglages, un PanneauRepaire plus petit), ouvert depuis
  l'écran titre et depuis le carnet de bord du repaire (`ui/repaire/carnet.gd` : Menu → Reprendre / Réglages / Écran titre).
  Volumes Général / Effets / Ambiances (0 à 1) dans le même fichier ; curseurs dans l'écran Réglages.
- Sons (jalon 6, 06/11) : `autoload/sons.gd` (Sons) : `jouer(nom, position|nœud|null)`, `jouer_plus_tard`,
  `ambiance([couches])`, `niveau_ambiance`, `jingle(nom)` ; catalogue des sons (fichiers, volume, variation, maximum
  en 0,07 s) en tête du fichier ; canaux « Effets » et « Ambiances » créés au démarrage. Fichiers : `assets/sons/fabriques/`
  (faits par `tools/sons/fabriquer_sons.py`) et `assets/sons/kenney/` (CC0, copiés par le même script depuis
  `third_party/sons/`, téléchargés par `tools/sons/telecharger_kenney.sh`). Les gestes sonnent par
  `sons_animation(nom, vitesse)` (Heros, Bretteur, Occultiste, Ennemi, Bosco), les chocs par `EventBus.coup_porte`.
- Jauge façon Diablo (06/11) : `Heros.jauge` (Fureur, Âmes), `cout_jauge(action)`, `jauge_coups(touches)`,
  `gagner_jauge`, `depenser_jauge`, `definir_jauge` (invité) ; réglages « Jauge façon Diablo » dans l'équilibrage ;
  globe `ui/hud/globe_jauge.gd` (`GlobeJauge`, `globe.gdshader`) ; captures `tools/capture_jauge.gd -- <dossier>`.
- Brume au ras du sol et poussière dans la lumière (06/11) : `Ambiance.brume(taille, centre)` (`game/commun/brume.gdshader`,
  groupe `brume`), `Ambiance.poussiere(...)` / `poussiere_torche(lumiere)` (groupe `poussiere`) ; réduites en Économie
  par Reglages. Captures : `tools/capture_brume.gd -- <dossier>`.
- `tests/unit/` : tests GUT (`test_*.gd`) ; `addons/gut/` : GUT 9.7.1 (exclu de l'APK) ; `tests/pre_run.gd` :
  avant les tests, la sauvegarde passe dans `user://sauvegarde_tests.json` (jamais celle du jeu).
  `test_scripts.gd` charge tous les scripts du jeu (remplace `--check-only`, voir pièges).
- `android/cle_de_test.keystore` : clé de signature **de test** (mot de passe « android »), commune à
  tous les APK pour que les mises à jour s'installent. Jamais pour le Play Store.
- `.github/workflows/apk.yml` : à chaque envoi sur main, tests puis APK publié sur la release `apk-test` ;
  le numéro de version prend le numéro de fabrication (`0.<jalon>.<n°>`).
- `assets/models/decor/` : décors KayKit Dungeon (CC0), copiés tels quels.
- `assets/models/heroes/` : héros exportés (.glb, 76 animations chacun). Ne pas les modifier à la main :
  ils sont fabriqués par `tools/blender/build_heroes.py`.
- `assets/models/heroes_meshy/` (07/11, à l'essai) : les héros faits par Téo sur Meshy, posés sur la même ossature et
  les mêmes animations par `tools/blender/build_heroes_meshy.py <bretteur|occultiste> <meshy.glb> <héros_actuel.glb>` ;
  en jeu seulement si le Mode test le demande (`Partie.debug_heros_meshy`, `Heros.MODELES_MESHY` / `modele_meshy`).
  Le sabre du Bretteur Meshy est aussi fait sur Meshy : `HEROS_MESHY_ARME=<sabre.glb>` (réglages `ARMES_MESHY`).
- `tools/blender/` : fabrication des modèles dans Blender (en script) : héros (`build_heroes.py`) et squelettes
  (`build_squelettes.py`).
- `tools/preview/` : petit projet Godot qui rend des captures d'aperçu ; exemples dans `tools/preview/exemples/`.
- `tools/fetch_kaykit.sh` : télécharge les packs KayKit dans `third_party/` (ignoré par git) ;
  `tools/sons/telecharger_kenney.sh` : les packs de sons Kenney dans `third_party/sons/`.
- `build/` : fichiers générés (textures, aperçus), ignoré par git.

## Commandes
- Importer le projet : `godot --headless --path . --import`
- Tests : `godot --headless --path . -s addons/gut/gut_cmdln.gd` (réglages dans `.gutconfig.json` ;
  code de sortie ≠ 0 si un test échoue, MAIS un fichier de test qui ne se charge pas est ignoré en silence :
  vérifier qu'aucune ligne « Ignoring script » / « Parse Error » n'apparaît — le CI le fait)
- Vérifier qu'un script se charge : lancer les tests (`test_scripts.gd` charge tous les scripts du jeu).
- Refaire les sons : `tools/sons/telecharger_kenney.sh` puis `python3 tools/sons/fabriquer_sons.py` (numpy, scipy,
  soundfile), puis `--import`. On ne peut pas écouter ici : vérifier crêtes, durées et spectres (images) ; Téo juge.
- Capture d'une scène du jeu (sans téléphone) :
  `xvfb-run -a godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 1280x720 -s "$PWD/tools/capture_scene.gd" -- res://game/vitrine/vitrine.tscn build/apercus/vitrine.png [nb_actions] [nb_images]`
- Captures mises en scène du combat (annonce, coup, fente) + état du combat dans la console :
  `xvfb-run -a godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 1280x720 -s "$PWD/tools/capture_combat.gd" -- build/apercus`
  (même chose pour l'Occultiste : `tools/capture_occultiste.gd` ; écran « Jouer à deux » : `tools/capture_coop_ecrans.gd` ;
  horde, coup critique, os qui volent et traînées du sabre : `tools/capture_horde.gd` ; zone rouge puis
  dorée et parade parfaite : `tools/capture_parade.gd` ; expédition (titre, salles, portes, trésor,
  chaloupe, fin) : `tools/capture_expedition.gd` ; chaque salle seule, vue de jeu et de dessus :
  `tools/capture_salles.gd [modèle]` ; squelettes sur fond neutre, arbalétrier, carreau renvoyé, prêtre,
  flaque, salles piège, explosion : `tools/capture_ennemis.gd` ; Bosco (portrait, annonces, charge, sonné,
  rage), choix de la malédiction, chaloupe sous les vagues, écran de fin : `tools/capture_bosco.gd` ;
  attaque façon Diablo (bond, moulinet, tir qui explose, charges de la téléportation) : `tools/capture_attaque.gd` ;
  butin (vitrine du catalogue, au sol, ramassage, trésor du Bosco, fins) : `tools/capture_butin.gd`,
  `SEULEMENT_VITRINE=1` pour la vitrine seule ; armes en main, écran Équipement, objets uniques en jeu :
  `tools/capture_equipement.gd -- <dossier> [armes|ecran|uniques|cale|double]` ; repaire (vues de jeu, de dessus,
  panneaux) et matériaux (au sol, sac, fin, gros plan), chantier naval et navire, bordée, forge et entrepôt niveau 2 :
  `tools/capture_repaire.gd -- <dossier> [vues|dessus|panneaux|matieres|chantier|bordee|forge]` ; écran titre,
  Réglages, carnet de bord et repaire dans les trois qualités : `tools/capture_reglages.gd -- <dossier>`)
- Où pointe l'arme d'un squelette dans chaque pose : `godot --headless --path . -s "$PWD/tools/sonde_arme.gd"`
  (sans argument : l'arbalétrier ; sinon `-- <modèle.glb> <arme.gltf> <axe x|y|z> [animations…]`)
- Essai de la coop (hôte + invité sur cette machine, vérifications automatiques, aussi dans le CI) :
  `GODOT=<godot> tools/test_coop.sh [127.0.0.1|auto]` ; Wi-Fi imparfait simulé : préfixer
  `LATENCE_MS=30 GIGUE_MS=20 PERTE_PCT=3` ; captures des deux écrans : ajouter
  `CAPTURE_DIR=$PWD/build/apercus AFFICHAGE="xvfb-run -a" OPTIONS_RENDU="--rendering-method gl_compatibility --rendering-driver opengl3 --resolution 1280x720"`
  (avec le rendu, le jeu tourne ici plus lentement que le temps réel : distances plus courtes, c'est normal) ;
  l'expédition à deux : préfixer `DESTINATION=expedition` ; la jauge de l'invité : `SCENARIO=jauge`
- Suivre la fabrication de l'APK : `gh api repos/teodico-cloud/les-damn-s-des-septs-mers/actions/runs`
- Diagnostics d'une fabrication (les journaux bruts ne sont pas lisibles d'ici, le workflow écrit ses
  diagnostics en annotations) : `gh api repos/teodico-cloud/les-damn-s-des-septs-mers/check-runs/<id du job>/annotations`
- Préparer les packs : `tools/fetch_kaykit.sh`
- Blender en module Python : `pip install bpy` (testé avec bpy 5.2.2 LTS, Python 3.13)
- Refabriquer les héros : `python tools/blender/build_heroes.py all` (ou `bretteur`, `occultiste`)
- Aperçu : `GODOT=<chemin de Godot 4.7.2> tools/preview/render.sh tools/preview/exemples/heros_trois_angles.json 1600x700`
  (nécessite xvfb-run ; image dans `build/apercus/`)
- Godot 4.7.2 Linux : https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip

## Pièges connus
- Fabrication de l'APK : une fabrication en cours n'est jamais annulée ; seule la plus récente des
  fabrications en attente est gardée. Une modification de `*.md` ou `docs/` seule ne relance rien.
  **Ne jamais renommer `apk.yml`** : le numéro de version Android (= numéro de fabrication) repartirait
  à 1 et le téléphone de Téo refuserait la mise à jour. Ne pas relancer une ancienne fabrication.
- Workflow en `shell: bash` (pipefail) : ne jamais faire `commande | head` dans une étape — la coupure
  de `head` fait échouer la commande. Écrire la sortie dans un fichier, puis l'afficher.
- `tools/` contient un `.gdignore` versionné ; `third_party/` et `build/` en reçoivent un créé par
  `fetch_kaykit.sh` / `render.sh`. Sans lui, Godot importerait des milliers d'assets KayKit.
  Tout nouveau dossier d'outils doit avoir son `.gdignore`.
- Textures des modèles : toujours `compress/mode=2` (VRAM, ETC2/ASTC sur téléphone) dans le `.import`
  — l'import en ligne de commande ne détecte pas l'usage 3D et laisse la texture non compressée.
- Les assets KayKit d'un même pack partagent une seule texture : dans le `.import` du .glb, mettre
  `gltf/embedded_image_handling=0` et rediriger la matière vers `assets/materials/*.tres`
  (`_subresources`), comme pour les décors (`kaykit_dungeon.tres`). Sinon chaque modèle charge sa copie.
- Les textures des héros sont extraites à l'import en .png à côté du .glb (ex. `Bretteur_bretteur_corps.png`) :
  ces fichiers et les `.import`/`.uid` se commitent.
- L'export Android est impossible dans l'espace de travail de Claude (SDK Android non téléchargeable) :
  il se fait uniquement sur GitHub.
- Les animations KayKit importées ne bouclent pas : mettre `loop_mode = LOOP_LINEAR` sur « Idle » (et la
  course) avant de les jouer en continu.
- `--check-only` et les scripts lancés par `-s` (outils `extends SceneTree`) ne connaissent pas les
  services globaux (EventBus) : un script qui en dépend y « échoue » alors qu'il marche dans le jeu.
  Dans ces outils, ne pas typer avec les classes du jeu ; charger par `load("res://...gd")`.
- Placer un combattant **avant** `add_child` (`e.position = …` puis `add_child(e)`) : ajouté puis déplacé,
  il apparaît un instant à l'origine et peut soulever ou décaler un personnage qui s'y trouve.
- Les ennemis n'ont pas la couche des héros dans leur masque de collision (sinon une roulade ou une
  fente pousse l'ennemi au lieu de le traverser).
- Ressource lue par `const EQ = preload(...)` : la modifier à l'exécution (par une autre variable) n'est
  pas vue par les scripts qui la lisent par leur constante (constaté en 4.7.2). Les tests utilisent donc
  les vraies valeurs de `equilibrage.tres` ; un futur menu de réglage en jeu devra passer par une variable.
- Tests du combat : 60 images de physique = 1 s de jeu ; les dégâts arrivent à l'instant d'impact de
  l'animation (pas à l'appui). Un coup peut être perdu si le héros est « touché » (0,4 s) plus longtemps
  que le tampon des commandes (0,25 s) : c'est voulu.
- Une minuterie (`create_timer`) créée pendant l'image de physique se déclenche **une image en avance**
  (elle est déjà décomptée dans la même boucle). Ne jamais vérifier « l'heure réelle est-elle passée ? »
  à son déclenchement : l'arrêt sur image est resté bloqué à 5 % de vitesse à cause de ça. Compter les
  arrêts en cours à la place (`EffetsCombat`).
- Tout ce qui compte une durée de jeu (invulnérabilité, recharges, états) utilise le **temps de jeu**
  (delta de physique), jamais `Time.get_ticks_msec()` : sinon l'arrêt sur image raccourcit l'esquive.
  `Sante` a sa propre horloge de jeu (priorité de physique -10 pour avancer avant les combattants).
- GUT 9.7.1 : `wait_physics_frames(1)` laisse passer **2** images de physique (n + 1). Pour une durée
  de jeu précise dans une boucle, mesurer avec `heros.horloge` plutôt que compter les attentes.
- Ajouter un archétype : un script `extends Heros` (voir `occultiste.gd`) qui crée ses 3 recharges
  dans `_init()` (l'interface les lit avant `_ready`), puis l'ajouter à `Heros.ARCHETYPES`.
- En mode test sans écran, les images de physique ne suivent pas le temps réel (9 images en 45 ms ou
  en 170 ms selon `time_scale`) : un test qui mêle temps réel et images de physique ne prouve rien.
- Animations : ne pas appeler `anim.stop()` avant `play(nom, fondu)` : le fondu partirait de rien et la
  pose sauterait d'un coup (mesuré : jambe de 31° à 1° en une image). Pour reprendre la même
  animation au début : `play()` puis `seek(0, true)` (voir `_jouer`).
- Coups critiques : tirés au hasard dans `Combat.porter_coup`. Un test qui compte des PV doit mettre
  `Combat.chance_critique = 0.0` (dans `before_all`) et le remettre à `-1.0` (dans `after_all`).
- Squelette vaincu : il n'a plus d'animation de mort, il éclate en os (`Ennemi._eclater`, corps physiques
  posés sur l'arène, pas sous le générateur) et son nœud disparaît après `squelette_duree_corps`.
  La marionnette de l'invité éclate aussi en recevant l'état MORT.
- Coop : les animations voyagent par numéro (`code_anim` / `nom_anim`, place dans la liste du modèle) ;
  chaque squelette est emballé en nombres à virgule simple (`SynchroArene._emballer` / `_deballer`),
  un vaincu en format court avec son tueur ; les héros aussi (`_emballer_heros` / `_deballer_heros`, depuis la
  relecture du jalon 6). Un instantané doit tenir sous 1 392 octets (un paquet Wi-Fi ; au-delà, un morceau perdu
  perd tout) : `test_instantane_tient_dans_un_paquet_wifi` et `test_instantane_du_quai_tient_dans_un_paquet_wifi`
  le vérifient avec des valeurs **non rondes** (`test_coop._valeurs_de_jeu` : un nombre comme 37,3 prend 8 octets
  au lieu de 4 ; avec des valeurs rondes, le quai débordait sans que le test le voie). Toute nouvelle valeur dans
  `Ennemi.instantane()` ou `Heros.instantane()` passe aussi par l'emballage, et augmente `VERSION_RESEAU`.
- Captures d'un effet très court (traînée de 0,2 s) : le rendu sans carte graphique est lent, l'effet a
  parfois disparu avant la capture. Ralentir (`Engine.time_scale = 0.1`) le temps de la capture.
- Sur le sol clair de l'arène, un effet en mélange additif vire au blanc éblouissant : préférer le
  mélange normal avec une couleur franche (voir la traînée du sabre).
- Annonce des squelettes : la zone est remplie et colorée (`_preparer_visuel`) dès qu'elle s'affiche,
  chez l'hôte comme chez l'invité ; sinon elle garde un instant l'aspect de l'annonce d'avant (pleine
  et dorée : le signal « pare maintenant » en faux, vu par le relecteur).
- Parade parfaite (`Bretteur._intercepter_coup`) : décidée par l'hôte, annoncée par
  `EventBus.parade_parfaite`. Chez l'invité, elle est montrée même pour son propre héros (exception à
  « notre propre sort : déjà affiché » dans `SynchroArene._effet_recu`) et lui rend sa Parade.
- Ralentis (`EffetsCombat.ralentir`) : une liste des ralentis en cours, le plus lent l'emporte. Ne pas
  remettre `Engine.time_scale` à 1 ailleurs pendant un combat. En coop, jamais de ralenti ; la parade
  parfaite n'y fige rien non plus (figer le héros décalait sa riposte de l'impact).
- Capture d'un effet qui ralentit lui-même le jeu (parade parfaite) : `Engine.time_scale = 0.1` ne sert
  à rien (le ralenti finit en temps réel) ; capturer à la toute première image après l'effet.
- GUT : le 4e argument de `assert_signal_emitted_with_parameters` est le numéro de l'émission, pas un
  message (un texte y provoque une erreur) ; vérifier avec `get_signal_parameters` à la place.
- Expédition : toutes les salles ont la même taille et les mêmes emplacements (entrée en bas à droite,
  portes au fond en x = 1,6 et à gauche en z = -1,6). Vérifier un nouveau modèle de salle avec
  `tools/capture_salles.gd` (vue de dessus) : passage libre de l'entrée aux deux portes, apparitions
  loin de l'entrée (test). Les dalles « small » font 1,6 m : elles laissent des trous sur la grille de 3,2 m.
- Expédition, coop : un message du lieu peut arriver pendant le fondu au noir de l'invité ; il porte le
  n° de salle et s'applique quand cette salle est construite (`_portes_ouvertes_pour`…). Changement de
  salle : l'invité oublie ses prédictions (`SynchroArene.oublier_predictions`) et les marionnettes qui
  sautent de plus de 3 m sont posées sans glisser (`SAUT_TELEPORTATION`).
- Ajouter un type d'ennemi : un script `extends Ennemi` (voir `arbaletrier.gd`), l'ajouter à
  `Ennemi.creer_type` et à `Ennemi.PREFIXES` (le préfixe du nom permet à l'invité de recréer le bon type).
- Armes KayKit : l'arbalète est tenue en travers du corps ; dans la pose de visée elle pointait à 90° sur
  le côté. `Arbaletrier._orienter_arme` la tourne d'un quart de tour ; vérifier toute nouvelle arme avec
  `tools/sonde_arme.gd` et les portraits de `capture_ennemis.gd` (la hache du Bosco va sans correction).
- Nouvelle classe (`class_name`) : relancer `godot --headless --path . --import` avant les tests, sinon
  « Identifier not declared » partout (le registre des classes n'est mis à jour que par l'import).
- Squelette agrandi (Bosco, `_taille()`) : le modèle et la collision suivent ; `EffetsMagie.eclater` met
  l'échelle sur l'image des os, jamais sur le corps physique (la physique refuse un corps mis à l'échelle).
- Bosco : il ne recule pas et n'est pas interrompu (`recevoir_coup` à lui) ; étourdissements et chaînes
  ×0,5 ; son masque de collision n'a que le monde (sa charge traverse son équipage). Sa rage ne part que
  depuis la poursuite : frappé à mi-vie pendant qu'il est sonné, il enrage juste après.
- Bosco en coop : l'attaque choisie part par `EventBus.effet_visuel` (« bosco_coup / tourbillon / charge »,
  avec le bout de la charge), la rage par « bosco_rage » ; `Bosco.effet_recu` redessine la zone chez
  l'invité. Ses PV max se calculent pareil des deux côtés (coop et malédiction connues des deux).
- `Ennemi._changer` laisse l'annonce visible en FRAPPE (la zone du matelot dure pendant son coup) : un
  ennemi dont l'annonce doit disparaître au tir la cache lui-même (trait de l'arbalétrier).
- Carreau : un héros intouchable le laisse passer **avant** toute parade. Pour mettre en scène un renvoi
  (capture, test), remettre `sante.invulnerable_jusqua = 0.0` et préférer la santé infinie.
- Tonneau de poudre : sur la couche des ennemis (pour être touché) mais pas dans le groupe « ennemis »
  (la visée assistée et les règles des squelettes l'ignorent).
- Capture hors d'une salle (« studio ») : un sol `StaticBody3D` est obligatoire, sinon les squelettes
  tombent sans fin (pesanteur) et l'image est vide.
- Tirages au hasard (composition d'une salle, plan) : un test qui les vérifie répète le tirage plusieurs
  fois, sinon un défaut peut passer par chance.
- Riposte : elle atteint l'ennemi paré jusqu'à `Ennemi.portee_riposte()` (3 m, Bosco ~5,6 m). Un ennemi qui
  frappe de loin doit l'augmenter, sinon la parade réussit mais la riposte frappe dans le vide.
- « Salle vidée » ne part qu'une fois par salle (`GenerateurEnnemis._videe`).
- Coups « discrets » (dégâts qui durent, épines, coups d'un squelette relevé) : `Combat.porter_coup_discret`
  (ou `Combat.coup_discret = true` autour de l'appel) ; EffetsCombat n'en fait ni arrêt sur image ni secousse,
  et l'invité le sait par l'argument `discret` de `SynchroArene._coup`. Tout nouveau dégât répété doit l'être.
- Retour d'Android (`NOTIFICATION_WM_GO_BACK_REQUEST`) : passe par `Arene._retour_demande()` (l'expédition le
  remplace : deux appuis comme le Menu). `_notification` est appelé par Godot pour **chaque** classe de la
  chaîne (Arene puis Expedition) : ne jamais y appeler `super`.
- Tests d'une arène / expédition : `changer_de_scene = false` évite que `retour_menu()` change de scène sous GUT
  (`revenu_au_menu` dit s'il a été demandé).
- Appli en pause pendant une expédition à deux : l'hôte ne l'entend plus au bout de 3 à 5 s ; une coupure
  constatée pendant ou juste après une pause est un abandon (`Expedition._coupure_pendant_une_pause`).
- Squelettes qui sortent de terre : jamais l'un dans l'autre (`GenerateurEnnemis._ecarter`, 1 m au moins) ;
  deux corps qui se chevauchent se repoussent d'un coup quand leur collision s'active (saut de 0,5 m en une
  image, vu par l'essai coop « affichage fluide »). Une nouvelle façon de faire apparaître des squelettes en
  groupe doit passer par `_ecarter`.
- Butin : tiré à chaque `EventBus.ennemi_vaincu` (hôte ou seul). À deux, celui de l'invité existe aussi chez
  l'hôte, **invisible** (l'hôte décide du ramassage) ; l'invité reçoit le sien par `envoyer_lieu("butin")`.
  Un objet ne se ramasse qu'une fois retombé (`ObjetAuSol.pose`) : dans un test, le mettre à `true` plutôt
  que d'attendre en temps réel. Les noms des joueurs (`HerosHote` / `HerosInvite`) servent de clés aux sacs.
- Équipement : `Heros.equiper()` avant `add_child` (ou après : PV max et arme suivent). Un nouvel effet passe
  par `Equipement` (texte, ordre) et se lit par `b()` ; une règle qui en dépend tourne chez l'hôte seulement.
- Squelette relevé (Grimoire du Pendu) : dans le générateur (l'invité le recrée par son nom « Allie_ »), mais
  ni dans le groupe « ennemis », ni compté par `vivants()`, sans collision (`_couche_vivant`) ; il retombe
  sans émettre `ennemi_vaincu` (pas de butin). Toute boucle sur les enfants du générateur doit penser à `allie`.
- Sauvegarde : ne pas lire un JSON avec `JSON.parse_string` (un fichier abîmé affiche une erreur que GUT
  compte comme un échec) ; utiliser `JSON.new().parse()` (voir `Sauvegarde._lire`). L'essai coop donne à
  chaque côté sa propre sauvegarde (`sauvegarde_coop_hote/invite.json`).
- Tirages du butin : un test de rareté ou de chance répète le tirage (des centaines de fois, graine fixée),
  sinon un sabotage (minimum oublié…) passe par chance.
- Au changement de salle, os, flaques et carreaux de la salle d'avant sont retirés (`_construire_salle`) :
  tout effet posé sous l'expédition (et non sous la salle) doit y être ajouté.
- Chaloupe : une vague attend tant que `chaloupe_max_debout` squelettes sont debout, pour que l'instantané
  tienne dans un paquet Wi-Fi (test `test_instantane_du_quai_tient_dans_un_paquet_wifi`).
- Messages du centre de l'écran en expédition : `Expedition._message` (hôte et invité), pas `hud.afficher_message`.
- Malédiction dans les tests : `Partie.destination = &"expedition"` est nécessaire (hors expédition, le niveau
  vaut 0) ; remettre `Partie.destination = &"arene"` et `Partie.malediction = 0` après chaque test.
- Chaloupe : `Expedition._verifier_chaloupe(delta)` fait avancer le compte (les tests lui passent un grand
  `delta` plutôt que d'attendre 45 s) ; l'invité reçoit le compte dans l'instantané (« @chaloupe »).
- Captures d'une annonce qui se remplit : le rendu est si lent que l'annonce est finie avant d'être
  dessinée ; mettre `Engine.time_scale = 0.05` juste avant la capture (voir `capture_bosco.gd`).
- Expédition, tests : `Arene.chance_orbe` impose la chance d'orbe (0 dans les tests qui comptent les PV) ;
  le Menu de l'expédition se confirme (2 appuis) ; un test qui appuie sur Menu doit débrancher
  `retour_menu` (sinon GUT changerait de scène).
- Recul des squelettes : la valeur de `equilibrage.tres` est une distance en mètres ; la vitesse de départ
  est `sqrt(2 × freinage × distance)`.
- Coop : un message envoyé à un nœud que l'autre téléphone n'a pas encore (arène pas encore ouverte)
  est perdu ET casse le cache des chemins de Godot (erreurs « Node not found » en rafale). L'invité
  passe donc par l'autoload `Reseau` (présent partout dès le démarrage) et n'envoie rien d'autre que
  « prêt » avant le premier instantané de l'hôte ; l'hôte n'envoie rien avant ce « prêt ».
- Coop, recalage de l'invité : après une correction, corriger aussi l'historique **à partir du même
  n°** d'entrée (`>= ack`), sinon un instantané suivant portant le même n° refait la correction et le
  héros dérive sans fin (vu : 322 km quand le jeu ralentit).
- Coop : chez l'invité, `Combat.porter_coup` ne fait rien (l'hôte décide de tous les coups). Une règle
  de jeu ne doit jamais tourner sur une marionnette (Heros/Ennemi `marionnette = true`).
- Coop : tout nouvel état visible (marque, chaînes, invisible…) doit passer dans `instantane()` et
  `appliquer_instantane()` des deux côtés, sinon l'invité ne le voit pas. Un effet ponctuel (cercle des
  Chaînes…) passe par `EventBus.effet_visuel`.
- Coop : ne jamais envoyer `anim.get_playing_speed()` : l'arrêt sur image local la met à 0 chez l'hôte
  et l'invité figerait l'animation pour toujours. Envoyer la vitesse demandée (`_vitesse_anim`) et le
  temps passé dans l'état (`_t`), que l'invité avance de l'âge de l'instantané.
- Coop : version et « partie complète » se vérifient au premier contact (`SceneMultiplayer.auth_callback`),
  jamais par un message du jeu : deux versions aux messages différents ne peuvent pas s'en échanger.
  Augmenter `Reseau.VERSION_RESEAU` à chaque changement des messages réseau.
- Essai coop : avant de mettre un héros à terre, remettre `sante.invulnerable_jusqua = 0.0` (un squelette
  a pu le toucher juste avant) — sinon l'essai échoue au hasard.
- Aperçus (rendu Compatibility) : l'erreur « Dual paraboloid shadow mode not supported » est normale
  (ombre de torche) ; sur téléphone (rendu Mobile) ce mode marche.
- Blender en script : ne jamais nommer un fichier comme un module Python standard (`inspect.py`…) :
  Blender plante au démarrage.
- `build_heroes.py` (06/11) : `HEROS_PROPS` / `HEROS_SORTIE` pour essayer des proportions sans toucher au jeu ;
  l'usure (couleurs ternies, ombres des creux en couleur de sommets) est faite à l'export (`HEROS_USURE=0` l'enlève).
  Après une refabrication, Godot **ne réécrit pas** les textures extraites à côté du .glb : supprimer les `*.png` et
  leurs `.import` (garder une copie des `.import`), importer, remettre les `.import` (compression `compress/mode=2`),
  vider `.godot/imported/<Héros>*`, importer encore. Une matière et son image portent souvent le même nom.
- Héros Meshy : leur liste d'animations doit rester **la même, dans le même ordre**, que celle des héros KayKit (en coop
  les animations voyagent par numéro, et l'autre téléphone peut avoir l'autre modèle) : `test_heros_meshy.gd` le vérifie.
  Refaire un héros Meshy : relancer `build_heroes_meshy.py` (le héros actuel du jeu sert de base : `git show
  HEAD:assets/models/heroes/<Héros>.glb`), puis la marche à suivre des textures extraites de `build_heroes.py` ;
  textures en `compress/mode=2`, reliefs en `compress/normal_map=1`. Les fichiers Meshy d'origine (trop lourds) ne sont
  pas dans le dépôt : les redemander à Téo.
- Armes Meshy : en acier tout métallique, une lame ne renvoie que le reflet de la salle, presque noir chez nous (vu :
  lame invisible en jeu, alors qu'elle se voyait dans Blender sur fond clair). Baisser le métal et éclaircir l'acier
  (`metal`, `eclat` de `ARMES_MESHY`) et vérifier **en jeu** (`tools/capture_meshy.gd`), pas seulement dans Blender.
- `build_heroes.py` : tout ce qui touche la tête est multiplié par `HEAD_K`. Ne jamais réutiliser `k`
  comme variable de boucle (un tel bug a multiplié les cheveux par 12).
- `bpy.ops.wm.read_factory_settings` efface les matériaux : les créer après (`init_mats()`).
- Capes rigides (attachées à l'os chest) : leur bas doit rester à ~0,35 du sol en pose de repos,
  sinon elles traversent le sol quand le personnage se baisse.
- Les objets attachés à un os (chapeau, armes) sont placés en coordonnées monde de la pose de repos
  (`parent_world_rest`) ou dans le repère d'arme KayKit (`WEAPON_R`) ; la lanterne est orientée
  d'après la pose « Idle ».
- Visages KayKit : chaque œil est un îlot sombre d'environ 66 faces (case c2r0) ; certaines têtes (Mage)
  ont en plus de petits îlots de cils recourbés. Repérer les yeux comme les **deux plus gros** îlots,
  jamais comme les deux plus hauts. Le menton = sommet de peau le plus bas sur l'axe du visage.
- Couleurs KayKit : chaque texture est une grille de cases 8 × 4 (128 × 256 px). Recolorer une case
  change toutes les parties qui l'utilisent ; baisser le contraste de la peau évite les reflets blancs.
- Rendus d'aperçu : sans carte graphique, ils utilisent le rendu Compatibility ; sur téléphone
  (rendu Mobile) l'image est un peu plus fine.
- Control déjà dans l'arbre (dans son `_ready`) : `set_anchors_preset(FULL_RECT)` garde sa taille actuelle (nulle) ;
  utiliser `set_anchors_and_offsets_preset` (vu : panneau du repaire réduit à son titre). Avant `add_child`, les deux
  marchent.
- Nouveaux décors KayKit : copier le `.gltf.glb`, importer, puis mettre `embedded_image_handling=0` et la matière
  partagée dans le `.import`, réimporter et **supprimer** les `*_dungeon_texture.png` extraits au premier import.
- Repaire : tout nouveau lieu s'ajoute à `Repaire.LIEUX` / `ORDRE_LIEUX` (enseigne, raccourci et bouton « Ouvrir »
  suivent) et à `Repaire.ouvrir` ; ce qui mérite une pastille « ! » à `Repaire.lieux_a_signaler`.
- Forge : les tirages au hasard (effet en plus, relance) passent par `Sauvegarde.rng` (un test fixe sa graine). Chaque
  achat vérifie l'état vu par le bouton (rareté, niveau, effet encore présent). Les panneaux ne gardent jamais un objet
  en mémoire : ils relisent la sauvegarde à chaque `rafraichir()`.
- Combo du Bretteur (façon Diablo, 05/11) : la vitesse du coup n est `_vitesse_coup(n)` (le moulinet, 3e coup, va
  `combo_vitesse_moulinet` fois plus vite) et sa fin `combo_fin_geste` (le moulinet s'arrête à 1,71 s : la suite de
  l'animation est immobile). Un test qui attend l'impact du coup n utilise `_vitesse_coup(n)`. Chaque coup bondit sur
  `cible_visee()` si elle est à `combo_aimant_portee` ou moins : un test qui veut un coup sur place met le squelette
  plus loin ; ce que touche un coup : `Bretteur.cibles_du_coup(n)`.
- Recharge à charges (`Recharge.new(duree, n)`, téléportation) : `prete()` = il reste une charge ; mettre `restant = 0`
  ne rend une charge qu'à une recharge simple (Parade rendue). La pastille du bouton suit seule les charges.
- Tir de l'Occultiste : sa cible est choisie au départ par `Projectile.cible_devant` (chez l'invité aussi, pour l'image :
  même règle, aucun message) ; l'explosion passe par `porter_coup_discret` (pas d'arrêt sur image par voisin) ;
  la jauge compte la cible et chaque voisin touché en un seul `jauge_coups(touches)` (plafond du geste).
- Interface : ne pas régler couleurs et boîtes une à une ; passer par le thème (`theme_type_variation` : BoutonPetit,
  BoutonOnglet/BoutonOngletActif, LabelEncre, PanelParchemin…). Sur un parchemin on écrit à l'encre (`StyleRepaire`) ;
  une couleur pensée pour le noir (rareté, matériau) passe par `StyleRepaire.encre()`. Changer une matière : modifier
  `tools/ui/matieres.py`, relancer `textures`, puis `--import` (sinon Godot garde l'ancienne image) ; changer le thème :
  `tools/ui/fabriquer_theme.gd`. `trait` est un mot réservé en GDScript 4.7 (variable « trait » : erreur de lecture).
- Ne pas modifier un script du jeu pendant que la suite de tests tourne : GUT charge les scripts au fil des tests et
  prend la version modifiée (vu : une erreur d'écriture en cours de route a fait échouer deux tests).
- Lumière façon Diablo IV : l'étalonnage (AgX, saturation 0,6) éteint les couleurs vives. Ce qui doit sauter aux yeux
  en combat (zones d'annonce, visée de l'arbalétrier, traînée du carreau) a une couleur « au-delà du blanc » (rouge à
  1,5–1,8, voir `Ennemi.COULEUR_ZONE`) ; un objet très lumineux (braises de la forge) vire au blanc : baisser son
  émission plutôt que d'éclaircir sa couleur. Vérifier toute nouvelle annonce sur capture.
- Matières réalistes : tout nouveau décor KayKit passe par `Matieres.habiller` (les `_objet` de l'arène, des salles et
  du repaire le font déjà) et son nom va dans une liste de `Matieres` (sinon il garde l'aspect KayKit). Textures :
  `compress/mode=2` et mipmaps dans le `.import` ; reliefs `compress/normal_map=1` (deux canaux : le shader recalcule le
  troisième, sinon tout devient noir). Un objet fait par code peut aussi les prendre (`Matieres.habiller(maillage, "wall")`).
- Une scène règle ses lumières comme avant (ombre voulue ou non) : c'est `Reglages` qui les coupe en Économie. Ne pas
  remettre `shadow_enabled` à chaud ailleurs (Reglages ne le reverrait qu'au prochain changement de qualité).
- Sons : un son prévu plus tard ne garde jamais le nœud (ni dans un lambda) : s'il disparaît entre-temps, Godot lève
  « Lambda capture … was freed » et les tests échouent (vu : 11 tests). `Sons.jouer_plus_tard` le retrouve par son
  numéro (`instance_from_id`) ; `Callable.is_valid()` d'un lambda ne dit **pas** si son objet a disparu.
- Sons : la minuterie d'un son prévu compte le temps de jeu (`create_timer(…, false, true)`, images de physique) :
  calée sur les animations, ralentie avec elles, et juste dans les tests.
- Sons : une ambiance boucle par son réglage d'import (`loop=true` dans son `.ogg.import`, versionné) ; une nouvelle
  ambiance doit le recevoir (le test `test_les_ambiances_bouclent` le vérifie).
- Sons : en coop, ne rien envoyer de neuf sur le réseau pour un son : le jouer là où l'image se montre déjà des deux
  côtés (animation lancée par `_jouer`, `EventBus.coup_porte`, fonctions de `EffetsMagie`, `_ready` d'un projectile…).
- Jauge : la Fente et les Chaînes coûtent de la jauge ; un test (ou une capture) qui les lance doit d'abord remplir
  `heros.jauge`. Elle ne se gagne que seul ou chez l'hôte (`gagner_jauge` ne fait rien chez l'invité ni sur une
  marionnette) : tout nouveau gain passe par elle. Un nouveau coût : `cout_jauge(action)` de l'archétype et le test
  de `Heros._essayer_actions_prioritaires`.
- Brume : faite de morceaux de 6 m au plus (`Ambiance.MORCEAU_BRUME`) ; sur téléphone un objet ne reçoit que 8 lumières.
  Son bord s'efface d'après la nappe entière (`centre`, `demi` du shader), pas d'après chaque morceau.
- Brume : ses nappes ont une priorité de rendu négative pour que les annonces au sol (priorité 0 et 1) se dessinent
  par-dessus ; une nouvelle annonce transparente garde une priorité ≥ 0.
- Retour d'Android sur l'écran titre : il quitte le jeu (`quit_on_go_back`), sauf réglages ouverts ; Godot décide de
  quitter **après** avoir prévenu les nœuds, d'où le `call_deferred` pour le réactiver en fermant les réglages.
- Panneaux du repaire : après une action, le panneau se refait **tout de suite** et un autre bouton apparaît sous le
  doigt (niveau suivant, « Sûr ? Recycler ») ; le second toucher d'un vrai double appui le touchait (relecture : cale
  achetée deux fois). Toute action commence donc par `appui_accepte()` (ignorée 0,4 s après la précédente). Dans un
  test, entre deux actions d'un même panneau : `await _doigt_leve()` (attente réelle de 0,5 s).
- Recyclage à la forge (choix de Téo du 05/11) : ce qui dépasse le plafond de l'entrepôt est **perdu** (jamais revendu :
  ce serait vendre depuis les coffres), écrit sur la ligne avant l'appui ; sans aucune place, bouton grisé.
- Bateau en expédition : la cale, la durée de la chaloupe et les tirs de bordée sont fixés au départ (`Expedition._pret`) ;
  à deux, le bateau de l'autre arrive à la connexion (`Reseau.bateau_partenaire`, `_bonjour` / `_bienvenue`).
- Bordée : chaque boulet est un `Boulet` posé dans la salle (retiré au changement de salle) ; l'invité le reçoit par
  `EventBus.effet_visuel` (« boulet_<délai ms> »), **même pour sa propre bordée** (décidée par l'hôte). Le bouton n'est
  pas dans `HudCombat._boutons` (son toucher vise avant de tirer) ; tout abandon passe par `finir_visee(false)`.
- Nœuds créés puis déplacés (`reparent`) sous un même parent : nommer **après** le `reparent` (sinon Godot renomme
  « @Canon@12 » et une recherche par nom ne les trouve plus).
- Sac d'expédition : toujours partir de `Expedition._sac_vide()` (objets, doublons et les trois matériaux) ; les messages
  réseau « butin » et « ramasse » portent la matière (`VERSION_RESEAU` 11 ; 12 : bateau et bordée ; 13 : l'hôte redit
  à l'invité ses tirs de bordée, message « bordee », même quand il refuse le tir).
