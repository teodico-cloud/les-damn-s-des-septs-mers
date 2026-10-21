# Les Damnés des Sept Mers

Jeu mobile Android d'action en 3D isométrique : roguelite pirate, coopération à deux joueurs,
raids sur des îles maudites, amélioration du bateau et du repaire.

Statut : jalon 0 — projet Godot, écran titre et vitrine des héros, APK fabriqué automatiquement.

**Télécharger l'APK de test (Android)** :
https://github.com/teodico-cloud/les-damn-s-des-septs-mers/releases/download/apk-test/damnes-des-sept-mers.apk

- Conception : [docs/conception.md](docs/conception.md)
- Avancement : [docs/avancement.md](docs/avancement.md)
- Crédits des assets : [assets/CREDITS.md](assets/CREDITS.md)

## Lancer les tests
```
godot --headless --path . --import
godot --headless --path . -s addons/gut/gut_cmdln.gd
```

## Fabriquer les modèles des héros
```
tools/fetch_kaykit.sh
pip install bpy
python tools/blender/build_heroes.py all
```
