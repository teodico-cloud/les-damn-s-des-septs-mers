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
- `ui/screens/` : écrans (écran titre `demarrage.tscn` = scène principale).
- `game/vitrine/` : vitrine des héros (jalon 0) : héros, salle, actions au toucher, compteur d'images.
- `tests/unit/` : tests GUT (`test_*.gd`) ; `addons/gut/` : GUT 9.7.1 (exclu de l'APK).
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
- Vérifier la syntaxe d'un script : `godot --headless --path . --check-only -s res://chemin/script.gd`
- Capture d'une scène du jeu (sans téléphone) :
  `xvfb-run -a godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 1280x720 -s "$PWD/tools/capture_scene.gd" -- res://game/vitrine/vitrine.tscn build/apercus/vitrine.png [nb_actions] [nb_images]`
- Suivre la fabrication de l'APK : `gh api repos/teodico-cloud/les-damn-s-des-septs-mers/actions/runs`
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
