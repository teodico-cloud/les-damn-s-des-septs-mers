# Les Damnés des Sept Mers — contexte pour Claude

## Le projet
Jeu mobile Android : action-RPG roguelite pirate, 3D isométrique, coopération à 2 joueurs.
Moteur : Godot 4.7.2 (version figée jusqu'à la fin du MVP), GDScript, rendu Mobile.
Aucun serveur au MVP. Le projet Godot du jeu sera créé au jalon 0 (pas encore commencé).

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
- `assets/models/heroes/` : héros exportés (.glb, 76 animations chacun). Ne pas les modifier à la main :
  ils sont fabriqués par `tools/blender/build_heroes.py`.
- `tools/blender/` : fabrication des modèles dans Blender (en script).
- `tools/preview/` : petit projet Godot qui rend des captures d'aperçu ; exemples dans `tools/preview/exemples/`.
- `tools/fetch_kaykit.sh` : télécharge les packs KayKit dans `third_party/` (ignoré par git).
- `build/` : fichiers générés (textures, aperçus), ignoré par git.

## Commandes
- Préparer les packs : `tools/fetch_kaykit.sh`
- Blender en module Python : `pip install bpy` (testé avec bpy 5.2.2 LTS, Python 3.13)
- Refabriquer les héros : `python tools/blender/build_heroes.py all` (ou `bretteur`, `occultiste`)
- Aperçu : `GODOT=<chemin de Godot 4.7.2> tools/preview/render.sh tools/preview/exemples/heros_trois_angles.json 1600x700`
  (nécessite xvfb-run ; image dans `build/apercus/`)
- Godot 4.7.2 Linux : https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip

## Pièges connus
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
- Couleurs KayKit : chaque texture est une grille de cases 8 × 4 (128 × 256 px). Recolorer une case
  change toutes les parties qui l'utilisent ; baisser le contraste de la peau évite les reflets blancs.
- Rendus d'aperçu : sans carte graphique, ils utilisent le rendu Compatibility ; sur téléphone
  (rendu Mobile) l'image est un peu plus fine.
