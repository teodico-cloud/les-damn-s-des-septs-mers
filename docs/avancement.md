# Avancement

Dernière mise à jour : 21 octobre 2026.

## Où on en est
- **Phase A (conception) : terminée et validée.** Voir `docs/conception.md`.
- **Héros : en cours de finition.** Le Bretteur est terminé. L'Occultiste a deux retouches à faire (voir plus bas).
- **Jalon 0 (projet Godot, APK fabriqué par GitHub) : pas commencé.**

## Travail en cours
Retouches de l'Occultiste, demandées par Téo et pas encore appliquées :
1. Peau encore trop claire en éclairage neutre : passer la case peau (0,0) et les mains (7,2)
   à environ (128, 136, 118) avec un contraste de 0,35.
2. Moustache et barbe tressée placées trop haut (au niveau du nez) : repérer le menton comme le sommet
   de peau le plus bas sur l'axe du visage (|x| < 0,06, à l'avant), et placer la moustache
   à ~38 % de la distance menton → bas des yeux.

## Journal des décisions
| Date | Décision |
| --- | --- |
| 21/10/2026 | Projet distinct des Flibustiers et des Cendres du Dernier Serment. |
| 21/10/2026 | Moteur Godot 4.7.2, APK fabriqué par GitHub Actions, Firebase plus tard. |
| 21/10/2026 | Coop du MVP en Wi-Fi local ; coop par internet au jalon 7. |
| 21/10/2026 | Archétypes du MVP : Bretteur et Occultiste. Toutes les propositions annexes acceptées. |
| 21/10/2026 | Style KayKit retravaillé ; héros masculins ; héros faits avant le jalon 0. |
| 21/10/2026 | Héros allongés (tête ×0,62, jambes ×2, buste ×1,35, bras ×1,3) et moins « mignons ». |
| 21/10/2026 | Visages plus durs et plus pirates : Bretteur avec bandeau, balafre, anneau d'or, bandoulière ; Occultiste avec yeux verts luisants, moustache tombante, barbe tressée, breloques. |
| 21/10/2026 | Contexte pour Claude dans le dépôt (CLAUDE.md, docs, deux compétences) ; agent relecteur en fin de jalon. |

## Prochaines étapes
1. Finir les retouches de l'Occultiste et les faire valider par Téo sur captures.
2. Jalon 0 : projet Godot, arborescence, fabrication automatique de l'APK par GitHub, premier APK installable.
3. Jalon 1 : combat solo du Bretteur contre un ennemi.

## Informations utiles
- Dépôt GitHub : teodico-cloud/les-damn-s-des-septs-mers (public pour l'instant ; Téo peut le passer en privé).
- Téo teste sur téléphone Android ; il n'a pas besoin d'ouvrir Godot.
