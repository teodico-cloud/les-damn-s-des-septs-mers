# Avancement

Dernière mise à jour : 4 novembre 2026.

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
- **Jalon 2 clos (30/10)** : coop validée par Téo sur deux téléphones ; relecture des ajouts corrigée
  (APK 0.2.10).
- **Jalon 3, étape 1 (expédition) : faite**, APK intermédiaire 0.3.x.
- **Jalon 3, étape 2 (arbalétrier, prêtre noyé, salles piège) : faite**, APK 0.3.13.
- **Jalon 3, étape 3 (Bosco Maudit, malédiction, chaloupe sous les vagues, écran de fin) : faite** ;
  relecture de fin de jalon puis APK 0.3.14.
- **Jalon 4, étape 1 (butin au sol, façon Diablo) : faite**, APK 0.3.15.
- **Jalon 4, étape 2 (sauvegarde, équipement, effets en combat, arme en main, objets uniques) : faite**, APK 0.4.17.
- **Jalon 4, étape 3 (tri de la cale, revente, extraction d'urgence) : faite** ; relecture de fin de jalon corrigée ; APK 0.4.18.
- **Jalon 5, étape 1 (matériaux, sauvegarde v2, repaire, salle des cartes, entrepôt) : faite**, APK 0.5.19 (voir plus bas).
- **Jalon 5, étape 2 (chantier naval, améliorations du bateau, bordée visée au joystick) : faite**, APK 0.5.20 (voir plus bas).
- **Jalon 5, étape 3 (forge : améliorer, recycler, relancer ; forge et entrepôt niveau 2) : faite** (voir plus bas) ;
  relecture de fin de jalon corrigée ; **APK 0.5.21 (fin du jalon 5)**, envoyé à Téo le 05/11.
- **Attaque façon Diablo (05/11, demande de Téo)** : bond, arcs, moulinet, tir qui explose, téléportation à charges
  (voir plus bas) ; APK 0.5.22.
- **Jalon 6 — refonte de l'interface (05/11, demande de Téo)** : tous les écrans existants refaits (voir plus bas) ;
  APK 0.5.23. Puis l'écran Réglages (qualité graphique) et le carnet de bord du repaire (choix de Téo du 05/11) ;
  APK 0.5.24. Reste : les sons.

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

## Expédition (jalon 3, étape 1)
- Écran titre → « Expédition » → choix du héros. À deux : l'hôte choisit « Lancer l'expédition ».
- 4 salles (la 1re est un combat), puis l'antre du Bosco (une grosse horde en attendant le Bosco, étape 3),
  puis la chaloupe. Salles faites main du Récif des Pendus : 6 de combat (Salle des gardes, Réfectoire,
  Cale effondrée, Crypte des noyés, Arsenal pillé, Puits maudit), 1 trésor, l'antre, le quai.
- Combat : 9 squelettes à vaincre (13 à deux), 5 debout à la fois (7 à deux). Salle nettoyée : les deux
  portes s'ouvrent, avec l'icône de la salle suivante (combat ou trésor ; un seul trésor par expédition).
- Trésor : le coffre soigne la moitié des PV (le butin arrive au jalon 4). Orbes de vie : 30 % des
  squelettes en lâchent une (+20 % des PV), ramassée en passant dessus si l'on est blessé ; aussi dans
  l'arène. PV gardés d'une salle à l'autre.
- Coop : la porte se prend quand les deux héros sont devant (« 1/2 » au-dessus d'elle sinon).
- Tomber seul, ou les deux à terre : « Expédition perdue ». Monter dans la chaloupe (cercle vert sur le
  quai, les deux à deux) : « Expédition réussie ». Écran de fin : progression, squelettes vaincus,
  parades parfaites, coups critiques, orbes, durée.
- Menu pendant l'expédition : deux appuis (on ne perd pas l'expédition d'un doigt maladroit).
- Mode test (écran titre) : santé infinie ; départ au trésor, à l'antre du Bosco ou à la chaloupe.
- Réseau version 5. Tests : 128 ; essai coop de l'expédition (aussi dans la fabrication de l'APK).

## Ennemis et pièges (jalon 3, étape 2)
- **Arbalétrier squelette** (dès la salle 2 ; 2 par salle, 3 à deux) : 22 PV, garde ses distances (recule
  si l'on s'approche), vise 0,8 s avec un **trait rouge** (il suit sa cible pendant 65 % de la visée, puis
  bloque : on a le temps de sortir de la ligne), tire un carreau visible (12 dégâts). La roulade et la
  téléportation le traversent ; la **Parade de face le renvoie** (24 dégâts aux squelettes ; parade
  parfaite : coup critique et Parade rendue). Pas de zone dorée : la parade d'un carreau se joue à son arrivée.
- **Prêtre noyé** (dès la salle 3, et dans l'antre ; jamais dans le premier groupe) : 45 PV, os verdis,
  yeux et lueur verts, garde ses distances.
  - Il **relève un squelette tombé** (une seule fois par mort ; pas les prêtres) : cercle vert qui se
    remplit sur la tombe pendant 1,6 s. **Un coup, même léger, l'interrompt** : le mort reste à terre.
  - Il **maudit le sol** sous un héros : cercle vert 0,9 s, puis une flaque (5 s, rayon 1,5 m) qui fait
    perdre 8 PV/s tant qu'on reste dedans, sans sonner ni rendre intouchable.
- **Salles piège** (porte « Piège », 2 au plus par expédition ; 5 squelettes, 7 à deux) : Salle aux pointes
  et Poudrière.
  - **Dalles à pics** : la dalle rougeoie et tremble 0,7 s, puis les pics sortent 0,8 s (18 dégâts, une fois
    par sortie) ; cycle de 3,2 s, les dalles voisines alternent. Elles blessent aussi les squelettes.
  - **Tonneaux de poudre** (rougis, avec une mèche) : un coup allume la mèche, explosion 0,35 s après
    (45 dégâts aux squelettes dans 3 m ; les tonneaux voisins sautent aussi). **Les héros sont épargnés.**
    La visée assistée les ignore.
- L'arène d'entraînement garde seulement les matelots (choix de Téo).
- Coop : l'invité recrée chaque squelette d'après son nom (« Arbaletrier_12 »), voit les carreaux (même
  ceux que son héros renvoie : c'est l'hôte qui décide), les cercles et la flaque du prêtre, et suit
  l'horloge des pièges de l'hôte. Réseau version 6.
- Tests : 146 (17 nouveaux, chacun vérifié par un sabotage de la règle qu'il surveille). Essai coop de
  l'expédition : l'hôte fait sortir un arbalétrier et un prêtre, tire un carreau, lance une flaque ;
  l'invité voit tout et suit l'horloge des pièges (écart 0,01 s), Wi-Fi parfait et moyen.
- Corrigé en passant : l'arbalète était tenue de travers (KayKit la tient en travers du corps : elle visait
  à 90° sur le côté) ; le trait rouge restait 0,35 s après le tir ; le carreau était trop fin pour être
  vu de loin (grossi, traînée plus franche) ; l'essai coop de l'arène échouait parfois (environ 1 fois
  sur 5, déjà avant l'étape 2) quand un vrai squelette était paré parfaitement pendant l'attente.
- Choix faits sans Téo, à lui signaler : héros épargnés par les tonneaux ; pics qui blessent aussi les
  squelettes ; Parade sans effet contre pics et flaque ; flaque sans étourdissement ; pas de prêtre dans le
  premier groupe ; trait de l'arbalétrier jamais doré.

## Bosco, malédiction, chaloupe (jalon 3, étape 3 — choix de Téo du 31/10)
- **Bosco Maudit** (antre) : grand squelette guerrier KayKit (×1,6) à hache géante, 1 400 PV (~1 min 30 en
  solo pour un bon joueur ; ×1,8 à deux). Il ne recule pas et n'est pas interrompu par les coups.
  - Coup de hache au sol, droit devant (4,6 m) : zone rouge qui devient **dorée** → **le seul qui se pare**
    (parade parfaite possible ; la riposte l'étourdit, deux fois moins longtemps qu'un matelot).
  - Tourbillon (cercle de 3,2 m) et charge (ligne vers le héros, jusqu'à 12 m) : **rouge sombre, imparables**
    (il faut s'éloigner ou rouler). Charge finie contre un mur ou un meuble : **sonné 2 s** (étoiles).
  - À mi-vie : **rage** (cri, yeux et lueur rouges, 25 % plus rapide) et **3 matelots** appelés.
  - Barre de vie en haut de l'écran. Vaincu : son équipage s'effondre avec lui, la porte de la chaloupe s'ouvre.
- **Malédiction** choisie au départ (écran du héros en solo ; l'hôte sur « Jouer à deux », envoyée à l'invité),
  effets cumulés : 1 Os durcis (squelettes +25 % PV) ; 2 Équipage nombreux (+2 squelettes par salle, 1 de plus
  debout, +1 par vague de la chaloupe) ; 3 Lames maudites (+25 % de dégâts des squelettes, pas des pièges) ;
  4 Mer avare (orbes 2 fois plus rares, coffre moitié moins) ; 5 Bosco enragé dès le début, pièges plus
  rapides. Butin +20 % par niveau (chance d'objet, et raretés poussées vers le haut). Niveau affiché sous les PV.
- **Chaloupe sous les vagues** : y monter lance un compte de 45 s, qui n'avance que si un héros debout est à
  bord (sinon « Remontez dans la chaloupe ! », sans rien perdre). 5 vagues de 3 squelettes (4 à deux) sortent
  de l'eau le long du quai, un arbalétrier par vague dès la 3e ; la houle et le tangage grossissent.
- **Écran de fin enrichi** : malédiction et bonus de butin, « Bosco vaincu en … » (ou ses PV restants).
- Annexes proposées et non retenues par Téo : départs « piège » / « salle 3 » au mode test, explosion plus
  grande, mort du Bosco mise en scène.
- Petits choix faits sans Téo, à lui signaler : riposte et chaînes deux fois moins longues sur le Bosco ; son
  équipage s'effondre avec lui ; la rage attend la fin d'une attaque ou d'un étourdissement ; 3 matelots même
  à deux ; les vagues de la chaloupe n'avancent qu'avec le compte (pas de vague tant que personne n'est à bord).
- Réseau version 7. Tests : 180 en tout, dont 34 nouveaux (vérifiés par sabotage) ; essai coop de l'expédition étendu (malédiction
  reçue, Bosco, zone de sa charge, rage, compte à rebours de la chaloupe chez l'invité).

## Butin au sol (jalon 4, étape 1 — choix de Téo du 31/10)
- **Façon Diablo** : un squelette vaincu lâche, **pour chaque joueur séparément**, peut-être un objet (matelot
  6 %, arbalétrier 10 %, prêtre noyé 15 %, ×1,2 par niveau de malédiction) et peut-être des doublons (35 %,
  2 à 6). Le Bosco : 2 objets (au moins un Épique, jamais de Commun) + 40 doublons ; le coffre : 2 objets
  (au moins Rare) + 25 doublons. Tout est dans `equilibrage.tres` (groupe « Butin »).
- L'objet saute hors du squelette, flotte et tourne, avec une **colonne de lumière** et son nom à la couleur de
  sa rareté : Commun blanc, Rare bleu, Épique violet (+ halo), Légendaire or, Maudit vert. Les objets uniques
  luisent. Quand plusieurs tombent au même endroit, les noms s'étagent.
- **Ramassé en passant dessus** (une fois retombé, héros debout) : ligne colorée à gauche (4 au plus, s'efface),
  « Sac : n objets · n doublons » sous la malédiction. Le butin laissé dans une salle est perdu.
- **Défaite : tout le sac est perdu** (« Butin perdu : … »). Victoire : « Butin rapporté : … » et les noms des
  objets (les plus rares d'abord, 10 au plus) sur l'écran de fin.
- **À deux : chacun le sien.** L'hôte tire le butin des deux joueurs ; celui de l'invité est invisible chez
  l'hôte et n'apparaît que chez l'invité ; l'hôte décide du ramassage et tient les deux sacs (envoyés avec la fin).
- Catalogue (`game/butin/butin.gd`) : 3 armes par héros, 6 reliques, 5 objets uniques (3 Légendaires, 2 Maudits).
  Effets validés par Téo le 01/11 (branchés à l'étape 2) : Commun = effet de base ; Rare = base +25 % et 1
  effet en plus ; Épique = base +50 % et 2 effets en plus. Sabre +10 % dégâts ; hache +30 % dégâts, coups 15 %
  plus lents ; coutelas coups 15 % plus rapides, +8 % critiques ; baguette tirs 20 % plus rapides ; bâton
  projectile +30 %, tirs 15 % plus lents ; grimoire Marque et Chaînes rechargées 20 % plus vite. Reliques :
  clé +25 % sur un squelette étourdi ou enchaîné ; fiole orbes +40 % ; chandelle +15 PV max ; doublon terni
  +30 % de doublons ; trousseau roulade/téléportation rechargée 25 % plus vite ; flasque 10 % des PV à chaque
  salle nettoyée. Effets en plus : +8 % dégâts, +10 PV max, +6 % critiques, +6 % vitesse, recharges −8 %,
  vol de vie 3 %, +15 % doublons, épines 20 % (corps-à-corps). Uniques : Lame du Noyé (traînée d'eau maudite
  de la roulade), Grimoire du Pendu (squelette tué par les sorts relevé ~6 s), Sablier de la Marée (esquive au
  dernier moment : squelettes figés 1,5 s), Talisman du Pendu (+40 % dégâts, orbes sans effet), Cœur de Kraken
  (+50 % PV max, 20 % moins vite). Sans arme trouvée : arme de départ sans bonus. Modèles : armes du pack KayKit
  Adventurers, reliques du pack Dungeon.
- Petits choix faits sans Téo, à lui signaler : un héros à terre ne ramasse rien ; objet ramassable seulement
  une fois retombé (0,35 s) ; l'équipage du Bosco qui s'effondre lâche aussi son butin.
- Réseau version 8. Tests : 197 en tout, dont 17 nouveaux (vérifiés par sabotage : 22 sabotages, tous vus) ;
  essai coop de l'expédition étendu (butin de l'invité invisible chez l'hôte, vu et ramassé chez l'invité,
  celui de l'hôte jamais vu chez l'invité, écran de fin de l'invité).

## Équipement et sauvegarde (jalon 4, étape 2 — choix de Téo du 01/11)
- **Sauvegarde** (`autoload/sauvegarde.gd`) : `user://sauvegarde.json`, version 1 ; écriture sûre (fichier
  temporaire relu, copie de secours `.bak` de l'ancien, puis remplacement) ; lecture : le fichier, sinon la
  copie, sinon un profil neuf. Contenu : doublons, objets des coffres, équipement des deux héros, expéditions
  encaissées (anti-doublon), historique des 20 dernières. Enregistrée au départ et à la fin d'une
  expédition, à chaque changement d'équipement, quand l'appli passe en arrière-plan ou se ferme.
- **Fin d'expédition** : victoire = le sac rejoint les coffres (une seule fois par expédition) ; défaite = rien.
- **Écran Équipement** (écran titre, à côté de « Voir les héros ») : le héros debout à gauche avec l'arme qu'il
  porte, onglets Bretteur / Occultiste, 3 emplacements, objets des coffres qui vont à l'emplacement choisi
  (les plus rares d'abord), fiche avec la comparaison ▲▼ (annexe retenue), Équiper / Retirer. Un objet n'est
  porté qu'à un endroit à la fois (le reporter ailleurs l'y retire). Doublons et objets affichés sur l'écran titre.
- **Effets en combat** (`game/butin/equipement.gd`, partout, arène comprise) : dégâts, vitesse d'attaque (coups
  du combo, cadence et geste de tir), critiques, PV max, vitesse, recharges, vol de vie, épines (≤ 3,2 m),
  doublons ramassés, soin des orbes, Clé du geôlier, Flasque (à chaque salle nettoyée). Plafonds : recharges
  au plus −50 %, vitesse d'attaque entre −50 % et +50 %.
- **Arme en main** : l'arme portée remplace l'arme de départ dans la main (même attache) ; bâton et grimoires
  réduits (×0,6 / ×0,7) ; les armes uniques luisent.
- **Objets uniques** : Lame du Noyé (flaques d'eau maudite le long de la roulade, 16 PV/s aux squelettes,
  2,5 s ; un squelette n'est blessé qu'une fois par tic même sur plusieurs flaques) ; Grimoire du Pendu (un
  squelette tué par l'Occultiste ressort de terre 0,5 s après, spectral et vert, et frappe les squelettes 6 s ;
  2 au plus ; jamais le Bosco ; ni visé, ni compté, ni lâcheur de butin) ; Sablier de la Marée (un coup
  esquivé pendant la roulade ou la téléportation fige les squelettes à 4 m pendant 1,5 s, une fois par
  esquive, cercle bleu) ; Talisman du Pendu ; Cœur de Kraken.
- **À deux** : chaque téléphone envoie l'équipement de ses héros à la connexion ; les deux équipent les deux
  héros pareil (PV, vitesse, arme en main) ; l'hôte décide des dégâts et des effets. Réseau version 9.
- **Mode test** : « Coffres de test » met un objet de chaque sorte dans les coffres (les cinq uniques compris).
- Petits choix faits sans Téo, à lui signaler : les armes uniques ont aussi l'effet de base d'une arme Épique
  (Lame du Noyé +15 % de dégâts, Grimoire du Pendu −30 % de recharge des sorts) ; le Talisman laisse les orbes
  au partenaire ; le vol de vie soigne sans afficher de chiffre ; « Coffres de test » ajouté au mode test.
- Défaut ancien trouvé par l'essai coop du CI (première fabrication de l'étape 2 refusée) : deux squelettes
  sortis de terre l'un dans l'autre (groupe serré contre un mur, ou sur un squelette debout) se repoussaient
  d'un coup en sortant (0,5 à 0,6 m en une image, chez l'hôte comme chez l'invité). Corrigé : ils sortent
  écartés d'au moins 1 m (`GenerateurEnnemis._ecarter`) ; mesuré ensuite : 0,05 m par image au plus.
- Tests : 227 en tout, dont 30 nouveaux (vérifiés par sabotage : 59 sabotages, tous vus) ; essais coop (arène et expédition) étendus :
  chacun voit l'arme et les PV max du héros de l'autre.

## Cale et extraction d'urgence (jalon 4, étape 3 — choix de Téo du 03/11)
- **Tri de la cale** : à la fin d'une expédition réussie, si le sac dépasse 8 objets (`cale_places`), écran
  « Charger la cale » avant l'écran de fin : les plus rares cochés d'avance (à rareté égale, les premiers
  ramassés) ; toucher un objet le garde ou le revend ; pas plus de 8 gardés (on peut en garder moins).
  Les doublons ne prennent pas de place. À deux, chacun trie son sac sur son téléphone.
- **Revente** des objets non gardés : 2 / 5 / 10 / 15 / 20 doublons (Commun → Maudit, `cale_prix_raretes`).
  Écran de fin : « Butin rapporté : 8 objets et N doublons » et « Revendus faute de place : … ».
- Appli fermée ou mise en arrière-plan pendant le tri, ou Menu / retour : la sélection en cours est gardée.
- **Cale visible en route** (annexe retenue) : « Sac : 9 objets / cale 8 · 27 doublons », en orange au-delà.
- **Extraction d'urgence** : l'hôte part en pleine expédition → l'invité garde son sac (tri de la cale si
  besoin), écran « Extraction d'urgence ! ». Son téléphone ne peut pas savoir si c'est l'hôte qui est parti
  ou son propre Wi-Fi qui a coupé : dans les deux cas, il garde son butin. L'hôte, lui, continue seul.
- Essai coop « hôte parti » (`FIN=hote_parti`) ajouté au CI.

## Repaire et matériaux (jalon 5, étape 1 — choix de Téo du 04/11)
- **Matériaux** : bois de coque (matelots), fer noir (arbalétriers), essence maudite (prêtres noyés) ; chance 30 / 40 /
  50 %, 1 à 2 par tas, tas grossis par la malédiction (comme les doublons) ; le Bosco 6 / 4 / 3, le coffre 4 / 2 / 1.
  Au sol : planches, lingots, fiole qui luit, sur un disque à leur couleur ; ramassés comme les doublons (sans place
  dans la cale, perdus en cas de défaite ; le Doublon terni ne compte que pour les doublons). En route, une 2e ligne
  sous le sac : « 4 bois de coque · 2 fer noir · 3 essence maudite ». Écran de fin : « Matériaux : … », « Matériaux
  perdus : … », « Entrepôt plein : … revendus, +N doublons ». À deux, chacun les siens (réseau version 11).
- **Entrepôt** : plafonds 150 / 80 / 40 (niveau 2, étape 3 : 400 / 200 / 100) ; au-delà, le surplus rapporté est
  revendu (1 / 2 / 3 doublons l'unité). Les doublons et les coffres n'ont pas de limite (choix de Téo).
- **Sauvegarde version 2** : matériaux, niveaux du bateau (0 à 3) et du repaire (1 et 2) ; une sauvegarde version 1 est
  convertie (rien n'est perdu) ; valeurs abîmées ramenées dans leurs bornes ; un tri en attente garde ses matériaux.
- **Repaire** (`game/repaire/`) : grotte avec quai et navire amarré (fait par code : coque, pont, château arrière, deux
  mâts et voiles gonflées, beaupré, pavillon noir, lanternes vertes ; il tangue). On y marche au joystick (pas dans
  l'eau). Quatre lieux, chacun avec son enseigne dorée : salle des cartes (table et carte), chantier naval (au quai),
  forge (foyer rougeoyant, enclume), entrepôt (coffres, caisses). Devant un lieu : bouton « Ouvrir : … » ; raccourcis à
  droite ; en haut, doublons et matériaux. Un lieu s'ouvre en panneau par-dessus la grotte (retour d'Android : ferme
  d'abord le panneau). Chantier naval et forge : un message (étapes 2 et 3).
- **Salle des cartes** : destination (le Récif des Pendus), le héros (celui qui marche dans le repaire change aussitôt),
  la malédiction, « Lever l'ancre ! ». Après l'expédition (finie ou abandonnée), retour au repaire, sur le quai ; bouton
  de l'écran de fin : « Retour au repaire ». À deux : on lance toujours depuis « Jouer à deux », et chacun revient à son
  repaire.
- **Écran titre** : « Le repaire » remplace « Expédition » ; l'Équipement est passé à l'entrepôt (son retour ramène devant
  l'entrepôt). Mode test : « Ressources de test » (1 000 doublons, entrepôt rempli jusqu'au plafond).
- Corrigé en passant (trouvé par le test « squelettes écartés », 1 fois) : dans une petite salle, un squelette pouvait
  encore sortir à 0,7 m d'un autre ; il cherche maintenant plus loin, et faute de place prend le point le plus libre
  (test durci : 80 tirages ; l'ancien code échoue 2 fois sur 3).
- Tests : 288 (28 nouveaux : `test_matieres.gd`, `test_repaire.gd` ; 31 sabotages, tous vus) ; essai coop de l'expédition :
  l'invité voit, ramasse et range son tas de fer noir.

## Chantier naval et bateau (jalon 5, étape 2 — choix de Téo du 04/11)
- **Chantier naval** (lieu du repaire) : les 4 améliorations, chacune « Cale   niveau 1 / 3 », ce qu'elle donne → le niveau
  suivant, son prix (en rouge avec « il manque … » si l'on ne peut pas payer) et « Améliorer ». Un niveau à la fois : un
  double appui n'achète jamais deux fois (journal des achats dans la sauvegarde). Prix (`bateau_prix`) : 60 à 80 doublons
  et 12 à 20 matériaux pour un 1er niveau, ~200 doublons et 35 à 45 matériaux pour un 3e (une quinzaine d'expéditions
  réussies pour tout).
- **Effets** : Cale 8 → 10 / 12 / 15 objets ; Voiles 45 → 40 / 35 / 30 s dans la chaloupe (à deux : les meilleures
  voiles des deux, fixées au départ) ; Coque : malédiction de départ jusqu'à 2 → 3 / 4 / 5 (« Plus haut : améliorez la
  coque au chantier naval » sous le choix ; à deux, la coque de l'hôte ; Mode test : « Malédiction : toutes ») ; Bordée
  0 → 1 / 2 / 3 tirs par expédition.
- **Bordée** (visée au joystick, choix de Téo) : bouton « Bordée » avec le nombre de tirs (caché sans canons, grisé
  quand c'est vide). Maintenu : un grand anneau rouge au sol, devant le héros ; en glissant le pouce depuis le bouton,
  il suit la direction et s'éloigne jusqu'à 10 m ; relâché : « Bordée ! », 5 boulets autour du point visé, un cercle
  rouge qui se remplit 0,9 s puis le boulet tombe et explose (45 dégâts aux squelettes à 1,6 m ; Bosco : moitié).
  Héros épargnés. Un toucher annulé (appel) ou une mise en arrière-plan ne tire rien. Clavier : B.
- **À deux** : le bateau de chacun est envoyé à la connexion (réseau version 12). Chacun sa cale et ses tirs ; l'invité
  vise chez lui, l'hôte tire (s'il lui reste des tirs) et les deux voient les mêmes boulets.
- **Bateau qui change d'aspect** (annexe retenue) : caisses sur le pont (cale), voiles de plus en plus sombres avec une
  lueur verte (voiles), bandes de fer sur la coque, canons sur les flancs (bordée).
- **Pastille « ! »** (annexe retenue) : au-dessus du chantier et sur son raccourci quand une amélioration est payable.
- Petits choix faits sans Téo, à lui signaler : sans glisser le pouce, la bordée tombe à 2,5 m devant le héros ; le
  message « Bordée ! » s'affiche chez les deux joueurs ; la bordée ne sert qu'en expédition (pas dans l'arène).
- Tests : 304 (16 nouveaux dans `test_bateau.gd` ; 29 sabotages, tous vus) ; essai coop de l'expédition étendu : les
  voiles de l'invité comptent chez les deux (35 s), sa bordée est tirée par l'hôte et ses 5 boulets tombent chez lui.

## Refonte de l'interface (05/11, demande de Téo : « une direction artistique professionnelle »)
Jalon 6 réordonné par Téo : la refonte d'abord (elle remplace « écrans restants »), les sons ensuite.
- **Choix de Téo** : matières créées sur mesure (pas de pack) ; police « gravure marine » (IM Fell English SC pour les
  titres, Alegreya Sans pour le jeu, licence OFL) ; direction validée sur les planches (`tools/ui/matieres.py planches`) ;
  pas de chambre des reliques (reportée après le MVP) ; l'inventaire = les coffres de l'écran Équipement.
- **Thème commun** (`assets/ui/theme_damnes.tres`, thème du projet) fabriqué par `tools/ui/fabriquer_theme.gd` ; matières
  (`assets/ui/matieres/*.png`) fabriquées par `tools/ui/matieres.py textures` : bouton en planche cerclée de fer (normal,
  appuyé, grisé), parchemin cloué sur bois, cuir cousu, plaque de fer oxydé, affiche, cordage, trait d'encre, rose des
  vents, sceaux de cire, volutes. Variantes : BoutonPrincipal, BoutonPetit, BoutonOnglet (cuir) / BoutonOngletActif
  (planche), BoutonAffiche, LabelTitre, LabelSousTitre, LabelGras, LabelEncre (et Gras, Titre, Discret), PanelParchemin,
  PanelCuir, PanelPlaque. `EffetsUI` : bouton qui s'enfonce, arrivées, fondus au noir.
- **Écrans refaits** : écran titre (navire 3D au ponton de nuit, `DecorMenu` ; titre gravé, planches clouées le long d'une
  corde) ; repaire (plaque, bourse en cuir avec icônes — annexe « bandeau » de Téo —, raccourcis en planches, sceaux
  « ! » qui battent, aussi en 3D, enseignes en police des titres qui s'effacent sous l'interface, joystick en boussole) ;
  les quatre lieux (parchemin cloué, plaque qui déborde, encre) ; choix du héros (avis de recrutement) ; « Jouer à deux »
  (le navire en fond, rôle d'équipage sur parchemin) ; Équipement (cuir, coffres sur parchemin, fiche sur cuir) ; HUD de
  combat (jauge de vie en fourreau de cuir avec la perte qui fond, médaillons cerclés de fer, Menu en planche, textes en
  police des titres, chiffres en Alegreya ExtraBold) ; barre du Bosco ; tri de la cale et écran de fin (parchemins).
- **Réglages** (choix de Téo : la qualité graphique seulement, ce qui marche déjà ; volumes avec les sons) : Économie
  (sans ombres ni halo, image à 75 %), Normale (le jeu tel quel, réglage de départ), Belle (bords lissés, ombres plus
  douces). Fichier à part de la sauvegarde. Ouvert depuis l'écran titre (planche « Réglages ») et le carnet.
- **Carnet de bord** (annexe retenue par Téo) : Menu, dans le repaire, ouvre le carnet (Reprendre / Réglages / Écran
  titre) au lieu de quitter tout de suite ; toucher à côté ou le retour d'Android le referme.
- **Vitrine « Voir les héros »** (06/11) : « Retour » et plaque « Les héros », noms en police des titres, bandeau de
  cuir pour la consigne et les actions, compteur discret, bords assombris (`EffetsUI.vignette`, partagé avec le choix
  du héros).
- Ensuite (Téo, 06/11) : revoir l'identité visuelle ; puis les sons.

## Identité visuelle façon Diablo IV (06/11, demande de Téo : « moins cartoon »)
- Téo veut revoir les personnages, les décors et la lumière, « façon Diablo IV ». Planche d'essai sur une salle figée
  (`tools/capture_style.gd`) : a lumière, b textures réalistes (Poly Haven, CC0 : pavés, pierre, bois, métal rouillé,
  envoyées par Téo), c personnages retouchés. Choix de Téo : **tout** (a, b, c rapide, puis c refait dans Blender), avec
  la noirceur de la planche. Ordre : lumière → personnages rapide → textures → personnages refaits ; APK à chaque étape.
- **Étape 1, lumière** : `Ambiance` (fond presque noir, ambiance faible et grise, AgX, saturation 0,6, contraste,
  brume, lune froide et faible, torches orangées qui s'éteignent vite), `HaloHeros` (une lumière chaude suit chaque
  héros, côté caméra), bords d'écran sombres ; palette KayKit du donjon assombrie (`kaykit_dungeon.tres`). Zones
  d'annonce, visée et carreau en rouge « au-delà du blanc » pour rester lisibles ; braises de la forge moins vives.
- **Étape 2, personnages (version rapide)** : `OsProportions` (modificateur d'os après l'animation) : crânes des
  squelettes à 0,64 (capuche, chapeau, casque suivent ; les os qui volent gardent cette taille), tête des héros à 0,8 ;
  os jaunis et mats (`kaykit_squelette.tres`) ; yeux verts (rouges pendant l'annonce, comme avant). Chiffres de dégâts :
  le contour s'efface avec le chiffre (il restait un chiffre noir en fin de course, plus visible dans le noir).
- **Étape 3, textures réalistes** (Poly Haven, CC0, envoyées par Téo) : `Matieres` + `matiere_monde.gdshader` : sols
  en pavés boueux, murs, piliers et éboulis en pierre taillée (la texture remplace la couleur KayKit), bois et métal en
  « grain » (veines et rouille sur la couleur KayKit), battants de porte en bois ; foyer de la forge en pierre. Posées en
  mètres du monde (pas besoin de Blender : un tirage par carte, moins cher qu'une projection sur trois axes). Décision :
  KayKit pour les formes, Poly Haven pour les matières. Pas encore : navire, chaloupe, enclume (faits par code),
  écran titre et vitrine (leur propre lumière).
- Au passage (suite complète) : deux squelettes sortis à 0,94 m l'un de l'autre, avec 4 squelettes seulement, contre
  un mur. `GenerateurEnnemis._ecarter` cherche maintenant, en dernier recours, la place libre la plus proche dans toute
  la salle (test fait exprès : salle pleine, une seule place, loin).
- Annexes proposées (pas encore retenues) : brume au ras du sol, poussière dans la lumière des torches.

## Attaque de base façon Diablo (05/11, demande et choix de Téo)
Téo : « le gameplay pas assez proche de Diablo, c'est peut-être l'attaque de base ». Ce qui le gênait : frapper dans le
vide, se sentir planté, pas assez de squelettes touchés ; modèle Diablo 3/4 ; les deux héros ; nerf de la téléportation.
- **Bretteur** :
  - **Bond** : chaque coup bondit sur le squelette visé s'il est à 4 m ou moins (il arrive au contact pile pour
    l'impact) ; plus loin, un petit pas comme avant. Le joystick choisit la cible (comme la visée).
  - **Taillades en arc** : les coups 1 et 2 touchent tout un arc de 150° jusqu'à 2,3 m devant lui.
  - **Moulinet** (3e coup, animation « 2H_Melee_Attack_Spin ») : un tour complet qui touche tout à 2,4 m autour ; il va
    au bout (choix du 30/10) mais plus vite (choix du 05/11) : 0,45 s au lieu de 0,63 s.
  - Dégâts et PV des squelettes inchangés : la horde tombe plus vite parce que chaque coup en touche plusieurs.
- **Occultiste** :
  - **Tir guidé** : le projectile s'incurve vers le squelette le plus près de sa direction (cône de 35°), jusqu'à
    180° par seconde.
  - **Explosion** (choix de Téo) : à l'impact, il blesse aussi les squelettes à 1,2 m autour (9 dégâts, coups
    « discrets » : ni arrêt sur image ni secousse de plus) ; gerbe verte et disque au sol.
  - **Téléportation à 2 charges de 3 s** (choix de Téo ; avant : toutes les 0,9 s) : deux sauts d'affilée puis attendre ;
    pastille du nombre de charges sur le bouton, liseré qui fait le tour quand une charge revient.
- Réseau version 14 (l'invité prédit son héros avec les mêmes règles). Captures : `tools/capture_attaque.gd`.
- Petits choix faits sans Téo, à lui signaler : portée du bond 4 m ; l'explosion fait autant de dégâts aux voisins
  que le tir à sa cible (9) ; elle part aussi quand le tir touche un mur ; la jauge façon Diablo 3/4 (l'attaque remplit,
  les compétences dépensent) gardée pour une étape suivante.
- Tests : 328 (10 dans `test_attaque_diablo.gd`, 1 dans `test_sante_recharge.gd`, 3 anciens mis à jour) ; 17 sabotages,
  tous vus ; essais coop réussis (arène 36, expédition 54, Wi-Fi moyen 54, hôte parti 56 vérifications).

## Forge et niveaux 2 du repaire (jalon 5, étape 3 — choix de Téo du 04-05/11)
- **Forge** (lieu du repaire), trois onglets :
  - **Améliorer** : une arme Commune ou Rare monte d'une rareté ; son effet de base grandit (×1,25 puis ×1,5) et elle
    gagne un effet en plus tiré au hasard (jamais un qu'elle a déjà). Portée, elle le reste. Prix : Commun → Rare
    80 doublons + 10 fer noir ; Rare → Épique 160 doublons + 25 fer noir + 5 essence maudite. Ni les reliques ni les
    objets uniques ; Épique est le plus haut.
  - **Recycler** : n'importe quel objet des coffres disparaît et rend des matériaux (arme : fer noir 2 / 4 / 8 / 12 pour
    Commun / Rare / Épique / unique ; relique : essence maudite 1 / 2 / 4 / 6). Deux appuis (« Sûr ? Recycler » en rouge) ; un objet porté est
    retiré au héros (écrit en rouge sur sa ligne). Entrepôt presque plein (choix de Téo du 05/11) : il rend ce qui
    entre, **le reste est perdu** (« 1 fer noir perdu : entrepôt presque plein », écrit avant d'appuyer) ; sans aucune
    place, « Recycler » est grisé (« Rendrait 2 essence maudite : entrepôt plein »). Jamais revendu en doublons.
  - **Relancer** (forge niveau 2, choix de Téo : **on choisit l'effet**) : chaque effet en plus d'un objet Rare ou Épique
    a son bouton « Relancer : +6 % de coups critiques » ; il est remplacé au hasard par un effet que l'objet n'a pas.
    40 doublons + 4 essence maudite. Sans le niveau 2, l'onglet propose « Agrandir la forge ».
- **Niveaux 2** : forge 300 doublons + 40 bois + 20 fer (débloque la relance) ; entrepôt 250 doublons + 60 bois (plafonds
  150 / 80 / 40 → 400 / 200 / 100), bouton « Agrandir » dans l'entrepôt. Une seule fois chacun.
- **Pastille « ! »** : sur la forge et l'entrepôt quand leur niveau 2 est payable (pas pour chaque arme améliorable :
  la pastille brillerait presque tout le temps).
- Tous les achats sont notés au journal de la sauvegarde ; chaque bouton redit ce qu'il a vu (rareté, effet), et dans
  les lieux du repaire un appui est ignoré pendant 0,4 s après une action (voir la relecture ci-dessous).
- Petits choix faits sans Téo, à lui signaler : les valeurs du recyclage ; un objet unique se recycle (12 fer pour une
  arme Légendaire) mais ne s'améliore pas ; la pastille de la forge ne signale que son agrandissement.
- Corrigé en relisant : l'arme recyclée restait dans la main du héros qui marche dans le repaire (jusqu'à en sortir).
- Tests : 317 après la relecture (12 dans `test_forge.gd`, 1 de plus dans `test_bateau.gd`) ; 42 sabotages de l'étape 3
  et de la relecture (3 tests renforcés en route : un unique mal rangé, l'identifiant d'un objet recyclé qui restait dans
  l'équipement, le second effet d'un objet à relancer) ; essais coop réussis (arène 36, expédition 54, Wi-Fi moyen 54,
  hôte parti 56 vérifications).

## Objets uniques : une fois par héros (04/11, choix de Téo)
- Un même objet unique (Légendaire ou Maudit) ne se porte qu'une fois par héros ; l'autre héros peut porter l'autre
  exemplaire. Équiper le 2e exemplaire retire le premier (comme un objet déplacé d'une relique à l'autre) ; écran
  Équipement : « (en double) » dans la liste et « Objet unique : un seul par héros. L'exemplaire porté sera retiré. »
  sur la fiche. Une sauvegarde de l'APK 0.4.18 avec deux exemplaires portés garde le premier ; le héros ne compte
  qu'un exemplaire (même si l'autre téléphone en envoie deux). Deux reliques ordinaires pareilles restent permises.
- Corrigé en passant : la comparaison ▲▼ d'un objet déplacé d'une relique à l'autre montrait un gain qui n'existait
  pas (elle comparait avec l'équipement déjà sans l'objet).
- Tests : 260 (4 nouveaux, 11 sabotages, tous vus) ; essai coop de l'expédition (Wi-Fi moyen) réussi.

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
- APK 0.2.8 envoyé à Téo.

## Parade parfaite (30/10, choix de Téo)
- La Parade coupe un coup du Bretteur avant son impact (comme la roulade).
- Parade parfaite : le coup arrive au plus 0,35 s après l'appui (0,25 au début). Riposte critique (dégâts doublés),
  étourdissement 2,2 s (1,4), Parade rendue aussitôt (enchaîner les parades dans la horde). Une parade
  plus tôt reste une parade ordinaire (riposte normale, recharge de 4 s).
- Indicateur avant : la zone rouge au sol devient dorée 0,4 s avant le coup (un peu avant la fenêtre
  parfaite, pour laisser le temps de réagir : ≈ 0,2 s + le délai de l'écran tactile). Aussi chez l'invité.
- Indicateur pendant : gerbe d'étincelles dorées, éclair de lumière, « PARFAIT ! » doré, court ralenti
  (seul) ou arrêt de l'animation du héros (en coop), secousse.
- Réseau : version 3. Non retenu : l'onde de choc qui repousse les squelettes proches.
- Limite connue : contre les squelettes (30 PV), la riposte ordinaire tue déjà ; les dégâts doublés et
  l'étourdissement plus long serviront contre les ennemis plus solides (mini-boss). En coop, la zone
  dorée de l'invité est calée sur l'hôte, mais son appui sur Parade met le temps d'un trajet réseau à
  arriver chez l'hôte : sa parade parfaite est un peu plus dure à réussir.

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
| 30/10/2026 | Parade : elle coupe le coup en cours ; parade parfaite en bonus (0,25 s), zone dorée avant le coup + étincelles, « PARFAIT ! » et ralenti, Parade rendue. Onde de choc : non retenue. |
| 31/10/2026 | Jalon 3, étape 3 (choix de Téo) : Bosco « brute à la hache » (tourbillon, charge qui le laisse sonné 2 s contre un mur, coup au sol ; rage à mi-vie + 3 matelots) ; coups mi-parables (seul le coup au sol se pare, les gros coups rouge sombre sont imparables) ; ~1 min 30 en solo ; malédiction 0–5 choisie au départ avec l'échelle proposée (+20 % de butin par niveau) ; chaloupe : tenir 45 s à bord, le compte s'arrête si personne n'y est ; annexe retenue : écran de fin enrichi. |
| 05/11/2026 | Refonte de l'interface (demande de Téo) avant les sons ; matières créées sur mesure ; police « gravure marine » (IM Fell English SC + Alegreya Sans) ; direction validée sur planches ; pas de chambre des reliques ; inventaire = coffres. Annexes retenues pour le jalon 6 : jauge façon Diablo 3/4, bandeau derrière les ressources (fait). |
| 05/11/2026 | Écran Réglages : seulement la qualité graphique (3 niveaux, Normale au départ) ; non retenus pour l'instant : limite 30/60 i/s, mode gaucher, compteur d'images, page Crédits, vibrations, cacher le mode test. Retenu : le carnet de bord du repaire. |
| 05/11/2026 | Attaque façon Diablo (demande de Téo, modèle Diablo 3/4) : Bretteur qui bondit sur sa cible (4 m), taillades en arc, moulinet 360° qui va au bout mais ~30 % plus vite ; tir de l'Occultiste guidé qui **explose** (1,2 m) ; téléportation **2 charges de 3 s**. Remplace directement l'ancienne attaque. Jauge façon Diablo 3/4 : plus tard. |
| 05/11/2026 | Jalon 5, étape 3 (choix de Téo) : forge et niveaux 2 avec les prix proposés ; « Relancer un effet » : **on choisit l'effet** à relancer (remplacé au hasard). Étape 3 lancée après l'APK 0.5.20. Après la relecture : recycler avec l'entrepôt presque plein **rend ce qui entre, le reste est perdu** (écrit avant d'appuyer ; sans aucune place, grisé) — pas de revente en doublons. |
| 04/11/2026 | Combats navals et abordages : gardés pour après le MVP, comme prévu (Téo, après explication de la bordée). |
| 04/11/2026 | Jalon 5, étape 2 (choix de Téo) : bordée **visée au joystick** (bouton maintenu, la zone suit le pouce, relâcher pour tirer). Étape 2 lancée après l'APK 0.5.19. |
| 04/11/2026 | Jalon 5 (choix de Téo) : plan validé (matériaux bois de coque / fer noir / essence maudite lâchés par matelots / arbalétriers / prêtres ; repaire 3D où l'on marche avec 4 lieux et raccourcis ; bateau : cale 8→10/12/15, voiles 45→40/35/30 s, coque = malédiction de départ 0–2 puis 3/4/5, bordée 0→1/2/3 tirs ; une quinzaine d'expéditions réussies pour finir le bateau ; à deux : chacun sa cale et sa bordée, les meilleures voiles des deux, malédiction limitée par la coque de l'hôte). Forge : « améliorer » = **monter d'une rareté** (armes seulement, pas les uniques). Coque : **comme la conception** (le Mode test débloque tout). Entrepôt : **plafond des ressources seulement** (surplus revendu en doublons, coffres sans limite). Annexes retenues : bateau qui change d'aspect, pastille « ! » sur les lieux. Non retenues : vendre à l'entrepôt, prochain achat en vue. Ordre : 1) ressources, sauvegarde v2, repaire, salle des cartes, entrepôt ; 2) chantier naval et 4 améliorations (bordée comprise) ; 3) forge, niveaux 2, prix, relecture, APK. |
| 04/11/2026 | Un objet unique ne se porte qu'une fois par héros (l'autre héros peut porter l'autre exemplaire). |
| 03/11/2026 | Jalon 4, étape 3 (choix de Téo) : tri de la cale à la fin d'une expédition réussie (8 objets, les plus rares cochés d'avance, doublons sans limite, chacun trie le sien à deux) ; les objets non gardés sont **revendus en doublons** selon leur rareté ; hôte parti en pleine expédition = **extraction d'urgence** de l'invité (il garde son sac, tri de la cale) ; annexe retenue : cale visible en route (« Sac : 9 objets / cale 8 » en orange). Non retenue : vendre depuis les coffres. |
| 01/11/2026 | Jalon 4, étape 2 (choix de Téo) : tout en un seul APK (uniques compris) ; écran Équipement ouvert depuis l'écran titre ; l'équipement compte partout, arène comprise. |
| 01/11/2026 | Jalon 4, étape 2 (choix de Téo) : liste des objets validée telle quelle (armes, reliques, effets en plus des Rares et Épiques, 5 objets uniques ; voir « Butin au sol ») ; on change d'équipement **entre deux expéditions** seulement ; défaite = **tout le sac perdu** (« sécurisés dès le ramassage » de la conception = à soi dès qu'on le prend, personne ne peut le voler) ; annexe retenue : comparaison ▲▼ avec l'objet porté. Non retenues : « Équiper le meilleur », annonce d'un objet rare. |
| 31/10/2026 | Jalon 4 (choix de Téo) : butin au sol façon Diablo (colonnes de lumière par rareté, ramassé en passant dessus, chacun le sien à deux, perdu en cas de défaite) ; les armes changent d'apparence en main dès ce jalon ; cale de base dès maintenant (8 objets, tri au-delà). Ordre : 1) butin au sol et ramassage, 2) inventaire, équipement, effets en combat et sauvegarde (liste des objets à valider avant), 3) tri de la cale, relecture, APK. |
| 30/10/2026 | Jalon 3, étape 2 (choix de Téo) : la Parade renvoie les carreaux d'arbalète ; un coup interrompt l'incantation du prêtre noyé ; salles piège avec dalles à pics et tonneaux de poudre explosifs ; l'arène d'entraînement garde seulement les matelots. |
| 30/10/2026 | Réglages (choix de Téo) : le joystick ne coupe plus le 3e coup du combo (le lourd va au bout) ; fenêtre de la parade parfaite 0,35 s (zone dorée 0,4 s avant le coup). Étape 2 du jalon 3 lancée. |
| 30/10/2026 | Jalon 2 : coop essayée par Téo sur ses deux téléphones, « ça marche » (porte franchie). |
| 30/10/2026 | Jalon 3, choix de Téo : expédition courte (4 salles, puis le Bosco, puis la chaloupe) ; PV gardés d'une salle à l'autre + orbes de vie lâchées par les squelettes (façon Diablo) ; en coop, la porte s'ouvre quand les deux héros sont devant la même. Ordre : 0) relecture des ajouts du jalon 2, 1) l'expédition (salles, portes, coop, mode debug ; APK), 2) arbalétrier, prêtre noyé, pièges (APK), 3) Bosco, malédiction, chaloupe sous les vagues, écran de fin (relecture, APK). |

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
- ~~Parade pendant l'élan d'un coup~~ : tranché le 30/10 (oui, avec la parade parfaite).
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

## Relecture des ajouts du jalon 2 (combat nerveux, parade) et corrections — 30/10
- Bloquant, corrigé : la zone d'annonce s'affichait une image pleine et dorée (l'annonce d'avant) au
  début de chaque annonce, chez l'hôte et chez l'invité. Test renforcé (sans appel manuel).
- Corrigé : instantanés au-dessus d'un paquet Wi-Fi (jusqu'à 1 960 octets) → squelettes emballés en
  nombres à virgule simple, vaincus en format court, squelettes en suppression ignorés ; test de taille.
  Réseau version 4.
- Corrigé : test de la horde qui passait sans la fonctionnalité (morts à des moments différents) ; test
  « en coop, la parade parfaite ne ralentit rien » ajouté ; en coop, le héros n'est plus figé par la
  parade parfaite (sa riposte touchait avant le sabre).
- Corrigé : os qui sortaient de la salle (poussée réduite, murs invisibles de 8 m) ; traînées du sabre
  avec une matière partagée ; chez l'invité, os qui partent loin du tueur et traînée dans la bonne
  direction ; seuil de fluidité de l'essai coop remis à 0,4 m ; l'essai vérifie une parade PARFAITE.
- Tranché par Téo : le 3e coup n'est plus coupé par le joystick ; fenêtre parfaite portée à 0,35 s.

## Relecture de fin du jalon 3 (agent relecteur) et corrections — 31/10
Aucun plantage ni blocage trouvé. Corrigé (chaque correction a un test qui échoue sans elle) :
- **Riposte contre le Bosco** : il lance son coup au sol à ~4 m, la riposte (portée 3 m) frappait dans le
  vide ; elle atteint maintenant l'ennemi paré jusqu'à la portée de son propre coup (`portee_riposte`).
- Chaînes posées au début du cri de rage : les 3 matelots ne venaient jamais ; ils viennent quand même.
- L'équipage du Bosco sortait derrière lui (parfois contre un mur) : il sort devant, jamais dans un mur.
- Sur le quai à deux, trop de squelettes faisaient dépasser l'instantané d'un paquet Wi-Fi : une vague attend
  tant qu'il y a déjà 8 squelettes debout (test de taille du quai ajouté). Toutes les vagues sortent de l'eau.
- Gerbes d'eau chez l'invité au mauvais endroit ; messages du centre de l'écran (Bosco, pièges, coffre,
  chaloupe) seulement chez l'hôte : corrigés.
- « Salle vidée » annoncé deux fois quand le Bosco meurt avec son équipage (aurait doublé le butin au jalon 4).
- Une flaque (ou un carreau en vol) suivait dans la salle suivante et blessait encore.
- Partenaire parti : la horde de l'hôte oubliait la malédiction et la règle des salles piège.
- Tourbillon : il ne blessait qu'au tout début de la rotation ; il blesse tant que la hache tourne (une fois).
- Mot « Chaloupe » sur la tête du héros à bord : placé au-dessus de la barque. Barre du Bosco redessinée
  seulement quand ses PV changent.
- Restés en l'état, à signaler à Téo : à la malédiction 5, le Bosco enragé dès le début pousse quand même son
  cri à mi-vie (et appelle son équipage) ; « Os durcis » s'applique aussi au Bosco (combat plus long) ; à deux,
  un seul héros debout à bord suffit pour partir ; l'équipage qui s'effondre peut lâcher des orbes.

## Relecture de fin du jalon 5 (agent relecteur) et corrections — 05/11
Aucune perte de sauvegarde ni coop cassée trouvée (conversion depuis l'APK 0.4.18, matériaux à deux, bateau, repaire,
forge, objets uniques vérifiés). Corrigé (chaque correction a un test qui échoue sans elle) :
- **Double appui dans le repaire** (vrais touchers simulés par le relecteur) : après un achat, le panneau se refait tout
  de suite et le bouton suivant apparaît sous le doigt ; un double appui achetait la cale niveaux 1 et 2, montait un sabre
  de Commun à Épique, relançait deux fois (l'effet obtenu perdu) ou recyclait sans vraie confirmation (même l'arme
  portée). Un appui est maintenant ignoré pendant 0,4 s après une action, dans tous les lieux.
- **Bordée de l'invité** : il décomptait son tir dès l'appui sans que l'hôte lui redise le vrai compte ; un tir refusé
  par l'hôte (changement de salle, chaloupe qui part, héros vu à terre) restait perdu chez l'invité. L'hôte redit
  maintenant le compte (réseau version 13) ; et rien ne part sous l'écran noir de l'arrivée.
- **Recycler, entrepôt plein** revenait à vendre depuis les coffres (refusé par Téo le 03/11) : Téo a choisi le 05/11
  « rend ce qui entre, le reste perdu » (voir la forge).
- Trouvé en relisant avant la relecture : l'arme recyclée restait dans la main du héros qui marche dans le repaire.

## Relecture de fin du jalon 4 (agent relecteur) et corrections — 03/11
- Geste ou bouton « retour » d'Android : il abandonnait l'expédition d'un seul geste (tout le sac perdu). Il fait
  maintenant comme le bouton Menu (deux appuis) ; pendant le tri, il charge la cale ; après la fin, menu.
- Extraction d'urgence : un invité **à terre** quand l'hôte part perd tout (comme un héros seul à terre) ; une
  coupure due à **sa propre pause** (appli en arrière-plan plus de 3 s) est un abandon (conception : « fermer
  l'appli en raid = abandon »).
- Quai de la chaloupe : les squelettes relevés (Grimoire du Pendu) comptent pour le plafond des vagues (sinon
  l'instantané dépassait un paquet Wi-Fi).
- Eau de la Lame du Noyé, épines, coups des squelettes relevés : « coups discrets » (chiffre affiché, ni arrêt sur
  image, ni secousse, ni figeage) ; sinon une traînée d'eau sous une horde figeait le jeu toutes les 0,5 s.
  Réseau version 10.
- Tri de la cale : une simple mise en arrière-plan (appel, notifications) ne valide plus le tri ; la sélection est
  notée dans la sauvegarde et encaissée au lancement suivant si Android a fermé l'appli entre-temps.
- La Flasque ne soigne plus sur le quai ; un squelette relevé ne ressort plus dans la salle suivante ; plus de
  salle jouée derrière l'écran de fin (extraction pendant un fondu).
- Doutes du relecteur, corrigés aussi : le Sablier marche pour l'Occultiste (sa téléportation dure 0,12 s mais
  son invulnérabilité 0,3 s) ; un squelette vaincu ne revient jamais à la vie (épines qui tuent le Bosco en
  pleine charge) ; copie de secours de la sauvegarde par renommage (rien n'est réécrit) ; équipement relu
  vérifié (objet existant, à sa place, porté une seule fois).
- Question à Téo : peut-on porter deux fois le même objet unique (deux Talismans : +80 % de dégâts) ? Tranché le
  04/11 : **une fois par héros** (voir ci-dessous).
- Tests : 256 en tout ; 18 nouveaux pour la relecture (`test_relecture_j4.gd`), vérifiés par sabotage.

## Prochaines étapes
0. Essai de Téo de l'APK 0.5.21 (fin du jalon 5 : repaire, chantier, bordée, forge) ; jalon 6 seulement après son feu
   vert. Proposé, pas fait : un bandeau sombre derrière les ressources en haut du repaire (l'enseigne « Salle des
   cartes » passe dessous quand le héros est près de la forge).
1. Essai de Téo du jalon 4 complet (butin, équipement, objets uniques grâce aux « Coffres de test », tri de la
   cale, sauvegarde : fermer l'appli, rien n'est perdu ; à deux : extraction d'urgence).
2. Jalon 5 : repaire et bateau (le butin dépensé change la suite) — plan validé le 04/11 ; étape 1 faite ; étape 2 :
   chantier naval (cale, voiles, coque, bordée, prix, bateau qui change d'aspect, pastille « ! ») ; étape 2 faite ;
   étape 3 : forge (monter d'une rareté, recycler, relancer un effet au niveau 2), niveaux 2 de la forge et de
   l'entrepôt, relecture de fin de jalon.

## Points à trancher plus tard
- Clé de signature définitive : passer à la vraie clé (secrète) **avant** que les sauvegardes comptent,
  car changer de clé oblige à désinstaller le jeu, ce qui efface les parties.

## Informations utiles
- Dépôt GitHub : teodico-cloud/les-damn-s-des-septs-mers (public pour l'instant ; Téo peut le passer en privé).
- APK : https://github.com/teodico-cloud/les-damn-s-des-septs-mers/releases/download/apk-test/damnes-des-sept-mers.apk
- Téo teste sur téléphone Android ; il n'a pas besoin d'ouvrir Godot.
