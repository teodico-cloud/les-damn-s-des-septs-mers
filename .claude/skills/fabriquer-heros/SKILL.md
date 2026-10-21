---
name: fabriquer-heros
description: Fabriquer ou retoucher un personnage 3D du jeu (héros, ennemi, mini-boss) à partir des packs KayKit dans Blender en script, en gardant l'ossature et les animations, puis l'exporter en .glb.
---

# Fabriquer un personnage à partir de KayKit

Le script de référence est `tools/blender/build_heroes.py`. Tout nouveau personnage suit la même chaîne.

## Préparer
1. `tools/fetch_kaykit.sh` (packs dans `third_party/`).
2. `pip install bpy` si Blender n'est pas importable (`python -c "import bpy"`).

## La chaîne, dans l'ordre
1. **Base** : `import_glb()` d'un personnage KayKit (ossature « Rig » commune aux aventuriers, 76 animations ;
   les squelettes en ont 95 : vérifier les noms d'os avant de mélanger des pièces d'un autre pack). Supprimer les armes et l'objet `Icosphere` inutiles.
2. **Mélange de pièces** : une tête ou une capuche d'un autre personnage se rattache avec `transfer()`
   (même ossature). Supprimer ensuite l'autre ossature **et ses actions** (sinon elles sont exportées).
3. **Proportions** : `reshape(rig, maillages_animés, capes)` avec la table `PROPS` (facteurs par os, y = le long
   de l'os) et `HEAD_K`. La pose devient la nouvelle pose de repos ; les animations restent valables.
4. **Couleurs** : `recolor(image, nom, {(colonne, ligne): couleur ou (couleur, contraste)})` puis `retexture()`.
   Pour savoir quelle case habille quelle partie, compter les cases par maillage avec `swatch_of_face()`.
   Peau : contraste ≈ 0,35–0,4 pour éviter les reflets blancs.
5. **Visage** : `face_parts()` repère yeux (case c2r0), sourcils (îlots c1r0 au-dessus des yeux) et bouche ;
   `harden_eyes_brows()` plisse les yeux et fronce les sourcils.
6. **Accessoires** : classe `Part` (cylindres, boîtes, icosphères, tores, surfaces), puis
   - tête, hanches, buste : modéliser en coordonnées monde de repos → `parent_world_rest(obj, rig, os)` ;
   - main droite : repère d'arme `WEAPON_R` (poignée à l'origine, lame vers +Z) → `parent_local()` ;
   - objet suspendu (lanterne) : orienter d'après la pose « Idle » avec `posed_bone_world()` ;
   - objet qui doit épouser le corps (bandoulière) : poids copiés avec `skin_like()` + modificateur Armature.
   Tailles des accessoires de tête : toujours multipliées par `HEAD_K`.
7. **Export** : `export(rig, objets_gardés, nom)` → `assets/models/heroes/<nom>.glb`. Vérifier dans la sortie :
   `EXPORTED <nom> ... actions 76` (ou 95 pour un squelette).

## Vérifier avant de montrer à Téo
Utiliser la compétence `rendre-apercu` : trois angles en éclairage neutre, poses d'animation (course,
attaque, parade ou sort, esquive), ambiance sombre. Regarder chaque image : accessoires qui flottent,
cape qui traverse le sol, tête trop claire, pièce mal placée.

## Pièges
Voir la section « Pièges connus » de `CLAUDE.md` (variables `k`, noms de scripts, matériaux après reset, capes).
