"""Prépare les textures Poly Haven (CC0) pour la planche d'essai du style (tools/capture_style.gd).

Entrée : third_party/polyhaven/<nom>/  (le dossier « textures » des .zip Poly Haven : *_diff_1k.jpg, *_nor_gl_1k.exr,
*_rough_1k.exr|jpg). Sortie : build/style/textures/<nom>_<diff|nor_gl|rough|grain>.png
- les .exr (relief, rugosité) sont lus par OpenEXR (pip install OpenEXR) : Godot ne lit pas leur compression ;
- « grain » : la couleur en gris ramenée autour de 0,82, multipliée à la palette KayKit (bois, métal, os).
Usage : python3 tools/style_textures.py
"""
import glob
import os

import numpy as np
from PIL import Image

SRC, DST = "third_party/polyhaven", "build/style/textures"
CARTES = ("diff", "nor_gl", "rough")


def lire(f):
    if f.endswith(".exr"):
        import OpenEXR
        with OpenEXR.File(f) as e:
            parts = e.channels()
            if "RGB" in parts:
                px = parts["RGB"].pixels
            elif "RGBA" in parts:
                px = parts["RGBA"].pixels[:, :, :3]
            else:
                ch = [parts[k].pixels for k in ("R", "G", "B") if k in parts]
                px = np.stack(ch, axis=-1) if len(ch) == 3 else ch[0]
        return (np.clip(np.asarray(px, dtype=np.float32), 0, 1) * 255 + 0.5).astype(np.uint8)
    return np.asarray(Image.open(f).convert("RGB"))


os.makedirs(DST, exist_ok=True)
for dossier in sorted(glob.glob(os.path.join(SRC, "*"))):
    nom = os.path.basename(dossier)
    for carte in CARTES:
        fichiers = glob.glob(os.path.join(dossier, f"*_{carte}_*"))
        if not fichiers:
            continue
        px = lire(sorted(fichiers)[0])
        if carte == "rough" and px.ndim == 3:
            px = px[:, :, 0]
        Image.fromarray(px).save(os.path.join(DST, f"{nom}_{carte}.png"))
    gris = np.asarray(Image.open(os.path.join(DST, f"{nom}_diff.png")).convert("L"), dtype=np.float32) / 255.0
    grain = np.clip(gris / gris.mean() * 0.82, 0, 1)
    Image.fromarray((grain * 255 + 0.5).astype(np.uint8)).convert("RGB").save(os.path.join(DST, f"{nom}_grain.png"))
    print(nom, "ok")
