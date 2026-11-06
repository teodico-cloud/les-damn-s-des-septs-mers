# Crédits et licences des assets

| Asset | Auteur | Licence | Utilisation |
| --- | --- | --- | --- |
| KayKit Character Pack : Adventurers 1.0 | Kay Lousberg (kaylousberg.com) | CC0 1.0 | Bases des héros (corps, têtes, capuche, animations) ; armes du butin dans `assets/models/armes/`, copiées telles quelles (textures réduites à 512 px) : sabre, hache, dague, baguette, bâton, grimoires |
| KayKit Character Pack : Skeletons 1.0 | Kay Lousberg | CC0 1.0 | Ennemis dans `assets/models/enemies/`, copiés tels quels : Matelot squelette (`Skeleton_Minion`, lame `Skeleton_Blade`), Arbalétrier (`Skeleton_Rogue`, `Skeleton_Crossbow`), Prêtre noyé (`Skeleton_Mage`, `Skeleton_Staff` ; verdi en jeu par une matière teintée), Bosco Maudit (`Skeleton_Warrior`, `Skeleton_Axe` ; agrandis en jeu) |
| KayKit Dungeon Remastered 1.0 | Kay Lousberg | CC0 1.0 | Décors (sol, murs, torches, tonneaux, coffre, dalle à pics…) dans `assets/models/decor/` ; reliques et doublons du butin (clé, trousseau, fioles, chandelle, pièces) ; essence maudite (fiole verte) ; repaire (table, malles, mur d'échafaudage, bouclier, étagère, bannières) |

| Poly Haven : Cobblestone Floor 001, Stone Brick Wall 001, Weathered Brown Planks, Rust Coarse 01 | Poly Haven (polyhaven.com) | CC0 1.0 | Textures réalistes des décors (06/11, identité visuelle façon Diablo IV) dans `assets/textures/polyhaven/`, en 1K : couleur, relief, rugosité ; pour le bois et la rouille, un « grain » en gris tiré de la couleur (`tools/style_textures.py`). Envoyées par Téo depuis polyhaven.com |

Les packs sont téléchargés par `tools/fetch_kaykit.sh` depuis https://github.com/KayKit-Game-Assets.
CC0 : utilisation libre, y compris commerciale, sans obligation de mention.

Les modèles de `assets/models/heroes/` sont des dérivés de ces packs (recoloration, proportions,
accessoires modélisés par script dans `tools/blender/build_heroes.py`).

Faits par code, sans asset (jalon 5) : le navire du repaire (`game/repaire/navire.gd`), les planches de bois de
coque et les lingots de fer noir au sol, le foyer et l'enclume de la forge ; les améliorations visibles du navire
(caisses, voiles, bandes de fer, canons) et les boulets de la bordée. Icône du bouton Bordée (`assets/ui/icones/canon.svg`) :
dessinée à la main en SVG, comme les autres icônes.
