"""Refait les squelettes KayKit (CC0) des Damnés des Sept Mers (06/11, identité visuelle façon Diablo IV, choix de Téo
« variante 3 + usure » appliqué aussi aux ennemis) : proportions plus élancées (crâne plus petit, buste, bras et jambes
plus longs) et ombres des creux cuites dans les sommets. Les couleurs restent celles de la matière partagée
(assets/materials/kaykit_squelette.tres : os jaunis), que l'import Godot met à la place de celle du modèle.

Même ossature et mêmes animations (95) que les modèles KayKit ; capuche, chapeau, casque et cape, accrochés à un os,
suivent la nouvelle taille de leur os.

Prérequis : tools/fetch_kaykit.sh, Blender en module Python (pip install bpy).
Usage     : python tools/blender/build_squelettes.py [minion|rogue|mage|warrior|all]
Sortie    : assets/models/enemies/Skeleton_<Nom>.glb (ou SQUELETTES_SORTIE=<dossier> pour un essai)
Réglages  : SQUELETTES_PROPS='{"head": [0.6, 0.6, 0.6]}' remplace des proportions (essais)
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
_argv = sys.argv
sys.argv = [_argv[0]]   # (build_heroes lit son propre argument : on ne lui passe rien)
import build_heroes as bh   # noqa: E402
sys.argv = _argv
import bpy   # noqa: E402
from mathutils import Matrix   # noqa: E402

SRC = os.path.join(bh.REPO, "third_party", "KayKit-Character-Pack-Skeletons-1.0", "addons",
                   "kaykit_character_pack_skeletons", "Characters", "gltf") + os.sep
OUT = os.path.abspath(os.environ.get("SQUELETTES_SORTIE", os.path.join(bh.REPO, "assets", "models", "enemies"))) + os.sep
os.makedirs(OUT, exist_ok=True)

TETE = 0.62
JAMBE = (0.85, 1.7, 0.85)
BRAS = (0.85, 1.35, 0.85)
PROPS = {
    "hips": (0.9, 1.0, 0.9),
    "spine": (0.85, 1.35, 0.85),
    "chest": (0.88, 1.15, 0.88),
    "upperarm.l": BRAS, "upperarm.r": BRAS, "lowerarm.l": BRAS, "lowerarm.r": BRAS,
    "hand.l": (0.8, 0.8, 0.8), "hand.r": (0.8, 0.8, 0.8),
    "upperleg.l": JAMBE, "upperleg.r": JAMBE, "lowerleg.l": JAMBE, "lowerleg.r": JAMBE,
    "foot.l": (0.8, 0.8, 0.8), "foot.r": (0.8, 0.8, 0.8),
    "toes.l": (0.8, 0.8, 0.8), "toes.r": (0.8, 0.8, 0.8),
    "head": (TETE, TETE, TETE),
}
if os.environ.get("SQUELETTES_PROPS"):
    for _os, _v in json.loads(os.environ["SQUELETTES_PROPS"]).items():
        PROPS[_os] = tuple(_v)


def construire(nom):
    bh.reset()
    objs, acts, rig = bh.import_glb(SRC + "Skeleton_%s.glb" % nom)
    bh.delete([objs.get("Icosphere")])   # (une sphère d'aide du pack, invisible en jeu)
    garder = [o for k, o in objs.items() if k != "Icosphere" and o.type == "MESH"]
    deformes = [o for o in garder if any(m.type == "ARMATURE" for m in o.modifiers)]
    accroches = [o for o in garder if o.parent_type == "BONE"]   # capuche, chapeau, casque, cape
    # avant : où sont l'os et l'objet accroché (pose de repos)
    avant = {}
    for o in accroches:
        b = rig.data.bones[o.parent_bone]
        avant[o.name] = (rig.matrix_world @ b.matrix_local, o.matrix_world.copy())
    bh.PROPS = PROPS
    bh.reshape(rig, deformes, [])
    # après : l'objet suit son os, à la nouvelle taille de l'os (l'échelle n'est pas gardée par la pose de repos)
    bpy.context.view_layer.update()
    for o in accroches:
        b = rig.data.bones[o.parent_bone]
        os0, w0 = avant[o.name]
        os1 = rig.matrix_world @ b.matrix_local
        e = PROPS.get(o.parent_bone, (1, 1, 1))
        o.matrix_world = os1 @ Matrix.Diagonal((e[0], e[1], e[2], 1.0)) @ os0.inverted() @ w0
        print("ACCROCHE", o.name, "->", o.parent_bone, e)
    bh.user_ombres(garder)
    for o in list(bpy.data.objects):
        if o not in garder and o is not rig:
            bpy.data.objects.remove(o, do_unlink=True)
    bpy.ops.export_scene.gltf(filepath=OUT + "Skeleton_%s.glb" % nom, export_format="GLB",
                              export_animation_mode="ACTIONS", export_yup=True, export_vertex_color="ACTIVE")
    print("EXPORTED Skeleton_%s actions %d" % (nom, len(bpy.data.actions)))


if __name__ == "__main__":
    quel = sys.argv[-1].lower() if sys.argv[-1].lower() in ("minion", "rogue", "mage", "warrior") else "all"
    for n in ("Minion", "Rogue", "Mage", "Warrior"):
        if quel in ("all", n.lower()):
            construire(n)
