#!/usr/bin/env bash
# Essai de la coop : lance un hôte et un invité (deux copies du jeu sans écran) sur cette machine,
# puis affiche ce que chacun a vu. Usage : GODOT=<chemin de Godot 4.7.2> tools/test_coop.sh [adresse|auto]
# (par défaut 127.0.0.1 ; « auto » : l'invité trouve la partie par les annonces de l'hôte)
set -u
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
SORTIE="build/test_coop"
mkdir -p "$SORTIE"
SCRIPT="$PWD/tools/test_coop.gd"
timeout 60 "$GODOT" --headless --path . -s "$SCRIPT" -- hote > "$SORTIE/hote.log" 2>&1 &
PID_HOTE=$!
sleep 2
timeout 60 "$GODOT" --headless --path . -s "$SCRIPT" -- invite "${1:-127.0.0.1}" > "$SORTIE/invite.log" 2>&1
CODE_INVITE=$?
wait $PID_HOTE
CODE_HOTE=$?
echo "== hôte (code $CODE_HOTE)"
grep -E "MESURE|VERIF|ECHEC|SCRIPT ERROR|ERROR:" "$SORTIE/hote.log" | grep -v "ALSA\|audio\|status < 0"
echo "== invité (code $CODE_INVITE)"
grep -E "MESURE|VERIF|ECHEC|SCRIPT ERROR|ERROR:" "$SORTIE/invite.log" | grep -v "ALSA\|audio\|status < 0"
if grep -qE "SCRIPT ERROR|Node not found|Invalid packet" "$SORTIE/hote.log" "$SORTIE/invite.log"; then
  echo "ECHEC : erreurs dans les journaux"
  exit 1
fi
[ "$CODE_HOTE" = 0 ] && [ "$CODE_INVITE" = 0 ]
