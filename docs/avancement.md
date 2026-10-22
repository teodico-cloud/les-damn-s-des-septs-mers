# Avancement

Dernière mise à jour : 22 octobre 2026.

## Où on en est
- **Phase A (conception) : terminée et validée.** Voir `docs/conception.md`.
- **Héros : validés par Téo.** Bretteur et Occultiste, visages durs et détails pirates.
- **Jalon 0 : validé par Téo** (« Tout marche » ; la vitrine tourne à 120 images/s sur son téléphone).
- **Jalon 1 (combat solo du Bretteur) : relu, corrigé, APK envoyé à Téo pour essai.**

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
- Tests automatiques : 53 au total (règles du combat chronométrées dans un petit monde de test, PV,
  recharges, arrêt sur image, toucher à plusieurs doigts, arène qui se construit, chargement de tous
  les scripts).

## Ce que Téo devra vérifier sur l'APK du jalon 1
1. « Combat d'entraînement » ouvre l'arène ; deux squelettes sortent de terre.
2. Le joystick apparaît là où le pouce se pose et déplace le héros sans à-coups.
3. Garder « Attaque » enfoncé enchaîne les 3 coups ; les chiffres de dégâts s'affichent.
4. Pendant l'annonce rouge au sol, « Esquive » permet de rouler à travers le squelette sans être touché.
5. « Parade » juste avant le coup d'un squelette déclenche la riposte (le squelette est sonné et
   reste à portée : on a le temps de le punir).
6. « Fente » traverse les squelettes ; les boutons affichent leur recharge.
7. Fluidité avec 2 squelettes, lisibilité des boutons et de l'annonce, sensation des coups.
8. « Menu » marche même avec le pouce gauche sur le joystick ; après un appel ou un retour à l'accueil,
   rien ne reste enfoncé.

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
| 22/10/2026 | Jalon 1 : combat validé par Téo ; ajout demandé : yeux rouges des squelettes pendant l'annonce. |
| 22/10/2026 | Jalon 2 (coop Wi-Fi) : Téo a deux téléphones Android. L'Occultiste complet est avancé au jalon 2 (projectile maudit, téléportation courte, Marque maudite, Chaînes spectrales ; 80 PV). Marque : +40 % de dégâts du partenaire, +15 % pour l'Occultiste lui-même. En coop, héros différents obligatoires. Si les deux héros tombent : retour au départ, squelettes remis à zéro. Annexes retenues : réanimation du partenaire, arrêt sur image propre à chaque joueur, anneau coloré sous chaque héros, 3 squelettes à deux. Ordre : 1) Occultiste solo + choix du héros (APK intermédiaire), 2) coop, 3) réanimation et arrêt sur image local. |

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

## Relecture du jalon 1 (agent relecteur) et corrections
- **Bloquant, corrigé :** l'arrêt sur image ne se terminait jamais (jeu à 5 % de vitesse après le
  premier coup). Cause : minuterie déclenchée une image en avance. Remplacé par un compteur ; 2 tests.
- Invulnérabilité comptée en temps de jeu (avant : temps réel, donc une esquive juste après un coup
  lourd ne durait que 0,25 s au lieu de 0,32). Test ajouté.
- Riposte : le squelette sonné le reste même s'il est frappé, et n'est plus repoussé à plus de 4 m
  (le recul est maintenant une vraie distance en mètres : 0,45 m coup léger, 1,1 m coup lourd). 3 tests.
- Visée assistée : ignore un squelette qui sort encore de terre (intouchable). Test ajouté.
- Bouton Menu utilisable avec un 2e doigt ; tout est relâché si l'appli passe en arrière-plan. 6 tests
  du toucher.
- Fondus d'animation réparés (la pose sautait d'un coup) ; texture du squelette avec mipmaps ;
  réglages restants déplacés dans `equilibrage.gd` ; boutons redessinés seulement si besoin.

## Questions pour Téo (après son essai)
- Parade et Fente pendant l'élan d'un coup : aujourd'hui seule l'Esquive peut couper un coup avant
  l'impact ; une Parade demandée trop tôt est perdue. Faut-il que la Parade puisse aussi couper le coup ?
- Annonce des coups ennemis : si la zone au sol reste difficile à voir, ajouter un signe sur le
  squelette lui-même (lueur rouge des yeux, éclair).

## À prévoir pour la coop (jalon réseau, rien à faire maintenant)
- L'arrêt sur image ralentit tout le jeu de l'hôte : il devra devenir un effet seulement visuel et local.
- Commandes horodatées par l'horloge locale du héros : passer à des numéros de séquence ; l'attaque
  maintenue devra être un état « appuyé » plutôt qu'une demande à chaque image.
- `EventBus.coup_porte` devra dire quel héros est touché (secousse de la bonne caméra).
- Effets (éclair, chiffres) déclenchés par les règles : à rejouer chez l'invité à partir des événements.
- Ennemis : noms stables nécessaires pour la réplication.

## Prochaines étapes
1. Essai de l'APK du jalon 1 par Téo.
2. Retour de Téo sur la sensation du combat ; réglages dans `data/equilibrage.tres`.
3. Jalon 2 (selon `docs/conception.md`).

## Points à trancher plus tard
- Clé de signature définitive : passer à la vraie clé (secrète) **avant** que les sauvegardes comptent,
  car changer de clé oblige à désinstaller le jeu, ce qui efface les parties.

## Informations utiles
- Dépôt GitHub : teodico-cloud/les-damn-s-des-septs-mers (public pour l'instant ; Téo peut le passer en privé).
- APK : https://github.com/teodico-cloud/les-damn-s-des-septs-mers/releases/download/apk-test/damnes-des-sept-mers.apk
- Téo teste sur téléphone Android ; il n'a pas besoin d'ouvrir Godot.
