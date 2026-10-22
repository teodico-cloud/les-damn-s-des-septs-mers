# Avancement

Dernière mise à jour : 21 octobre 2026.

## Où on en est
- **Phase A (conception) : terminée et validée.** Voir `docs/conception.md`.
- **Héros : validés par Téo.** Bretteur et Occultiste, visages durs et détails pirates.
- **Jalon 0 : validé par Téo** (« Tout marche » ; la vitrine tourne à 120 images/s sur son téléphone).
- **Jalon 1 (combat solo du Bretteur) : écrit et testé dans l'espace de travail, en relecture avant APK.**

## Travail en cours — jalon 1
Arène d'entraînement (bouton « Combat d'entraînement » de l'écran titre) : le Bretteur contre deux
Matelots squelettes qui reviennent sans fin.
- Contrôles : joystick flottant (moitié gauche de l'écran), boutons Attaque / Esquive / Parade / Fente
  à droite avec leur temps de recharge affiché ; clavier sur ordinateur (ZQSD, J, K, L, I).
- Bretteur : combo de 3 coups (le 3e est lourd), esquive en roulade (invulnérable 0,32 s, traverse les
  ennemis), Parade-riposte (un coup de face paré déclenche une riposte qui étourdit), Fente (traverse et
  touche chaque ennemi une fois). Visée assistée : sans joystick, il frappe l'ennemi le plus proche.
- Matelot squelette : sort de terre, poursuit, annonce son coup (zone rouge au sol qui se remplit),
  frappe, reste vulnérable ; un coup léger ne l'interrompt pas, un coup lourd oui.
- Impacts : chiffres de dégâts, arrêt sur image, recul, éclair blanc, secousse de caméra.
- Mort du héros : « Vous êtes tombé… », retour au point de départ après 2,5 s.
- Toutes les valeurs de réglage sont dans `data/equilibrage.tres`.
- Tests automatiques : 40 au total (règles du combat chronométrées dans un petit monde de test, PV,
  recharges, arène qui se construit, chargement de tous les scripts).

## Ce que Téo devra vérifier sur l'APK du jalon 1
1. « Combat d'entraînement » ouvre l'arène ; deux squelettes sortent de terre.
2. Le joystick apparaît là où le pouce se pose et déplace le héros sans à-coups.
3. Garder « Attaque » enfoncé enchaîne les 3 coups ; les chiffres de dégâts s'affichent.
4. Pendant l'annonce rouge au sol, « Esquive » permet de rouler à travers le squelette sans être touché.
5. « Parade » juste avant le coup d'un squelette déclenche la riposte (le squelette est sonné).
6. « Fente » traverse les squelettes ; les boutons affichent leur recharge.
7. Fluidité avec 2 squelettes, lisibilité des boutons et de l'annonce, sensation des coups.

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
| 21/10/2026 | Jalon 0 validé sur téléphone (120 images/s dans la vitrine). |
| 21/10/2026 | Jalon 1 : joystick flottant ; annexes retenues : visée assistée et chiffres de dégâts (pas de vibrations ni de vagues infinies pour l'instant). Décors réduits à ×0,8. |

## Relecture du jalon 0 (agent relecteur) et corrections
- Le CI refuse désormais un script ou un fichier de test cassé (chargement de tous les scripts + contrôle du
  journal des tests) ; étape « Vérifier l'APK » réellement bloquante ; publication seulement depuis main ;
  pas d'annulation d'une fabrication en cours ; la doc seule ne relance pas de fabrication.
- Textures compressées (VRAM) et une seule texture partagée par les 11 décors : mémoire textures de la
  vitrine ≈ 20 Mo au lieu d'environ 84 Mo.
- Vitrine : seul le premier doigt est suivi, un toucher annulé par le système ne lance rien (4 tests ajoutés).
- Capture d'écran : crée le dossier de sortie et échoue proprement si l'image n'est pas enregistrée.

## Défauts trouvés pendant le jalon 1 (déjà corrigés)
- La roulade poussait le squelette devant le héros au lieu de passer à travers : le héros ressortait
  dans sa zone et prenait le coup. Les ennemis ne se heurtent plus aux héros (c'est le héros qui se heurte
  à eux quand il marche). Test ajouté.
- L'annonce au sol était cachée : d'abord sous les dalles, puis sous les pieds des personnages (le disque
  partait de zéro). La zone entière s'affiche maintenant dès le début, et un remplissage rouge grandit
  jusqu'au coup.
- Deux chiffres de dégâts rapprochés se chevauchaient : ils partent maintenant en alternance à gauche
  et à droite.
- Quitter l'arène juste après un coup ou une victoire faisait reprendre du code sur un objet détruit
  (réapparition des squelettes, fin de l'arrêt sur image) : branché proprement sur les minuteries.

## Prochaines étapes
1. Relecture du jalon 1 par l'agent relecteur, corrections, puis APK.
2. Retour de Téo sur la sensation du combat ; réglages dans `data/equilibrage.tres`.
3. Jalon 2 (selon `docs/conception.md`).

## Points à trancher plus tard
- Clé de signature définitive : passer à la vraie clé (secrète) **avant** que les sauvegardes comptent,
  car changer de clé oblige à désinstaller le jeu, ce qui efface les parties.
- Annonce des coups ennemis : si la zone au sol reste difficile à voir sur téléphone, ajouter un signe
  sur le squelette lui-même (lueur rouge des yeux, éclair) — à proposer à Téo après son essai.

## Informations utiles
- Dépôt GitHub : teodico-cloud/les-damn-s-des-septs-mers (public pour l'instant ; Téo peut le passer en privé).
- APK : https://github.com/teodico-cloud/les-damn-s-des-septs-mers/releases/download/apk-test/damnes-des-sept-mers.apk
- Téo teste sur téléphone Android ; il n'a pas besoin d'ouvrir Godot.
