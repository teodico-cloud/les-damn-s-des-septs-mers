"""Construit les deux héros des Damnés des Sept Mers à partir des packs KayKit (CC0).

Bretteur  : tête du Barbare (barbu) + corps du Rogue, tricorne, sabre d'abordage, pistolet,
            bandeau sur l'œil, balafre, anneau d'or, bandoulière.
Occultiste: corps et visage du Mage + capuche du Rogue encapuchonné, lanterne maudite,
            bâton à cristal, barbe tressée, yeux luisants, breloques.
Les deux gardent l'ossature KayKit et ses 76 animations ; leurs proportions sont allongées (voir PROPS).

Prérequis : tools/fetch_kaykit.sh, puis Blender en module Python (pip install bpy).
Usage     : python tools/blender/build_heroes.py [bretteur|occultiste|all]
Sortie    : assets/models/heroes/<Héros>.glb
"""
import bpy, bmesh, math, os, sys
import numpy as np
from mathutils import Vector, Matrix

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
CH = os.path.join(REPO, "third_party", "KayKit-Character-Pack-Adventures-1.0", "addons",
                  "kaykit_character_pack_adventures", "Characters", "gltf") + os.sep
OUT = os.path.join(REPO, "assets", "models", "heroes") + os.sep
TEX = os.path.join(REPO, "build", "textures") + os.sep
os.makedirs(OUT, exist_ok=True)
os.makedirs(TEX, exist_ok=True)

# Repère des armes tenues en main droite (copié du sabre KayKit) : poignée à l'origine, lame vers +Z.
WEAPON_R = Matrix(((-1, 0, 0, 0), (0, 0, 1, -0.079), (0, 1, 0, 0), (0, 0, 0, 1)))


# ---------------------------------------------------------------- utilitaires
def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def base_name(n):
    parts = n.rsplit(".", 1)
    return parts[0] if len(parts) == 2 and parts[1].isdigit() else n


def import_glb(path):
    b_obj, b_act = set(bpy.data.objects), set(bpy.data.actions)
    bpy.ops.import_scene.gltf(filepath=path)
    objs = {base_name(o.name): o for o in bpy.data.objects if o not in b_obj}
    acts = [a for a in bpy.data.actions if a not in b_act]
    rig = next(o for o in objs.values() if o.type == "ARMATURE")
    return objs, acts, rig


def delete(objs):
    for o in list(objs):
        if o and o.name in bpy.data.objects:
            bpy.data.objects.remove(o, do_unlink=True)


def transfer(o, rig):
    """Rattache un mesh d'un autre personnage KayKit à notre ossature (même squelette)."""
    basis, pinv = o.matrix_basis.copy(), o.matrix_parent_inverse.copy()
    ptype, pbone = o.parent_type, o.parent_bone
    o.parent = rig
    o.parent_type = ptype
    if ptype == "BONE":
        o.parent_bone = pbone
    o.matrix_parent_inverse = pinv
    o.matrix_basis = basis
    for m in o.modifiers:
        if m.type == "ARMATURE":
            m.object = rig


def srgb2lin(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def mat(name, rgb, rough=0.85, metal=0.0, emit=None, strength=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*[srgb2lin(x) for x in rgb], 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emit:
        b.inputs["Emission Color"].default_value = (*[srgb2lin(x) for x in emit], 1)
        b.inputs["Emission Strength"].default_value = strength
    return m


def recolor(src_img, name, mapping):
    """Recolore des cases de la texture KayKit (8 colonnes x 4 lignes) en gardant leur dégradé."""
    w, h = src_img.size
    px = np.array(src_img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    lum = np.array([0.299, 0.587, 0.114], dtype=np.float32)
    for (c, r), spec in mapping.items():
        rgb, contrast = (spec, 0.75) if isinstance(spec[0], (int, float)) else spec
        y0, x0 = (3 - r) * 256, c * 128
        blk = px[y0:y0 + 256, x0:x0 + 128, :3]
        L = blk @ lum
        t = np.array(rgb, dtype=np.float32) / 255.0
        ratio = 1 + (L / max(L.mean(), 1e-3) - 1) * contrast
        px[y0:y0 + 256, x0:x0 + 128, :3] = np.clip(ratio[..., None] * t, 0, 1)
    im = bpy.data.images.new(name, w, h, alpha=True)
    im.pixels.foreach_set(px.ravel())
    im.filepath_raw = TEX + name + ".png"
    im.file_format = "PNG"
    im.save()
    return im


def retexture(objs, new_img):
    cache = {}
    for o in objs:
        for i, m in enumerate(o.data.materials):
            if m is None:
                continue
            if m.name not in cache:
                nm = m.copy()
                nm.name = new_img.name
                for n in nm.node_tree.nodes:
                    if n.type == "TEX_IMAGE":
                        n.image = new_img
                cache[m.name] = nm
            o.data.materials[i] = cache[m.name]


def swatch_of_face(me, poly, w=1024, h=1024):
    uv = me.uv_layers.active.data
    us = [uv[i].uv for i in poly.loop_indices]
    u = sum(x[0] for x in us) / len(us)
    v = sum(x[1] for x in us) / len(us)
    x, y = min(w - 1, max(0, int(u * w))), min(h - 1, max(0, int(v * h)))
    return (x // 128, 3 - (y // 256))


def keep_faces(o, pred):
    """Supprime les faces d'un mesh qui ne vérifient pas pred(swatch, centre)."""
    me = o.data
    drop = {p.index for p in me.polygons if not pred(swatch_of_face(me, p), p.center)}
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[bm.faces[i] for i in drop], context="FACES")
    loose = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context="VERTS")
    bm.to_mesh(me)
    bm.free()


# ------------------------------------------------------------- visages
def islands(me, face_pred):
    """Îlots de faces connexes (par sommets partagés) parmi celles qui vérifient face_pred(poly)."""
    faces = [p for p in me.polygons if face_pred(p)]
    by_vert = {}
    for p in faces:
        for vi in p.vertices:
            by_vert.setdefault(vi, []).append(p.index)
    seen, out = set(), []
    for p in faces:
        if p.index in seen:
            continue
        stack, isl = [p.index], set()
        while stack:
            fi = stack.pop()
            if fi in seen:
                continue
            seen.add(fi)
            isl.add(fi)
            for vi in me.polygons[fi].vertices:
                stack.extend(by_vert[vi])
        out.append(isl)
    return out


def isl_verts(me, isl):
    return {vi for fi in isl for vi in me.polygons[fi].vertices}


def isl_bbox(me, isl):
    pts = [me.vertices[i].co for i in isl_verts(me, isl)]
    return Vector([min(p[i] for p in pts) for i in range(3)]), Vector([max(p[i] for p in pts) for i in range(3)])


def face_parts(head):
    """Repère yeux, sourcils et bouche d'une tête KayKit (cases c2r0 = yeux/bouche, c1r0 = poils)."""
    me = head.data
    sw = {p.index: swatch_of_face(me, p) for p in me.polygons}
    dark = islands(me, lambda p: sw[p.index] == (2, 0))
    dark = sorted(dark, key=lambda i: -len(i))
    # les deux plus gros îlots sombres sont les yeux (chaque œil ≈ 66 faces) ; les petits îlots
    # à hauteur des yeux sont des cils recourbés, ceux en dessous forment la bouche
    eyes = sorted(dark[:2], key=lambda i: isl_bbox(me, i)[0].x)
    eye_top = max(isl_bbox(me, i)[1].z for i in eyes)
    eye_bot = min(isl_bbox(me, i)[0].z for i in eyes)
    others = dark[2:]
    mouth = [i for i in others if isl_bbox(me, i)[1].z < eye_bot]
    lashes = [i for i in others if i not in mouth]
    hair = islands(me, lambda p: sw[p.index] == (1, 0))
    brows = []
    for i in hair:
        lo, hi = isl_bbox(me, i)
        c = (lo + hi) / 2
        if hi.x - lo.x < 0.25 and hi.z - lo.z < 0.12 and eye_top - 0.02 < c.z < eye_top + 0.16 and c.y < -0.12 and 0.02 < abs(c.x) < 0.3:
            brows.append(i)
    return me, eyes, brows, mouth, eye_top, lashes


def delete_faces(me, faces):
    if not faces:
        return
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[bm.faces[i] for i in faces], context="FACES")
    loose = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context="VERTS")
    bm.to_mesh(me)
    bm.free()


def harden_eyes_brows(head, squint=0.5, tilt=0.35, brow_tilt=0.55, brow_thick=1.0):
    """Plisse et incline les yeux, fronce les sourcils, retire les cils recourbés.
    Renvoie (yeux, bouche) recalculés après modification du maillage."""
    me, eyes, brows, mouth, eye_top, lashes = face_parts(head)
    print("FACE eyes", [len(i) for i in eyes], "brows", len(brows), "mouth", len(mouth), "lashes", len(lashes))
    new_top = {}
    for isl in eyes:
        vids = isl_verts(me, isl)
        lo, hi = isl_bbox(me, isl)
        c = (lo + hi) / 2
        side = 1 if c.x > 0 else -1
        for vi in vids:
            v = me.vertices[vi].co
            dx, dz = v.x - c.x, v.z - c.z
            v.x = c.x + dx * 0.92
            v.z = c.z + dz * squint + tilt * dx * side
        new_top[side] = max(me.vertices[vi].co.z for vi in vids)
    for isl in brows:
        vids = isl_verts(me, isl)
        lo, hi = isl_bbox(me, isl)
        c = (lo + hi) / 2
        side = 1 if c.x > 0 else -1
        target_c = new_top.get(side, eye_top) + (hi.z - lo.z) * brow_thick / 2 + 0.004
        for vi in vids:
            v = me.vertices[vi].co
            dx, dz = v.x - c.x, v.z - c.z
            v.z = target_c + dz * brow_thick + brow_tilt * dx * side
            v.y -= 0.006
    delete_faces(me, set().union(*lashes) if lashes else set())
    _, eyes, _, mouth, _, _ = face_parts(head)
    return eyes, mouth


def head_frame(head):
    vs = [v.co for v in head.data.vertices]
    lo = Vector([min(v[i] for v in vs) for i in range(3)])
    hi = Vector([max(v[i] for v in vs) for i in range(3)])
    return (lo + hi) / 2, (hi - lo) / 2


def on_head(p, C, A, grow=1.06):
    d = Vector(((p.x - C.x) / A.x, (p.y - C.y) / A.y, (p.z - C.z) / A.z)).normalized()
    return Vector((C.x + d.x * A.x * grow, C.y + d.y * A.y * grow, C.z + d.z * A.z * grow))


def skin_like(obj, source):
    """Donne à obj les poids d'ossature du sommet le plus proche de source (pour qu'il suive le corps)."""
    from mathutils import kdtree
    sm = source.data
    kd = kdtree.KDTree(len(sm.vertices))
    for v in sm.vertices:
        kd.insert(v.co, v.index)
    kd.balance()
    names = {g.index: g.name for g in source.vertex_groups}
    groups = {}
    for v in obj.data.vertices:
        _, idx, _ = kd.find(v.co)
        for g in sm.vertices[idx].groups:
            n = names[g.group]
            if n not in groups:
                groups[n] = obj.vertex_groups.new(name=n)
            groups[n].add([v.index], g.weight, "REPLACE")


# ------------------------------------------------- construction de géométrie
class Part:
    """Petit constructeur de mesh multi-matériaux."""

    def __init__(self):
        self.bm = bmesh.new()
        self.mats = []

    def _mi(self, m):
        if m not in self.mats:
            self.mats.append(m)
        return self.mats.index(m)

    def _tag(self, faces, m, smooth=False):
        i = self._mi(m)
        for f in faces:
            f.material_index = i
            f.smooth = smooth

    def add_geom(self, ret_geom, m, smooth=False):
        self._tag([g for g in ret_geom if isinstance(g, bmesh.types.BMFace)], m, smooth)

    def cyl(self, p0, p1, r0, m, r1=None, segs=10, smooth=False, cap=True):
        p0, p1 = Vector(p0), Vector(p1)
        d = p1 - p0
        L = d.length
        rot = d.normalized().to_track_quat("Z", "Y").to_matrix().to_4x4()
        M = Matrix.Translation((p0 + p1) / 2) @ rot
        ret = bmesh.ops.create_cone(self.bm, cap_ends=cap, cap_tris=False, segments=segs,
                                    radius1=r0, radius2=r0 if r1 is None else r1, depth=L, matrix=M)
        self._tag(set(f for v in ret["verts"] for f in v.link_faces), m, smooth)

    def box(self, center, size, m, rot=None):
        M = Matrix.Translation(center) @ (rot.to_4x4() if rot else Matrix.Identity(4)) @ Matrix.Diagonal((*size, 1))
        ret = bmesh.ops.create_cube(self.bm, size=1.0, matrix=M)
        self._tag(set(f for v in ret["verts"] for f in v.link_faces), m)

    def ico(self, center, radius, m, scale=(1, 1, 1), subdiv=1, smooth=False):
        M = Matrix.Translation(center) @ Matrix.Diagonal((*scale, 1))
        ret = bmesh.ops.create_icosphere(self.bm, subdivisions=subdiv, radius=radius, matrix=M)
        self._tag(set(f for v in ret["verts"] for f in v.link_faces), m, smooth)

    def torus(self, center, R, r, m, axis="Y", segs=16, rsegs=6, arc=2 * math.pi, a0=0.0):
        vs = []
        for i in range(segs + (0 if arc >= 2 * math.pi - 1e-6 else 1)):
            a = a0 + arc * i / segs
            ring = []
            for j in range(rsegs):
                b = 2 * math.pi * j / rsegs
                x = (R + r * math.cos(b)) * math.cos(a)
                y = (R + r * math.cos(b)) * math.sin(a)
                z = r * math.sin(b)
                p = Vector((x, y, z))
                if axis == "Y":  # anneau dans le plan XZ
                    p = Vector((p.x, p.z, p.y))
                elif axis == "X":  # anneau dans le plan YZ
                    p = Vector((p.z, p.x, p.y))
                ring.append(self.bm.verts.new(Vector(center) + p))
            vs.append(ring)
        closed = arc >= 2 * math.pi - 1e-6
        faces = []
        n = len(vs)
        for i in range(n if closed else n - 1):
            a, b = vs[i], vs[(i + 1) % n]
            for j in range(rsegs):
                faces.append(self.bm.faces.new((a[j], b[j], b[(j + 1) % rsegs], a[(j + 1) % rsegs])))
        self._tag(faces, m, True)

    def grid_surface(self, rings, m_of_band, closed=True, smooth=False):
        """rings : liste d'anneaux (listes de Vector de même taille). Relie les anneaux successifs."""
        vr = [[self.bm.verts.new(p) for p in ring] for ring in rings]
        n = len(rings[0])
        for k in range(len(vr) - 1):
            a, b = vr[k], vr[k + 1]
            fs = []
            for j in range(n if closed else n - 1):
                j2 = (j + 1) % n
                fs.append(self.bm.faces.new((a[j], a[j2], b[j2], b[j])))
            self._tag(fs, m_of_band(k), smooth)
        return vr

    def to_object(self, name, solidify=0.0):
        me = bpy.data.meshes.new(name)
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        self.bm.to_mesh(me)
        self.bm.free()
        for m in self.mats:
            me.materials.append(m)
        o = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(o)
        if solidify:
            mod = o.modifiers.new("solid", "SOLIDIFY")
            mod.thickness = solidify
            mod.offset = 0
            bpy.context.view_layer.objects.active = o
            o.select_set(True)
            bpy.ops.object.modifier_apply(modifier=mod.name)
            o.select_set(False)
        return o


def parent_world_rest(o, rig, bone):
    """L'objet est modélisé en coordonnées monde de la pose de repos ; on le fixe à un os."""
    b = rig.data.bones[bone]
    M = rig.matrix_world @ b.matrix_local @ Matrix.Translation((0, b.length, 0))
    o.parent = rig
    o.parent_type = "BONE"
    o.parent_bone = bone
    o.matrix_parent_inverse = Matrix.Identity(4)
    o.matrix_basis = M.inverted()


def parent_local(o, rig, bone, basis):
    o.parent = rig
    o.parent_type = "BONE"
    o.parent_bone = bone
    o.matrix_parent_inverse = Matrix.Identity(4)
    o.matrix_basis = basis


def posed_bone_world(rig, bone, action, frame):
    ad = rig.animation_data or rig.animation_data_create()
    ad.action = action
    if hasattr(ad, "action_slot") and getattr(action, "slots", None) and len(action.slots):
        ad.action_slot = action.slots[0]
    bpy.context.scene.frame_set(frame)
    bpy.context.view_layer.update()
    pb = rig.pose.bones[bone]
    return rig.matrix_world @ pb.matrix @ Matrix.Translation((0, pb.bone.length, 0))


def head_radius(o, z, cy, band=0.035):
    vs = [o.matrix_world @ v.co for v in o.data.vertices]
    sel = [v for v in vs if abs(v.z - z) < band]
    return max(math.hypot(v.x, v.y - cy) for v in sel) if sel else 0.5


def hair_shell(head, name, material, pred, offset=0.03):
    """Couche de cheveux rigide copiée de la tête (faces choisies par pred), gonflée le long des normales."""
    me = head.data.copy()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    o.matrix_world = head.matrix_world.copy()
    keep_faces(o, pred)
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.normal_update()
    for v in bm.verts:
        v.co += v.normal * offset
    bm.to_mesh(me)
    bm.free()
    me.materials.clear()
    me.materials.append(material)
    for poly in me.polygons:
        poly.material_index = 0
    o.vertex_groups.clear()
    return o


# Proportions « élancées » : facteurs (x, y, z) par os, y = le long de l'os.
HEAD_K = 0.62
LEG = (0.84, 2.0, 0.84)
ARM = (0.85, 1.3, 0.85)
PROPS = {
    "hips": (0.88, 1.0, 0.88),
    "spine": (0.82, 1.35, 0.82),
    "chest": (0.84, 1.15, 0.84),
    "upperarm.l": ARM, "upperarm.r": ARM, "lowerarm.l": ARM, "lowerarm.r": ARM,
    "wrist.l": (0.75, 0.75, 0.75), "wrist.r": (0.75, 0.75, 0.75),
    "hand.l": (0.75, 0.75, 0.75), "hand.r": (0.75, 0.75, 0.75),
    "upperleg.l": LEG, "upperleg.r": LEG, "lowerleg.l": LEG, "lowerleg.r": LEG,
    "foot.l": (0.8, 0.8, 0.8), "foot.r": (0.8, 0.8, 0.8),
    "toes.l": (0.8, 0.8, 0.8), "toes.r": (0.8, 0.8, 0.8),
    "head": (HEAD_K, HEAD_K, HEAD_K),
}
CAPE_BOTTOM = 0.35


def action_fcurves(act):
    try:
        return list(act.fcurves)
    except AttributeError:
        out = []
        for layer in act.layers:
            for strip in layer.strips:
                for cb in strip.channelbags:
                    out += list(cb.fcurves)
        return out


def reshape(rig, skinned, capes):
    """Allonge la silhouette : on pose l'ossature avec des échelles par os, on fige le maillage
    déformé, puis cette pose devient la nouvelle pose de repos. Les animations (rotations
    relatives au repos) restent valables."""
    vl = bpy.context.view_layer
    for o in bpy.context.selected_objects:
        o.select_set(False)
    vl.objects.active = rig
    rig.select_set(True)
    if rig.animation_data:
        rig.animation_data.action = None
    bpy.ops.object.mode_set(mode="EDIT")
    inherit = {}
    for eb in rig.data.edit_bones:
        inherit[eb.name] = eb.inherit_scale
        eb.inherit_scale = "NONE"
    bpy.ops.object.mode_set(mode="POSE")
    for pb in rig.pose.bones:
        pb.location = (0, 0, 0)
        pb.rotation_mode = "QUATERNION"
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.scale = PROPS.get(pb.name, (1, 1, 1))
    vl.update()
    # contrôle : la tête de chaque os suit bien la queue de son parent
    gap = max(((pb.parent.tail - pb.head).length for pb in rig.pose.bones
               if pb.parent and pb.bone.use_connect), default=0.0)
    print("RESHAPE max connect gap", round(gap, 4))
    dg = bpy.context.evaluated_depsgraph_get()
    baked = {}
    for o in skinned:
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        baked[o.name] = [v.co.copy() for v in me.vertices]
        ev.to_mesh_clear()
    for o in skinned:
        for v, c in zip(o.data.vertices, baked[o.name]):
            v.co = c
    bpy.ops.pose.armature_apply(selected=False)
    bpy.ops.object.mode_set(mode="EDIT")
    for eb in rig.data.edit_bones:
        eb.inherit_scale = inherit[eb.name]
    # pieds au sol
    zmin = min(v.co.z for o in skinned for v in o.data.vertices)
    for eb in rig.data.edit_bones:
        eb.head.z -= zmin
        eb.tail.z -= zmin
    bpy.ops.object.mode_set(mode="OBJECT")
    for o in skinned:
        for v in o.data.vertices:
            v.co.z -= zmin
    # pans de manteau / capes rigides : rallongés pour suivre les jambes
    bpy.context.view_layer.update()
    for c in capes:
        # bas de la cape à ~0,35 du sol en pose de repos, pour ne pas traverser le sol quand on se baisse
        W0 = (c.matrix_world @ Vector((0, 0, 0))).z
        zl = min(v.co.z for v in c.data.vertices)
        f = (CAPE_BOTTOM - W0) / zl
        for v in c.data.vertices:
            v.co.z *= f
            v.co.x *= 0.88
        print("CAPE", c.name, "stretch", round(f, 2))
    zs = [v.co.z for o in skinned for v in o.data.vertices]
    print("RESHAPE height", round(max(zs) - min(zs), 3), "ground shift", round(-zmin, 3))


def export(rig, keep_objs, name):
    for o in list(bpy.data.objects):
        if o not in keep_objs and o is not rig:
            bpy.data.objects.remove(o, do_unlink=True)
    bpy.ops.export_scene.gltf(filepath=OUT + name + ".glb", export_format="GLB",
                              export_animation_mode="ACTIONS", export_yup=True)
    print("EXPORTED", name, "objects", len(keep_objs), "actions", len(bpy.data.actions))


# ------------------------------------------------------------------ couleurs
def init_mats():
    global EYE_GLOW, SCAR, HAIR_DARK, HAIR_BLACK, RIBBON, FELT, GOLD, BONE, STEEL, DARK_STEEL, BRASS, LEATHER, WOOD, DRIFT, CURSE_GLOW, GLASS_GLOW, VERDIGRIS
    FELT = mat("feutre_noir", (34, 30, 34), 0.95)
    GOLD = mat("dorure", (172, 128, 54), 0.5, 0.4)
    BONE = mat("os", (226, 214, 186), 0.7)
    STEEL = mat("acier", (146, 154, 162), 0.35, 0.45)
    DARK_STEEL = mat("acier_noir", (58, 60, 66), 0.5, 0.4)
    BRASS = mat("laiton", (176, 128, 56), 0.45, 0.4)
    LEATHER = mat("cuir_sombre", (58, 38, 30), 0.9)
    WOOD = mat("bois", (92, 58, 36), 0.85)
    DRIFT = mat("bois_flotte", (78, 70, 62), 0.9)
    CURSE_GLOW = mat("lueur_maudite", (60, 210, 120), 0.4, 0.0, emit=(50, 220, 110), strength=2.2)
    GLASS_GLOW = mat("verre_maudit", (120, 255, 170), 0.3, 0.0, emit=(70, 240, 140), strength=3.0)
    HAIR_DARK = mat("cheveux_bruns", (46, 34, 30), 0.95)
    HAIR_BLACK = mat("cheveux_noirs", (26, 24, 26), 0.95)
    RIBBON = mat("ruban_cramoisi", (112, 26, 34), 0.8)
    EYE_GLOW = mat("yeux_maudits", (120, 255, 150), 0.4, 0.0, emit=(80, 255, 130), strength=3.0)
    SCAR = mat("cicatrice", (156, 92, 80), 0.9)
    VERDIGRIS = mat("bronze_vert", (70, 112, 96), 0.6, 0.35)


# ================================================================== BRETTEUR
def build_bretteur():
    reset()
    init_mats()
    objs, acts, rig = import_glb(CH + "Rogue.glb")
    delete([objs[n] for n in ("Rogue_Head", "Knife", "Knife_Offhand", "1H_Crossbow", "2H_Crossbow", "Throwable", "Icosphere")])
    keep = [objs[n] for n in ("Rogue_Body", "Rogue_ArmLeft", "Rogue_ArmRight", "Rogue_LegLeft", "Rogue_LegRight", "Rogue_Cape")]

    bobjs, bacts, brig = import_glb(CH + "Barbarian.glb")
    head = bobjs["Barbarian_Head"]
    transfer(head, rig)
    delete([o for k, o in bobjs.items() if k != "Barbarian_Head"])
    for a in bacts:
        bpy.data.actions.remove(a)

    body = objs["Rogue_Body"]
    # repère de ceinture choisi avant remodelage (pour le pistolet)
    bvs0 = [(i, body.matrix_world @ v.co) for i, v in enumerate(body.data.vertices)]
    belt_idx = min((iv for iv in bvs0 if abs(iv[1].z - 0.64) < 0.03 and iv[1].x > 0.1), key=lambda iv: iv[1].y)[0]
    reshape(rig, [objs[n] for n in ("Rogue_Body", "Rogue_ArmLeft", "Rogue_ArmRight", "Rogue_LegLeft", "Rogue_LegRight")] + [head],
            [objs["Rogue_Cape"]])
    k = HEAD_K

    # --- recoloration : capitaine maudit (manteau cramoisi, cuir noirci, laiton)
    rogue_img = next(i for i in bpy.data.images if "rogue" in i.name.lower())
    barb_img = next(i for i in bpy.data.images if "barbarian" in i.name.lower())
    body_img = recolor(rogue_img, "bretteur_corps", {
        (0, 1): (112, 26, 34),    # tunique -> manteau cramoisi
        (1, 1): (40, 34, 44),     # bordures et pans -> noir délavé
        (6, 0): (74, 48, 36),     # cuir
        (5, 0): (104, 74, 54),    # cuir clair
        (7, 1): (66, 56, 54),     # culotte gris-brun
        (3, 0): (196, 150, 64),   # boucles -> laiton
        (5, 2): (46, 38, 36),     # gants noirs
        (3, 2): (54, 38, 32),     # bottes de cuir
    })
    head_img = recolor(barb_img, "bretteur_tete", {
        (0, 0): ((188, 128, 92), 0.4),  # peau tannée par le sel
        (1, 0): (52, 40, 34),     # barbe et sourcils bruns-noirs
    })
    retexture(keep, body_img)
    retexture([head], head_img)

    # --- visage plus dur : œil plissé, sourcils froncés
    eyes, _ = harden_eyes_brows(head, squint=0.5, tilt=0.35, brow_tilt=0.6)

    # --- tricorne (coordonnées monde, pose de repos)
    vs = [head.matrix_world @ v.co for v in head.data.vertices]
    top = max(v.z for v in vs)
    hzmin = min(v.z for v in vs)
    H = top - hzmin
    cy = (min(v.y for v in vs) + max(v.y for v in vs)) / 2
    hb = top - 0.36 * k
    r0 = head_radius(head, hb, cy) + 0.03 * k
    p = Part()
    N = 48
    # Calotte
    prof = [(dz * k, f) for dz, f in [(0.0, 1.0), (0.16, 0.99), (0.30, 0.92), (0.40, 0.74), (0.46, 0.42), (0.48, 0.0)]]
    crown = []
    for dz, f in prof:
        crown.append([Vector((r0 * f * math.cos(2 * math.pi * i / N), cy + r0 * f * math.sin(2 * math.pi * i / N), hb + dz))
                      for i in range(N)])
    p.grid_surface(crown, lambda b: FELT, smooth=True)
    # Bord relevé à trois cornes (une corne pointe vers l'avant = -Y)
    rings = []
    for t in (0.0, 0.84, 1.0):
        ring = []
        for i in range(N):
            th = 2 * math.pi * i / N
            phi = th + math.pi / 2  # 0 = avant
            c3 = math.cos(3 * phi)
            R = r0 * 1.02 + t * k * (0.30 + 0.17 * c3)
            z = hb + 0.01 * k + t * k * (0.27 * (1 - c3) / 2 + 0.015)
            ring.append(Vector((R * math.cos(th), cy + R * math.sin(th), z)))
        rings.append(ring)
    p.grid_surface(rings, lambda b: FELT if b == 0 else GOLD, smooth=False)
    hat = p.to_object("Bretteur_Tricorne", solidify=0.03 * k)
    # Insigne : crâne et tibias à l'avant de la calotte
    q = Part()
    fz = hb + 0.2 * k
    fy = cy - r0 * 0.99 - 0.02 * k
    q.ico((0, fy - 0.01 * k, fz + 0.02 * k), 0.065 * k, BONE, scale=(1, 0.7, 1), subdiv=2, smooth=True)
    q.ico((-0.024 * k, fy - 0.055 * k, fz + 0.025 * k), 0.016 * k, FELT)
    q.ico((0.024 * k, fy - 0.055 * k, fz + 0.025 * k), 0.016 * k, FELT)
    q.cyl((-0.11 * k, fy, fz - 0.07 * k), (0.11 * k, fy, fz + 0.09 * k), 0.016 * k, BONE, segs=6)
    q.cyl((0.11 * k, fy, fz - 0.07 * k), (-0.11 * k, fy, fz + 0.09 * k), 0.016 * k, BONE, segs=6)
    badge = q.to_object("Bretteur_Insigne")
    for o in (hat, badge):
        parent_world_rest(o, rig, "head")

    # --- sabre d'abordage (repère arme : poignée à l'origine, lame vers +Z, tranchant côté +X)
    s = Part()
    s.cyl((0, 0, -0.29), (0, 0, 0.0), 0.047, LEATHER, segs=8)
    s.ico((0, 0, -0.33), 0.062, BRASS, subdiv=1)
    # coquille de garde
    s.cyl((0, 0, -0.01), (0, 0, 0.045), 0.16, BRASS, r1=0.13, segs=12)
    # arc de jointure (protège-doigts)
    s.torus((0.0, 0.0, -0.16), 0.17, 0.018, BRASS, axis="Y", segs=10, rsegs=5, arc=math.pi * 0.95, a0=-math.pi * 0.47)
    # lame courbe
    n = 12
    L = 1.2
    rings = []
    for i in range(n + 1):
        t = i / n
        z = 0.05 + L * t
        bend = 0.17 * t * t
        w = 0.17 - 0.05 * t
        spine = -0.06 + bend
        edge = spine + w
        if i == n:  # pointe
            rings.append([Vector((edge - 0.02, 0.0, z + 0.04))] * 3)
        else:
            rings.append([Vector((spine, -0.022, z)), Vector((edge, 0.0, z)), Vector((spine, 0.022, z))])
    bm = s.bm
    vr = []
    for ki, ring in enumerate(rings):
        if ki == n:
            v = bm.verts.new(ring[0])
            vr.append([v, v, v])
        else:
            vr.append([bm.verts.new(x) for x in ring])
    fs = []
    for ki in range(n):
        a, b = vr[ki], vr[ki + 1]
        for j in range(3):
            j2 = (j + 1) % 3
            quad = [a[j], a[j2], b[j2], b[j]]
            uniq = []
            for v in quad:
                if v not in uniq:
                    uniq.append(v)
            fs.append(bm.faces.new(uniq))
    fs.append(bm.faces.new(vr[0]))
    s._tag(fs, STEEL)
    saber = s.to_object("Bretteur_Sabre")
    parent_local(saber, rig, "handslot.r", WEAPON_R.copy())

    # --- pistolet à silex glissé dans la ceinture (côté gauche du personnage = +X)
    belt = body.matrix_world @ body.data.vertices[belt_idx].co
    g = Part()
    base = Vector((belt.x * 0.8, belt.y - 0.05, belt.z))
    d = Vector((0.35, 0.0, -1.0)).normalized()  # canon vers le bas
    up = Vector((-0.55, 0.0, 1.0)).normalized()  # crosse vers le haut
    g.cyl(base, base + d * 0.36, 0.032, DARK_STEEL, segs=8)
    g.cyl(base + d * 0.36, base + d * 0.39, 0.042, BRASS, segs=8)
    g.cyl(base - up * 0.02, base + up * 0.2, 0.05, WOOD, r1=0.062, segs=8)
    g.ico(base + up * 0.22, 0.068, BRASS, subdiv=1)
    g.box(base + Vector((0.0, -0.035, 0.0)), (0.07, 0.03, 0.09), DARK_STEEL)
    pistol = g.to_object("Bretteur_Pistolet")
    parent_world_rest(pistol, rig, "hips")

    # --- cheveux à l'arrière du crâne (sous le tricorne) et catogan noué d'un ruban
    hair = hair_shell(head, "Bretteur_Cheveux", HAIR_DARK,
                      lambda sw, c: sw == (0, 0) and c.y > -0.12 * k and c.z > hzmin + 0.165 * H, offset=0.028 * k)
    parent_world_rest(hair, rig, "head")
    hz = lambda f: hzmin + f * H
    back = max(v.y for v in vs if abs(v.z - hz(0.46)) < 0.05 * k)
    t = Part()
    t.cyl((0, back - 0.02 * k, hz(0.5)), (0, back + 0.13 * k, hz(0.186)), 0.075 * k, HAIR_DARK, r1=0.035 * k, segs=8, smooth=True)
    t.torus((0, back + 0.02 * k, hz(0.443)), 0.07 * k, 0.025 * k, RIBBON, axis="X", segs=10, rsegs=5)
    t.box(Vector((0.05 * k, back + 0.06 * k, hz(0.395))), (0.04 * k, 0.02 * k, 0.14 * k), RIBBON)
    t.box(Vector((-0.05 * k, back + 0.06 * k, hz(0.395))), (0.04 * k, 0.02 * k, 0.14 * k), RIBBON)
    tail = t.to_object("Bretteur_Catogan")
    parent_world_rest(tail, rig, "head")

    # --- bandeau sur l'œil droit (côté -X), sangle qui file sous le tricorne
    C, A = head_frame(head)
    me = head.data
    rlo, rhi = isl_bbox(me, eyes[0])
    ec = (rlo + rhi) / 2
    e = Part()
    e.ico((ec.x, rlo.y - 0.016, ec.z + 0.004), 0.06, FELT, scale=(1.05, 0.34, 0.92), subdiv=2, smooth=True)
    pts = [Vector((ec.x - 0.045, rlo.y, ec.z + 0.03))]
    end = Vector((C.x - A.x * 0.98, C.y + A.y * 0.15, hb - 0.01))
    for i in range(1, 7):
        t = i / 6
        pts.append(on_head(pts[0].lerp(end, t), C, A, grow=1.05))
    for a, b in zip(pts[:-1], pts[1:]):
        e.cyl(a, b, 0.011, FELT, segs=5)
    patch = e.to_object("Bretteur_Bandeau")
    parent_world_rest(patch, rig, "head")

    # --- balafre sur la joue gauche, anneau d'or à l'oreille gauche
    llo, lhi = isl_bbox(me, eyes[1])
    skin = [v.co for p in me.polygons if swatch_of_face(me, p) == (0, 0) for v in (me.vertices[i] for i in p.vertices)]
    def surf_y(x, z):
        near = [v.y for v in skin if abs(v.x - x) < 0.03 and abs(v.z - z) < 0.03]
        return min(near) if near else C.y - A.y
    sc = Part()
    a0 = Vector((lhi.x + 0.025, 0, lhi.z + 0.03))
    a1 = Vector((llo.x + 0.01, 0, llo.z - 0.075))
    prev = None
    for i in range(6):
        t = i / 5
        q = a0.lerp(a1, t)
        q.y = surf_y(q.x, q.z) - 0.006
        if prev is not None:
            sc.cyl(prev, q, 0.007, SCAR, segs=4)
        prev = q
    scar = sc.to_object("Bretteur_Balafre")
    parent_world_rest(scar, rig, "head")
    ear = [v for v in skin if v.x > A.x * 0.8 and v.y > C.y - A.y * 0.4]
    lobe = min(ear, key=lambda v: v.z) if ear else Vector((A.x, C.y, C.z - 0.1))
    ri = Part()
    ri.torus((lobe.x + 0.004, lobe.y, lobe.z - 0.03), 0.028, 0.0075, GOLD, axis="X", segs=14, rsegs=5)
    ring = ri.to_object("Bretteur_Anneau")
    parent_world_rest(ring, rig, "head")

    # --- bandoulière de cuir en travers du torse (épaule droite -> hanche gauche), suit le corps
    bv = [v.co for v in body.data.vertices]
    top_z = max(v.z for v in bv) - 0.06
    p0 = Vector((-0.2, 0, top_z))
    p1 = Vector((belt.x * 0.9, 0, belt.z + 0.03))
    def body_front(x, z):
        near = [v.y for v in bv if abs(v.x - x) < 0.05 and abs(v.z - z) < 0.05]
        return min(near) if near else -0.3
    bm_ = bmesh.new()
    dirv = (p1 - p0).normalized()
    perp = Vector((-dirv.z, 0, dirv.x)) * 0.045
    rows = []
    for i in range(13):
        t = i / 12
        q = p0.lerp(p1, t)
        q.y = body_front(q.x, q.z) - 0.018
        rows.append((bm_.verts.new(q - perp), bm_.verts.new(q + perp)))
    for a, b in zip(rows[:-1], rows[1:]):
        bm_.faces.new((a[0], b[0], b[1], a[1]))
    me_b = bpy.data.meshes.new("Bretteur_Bandouliere")
    bm_.to_mesh(me_b)
    bm_.free()
    me_b.materials.append(LEATHER)
    strap = bpy.data.objects.new("Bretteur_Bandouliere", me_b)
    bpy.context.scene.collection.objects.link(strap)
    mod = strap.modifiers.new("solid", "SOLIDIFY")
    mod.thickness = 0.018
    bpy.context.view_layer.objects.active = strap
    strap.select_set(True)
    bpy.ops.object.modifier_apply(modifier=mod.name)
    strap.select_set(False)
    # boucle de laiton au milieu
    mid = p0.lerp(p1, 0.45)
    mid.y = body_front(mid.x, mid.z) - 0.035
    bk = Part()
    bk.box(mid, (0.075, 0.02, 0.075), BRASS)
    buckle = bk.to_object("Bretteur_Boucle")
    for o in (strap, buckle):
        skin_like(o, body)
        o.parent = rig
        am = o.modifiers.new("Armature", "ARMATURE")
        am.object = rig

    export(rig, keep + [head, hat, badge, saber, pistol, hair, tail, patch, scar, ring, strap, buckle], "Bretteur")


# ================================================================ OCCULTISTE
def build_occultiste():
    reset()
    init_mats()
    objs, acts, rig = import_glb(CH + "Mage.glb")
    delete([objs[n] for n in ("Mage_Hat", "Spellbook", "Spellbook_open", "2H_Staff", "1H_Wand", "Icosphere")])
    keep = [objs[n] for n in ("Mage_Body", "Mage_ArmLeft", "Mage_ArmRight", "Mage_LegLeft", "Mage_LegRight", "Mage_Cape", "Mage_Head")]
    head = objs["Mage_Head"]

    # Capuche découpée dans la tête du Rogue encapuchonné (faces de la case c1r1)
    hobjs, hacts, hrig = import_glb(CH + "Rogue_Hooded.glb")
    hood = hobjs["Rogue_Head_Hooded"]
    keep_faces(hood, lambda sw, c: sw == (1, 1))
    hood.name = "Occultiste_Capuche"
    transfer(hood, rig)
    delete([o for k, o in hobjs.items() if k != "Rogue_Head_Hooded"])
    for a in hacts:
        bpy.data.actions.remove(a)
    # La capuche est légèrement agrandie autour du centre de la tête, pour couvrir les cheveux du Mage
    hv = [v.co for v in hood.data.vertices]
    hc = Vector((0, (min(v.y for v in hv) + max(v.y for v in hv)) / 2, (min(v.z for v in hv) + max(v.z for v in hv)) / 2))
    for v in hood.data.vertices:
        v.co = hc + (v.co - hc) * Vector((1.06, 1.06, 1.04))
    # Cheveux qui dépasseraient à l'arrière : supprimés (cachés par la capuche)
    keep_faces(head, lambda sw, c: not ((sw == (1, 0) and c.y > 0.30) or sw == (1, 1)))
    idle0 = next(a for a in acts if base_name(a.name) == "Idle")
    locs = sorted({fc.data_path.split('"')[1] for fc in action_fcurves(idle0) if fc.data_path.endswith("location")})
    print("IDLE location channels:", locs)
    reshape(rig, [objs[n] for n in ("Mage_Body", "Mage_ArmLeft", "Mage_ArmRight", "Mage_LegLeft", "Mage_LegRight", "Mage_Head")] + [hood],
            [objs["Mage_Cape"]])
    k = HEAD_K

    # --- recoloration : sorcier noyé (robe vert abyssal, liserés verts maladifs)
    mage_img = next(i for i in bpy.data.images if "mage" in i.name.lower())
    rogue_img = next(i for i in bpy.data.images if "rogue" in i.name.lower())
    occ_img = recolor(mage_img, "occultiste", {
        (0, 1): (30, 56, 58),     # robe
        (7, 1): (20, 32, 36),     # robe foncée
        (5, 0): (84, 58, 40),     # ceinture cuir
        (3, 0): (88, 132, 112),   # métal -> bronze vert-de-gris
        (4, 0): (88, 132, 112),
        (2, 2): (210, 198, 166),  # grimoire de ceinture -> os
        (0, 2): (96, 176, 128),   # liserés -> vert maladif
        (2, 1): (26, 52, 44),     # cape -> vert noyé
        (3, 2): (56, 42, 34),     # bottes
        (0, 0): ((128, 136, 118), 0.35),  # peau de noyé, gris-vert
        (7, 2): ((128, 136, 118), 0.35),  # mains de noyé
        (1, 1): (40, 74, 70),
    })
    hood_img = recolor(rogue_img, "occultiste_capuche", {(1, 1): (26, 46, 48)})
    retexture(keep, occ_img)
    retexture([hood], hood_img)

    # --- bâton de bois flotté à cristal maudit (repère arme, main droite)
    w = Part()
    w.cyl((0, 0, -0.26), (0, 0, 0.55), 0.048, DRIFT, r1=0.056, segs=7)
    w.cyl((0.0, 0.0, 0.1), (0.0, 0.0, 0.16), 0.05, VERDIGRIS, segs=7)
    for ki in range(3):
        a = 2 * math.pi * ki / 3
        x, y = math.cos(a), math.sin(a)
        w.cyl((0.03 * x, 0.03 * y, 0.52), (0.1 * x, 0.1 * y, 0.68), 0.016, DRIFT, r1=0.012, segs=5)
        w.cyl((0.1 * x, 0.1 * y, 0.68), (0.03 * x, 0.03 * y, 0.85), 0.012, DRIFT, r1=0.006, segs=5)
    w.ico((0, 0, 0.71), 0.1, CURSE_GLOW, scale=(1, 1, 1.6), subdiv=0)
    wand = w.to_object("Occultiste_Baton")
    parent_local(wand, rig, "handslot.r", Matrix(((-1, 0, 0, 0), (0, 0, 1, -0.112), (0, 1, 0, 0), (0, 0, 0, 1))))

    # --- lanterne maudite pendue à la main gauche (orientée pour la pose de repos « Idle »)
    idle = next(a for a in acts if base_name(a.name) == "Idle")
    hand = posed_bone_world(rig, "handslot.l", idle, 10)
    l = Part()
    hz = -0.13  # le haut de la lanterne sous la main
    l.torus((0, 0, -0.02), 0.06, 0.012, DARK_STEEL, axis="Y", segs=12, rsegs=5)
    l.cyl((0, 0, hz - 0.01), (0, 0, hz + 0.06), 0.12, DARK_STEEL, r1=0.03, segs=6)
    l.cyl((0, 0, hz - 0.035), (0, 0, hz - 0.01), 0.13, DARK_STEEL, segs=6)
    for ki in range(6):
        a = 2 * math.pi * (ki + 0.5) / 6
        l.cyl((0.115 * math.cos(a), 0.115 * math.sin(a), hz - 0.3), (0.115 * math.cos(a), 0.115 * math.sin(a), hz - 0.03), 0.014, DARK_STEEL, segs=4)
    l.cyl((0, 0, hz - 0.29), (0, 0, hz - 0.04), 0.095, GLASS_GLOW, segs=6)
    l.cyl((0, 0, hz - 0.34), (0, 0, hz - 0.29), 0.135, DARK_STEEL, segs=6)
    l.cyl((0, 0, hz - 0.37), (0, 0, hz - 0.34), 0.09, DARK_STEEL, segs=6)
    lantern = l.to_object("Occultiste_Lanterne")
    W = Matrix.Translation(hand.to_translation())
    parent_local(lantern, rig, "handslot.l", hand.inverted() @ W)
    rig.animation_data.action = None
    bpy.context.scene.frame_set(1)

    # --- visage dur : yeux plissés et luisants, sourcils froncés, bouche remplacée par la moustache
    eyes, mouth = harden_eyes_brows(head, squint=0.45, tilt=0.4, brow_tilt=0.7, brow_thick=1.5)
    me = head.data
    mc = None
    if mouth:
        mlo, mhi = isl_bbox(me, set().union(*mouth))
        mc = (mlo + mhi) / 2
        drop = set().union(*mouth)
        bm_ = bmesh.new()
        bm_.from_mesh(me)
        bm_.faces.ensure_lookup_table()
        bmesh.ops.delete(bm_, geom=[bm_.faces[i] for i in drop], context="FACES")
        bm_.to_mesh(me)
        bm_.free()
    eyes = face_parts(head)[1]
    me.materials.append(EYE_GLOW)
    gi = len(me.materials) - 1
    for isl in eyes:
        for fi in isl:
            me.polygons[fi].material_index = gi
    # menton = sommet de peau le plus bas sur l'axe du visage ; bouche à 38 % menton -> bas des yeux
    C, A = head_frame(head)
    skin = [me.vertices[i].co for p in me.polygons if swatch_of_face(me, p) == (0, 0) for i in p.vertices]
    front = [v for v in skin if abs(v.x) < 0.06 and v.y < C.y - 0.55 * A.y]
    chin = min(front, key=lambda v: v.z)
    eye_bot = min(isl_bbox(me, i)[0].z for i in eyes)

    def surf_y(x, z):
        near = [v.y for v in skin if abs(v.x - x) < 0.03 and abs(v.z - z) < 0.03]
        return min(near) if near else chin.y

    mz = chin.z + 0.38 * (eye_bot - chin.z)
    mc = Vector((0, surf_y(0, mz), mz))
    print("OCC chin", tuple(round(x, 3) for x in chin), "bouche", tuple(round(x, 3) for x in mc), "bas des yeux", round(eye_bot, 3))
    b = Part()
    # moustache tombante
    for sd in (-1, 1):
        pts = [Vector((sd * 0.012, mc.y - 0.012, mc.z + 0.012)), Vector((sd * 0.05, mc.y - 0.008, mc.z - 0.005)),
               Vector((sd * 0.075, mc.y + 0.004, mc.z - 0.06)), Vector((sd * 0.08, mc.y + 0.01, mc.z - 0.13))]
        rr = [0.017, 0.015, 0.011, 0.006]
        for i in range(3):
            b.cyl(pts[i], pts[i + 1], rr[i], HAIR_BLACK, r1=rr[i + 1], segs=6)
    # barbe tressée et perle d'os
    # la tresse pend devant le col de la capuche (au ras du visage), pas sous la mâchoire
    zc = chin.z + 0.035
    cyb = mc.y + 0.012
    for r, dz in [(0.034, 0.0), (0.03, -0.045), (0.026, -0.088), (0.021, -0.127)]:
        b.ico((0, cyb, zc + dz), r, HAIR_BLACK, scale=(1, 0.8, 1.25), subdiv=1)
    b.cyl((0, cyb, zc - 0.15), (0, cyb, zc - 0.185), 0.027, BONE, segs=8)
    b.cyl((0, cyb, zc - 0.185), (0, cyb, zc - 0.23), 0.016, HAIR_BLACK, r1=0.0, segs=6)
    goatee = b.to_object("Occultiste_Barbe")
    parent_world_rest(goatee, rig, "head")

    # --- breloques à la ceinture : petit crâne et fiole de poison luminescente
    body = objs["Mage_Body"]
    bme = body.data
    belt_f = [p for p in bme.polygons if swatch_of_face(bme, p) == (5, 0) and p.center.x > 0.1]
    side_f = max(belt_f, key=lambda p: p.center.x - p.center.y * 0.5)
    bc = body.matrix_world @ side_f.center
    ch = Part()
    sk = bc + Vector((-0.02, -0.05, -0.1))
    ch.cyl(bc + Vector((-0.02, -0.04, -0.01)), sk + Vector((0, 0, 0.04)), 0.006, LEATHER, segs=4)
    ch.ico(sk, 0.05, BONE, scale=(0.9, 0.85, 1.0), subdiv=2, smooth=True)
    ch.ico(sk + Vector((-0.018, -0.042, 0.008)), 0.014, HAIR_BLACK)
    ch.ico(sk + Vector((0.018, -0.042, 0.008)), 0.014, HAIR_BLACK)
    ch.box(sk + Vector((0, -0.035, -0.035)), (0.04, 0.02, 0.02), BONE)
    vi = bc + Vector((0.06, -0.01, -0.13))
    ch.cyl(bc + Vector((0.06, -0.02, -0.01)), vi + Vector((0, 0, 0.06)), 0.006, LEATHER, segs=4)
    ch.cyl(vi + Vector((0, 0, -0.05)), vi + Vector((0, 0, 0.03)), 0.032, GLASS_GLOW, segs=8)
    ch.cyl(vi + Vector((0, 0, 0.03)), vi + Vector((0, 0, 0.065)), 0.014, GLASS_GLOW, segs=6)
    ch.cyl(vi + Vector((0, 0, 0.065)), vi + Vector((0, 0, 0.085)), 0.018, WOOD, segs=6)
    charms = ch.to_object("Occultiste_Breloques")
    parent_world_rest(charms, rig, "hips")

    export(rig, keep + [hood, wand, lantern, goatee, charms], "Occultiste")


if __name__ == "__main__":
    which = sys.argv[-1] if sys.argv[-1] in ("bretteur", "occultiste") else "all"
    if which in ("bretteur", "all"):
        build_bretteur()
    if which in ("occultiste", "all"):
        build_occultiste()
