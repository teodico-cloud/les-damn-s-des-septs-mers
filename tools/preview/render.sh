#!/bin/bash
# Rend une capture d'aperçu d'un ou plusieurs modèles .glb avec Godot.
# Usage : tools/preview/render.sh config.json [LARGEURxHAUTEUR]
# Variable GODOT : chemin de l'exécutable Godot 4.7.2 (par défaut : godot).
set -e
R=${2:-1280x720}
GODOT=${GODOT:-godot}
DIR="$(cd "$(dirname "$0")" && pwd)"
CFG="$(realpath "$1")"
mkdir -p "$DIR/../../build" && touch "$DIR/../../build/.gdignore"  # le jeu ignore build/
xvfb-run -a -s "-screen 0 ${R}x24" "$GODOT" --rendering-driver opengl3 --resolution "$R" --path "$DIR" -- "$CFG" 2>&1 \
  | grep -E "SCRIPT ERROR|Parse Error|load fail" || true
