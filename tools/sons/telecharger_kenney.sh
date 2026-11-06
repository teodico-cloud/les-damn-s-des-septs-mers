#!/usr/bin/env bash
# Télécharge les packs de sons Kenney (CC0, kenney.nl) dont tools/sons/fabriquer_sons.py copie quelques sons :
# Impact Sounds, RPG Audio, Music Jingles (copies publiques sur GitHub, sous forme d'extensions Godot).
# Sortie : third_party/sons/ (ignoré par git).
set -euo pipefail
cd "$(dirname "$0")/../.."
mkdir -p third_party/sons
touch third_party/.gdignore
for depot in kenney-impact-sounds-for-godot kenney-rpg-audio-for-godot kenney-music-jingles-for-godot; do
	if [ ! -d "third_party/sons/$depot" ]; then
		git clone --depth 1 "https://github.com/Boyquotes/$depot" "third_party/sons/$depot"
	fi
done
echo "Packs Kenney prêts dans third_party/sons/"
