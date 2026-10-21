---
name: rendre-apercu
description: Rendre une capture d'aperçu d'un ou plusieurs modèles .glb du jeu dans Godot (angles, poses d'animation, éclairage neutre ou sombre) pour vérifier un modèle ou le montrer à Téo.
---

# Rendre un aperçu dans Godot

Outil : `tools/preview/` (petit projet Godot) lancé par `tools/preview/render.sh`.

## Commande
```
GODOT=<chemin de Godot 4.7.2> tools/preview/render.sh <config.json> 1600x700
```
Nécessite `xvfb-run`. Sans carte graphique, le rendu Compatibility est utilisé (un peu moins fin que sur téléphone).

## Config JSON
Les chemins relatifs partent du dossier du fichier de config. Exemples prêts dans `tools/preview/exemples/`.
```json
{
  "out": "../../../build/apercus/mon_apercu.png",
  "dark": false,
  "floor": true,
  "items": [{"glb": "../../../assets/models/heroes/Bretteur.glb", "anim": "Idle", "t": 0.6,
             "pos": [0, 0, 0], "rot": 0, "scale": 1, "hide": [], "label": "Bretteur", "label_h": 2.9}],
  "lights": [{"pos": [1, 1, 1], "color": [0.3, 1.0, 0.55], "energy": 1.6, "range": 3.5}],
  "cam": {"target": [0, 1.3, 0], "dir": [0, 0.15, 1], "dist": 13, "fov": 30}
}
```

## Réglages standard
- Angles : `rot` 0 (face), -40 (trois-quarts), -90 (profil), 180 (dos). Les modèles regardent vers +Z.
- Héros (≈ 2,4 de haut) : `target` y ≈ 1,3, `dist` ≈ 13 pour 6 personnages côte à côte ; gros plan visage :
  `target` y ≈ 1,95, `dist` ≈ 3,4, `"floor": false`.
- Poses utiles : `Idle`, `Running_A` (t 0,3), `1H_Melee_Attack_Slice_Diagonal` (0,35), `Block` (0,4),
  `Spellcast_Shoot` (0,35), `Spellcast_Raise` (0,6), `Dodge_Forward` (0,25), `T-Pose`.
- Ambiance des raids : `"dark": true` + une lumière colorée près des objets lumineux.

## Règle
Toujours ouvrir et regarder l'image avant de l'envoyer à Téo, et décrire honnêtement les défauts restants.
