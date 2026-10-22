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
  ambiance sombre donnée par l'éclairage (torches, brume, lueurs vertes).
- Assets : une seule famille (KayKit) pour la cohérence ; crédits dans `assets/CREDITS.md`.

## Arborescence actuelle
- `project.godot`, `export_presets.cfg` (Android arm64, paquet `fr.teodico.damnes`), `icon.svg`.
- `ui/screens/` : écrans (écran titre `demarrage.tscn` = scène principale ; `choix_heros.tscn` avant l'arène ;
  `coop.tscn` « Jouer à deux » : héberger / rejoindre, parties trouvées sur le Wi-Fi, code de secours).
- `game/vitrine/` : vitrine des héros (jalon 0) : héros, salle, actions au toucher, compteur d'images.
- Combat (jalon 1) :
  - `autoload/event_bus.gd` : signaux globaux (`coup_porte`, `ennemi_vaincu`, `heros_mort`, `heros_reapparu`).
  - `autoload/partie.gd` : état de la partie partagé entre écrans (héros choisi, mode solo / hôte / invité).
  - `autoload/reseau.gd` (Reseau) : session de coop (ENet, port 34778 ; annonces UDP 34779 ; code = dernier
    nombre de l'adresse de l'hôte). Les messages de l'invité pendant le combat passent par lui.
  - `data/equilibrage.tres` (+ `core/resources/equilibrage.gd`) : **toutes** les valeurs de réglage du combat.
  - `core/components/` : `Sante` (PV, invulnérabilité), `Recharge` (temps de recharge).
  - `game/combat/` : `Combat` (couches de collision, zones de coup, `porter_coup`), `CameraCombat`,
    `EffetsCombat` (chiffres, arrêt sur image, secousse), `Projectile` (tir de l'Occultiste),
    `EffetsMagie` (fumée, éclats, cercle au sol ; purement visuels).
  - `game/player/` : `Heros` (base commune : déplacement, visée, recharges, coup reçu, mort), un script
    par archétype (`Bretteur`, `Occultiste` ; `Heros.creer(&"occultiste")`) et `CommandesHeros` (ce que
    le joueur demande : seule entrée du héros, pour que le réseau puisse la remplir plus tard).
  - `game/enemies/` : `Ennemi` (Matelot squelette), `GenerateurEnnemis`.
  - `game/arene/` : arène d'entraînement, tout construit par code ; `regles_coop.gd` (hôte) : réanimation
    du partenaire, retour au départ si les deux tombent.
  - `game/reseau/synchro_arene.gd` (nœud « Synchro » de l'arène) : l'hôte simule tout et envoie 30
    instantanés/s + les événements ; l'invité prédit son héros et affiche le reste en « marionnettes »
    (`marionnette = true` sur Heros et Ennemi : affichés d'après l'hôte, sans règles).
  - `ui/hud/` : `HudCombat`, `JoystickFlottant`, `BoutonAction`.
  - `assets/models/enemies/` : squelette et lame KayKit ; `assets/materials/` : matières partagées.
- `tests/unit/` : tests GUT (`test_*.gd`) ; `addons/gut/` : GUT 9.7.1 (exclu de l'APK).
  `test_scripts.gd` charge tous les scripts du jeu (remplace `--check-only`, voir pièges).
- `android/cle_de_test.keystore` : clé de signature **de test** (mot de passe « android »), commune à
  tous les APK pour que les mises à jour s'installent. Jamais pour le Play Store.
- `.github/workflows/apk.yml` : à chaque envoi sur main, tests puis APK publié sur la release `apk-test` ;
  le numéro de version prend le numéro de fabrication (`0.<jalon>.<n°>`).
- `assets/models/decor/` : décors KayKit Dungeon (CC0), copiés tels quels.
- `assets/models/heroes/` : héros exportés (.glb, 76 animations chacun). Ne pas les modifier à la main :
  ils sont fabriqués par `tools/blender/build_heroes.py`.
- `tools/blender/` : fabrication des modèles dans Blender (en script).
- `tools/preview/` : petit projet Godot qui rend des captures d'aperçu ; exemples dans `tools/preview/exemples/`.
- `tools/fetch_kaykit.sh` : télécharge les packs KayKit dans `third_party/` (ignoré par git).
- `build/` : fichiers générés (textures, aperçus), ignoré par git.

## Commandes
- Importer le projet : `godot --headless --path . --import`
- Tests : `godot --headless --path . -s addons/gut/gut_cmdln.gd` (réglages dans `.gutconfig.json` ;
  code de sortie ≠ 0 si un test échoue, MAIS un fichier de test qui ne se charge pas est ignoré en silence :
  vérifier qu'aucune ligne « Ignoring script » / « Parse Error » n'apparaît — le CI le fait)
- Vérifier qu'un script se charge : lancer les tests (`test_scripts.gd` charge tous les scripts du jeu).
- Capture d'une scène du jeu (sans téléphone) :
  `xvfb-run -a godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 1280x720 -s "$PWD/tools/capture_scene.gd" -- res://game/vitrine/vitrine.tscn build/apercus/vitrine.png [nb_actions] [nb_images]`
- Captures mises en scène du combat (annonce, coup, fente) + état du combat dans la console :
  `xvfb-run -a godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 1280x720 -s "$PWD/tools/capture_combat.gd" -- build/apercus`
  (même chose pour l'Occultiste : `tools/capture_occultiste.gd` ; écran « Jouer à deux » : `tools/capture_coop_ecrans.gd`)
- Essai de la coop (hôte + invité sur cette machine, vérifications automatiques, aussi dans le CI) :
  `GODOT=<godot> tools/test_coop.sh [127.0.0.1|auto]` ; Wi-Fi imparfait simulé : préfixer
  `LATENCE_MS=30 GIGUE_MS=20 PERTE_PCT=3` ; captures des deux écrans : ajouter
  `CAPTURE_DIR=$PWD/build/apercus AFFICHAGE="xvfb-run -a" OPTIONS_RENDU="--rendering-method gl_compatibility --rendering-driver opengl3 --resolution 1280x720"`
  (avec le rendu, le jeu tourne ici plus lentement que le temps réel : distances plus courtes, c'est normal)
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
  `appliquer_instantane()` des deux côtés, sinon l'invité ne le voit pas.
- Aperçus (rendu Compatibility) : l'erreur « Dual paraboloid shadow mode not supported » est normale
  (ombre de torche) ; sur téléphone (rendu Mobile) ce mode marche.
- Blender en script : ne jamais nommer un fichier comme un module Python standard (`inspect.py`…) :
  Blender plante au démarrage.
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
