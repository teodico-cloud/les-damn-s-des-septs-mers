# Avancement

Dernière mise à jour : 30 octobre 2026.

## Où on en est
- **Phase A (conception) : terminée et validée.** Voir `docs/conception.md`.
- **Héros : validés par Téo.** Bretteur et Occultiste, visages durs et détails pirates.
- **Jalon 0 : validé par Téo** (« Tout marche » ; la vitrine tourne à 120 images/s sur son téléphone).
- **Jalon 1 (combat solo du Bretteur) : validé par Téo.**
- **Jalon 2 (coop Wi-Fi) : relu, corrigé, APK envoyé à Téo pour l'essai sur deux téléphones.** Étape 1 (Occultiste, choix du héros,
  yeux rouges) envoyée à Téo en APK intermédiaire (0.2.6). Étapes 2 et 3 (coop, réanimation) : 89 tests
  automatiques + essai à deux copies du jeu (Wi-Fi parfait, moyen et mauvais simulés).
- **30/10 : combat « nerveux » (façon Diablo)** demandé par Téo, sur la branche `jalon-2-nervosite` puis
  main : héros plus vif, hordes, coups qui claquent, coups critiques. 100 tests ; essai coop réussi.

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

## Coop (jalon 2) : comment ça marche
- Écran titre → « Jouer à deux ». Un téléphone **héberge** (il choisit son héros, voit un code), l'autre
  **rejoint** : la partie apparaît d'elle-même sur le même Wi-Fi ; sinon il tape le code de l'hôte.
  L'invité prend l'autre héros. L'hôte appuie sur « Lancer le combat ».
- L'hôte décide de tout (coups, squelettes, morts) et envoie 30 « instantanés » par seconde. L'invité
  bouge son héros tout de suite chez lui (pas de retard ressenti) ; s'il s'écarte de ce que l'hôte a
  décidé, il est recalé en douceur. Le reste est affiché avec 0,1 s de retard pour être fluide.
- 3 squelettes à deux ; anneau doré sous son héros, vert sous celui du partenaire ; arrêt sur image
  seulement sur le frappeur et sa cible ; la caméra ne tremble que pour ses propres coups.
- À terre : le partenaire reste 3 s dans la zone verte pour relever (moitié des PV). Les deux à terre :
  « Vous êtes tombés… », retour au départ et squelettes remis à zéro.
- Si l'invité part : l'hôte continue seul. Si l'hôte part : l'invité revient au menu avec un message.

## Combat « nerveux » (30/10, demande de Téo : « vraiment Diablo like »)
Téo a choisi : héros plus vif, hordes, coups qui claquent, coups critiques (pas les ennemis plus agressifs).
- Héros plus vif : marche 6,2 m/s (5,2) ; combo 25 % plus rapide ; bouger le joystick 0,05 s après
  l'impact coupe la fin du coup (le combo reste enchaînable) ; recharges raccourcies (roulade 0,6 s,
  Parade 4 s, Fente 3,5 s ; Occultiste : tir toutes les 0,32 s, téléportation 0,9 s). Le Bretteur vise
  aussi l'ennemi dans la direction du joystick (même règle que le tir de l'Occultiste).
- Hordes : 5 squelettes seul, 8 à deux, qui sortent par groupes de 2 à 4 ; 30 PV (60) ; quand certains
  tombent, les manquants ressortent ensemble 2 s plus tard. Dégâts des squelettes 15 → 10 pour que la
  horde reste jouable.
- Coups qui claquent : le squelette vaincu éclate en os qui volent loin du tueur et rebondissent ;
  recul des coups lourds 1,6 m (1,1) ; traînée dorée du sabre à chaque coup (vue aussi par l'autre joueur).
- Coups critiques : 1 chance sur 10 (coups des héros sur les ennemis), dégâts doublés, gros chiffre doré
  avec « ! », secousse plus forte. Jamais sur un héros.
- Compteur d'images par seconde sous le bouton Menu (APK de test : pour juger la fluidité avec la horde).
- Réseau : version 2 (un APK plus ancien est refusé en coop) ; animations envoyées par numéro.

## Ce que Téo devra vérifier sur l'APK du jalon 2 (deux téléphones sur le même Wi-Fi)
1. « Jouer à deux » : héberger sur l'un, rejoindre sur l'autre (la partie apparaît, ou avec le code).
2. Les deux héros, les mêmes squelettes aux mêmes endroits sur les deux écrans ; ça reste fluide.
3. Chacun bouge et frappe sans retard ressenti ; les coups de l'un se voient chez l'autre.
4. La Marque de l'Occultiste fait plus mal aux coups du Bretteur ; les Chaînes bloquent pour les deux.
5. Tomber, être relevé par l'autre ; tomber tous les deux → retour au départ.
6. Quitter d'un côté (bouton Menu) : l'autre est prévenu.

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
| 22/10/2026 | Occultiste, après relecture (choix de Téo) : le tir vise l'ennemi le plus proche de la direction du joystick (cône de 60°), sinon la direction du joystick ; il peut bouger dès que le projectile est parti (la cadence reste d'un tir toutes les 0,45 s) ; sans joystick, la téléportation part en arrière ; un sort coupé par un coup avant son effet rend sa recharge. |
| 22/10/2026 | Icônes des compétences sur les boutons, propres à chaque héros (demande de Téo). |
| 30/10/2026 | Combat « nerveux » : héros plus vif, hordes, coups qui claquent, coups critiques (choix de Téo, voir plus haut). Ennemis plus agressifs : non retenu. |

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

## Relecture du jalon 2, étape 1 (agent relecteur) et corrections
- Rien de bloquant ; Bretteur identique à main image par image après le découpage du héros (vérifié).
- Corrigé selon les choix de Téo : tir avec visée dans la direction du joystick, mouvement après le tir,
  téléportation en arrière, recharge rendue si un sort est coupé ou si la cible de la Marque meurt.
- Corrigé : un étourdissement ne raccourcit plus les Chaînes (le plus long des deux est gardé) ;
  formes et requêtes partagées (projectiles, fumées, chaînes) ; deux tests rendus plus probants.
- Noté pour plus tard : la visée assistée ignore les murs (à revoir avec les donjons).

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

## Relecture de fin du jalon 2 (agent relecteur) et corrections
- Bloquant, corrigé : chez l'invité, les squelettes et le héros de l'hôte restaient figés (animation
  envoyée à vitesse 0 à cause de l'arrêt sur image local). Test qui le détecte ajouté.
- Bloquant, corrigé : l'essai à deux copies échouait au hasard (héros encore invulnérable) ; stable 6/6.
- Corrigé : héros de l'invité envoyé hors de la salle au retour au départ ; annonce rouge pleine au bon
  moment chez l'invité (calée sur l'hôte) ; écoute des annonces en broadcast ; adresse du Wi-Fi choisie
  par interface (pas celle des données mobiles), adresse complète tapable ; coupure détectée en 3 à 5 s
  et message « Connexion instable… » ; version différente ou partie complète refusées avec un message ;
  squelettes lancés quand l'invité est prêt ; 2 squelettes si l'hôte continue seul ; cercle des Chaînes
  visible chez l'invité.
- Reste connu (mineur) : petits recalages de l'invité pendant une Fente ou une téléportation (la visée
  assistée peut différer d'un téléphone à l'autre) ; long recalage après une pause de l'hôte (appel).
- 22/10 (demande de Téo) : icônes des compétences sur les boutons, propres à chaque héros.

## Prochaines étapes
1. Essai de Téo du combat « nerveux » (seul et à deux) ; réglages selon son ressenti.
2. Essai de Téo sur deux téléphones (jalon « porte » : on corrige avant d'avancer).
3. Jalon 3 : raid jouable (salles, 3 ennemis, mini-boss, malédiction, extraction).

## Points à trancher plus tard
- Clé de signature définitive : passer à la vraie clé (secrète) **avant** que les sauvegardes comptent,
  car changer de clé oblige à désinstaller le jeu, ce qui efface les parties.

## Informations utiles
- Dépôt GitHub : teodico-cloud/les-damn-s-des-septs-mers (public pour l'instant ; Téo peut le passer en privé).
- APK : https://github.com/teodico-cloud/les-damn-s-des-septs-mers/releases/download/apk-test/damnes-des-sept-mers.apk
- Téo teste sur téléphone Android ; il n'a pas besoin d'ouvrir Godot.
