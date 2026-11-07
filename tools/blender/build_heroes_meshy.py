"""Pose un héros fait par Téo sur Meshy (06/11, modèles réalistes « façon Diablo IV », abonnement payant : ils sont à
lui) sur l'ossature des héros du jeu, sans rien perdre de ce qui marche déjà : les 76 animations KayKit, l'attache de
l'arme (handslot.r) et celle de la lanterne (handslot.l), donc l'équipement et la coop.

Comment :
1. on part du héros actuel du jeu (le .glb fait par build_heroes.py : ossature, animations, arme de départ) ;
2. on retire son corps KayKit et on met à sa place le maillage Meshy, mis à la taille du héros actuel ;
3. on déplace les os pour qu'ils tombent aux articulations du nouveau corps (épaules, coudes, poignets, hanches,
   genoux, chevilles, cou), mesurées sur le maillage : les animations sont des rotations, elles restent valables ;
4. le corps suit les os par des poids calculés ici (les « automatic weights » de Blender échouent sur ce maillage) :
   distance aux os du corps, sans passer d'un côté à l'autre, puis lissés de proche en proche ;
5. les images Meshy (4096 px) sont réduites pour le téléphone, puis tout est exporté en .glb.

Prérequis : Blender en module Python (pip install bpy) ; le maillage Meshy allégé (Remesh ~25 000 triangles, GLB).
Usage : python tools/blender/build_heroes_meshy.py <bretteur|occultiste> <meshy.glb> <héros_actuel.glb>
        (HEROS_MESHY_ARME=<arme.glb> : l'arme faite sur Meshy à la place de l'arme de départ, voir ARMES_MESHY)
Sortie : assets/models/heroes_meshy/<Héros>.glb (ou HEROS_MESHY_SORTIE=<dossier>)
"""
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
HEROS, MESHY, BASE = sys.argv[-3].lower(), sys.argv[-2], sys.argv[-1]
NOM = {"bretteur": "Bretteur", "occultiste": "Occultiste"}[HEROS]
SORTIE = os.path.abspath(os.environ.get("HEROS_MESHY_SORTIE", os.path.join(REPO, "assets", "models", "heroes_meshy")))
os.makedirs(SORTIE, exist_ok=True)
# ce qu'on garde du héros actuel : l'arme de départ (et la lanterne de l'Occultiste, qui éclaire en jeu)
GARDER = {"bretteur": ["Bretteur_Sabre"], "occultiste": ["Occultiste_Baton", "Occultiste_Lanterne"]}[HEROS]
HAUTEUR = float(os.environ.get("HEROS_MESHY_HAUTEUR", "2.45"))   # du sol au haut du chapeau / de la capuche
TAILLE_IMAGES = {"base": 2048, "normal": 1024, "autre": 1024}
# Arme faite par Téo sur Meshy (07/11, sabre « pirate cutlass ») à la place de l'arme de départ KayKit :
# HEROS_MESHY_ARME=<arme.glb>. Réglée sur l'arme KayKit, dans le repère de l'attache de la main (handslot.r) :
# le sabre Meshy arrive pointe en bas (-z) et coquille côté -x ; il est retourné d'un demi-tour autour de y (pointe
# en +z, coquille côté +x comme l'arc de garde KayKit, pour que les phalanges soient dedans), mis à l'échelle (lame
# de la longueur de la lame KayKit, ~1,2 m) et sa poignée (z = « poignee » chez Meshy) posée au milieu de la poignée
# KayKit (z = « poignee_main »). Mesures : profil des deux armes tranche par tranche le long de leur axe.
ARMES_MESHY = {
    "bretteur": {"objet": "Bretteur_Sabre", "echelle": 0.89, "poignee": 0.63, "poignee_main": -0.17,
                 "triangles": 3500, "image": 512},
}
ARME = os.environ.get("HEROS_MESHY_ARME", "")

# Os du corps (ceux qui déforment) ; les autres (racine, contrôles, IK, attaches) ne reçoivent pas de poids.
CORPS = ["hips", "spine", "chest", "head"] + [b + s for s in (".l", ".r") for b in (
    "upperarm", "lowerarm", "wrist", "hand", "upperleg", "lowerleg", "foot", "toes")]
BRAS = ("upperarm", "lowerarm", "wrist", "hand", "handslot", "elbowIK", "handIK")
JAMBE = ("upperleg", "lowerleg", "foot", "toes", "toe-roll", "heel-roll", "foot-roll", "heelIK", "IK-foot", "IK-toe")
# Repères de l'ossature actuelle (mesurés sur le héros du jeu, en mètres)
K_CHEVILLE, K_GENOU, K_HANCHE, K_EPAULE, K_COU, K_HAUT = 0.14, 0.48, 1.00, 1.88, 2.06, 2.44
K_EPAULE_X, K_COUDE_X, K_POIGNET_X, K_BOUT_X = 0.16, 0.54, 0.96, 1.08
K_PIED_X = 0.13


def importer(chemin):
    avant = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=chemin)
    return [o for o in bpy.data.objects if o not in avant]


def sommets(o):
    return np.array([o.matrix_world @ v.co for v in o.data.vertices])


def preparer_maillage(m):
    """Taille du héros actuel, pieds au sol, centré : renvoie les sommets (repère du monde)."""
    bpy.context.view_layer.objects.active = m
    for o in bpy.context.selected_objects:
        o.select_set(False)
    m.select_set(True)
    m.rotation_mode = "XYZ"
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    p = sommets(m)
    e = HAUTEUR / (p[:, 2].max() - p[:, 2].min())
    bas = p[:, 2].min()
    # milieu : en largeur, le centre ; en profondeur, l'axe des bras tendus (l'ossature a ses bras et sa colonne
    # sur la même ligne ; le manteau ou le chapeau décaleraient un centre pris sur tout le corps)
    cx = (p[:, 0].max() + p[:, 0].min()) / 2
    bout = (p[:, 0].max() - p[:, 0].min()) / 2
    bras = np.abs(p[:, 0] - cx) > 0.7 * bout
    cy = float(np.median(p[bras, 1]))
    for v in m.data.vertices:
        v.co = Vector(((v.co.x - cx) * e, (v.co.y - cy) * e, (v.co.z - bas) * e))
    m.data.update()
    return sommets(m)


def reperes(p):
    """Articulations mesurées sur le corps en T : hauteur et largeur des bras, épaules, pieds, stature."""
    bout_g, bout_d = p[:, 0].max(), -p[:, 0].min()
    bout = (bout_g + bout_d) / 2
    bras = np.abs(p[:, 0]) > 0.55 * bout
    za = float(np.median(p[bras, 2]))
    ya = float(np.median(p[bras, 1]))
    # l'épaule : en partant du milieu, là où la tranche verticale (torse) devient une tranche de bras
    bande = np.abs(p[:, 2] - za) < 0.35
    epaule = 0.2
    for x in np.arange(0.06, bout, 0.01):
        t = bande & (np.abs(np.abs(p[:, 0]) - x) < 0.006)
        if t.sum() < 8:
            continue
        haut = p[t, 2].max() - p[t, 2].min()
        if haut < 0.42:
            epaisseur = haut
            epaule = x - 0.3 * epaisseur
            break
    stature = za / 0.80   # (bras en T : à 80 % de la stature environ)
    pieds = p[:, 2] < 0.08
    pied_x = float((np.abs(p[pieds & (p[:, 0] > 0), 0]).mean() + np.abs(p[pieds & (p[:, 0] < 0), 0]).mean()) / 2)
    r = {"za": za, "ya": ya, "bout": bout, "epaule": epaule, "stature": stature, "pied_x": pied_x,
         "haut": p[:, 2].max()}
    print("REPERES", {k: round(v, 3) for k, v in r.items()})
    return r


def deplacement(r):
    """Fonction qui envoie un point de l'ossature actuelle à sa place dans le nouveau corps."""
    S = r["stature"]
    zk = [0.0, K_CHEVILLE, K_GENOU, K_HANCHE, K_EPAULE, K_COU, K_HAUT, K_HAUT + 1.0]
    zm = [0.0, 0.045 * S, 0.28 * S, 0.52 * S, r["za"], r["za"] + 0.07 * S, S, S + 1.0]
    sh, bout = r["epaule"], r["bout"] - 0.02 * S
    xk = [0.0, K_EPAULE_X, K_COUDE_X, K_POIGNET_X, K_BOUT_X, K_BOUT_X + 1.0]
    xm = [0.0, sh, sh + 0.423 * (bout - sh), sh + 0.755 * (bout - sh), bout, bout + 1.0]
    fy = S / K_HAUT

    def f(nom, v):
        z = float(np.interp(v.z, zk, zm))
        y = v.y * fy
        x = v.x
        if nom.startswith(BRAS):
            x = math.copysign(float(np.interp(abs(v.x), xk, xm)), v.x)
            y += r["ya"]
        elif nom.startswith(JAMBE):
            x = v.x * r["pied_x"] / K_PIED_X
        return Vector((x, y, z))
    return f


def deplacer_os(rig, f):
    bpy.context.view_layer.objects.active = rig
    for o in bpy.context.selected_objects:
        o.select_set(False)
    rig.select_set(True)
    if rig.animation_data:
        rig.animation_data.action = None
    bpy.ops.object.mode_set(mode="EDIT")
    lies = {}
    for eb in rig.data.edit_bones:
        lies[eb.name] = eb.use_connect
        eb.use_connect = False
    places = {eb.name: (f(eb.name, eb.head.copy()), f(eb.name, eb.tail.copy())) for eb in rig.data.edit_bones}
    for eb in rig.data.edit_bones:
        eb.head, eb.tail = places[eb.name]
    for eb in rig.data.edit_bones:
        eb.use_connect = lies[eb.name]
    bpy.ops.object.mode_set(mode="OBJECT")


def habiller(rig, m):
    """Le corps suit les os du corps seulement. Poids calculés ici : la « chaleur » de Blender (automatic weights)
    échoue sur les maillages Meshy, faits de plusieurs pièces (manteau, ceinture, chapeau…). Chaque sommet suit les os
    les plus proches (inverse de la distance à la puissance 4, trois os au plus, jamais un os de l'autre côté du
    corps), puis les poids sont adoucis le long du maillage pour que les plis aux articulations soient souples."""
    from scipy import sparse
    noms = [n for n in CORPS if n in rig.data.bones]
    A = np.array([rig.matrix_world @ rig.data.bones[n].head_local for n in noms])
    B = np.array([rig.matrix_world @ rig.data.bones[n].tail_local for n in noms])
    P = sommets(m)
    AB = B - A
    t = np.clip(((P[:, None, :] - A[None]) * AB[None]).sum(-1) / np.maximum((AB ** 2).sum(-1), 1e-9)[None], 0, 1)
    d = np.linalg.norm(P[:, None, :] - (A[None] + t[..., None] * AB[None]), axis=-1)
    gauche = np.array([n.endswith(".l") for n in noms])
    droite = np.array([n.endswith(".r") for n in noms])
    d[np.ix_(P[:, 0] < -0.04, gauche)] = np.inf
    d[np.ix_(P[:, 0] > 0.04, droite)] = np.inf
    w = 1.0 / (d + 0.02) ** 4
    w = _garder(w, 3)
    # adoucir le long du maillage (voisins par les arêtes)
    n = len(m.data.vertices)
    ar = np.array([e.vertices[:] for e in m.data.edges])
    adj = sparse.coo_matrix((np.ones(len(ar) * 2), (np.r_[ar[:, 0], ar[:, 1]], np.r_[ar[:, 1], ar[:, 0]])),
                            shape=(n, n)).tocsr()
    deg = np.asarray(adj.sum(1)).ravel()
    deg[deg == 0] = 1
    for _ in range(4):
        w = 0.5 * w + 0.5 * (adj @ w) / deg[:, None]
    w[np.isinf(d)] = 0.0
    w = _garder(w, 4)
    bpy.context.view_layer.objects.active = rig
    for o in bpy.context.selected_objects:
        o.select_set(False)
    m.select_set(True)
    rig.select_set(True)
    bpy.ops.object.parent_set(type="ARMATURE_NAME")
    groupes = {g.name: g for g in m.vertex_groups}
    for j, nom in enumerate(noms):
        g = groupes.get(nom) or m.vertex_groups.new(name=nom)
        for i in np.nonzero(w[:, j] > 0.0)[0]:
            g.add([int(i)], float(w[i, j]), "REPLACE")
    print("POIDS os par sommet (moyenne)", round(float((w > 0).sum(1).mean()), 2))


def _garder(w, k):
    """Garde les k plus forts poids de chaque sommet (les autres à 0), les petits restes enlevés, total 1."""
    if w.shape[1] > k:
        seuil = -np.sort(-w, axis=1)[:, k - 1:k]
        w = np.where(w >= seuil, w, 0.0)
    w = w / np.maximum(w.sum(1, keepdims=True), 1e-12)
    w = np.where(w < 0.02, 0.0, w)
    return w / np.maximum(w.sum(1, keepdims=True), 1e-12)


def _distance_segment(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
    return (a + ab * t - p).length


def reduire_images(m):
    for slot in m.material_slots:
        if slot.material is None or not slot.material.use_nodes:
            continue
        slot.material.name = "%s_meshy" % HEROS
        for n in slot.material.node_tree.nodes:
            if n.type != "TEX_IMAGE" or n.image is None:
                continue
            lien = n.outputs["Color"].links
            vers = lien[0].to_socket.name if lien else ""
            cle = "base" if vers == "Base Color" else ("normal" if n.image.colorspace_settings.name == "Non-Color"
                                                       and "Normal" in [l.to_node.type.title() for l in lien] else "autre")
            if lien and lien[0].to_node.type == "NORMAL_MAP":
                cle = "normal"
            t = TAILLE_IMAGES[cle]
            if n.image.size[0] > t:
                n.image.scale(t, t)
            n.image.name = "%s_meshy_%s" % (HEROS, cle if cle != "autre" else "orm")
            print("IMAGE", n.image.name, tuple(n.image.size))


def arme_meshy(rig, garder):
    """Met l'arme Meshy à la place de l'arme de départ (même attache) ; renvoie la liste des objets gardés."""
    r = ARMES_MESHY[HEROS]
    ancienne = next(o for o in garder if o.name.split(".")[0] == r["objet"])
    a = next(o for o in importer(ARME) if o.type == "MESH")
    bpy.context.view_layer.objects.active = a
    for o in bpy.context.selected_objects:
        o.select_set(False)
    a.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    e = r["echelle"]
    c = r["poignee_main"] + e * r["poignee"]
    for v in a.data.vertices:
        v.co = Vector((-e * v.co.x, e * v.co.y, -e * v.co.z + c))   # demi-tour autour de y, échelle, poignée en main
    a.data.update()
    avant = sum(len(f.vertices) - 2 for f in a.data.polygons)
    if avant > r["triangles"]:
        d = a.modifiers.new("alleger", "DECIMATE")
        d.ratio = r["triangles"] / avant
        bpy.ops.object.modifier_apply(modifier=d.name)
    for slot in a.material_slots:
        if slot.material is None or not slot.material.use_nodes:
            continue
        slot.material.name = "%s_arme_meshy" % HEROS
        for n in slot.material.node_tree.nodes:
            if n.type == "TEX_IMAGE" and n.image is not None:
                if n.image.size[0] > r["image"]:
                    n.image.scale(r["image"], r["image"])
                lien = n.outputs["Color"].links
                cle = "base" if lien and lien[0].to_socket.name == "Base Color" else (
                    "normal" if lien and lien[0].to_node.type == "NORMAL_MAP" else "orm")
                n.image.name = "%s_arme_meshy_%s" % (HEROS, cle)
    a.parent = rig
    a.parent_type = "BONE"
    a.parent_bone = ancienne.parent_bone
    a.matrix_parent_inverse = ancienne.matrix_parent_inverse.copy()
    a.matrix_basis = ancienne.matrix_basis.copy()
    nom = ancienne.name
    reste = [o for o in garder if o is not ancienne]
    bpy.data.objects.remove(ancienne, do_unlink=True)
    a.name = nom
    print("ARME", nom, "triangles", avant, "->", sum(len(f.vertices) - 2 for f in a.data.polygons))
    return reste + [a]


def principal():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    base = importer(BASE)
    rig = next(o for o in base if o.type == "ARMATURE")
    garder = [o for o in base if o.type == "MESH" and o.name.split(".")[0] in GARDER]
    for o in base:
        if o.type == "MESH" and o not in garder:
            bpy.data.objects.remove(o, do_unlink=True)
    neuf = [o for o in importer(MESHY) if o.type == "MESH"]
    m = neuf[0]
    m.name = "%s_Corps" % NOM
    p = preparer_maillage(m)
    r = reperes(p)
    deplacer_os(rig, deplacement(r))
    habiller(rig, m)
    reduire_images(m)
    if ARME:
        garder = arme_meshy(rig, garder)
    for o in list(bpy.data.objects):
        if o is not rig and o is not m and o not in garder:
            bpy.data.objects.remove(o, do_unlink=True)
    chemin = os.path.join(SORTIE, NOM + ".glb")
    bpy.ops.export_scene.gltf(filepath=chemin, export_format="GLB", export_animation_mode="ACTIONS",
                              export_yup=True, export_image_format="JPEG")
    tris = sum(len(f.vertices) - 2 for f in m.data.polygons)
    print("EXPORTE", chemin, "triangles", tris, "animations", len(bpy.data.actions), "gardés", [o.name for o in garder])


principal()
