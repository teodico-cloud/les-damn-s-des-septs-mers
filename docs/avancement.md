# Avancement

Dernière mise à jour : 21 octobre 2026.

## Où on en est
- **Phase A (conception) : terminée et validée.** Voir `docs/conception.md`.
- **Héros : validés par Téo.** Bretteur et Occultiste, visages durs et détails pirates.
- **Jalon 0 : fait, en attente du test de Téo sur téléphone.** Projet Godot, écran titre, vitrine des héros,
  11 tests automatiques, APK fabriqué et publié par GitHub à chaque envoi.

## Travail en cours
Test du premier APK par Téo : installation, ouverture, vitrine, fluidité (compteur d'images par seconde),
toucher et rotation de la caméra. Ses retours décideront des réglages avant le jalon 1.

## Ce que Téo doit vérifier sur l'APK du jalon 0
1. L'APK s'installe (autoriser l'installation d'applications inconnues pour le navigateur).
2. L'écran titre s'affiche en paysage, en plein écran.
3. « Voir les héros » ouvre la vitrine ; les deux héros respirent (animation de repos).
4. Toucher l'écran : les héros enchaînent leurs actions ; glisser : la caméra tourne.
5. Le compteur en haut à gauche indique combien d'images par seconde (idéalement 30 ou plus).
6. Le bouton « Retour » et le bouton retour d'Android ramènent à l'écran titre.

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
| 21/10/2026 | Occultiste finalisé : peau gris-vert de noyé, yeux verts luisants et plissés, cils recourbés retirés, moustache tombante, barbe tressée devant le col. |
| 21/10/2026 | Jalon 0 : clé de signature de test commitée (mises à jour installables par-dessus) ; version = 0.<jalon>.<n° de fabrication> ; APK arm64 seulement ; paquet `fr.teodico.damnes` (modifiable avant le Play Store, définitif après). |

## Relecture du jalon 0 (agent relecteur) et corrections
- Le CI refuse désormais un script ou un fichier de test cassé (vérification de syntaxe + contrôle du
  journal des tests) ; étape « Vérifier l'APK » réellement bloquante ; publication seulement depuis main ;
  pas d'annulation d'une fabrication en cours ; la doc seule ne relance pas de fabrication.
- Textures compressées (VRAM) et une seule texture partagée par les 11 décors : mémoire textures de la
  vitrine ≈ 20 Mo au lieu d'environ 84 Mo.
- Vitrine : seul le premier doigt est suivi, un toucher annulé par le système ne lance rien (4 tests ajoutés).
- Capture d'écran : crée le dossier de sortie et échoue proprement si l'image n'est pas enregistrée.

## Prochaines étapes
1. Retour de Téo sur l'APK du jalon 0.
2. Jalon 1 : combat solo du Bretteur contre un ennemi (joystick, attaque, esquive, 2 compétences, impacts).

## Points à trancher plus tard
- Clé de signature définitive : passer à la vraie clé (secrète) **avant** que les sauvegardes comptent,
  car changer de clé oblige à désinstaller le jeu, ce qui efface les parties.
- Échelle des décors : les meubles KayKit (tonneaux, coffres) paraissent grands à côté des héros allongés.
  Réduire les décors d'environ 20 % ou agrandir légèrement les héros (à décider au jalon 1 ou 3).

## Informations utiles
- Dépôt GitHub : teodico-cloud/les-damn-s-des-septs-mers (public pour l'instant ; Téo peut le passer en privé).
- APK : https://github.com/teodico-cloud/les-damn-s-des-septs-mers/releases/download/apk-test/damnes-des-sept-mers.apk
- Téo teste sur téléphone Android ; il n'a pas besoin d'ouvrir Godot.
