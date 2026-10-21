#!/bin/bash
# Télécharge les packs KayKit (CC0) utilisés comme bases, dans third_party/ (ignoré par git).
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/third_party"
for r in KayKit-Character-Pack-Adventures-1.0 KayKit-Character-Pack-Skeletons-1.0 KayKit-Dungeon-Remastered-1.0; do
  if [ ! -d "$ROOT/third_party/$r" ]; then
    git clone --depth 1 "https://github.com/KayKit-Game-Assets/$r" "$ROOT/third_party/$r"
  fi
done
echo "Packs KayKit prêts dans third_party/"
