# Conception — phase A (validée le 21/10/2026)

Version complète avec schémas : document « Les Damnés des Sept Mers — Phase A : Conception »
(https://claude.ai/artifact/B3Q9zHfa89eUG8rHdMSEBk). Ce fichier en est le résumé de référence pour le code.

## En bref
Godot 4.7.2, aucun serveur au MVP, APK fabriqué par GitHub, assets KayKit (CC0).
Le MVP couvre la boucle complète — préparer, raider, s'extraire, améliorer — jouable à deux, en 8 jalons.

## Périmètre
| Système | Dans le MVP | Reporté |
| --- | --- | --- |
| Combat tactile | 2 archétypes, attaque, esquive, 2 compétences chacun | Ultime, Canonnier, Flibustier |
| Raids | 1 région, salles faites main assemblées depuis une graine, malédiction, extraction | Marchands, sanctuaires, événements narratifs, boss final |
| Ennemis | 3 types + 1 mini-boss | Boss, créatures marines |
| Butin | Armes, reliques, matériaux, 5 raretés dont « Maudit », effets qui changent le jeu | Consommables, plans, builds avancés |
| Bateau | 4 stats utiles en raid (cale, coque, voiles, bordée) | Combat naval, abordages, bateau qui change d'aspect |
| Repaire | Salle des cartes, chantier naval, forge, entrepôt | Taverne, chambre des reliques |
| Coopération | 2 joueurs, même zone, mêmes ennemis, réanimation, extraction commune | Invitation par compte, reconnexion en cours de raid |
| Comptes et serveur | Aucun : sauvegarde locale | Sauvegarde en ligne, validation des récompenses par serveur |

## Choix techniques
- Godot 4.7.2, GDScript, rendu Mobile (Compatibility en repli pour les vieux téléphones sans Vulkan).
- APK fabriqué par GitHub Actions : Téo n'a besoin d'aucun PC.
- Données : sauvegarde locale JSON. Pas de PostgreSQL (aucun besoin relationnel au MVP).
- Plus tard : Firebase (comptes, sauvegarde en ligne, mise en relation). La validation serveur des
  récompenses passe par Cloud Functions, qui exige le forfait Blaze (paiement à l'usage, quota gratuit).
- Réseau : multijoueur intégré à Godot ; Wi-Fi local puis WebRTC (plugin officiel webrtc-native 1.2.2,
  compilé pour Android arm64) avec un service de mise en relation.

## Architecture du client (4 couches, chacune n'utilise que celles du dessous)
1. **Interface** : écrans, HUD, joystick. Affiche l'état et transmet les commandes ; ne décide rien.
2. **Gameplay** : héros et combat, ennemis, raid (salles, malédiction, extraction), butin et repaire.
3. **Services globaux (autoloads)** : `balance` (valeurs de réglage), `game_state` (profil en mémoire),
   `event_bus` (signaux partagés), `save_service` (écriture sûre, versions), `net_session` (hôte/invité).
4. **Données** : fichiers `.tres` (objets, ennemis, salles, améliorations, archétypes, équilibrage).

## Coopération
L'hôte décide de tout ce qui compte ; l'invité envoie ses commandes et affiche ce que l'hôte renvoie.
| Ce qui se décide | Qui décide |
| --- | --- |
| Déplacement de son héros | Chaque joueur, contrôlé par l'hôte (vitesse impossible rejetée) |
| Attaques, dégâts, morts | L'hôte |
| IA et position des ennemis | L'hôte |
| Carte du raid | L'hôte tire une graine et l'envoie |
| Butin | L'hôte, séparément pour chaque joueur |
| Progression permanente | Chaque téléphone, une seule fois, à partir du résultat de l'hôte |

Déconnexions au MVP : invité déconnecté = abandon pour lui ; hôte déconnecté = extraction d'urgence
pour l'invité (butin gardé dans la limite de la cale) ; fermer l'appli en raid = abandon.

## Sauvegarde
- Écriture sûre (fichier temporaire vérifié, puis remplacement ; copie de secours ; profil neuf si tout est illisible).
- Numéro de version et conversions automatiques testées.
- Sauvegarde au départ et à la fin d'expédition, à chaque achat, au retour au repaire, à la mise en arrière-plan.
- Anti-doublon : identifiant unique par expédition et par achat ; un résultat déjà encaissé est ignoré.
- Contenu : profil, personnage, inventaire, ressources (doublons, bois de coque, fer noir, essence maudite),
  bateau, repaire, régions, historique (20 dernières), identifiants encaissés. Réglages dans un fichier séparé.

## Systèmes de jeu
- **Combat** : briques réutilisables (santé, zones de coup, statuts, compétences) ; esquive avec
  invulnérabilité réglable ; attaques ennemies annoncées ; réanimation du partenaire.
- **Bretteur** : combo de 3 coups, parade-riposte, fente traversante, roulade.
- **Occultiste** : projectile maudit, marque maudite (bonus de dégâts du partenaire), chaînes spectrales, téléportation courte.
- **Ennemis** : matelot squelette, arbalétrier squelette, prêtre noyé (relève les morts) ; mini-boss : le Bosco Maudit.
- **Raids** : salles faites main tirées d'une réserve selon des règles fixes ; deux portes au choix après
  chaque salle ; malédiction 0–5 (plus dur, meilleur butin) ; extraction = tenir la chaloupe sous les vagues,
  tri du butin selon la cale.
- **Butin** : Commun, Rare (+1 effet), Épique (+2), Légendaire (effet unique), Maudit (puissant avec contrepartie) ;
  effets branchés sur des moments du combat ; objets « sécurisés dès le ramassage ».
- **Bateau** : Cale (butin rapporté), Voiles (extraction plus courte), Coque renforcée (destinations
  dangereuses), Bordée (tir de canon en raid) ; 3 niveaux chacune.
- **Repaire** : salle des cartes, chantier naval, forge, entrepôt ; scène 3D + raccourcis.

## Ordre de développement
| Jalon | Contenu | Test de Téo |
| --- | --- | --- |
| J0 | Projet Godot, dépôt, APK automatique | L'APK s'installe et s'ouvre |
| J1 | Combat solo du Bretteur contre 1 ennemi | Combat agréable et précis ? |
| J2 | Coop sur le même Wi-Fi | Synchro parfaite sur 2 téléphones ? (porte : on corrige avant d'avancer) |
| J3 | Raid jouable : salles, 3 ennemis, mini-boss, malédiction, extraction | Une expédition complète |
| J4 | Butin et sauvegarde | Fermer l'appli, rien n'est perdu |
| J5 | Repaire et bateau | Le butin dépensé change la suite |
| J6 | MVP complet : Occultiste, écrans restants, réglages | Toute la liste du MVP (porte : validation phase C) |
| J7 | Coop par internet (WebRTC, Firebase, code de groupe) | Jouer depuis deux réseaux |

## Risques majeurs
Coop par internet en 4G/5G (serveur relais possible) ; sensations de combat au tactile ; rendu 3D non
visible par Claude (captures de Téo) ; performances sur téléphone moyen ; désynchronisation ;
triche (acceptée au MVP) ; clé de signature perdue ; mise à jour de Godot en cours de route.

## Propositions annexes acceptées
Deux portes au choix après chaque salle · bordée du navire en soutien · objets sécurisés dès le ramassage ·
extraction d'urgence si l'hôte se déconnecte · mode debug dans l'APK de test · un seul fichier d'équilibrage.
