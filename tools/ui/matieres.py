"""Matières de l'interface des Damnés des Sept Mers (refonte, choix de Téo du 05/11 : créées sur mesure).

Tout est fabriqué ici, par calcul : bois vieilli, cuir sombre, parchemin aux bords brûlés, métal oxydé à rivets,
cordage, ornements à l'or vieilli (rose des vents, coins), sceau de cire. Aucune image d'origine extérieure.

Usage (depuis la racine du dépôt) :
    python3 tools/ui/matieres.py planches <dossier>     # planches de direction artistique (étape 0)
    python3 tools/ui/matieres.py textures assets/ui/matieres   # les textures du thème du jeu
"""
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

RACINE = Path(__file__).resolve().parents[2]
POLICES = RACINE / "third_party" / "polices"

# ---------------------------------------------------------------- palette (demande de Téo)
PALETTE = {
    "charbon": (21, 18, 15),
    "charbon_clair": (38, 32, 27),
    "bois_sombre": (43, 29, 19),
    "bois": (74, 51, 34),
    "bois_clair": (112, 80, 52),
    "cuir": (46, 31, 23),
    "cuir_clair": (70, 48, 34),
    "parchemin": (217, 199, 159),
    "parchemin_sombre": (140, 107, 62),
    "encre": (43, 29, 19),
    "or": (176, 138, 66),
    "or_sombre": (110, 83, 38),
    "or_clair": (222, 186, 112),
    "rouge": (139, 30, 26),
    "rouge_clair": (178, 52, 42),
    "vert_de_gris": (95, 143, 134),
    "vert_de_gris_sombre": (47, 79, 74),
    "fer": (61, 59, 55),
    "rouille": (109, 61, 30),
}


def c(nom, a=255):
    return PALETTE[nom] + (a,)


# ---------------------------------------------------------------- bruit
def bruit(w, h, sx, sy=None, graine=0, octaves=4):
    """Bruit de valeur fractal dans [0, 1] ; sx, sy : taille des plus gros motifs (étiré si sx != sy)."""
    sy = sx if sy is None else sy
    rng = np.random.default_rng(graine)
    total = np.zeros((h, w))
    amp, norme = 1.0, 0.0
    for o in range(octaves):
        gw = max(2, int(round(w / sx * 2 ** o)) + 1)
        gh = max(2, int(round(h / sy * 2 ** o)) + 1)
        g = rng.random((gh, gw))
        im = Image.fromarray((g * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
        total += np.asarray(im, float) / 255.0 * amp
        norme += amp
        amp *= 0.5
    t = total / norme
    return (t - t.min()) / max(t.max() - t.min(), 1e-6)


def degrade(lum, sombre, clair):
    """Couleur entre `sombre` et `clair` selon lum (0..1) : tableau h × w × 3."""
    lum = np.clip(lum, 0, 1)[..., None]
    a = np.array(sombre, float)
    b = np.array(clair, float)
    return a + (b - a) * lum


def image(rgb, alpha=None):
    rgb = np.clip(rgb, 0, 255).astype(np.uint8)
    if alpha is None:
        return Image.fromarray(rgb, "RGB").convert("RGBA")
    a = np.clip(alpha, 0, 255).astype(np.uint8)
    return Image.fromarray(np.dstack([rgb, a]), "RGBA")


def distance_bord(w, h):
    y, x = np.mgrid[0:h, 0:w]
    return np.minimum(np.minimum(x, w - 1 - x), np.minimum(y, h - 1 - y)).astype(float)


# ---------------------------------------------------------------- matières
def bois(w, h, graine=1, planches=3, teinte=1.0):
    """Planches de bois vieilli, horizontales, joints sombres, nœuds, rayures claires."""
    gros = bruit(w, h, w / 1.2, h / 6, graine)
    fil = bruit(w, h, 90, 3, graine + 1, octaves=3)
    y = np.arange(h)[:, None].astype(float)
    veines = np.sin(2 * np.pi * (y / 7.0 + gros * 9.0))
    lum = 0.5 + 0.13 * veines + 0.32 * (fil - 0.5) + 0.25 * (gros - 0.5)
    rng = np.random.default_rng(graine)
    hp = h / planches
    for i in range(planches):
        y0, y1 = int(i * hp), int((i + 1) * hp)
        lum[y0:y1] += rng.uniform(-0.08, 0.08)
        lum[y0:y0 + 2] -= 0.35          # joint
        lum[y0 + 2:y0 + 3] += 0.08      # arête éclairée
    for _ in range(max(1, w * h // 60000)):   # nœuds
        cx, cy = rng.uniform(0, w), rng.uniform(0, h)
        rx, ry = rng.uniform(10, 22), rng.uniform(4, 8)
        yy, xx = np.mgrid[0:h, 0:w]
        d = ((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2
        lum -= 0.3 * np.exp(-d * 1.5)
    rgb = degrade(lum, PALETTE["bois_sombre"], PALETTE["bois_clair"]) * teinte
    im = image(rgb)
    d = ImageDraw.Draw(im)
    for _ in range(w * h // 9000):   # rayures d'usure
        x0, y0 = rng.uniform(0, w), rng.uniform(0, h)
        L = rng.uniform(8, 40)
        a = rng.uniform(-0.25, 0.25)
        d.line([(x0, y0), (x0 + L * math.cos(a), y0 + L * math.sin(a))], fill=(150, 112, 74, 70), width=1)
    return im


def cuir(w, h, graine=2, coutures=True):
    """Cuir sombre grenu, coutures claires sur le pourtour."""
    grain = bruit(w, h, 6, None, graine, octaves=2)
    bas = bruit(w, h, 120, None, graine + 1)
    lum = 0.45 + 0.28 * (grain - 0.5) + 0.3 * (bas - 0.5)
    db = distance_bord(w, h)
    lum -= 0.25 * np.exp(-db / 18)
    im = image(degrade(lum, (20, 13, 9), PALETTE["cuir_clair"]))
    if coutures:
        d = ImageDraw.Draw(im)
        m = 9
        for (x0, y0, x1, y1) in [(m, m, w - m, m), (w - m, m, w - m, h - m), (w - m, h - m, m, h - m), (m, h - m, m, m)]:
            L = math.hypot(x1 - x0, y1 - y0)
            n = int(L // 14)
            for i in range(n):
                t0, t1 = i / n, (i + 0.55) / n
                d.line([(x0 + (x1 - x0) * t0, y0 + (y1 - y0) * t0), (x0 + (x1 - x0) * t1, y0 + (y1 - y0) * t1)],
                       fill=(160, 134, 96, 220), width=2)
    return im


def parchemin(w, h, graine=3, dechire=True):
    """Parchemin beige, taches, fibres, bords brûlés et un peu déchirés (transparents)."""
    taches = bruit(w, h, 160, None, graine)
    fibres = bruit(w, h, 70, 2.5, graine + 1, octaves=3)
    points = bruit(w, h, 3, None, graine + 2, octaves=1)
    bord_bruit = bruit(w, h, 40, None, graine + 3)
    db = distance_bord(w, h) + (bord_bruit - 0.5) * 26
    lum = 0.78 - 0.22 * taches + 0.08 * (fibres - 0.5) - 0.05 * (points > 0.93)
    brule = np.clip(1.0 - (db - 4) / 26, 0, 1) ** 1.6
    lum = lum * (1 - 0.75 * brule)
    rgb = degrade(lum, (70, 46, 22), (236, 222, 186))
    alpha = np.full((h, w), 255.0)
    if dechire:
        alpha = np.clip((db - 1.5) * 90, 0, 255)
    return image(rgb, alpha)


def metal(w, h, graine=4, rivets=True, oxyde=1.0):
    """Plaque de fer oxydé : brossé, rouille et vert-de-gris par plaques, biseau, rivets aux coins."""
    brosse = bruit(w, h, 220, 1.2, graine, octaves=3)
    bas = bruit(w, h, 90, None, graine + 1)
    rouille = bruit(w, h, 22, None, graine + 2)
    vdg = bruit(w, h, 30, None, graine + 3)
    pres_bord = np.exp(-distance_bord(w, h) / 14)
    lum = 0.45 + 0.12 * (brosse - 0.5) + 0.2 * (bas - 0.5)
    rgb = degrade(lum, (28, 27, 25), (104, 100, 92))
    mr = (np.clip((rouille - (1 - 0.3 * oxyde)) * 3.5, 0, 1) * 0.75)[..., None]
    rgb = rgb * (1 - mr) + np.array(PALETTE["rouille"], float) * (0.6 + 0.4 * bas[..., None]) * mr
    mv = (np.clip((vdg + 0.35 * pres_bord - (1 - 0.18 * oxyde)) * 3, 0, 1) * 0.55)[..., None]
    rgb = rgb * (1 - mv) + np.array(PALETTE["vert_de_gris_sombre"], float) * 1.3 * mv
    # biseau : haut et gauche éclairés, bas et droite dans l'ombre
    y, x = np.mgrid[0:h, 0:w]
    b = 4
    rgb[(y < b) | (x < b)] *= 1.35
    rgb[(y >= h - b) | (x >= w - b)] *= 0.55
    im = image(rgb)
    if rivets:
        for (rx, ry) in [(14, 14), (w - 15, 14), (14, h - 15), (w - 15, h - 15)]:
            dessiner_rivet(im, rx, ry, 6)
    return im


def dessiner_rivet(im, cx, cy, r):
    d = ImageDraw.Draw(im)
    d.ellipse([cx - r - 1, cy - r + 1, cx + r + 1, cy + r + 3], fill=(10, 9, 8, 160))   # ombre
    for i in range(r, 0, -1):
        t = i / r
        col = tuple(int(v) for v in (np.array((60, 56, 50)) * t + np.array((170, 160, 140)) * (1 - t)))
        off = (1 - t) * r * 0.45
        d.ellipse([cx - i - off, cy - i - off, cx + i - off, cy + i - off], fill=col + (255,))


def cordage(longueur, epaisseur=22, graine=5):
    """Corde torsadée horizontale (bandes en diagonale, ombre de cylindre)."""
    w, h = longueur, epaisseur
    y, x = np.mgrid[0:h, 0:w].astype(float)
    pas = epaisseur * 0.9
    u = ((x + y * 1.1) % pas) / pas
    torsade = np.sin(np.pi * u) ** 0.7
    cyl = np.cos((y - h / 2) / (h / 2) * (np.pi / 2) * 0.95)
    fibre = bruit(w, h, 6, None, graine, octaves=2)
    lum = 0.25 + 0.75 * torsade * cyl + 0.12 * (fibre - 0.5)
    rgb = degrade(lum, (40, 28, 16), (190, 156, 104))
    alpha = np.clip(cyl * 4, 0, 1) * 255
    return image(rgb, alpha)


def or_vieilli(w, h, graine=6):
    n = bruit(w, h, 30, None, graine)
    return image(degrade(0.35 + 0.6 * n, PALETTE["or_sombre"], PALETTE["or_clair"]))


# ---------------------------------------------------------------- ornements (dessinés, suréchantillonnés)
def rose_des_vents(taille, graine=7):
    s = 4
    T = taille * s
    im = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    cx = cy = T / 2
    clair, sombre, trait = c("or_clair"), c("or_sombre"), (40, 28, 14, 255)
    for r, w in [(0.47, 3), (0.42, 1), (0.30, 2)]:
        d.ellipse([cx - T * r, cy - T * r, cx + T * r, cy + T * r], outline=trait if w > 1 else c("or"), width=w * s)
    for i in range(32):   # graduations
        a = i / 32 * 2 * math.pi
        r0, r1 = T * (0.42 if i % 4 else 0.38), T * 0.47
        d.line([(cx + r0 * math.sin(a), cy - r0 * math.cos(a)), (cx + r1 * math.sin(a), cy - r1 * math.cos(a))],
               fill=c("or_sombre"), width=s)

    def branche(a, L, l, c1, c2):
        pointe = (cx + L * math.sin(a), cy - L * math.cos(a))
        g = (cx + l * math.sin(a - math.pi / 2), cy - l * math.cos(a - math.pi / 2))
        dr = (cx + l * math.sin(a + math.pi / 2), cy - l * math.cos(a + math.pi / 2))
        d.polygon([pointe, g, (cx, cy)], fill=c1, outline=trait)
        d.polygon([pointe, dr, (cx, cy)], fill=c2, outline=trait)

    for i in range(4):   # diagonales, courtes
        branche(math.pi / 4 + i * math.pi / 2, T * 0.30, T * 0.06, clair, sombre)
    for i in range(4):   # cardinales, longues
        branche(i * math.pi / 2, T * 0.46, T * 0.085, clair, sombre)
    d.ellipse([cx - T * 0.035, cy - T * 0.035, cx + T * 0.035, cy + T * 0.035], fill=c("rouge"), outline=trait, width=s)
    return im.resize((taille, taille), Image.LANCZOS)


def sceau(taille, graine=8):
    """Sceau de cire rouge, bord irrégulier, ancre en relief."""
    s = 4
    T = taille * s
    im = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    rng = np.random.default_rng(graine)
    cx = cy = T / 2
    pts = []
    for i in range(48):
        a = i / 48 * 2 * math.pi
        r = T * (0.44 + rng.uniform(-0.035, 0.035))
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    d = ImageDraw.Draw(im)
    d.polygon([(x + 2 * s, y + 3 * s) for x, y in pts], fill=(20, 5, 4, 140))
    d.polygon(pts, fill=c("rouge"))
    d.ellipse([cx - T * 0.33, cy - T * 0.33, cx + T * 0.33, cy + T * 0.33], fill=(118, 24, 21, 255),
              outline=(170, 50, 42, 255), width=2 * s)

    def ancre(dx, dy, col):
        w = int(T * 0.035)
        h0, h1 = cy - T * 0.2, cy + T * 0.2
        d.line([(cx + dx, h0 + dy), (cx + dx, h1 + dy)], fill=col, width=w)
        d.ellipse([cx - T * 0.05 + dx, h0 - T * 0.09 + dy, cx + T * 0.05 + dx, h0 + T * 0.01 + dy], outline=col, width=w)
        d.line([(cx - T * 0.1 + dx, h0 + T * 0.06 + dy), (cx + T * 0.1 + dx, h0 + T * 0.06 + dy)], fill=col, width=w)
        d.arc([cx - T * 0.18 + dx, h1 - T * 0.22 + dy, cx + T * 0.18 + dx, h1 + T * 0.04 + dy], 20, 160, fill=col, width=w)

    ancre(2 * s, 2 * s, (70, 10, 8, 255))
    ancre(0, 0, (196, 70, 58, 255))
    im = im.filter(ImageFilter.GaussianBlur(s * 0.4))
    return im.resize((taille, taille), Image.LANCZOS)


def coin_ornement(taille):
    """Coin d'ornement : volute à l'or vieilli, gravée (pour cadres et plaques)."""
    s = 4
    T = taille * s
    im = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for (dx, dy, col) in [(s, s, (25, 16, 8, 200)), (0, 0, c("or"))]:
        d.line([(T * 0.05 + dx, T * 0.05 + dy), (T * 0.95 + dx, T * 0.05 + dy)], fill=col, width=2 * s)
        d.line([(T * 0.05 + dx, T * 0.05 + dy), (T * 0.05 + dx, T * 0.95 + dy)], fill=col, width=2 * s)
        d.arc([T * 0.12 + dx, T * 0.12 + dy, T * 0.62 + dx, T * 0.62 + dy], 180, 360, fill=col, width=2 * s)
        d.arc([T * 0.12 + dx, T * 0.12 + dy, T * 0.62 + dx, T * 0.62 + dy], 90, 180, fill=col, width=2 * s)
        d.ellipse([T * 0.31 + dx, T * 0.31 + dy, T * 0.43 + dx, T * 0.43 + dy], fill=col)
        d.line([(T * 0.62 + dx, T * 0.37 + dy), (T * 0.9 + dx, T * 0.37 + dy)], fill=col, width=s)
        d.line([(T * 0.37 + dx, T * 0.62 + dy), (T * 0.37 + dx, T * 0.9 + dy)], fill=col, width=s)
    return im.resize((taille, taille), Image.LANCZOS)


# ---------------------------------------------------------------- composants
def police(nom, taille):
    chemins = {
        "fell_sc": POLICES / "imfellenglishsc" / "IMFeENsc28P.ttf",
        "fell": POLICES / "imfellenglish" / "IMFeENrm28P.ttf",
        "pirata": POLICES / "pirataone" / "PirataOne-Regular.ttf",
        "cinzel": POLICES / "cinzel" / "Cinzel[wght].ttf",
        "grenze": POLICES / "grenzegotisch" / "GrenzeGotisch[wght].ttf",
        "alegreya": POLICES / "alegreyasans" / "AlegreyaSans-Regular.ttf",
        "alegreya_gras": POLICES / "alegreyasans" / "AlegreyaSans-Bold.ttf",
        "alegreya_noir": POLICES / "alegreyasans" / "AlegreyaSans-ExtraBold.ttf",
        "alegreya_sc": POLICES / "alegreyasanssc" / "AlegreyaSansSC-Bold.ttf",
    }
    f = ImageFont.truetype(str(chemins[nom]), taille)
    if nom == "cinzel":
        try:
            f.set_variation_by_axes([700])
        except Exception:
            pass
    return f


def texte_grave(im, xy, t, f, couleur, ombre=(12, 8, 5, 230), relief=(255, 236, 190, 70), ancre="la"):
    """Texte gravé : ombre portée sombre sous un liseré clair (lettres frappées dans la matière)."""
    d = ImageDraw.Draw(im)
    x, y = xy
    d.text((x, y + 2), t, font=f, fill=ombre, anchor=ancre)
    d.text((x, y - 1), t, font=f, fill=relief, anchor=ancre)
    d.text((x, y), t, font=f, fill=couleur, anchor=ancre)


def bouton(w, h, texte, f, appuye=False, graine=11):
    """Bouton : planche de bois cerclée de fer aux deux bouts, rivets, filet gravé, texte frappé à l'or."""
    im = bois(w, h, graine, planches=1, teinte=0.82 if appuye else 1.0)
    bande = 26
    for x0 in (0, w - bande):
        m = metal(bande, h, graine + x0, rivets=False, oxyde=0.8)
        im.paste(m, (x0, 0))
        dessiner_rivet(im, x0 + bande // 2, h // 2 - 14, 4)
        dessiner_rivet(im, x0 + bande // 2, h // 2 + 14, 4)
    d = ImageDraw.Draw(im)
    d.rectangle([bande + 6, 7, w - bande - 7, h - 8], outline=(22, 14, 8, 200), width=2)
    d.rectangle([bande + 6, 9, w - bande - 7, h - 6], outline=(140, 104, 66, 60), width=1)
    d.rectangle([0, 0, w - 1, h - 1], outline=(10, 7, 4, 255), width=2)
    dy = 2 if appuye else 0
    texte_grave(im, (w // 2, h // 2 + dy), texte, f, c("or_clair") if not appuye else c("or"), ancre="mm")
    if appuye:
        ombre = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        ImageDraw.Draw(ombre).rectangle([0, 0, w - 1, 8], fill=(0, 0, 0, 90))
        im.alpha_composite(ombre)
    return im


def plaque_titre(w, h, texte, f, graine=12):
    im = metal(w, h, graine, rivets=True, oxyde=1.0)
    texte_grave(im, (w // 2, h // 2 + 1), texte, f, c("or_clair"), ancre="mm")
    return im


def barre_vie(w, h, part, f):
    im = cuir(w, h, 21, coutures=False)
    d = ImageDraw.Draw(im)
    m = 6
    fond = Image.new("RGBA", (w - 2 * m, h - 2 * m), (12, 6, 5, 255))
    im.paste(fond, (m, m))
    lw = int((w - 2 * m) * part)
    y, x = np.mgrid[0:h - 2 * m, 0:lw].astype(float)
    lum = 0.55 + 0.45 * np.cos((y / (h - 2 * m) - 0.35) * np.pi)
    rgb = degrade(lum, (70, 10, 8), PALETTE["rouge_clair"])
    im.paste(image(rgb), (m, m))
    for i in range(1, 10):   # crans tous les 10 %
        xx = m + (w - 2 * m) * i / 10
        d.line([(xx, m), (xx, h - m - 1)], fill=(10, 4, 3, 150), width=1)
    d.rectangle([m - 1, m - 1, w - m, h - m], outline=c("or_sombre"), width=2)
    texte_grave(im, (w // 2, h // 2), "PV 76 / 100", f, c("parchemin"), ancre="mm")
    return im


def panneau_parchemin(w, h, cadre=22, graine=13):
    """Panneau : parchemin cloué sur un cadre de bois sombre (clous de fer aux coins)."""
    im = bois(w, h, graine, planches=max(2, h // 120), teinte=0.75)
    p = parchemin(w - 2 * cadre, h - 2 * cadre, graine + 1)
    ombre = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(ombre).rectangle([cadre + 4, cadre + 6, w - cadre + 4, h - cadre + 6], fill=(0, 0, 0, 120))
    im.alpha_composite(ombre.filter(ImageFilter.GaussianBlur(6)))
    im.alpha_composite(p, (cadre, cadre))
    for (x, y) in [(cadre + 14, cadre + 14), (w - cadre - 15, cadre + 14), (cadre + 14, h - cadre - 15), (w - cadre - 15, h - cadre - 15)]:
        dessiner_rivet(im, x, y, 5)
    ImageDraw.Draw(im).rectangle([0, 0, w - 1, h - 1], outline=(8, 5, 3, 255), width=3)
    return im


# ---------------------------------------------------------------- planches de direction artistique
def fond_planche(w, h):
    n = bruit(w, h, 300, None, 99)
    g = bruit(w, h, 4, None, 98, octaves=1)
    lum = 0.35 + 0.35 * n + 0.08 * (g - 0.5)
    db = distance_bord(w, h)
    lum *= 0.55 + 0.45 * np.clip(db / 260, 0, 1)
    return image(degrade(lum, (10, 8, 7), (46, 38, 30)))


def planche_polices(chemin):
    W, H = 1800, 1120
    im = fond_planche(W, H)
    d = ImageDraw.Draw(im)
    f_info = police("alegreya", 22)
    d.text((40, 24), "Proposition — associations de polices (libres, licence OFL), sur de vrais textes du jeu", font=f_info,
           fill=c("parchemin", 200))
    associations = [
        ("A", "Gravure marine", "fell_sc", "IM Fell English SC + Alegreya Sans",
         "Caractères d'imprimerie du XVIIe siècle : cartes marines, gravures, avis de recherche."),
        ("B", "Pavillon noir", "pirata", "Pirata One + Alegreya Sans",
         "Gothique pirate : très marqué, plus difficile à lire en petit."),
        ("C", "Épique sombre", "cinzel", "Cinzel + Alegreya Sans",
         "Capitales romaines : très « grand jeu », mais vue dans beaucoup de jeux."),
    ]
    col_w = (W - 80) // 3
    for i, (lettre, nom, titre, noms, desc) in enumerate(associations):
        x0 = 40 + i * col_w
        bloc = panneau_parchemin(col_w - 24, 470, graine=40 + i)
        im.alpha_composite(bloc, (x0, 70))
        f_t = police(titre, 58 if titre != "pirata" else 64)
        f_t2 = police(titre, 34 if titre != "pirata" else 40)
        f_b = police("alegreya", 26)
        f_bg = police("alegreya_gras", 26)
        cx = x0 + (col_w - 24) // 2
        texte_grave(im, (cx, 130), "Les Damnés", f_t, c("encre"), ombre=(120, 92, 52, 120), relief=(255, 245, 220, 60), ancre="mm")
        texte_grave(im, (cx, 190), "des Sept Mers", f_t2, c("rouge"), ombre=(120, 92, 52, 120), relief=(255, 245, 220, 60), ancre="mm")
        d.line([(x0 + 60, 228), (x0 + col_w - 84, 228)], fill=c("parchemin_sombre"), width=2)
        f_s = police(titre, 36 if titre != "pirata" else 42)
        d.text((x0 + 50, 248), "La Forge", font=f_s, fill=c("encre"))
        d.text((x0 + 50, 300), "Hache d'abordage", font=f_bg, fill=(38, 74, 110, 255))
        d.text((x0 + 50, 332), "Rare → Épique : effet de base plus fort,", font=f_b, fill=c("encre"))
        d.text((x0 + 50, 362), "un effet en plus au hasard.", font=f_b, fill=c("encre"))
        d.text((x0 + 50, 404), "Prix : 160 doublons · 25 fer noir", font=f_bg, fill=c("rouge"))
        d.text((x0 + 50, 446), "+8 % de dégâts   +6 % de coups critiques", font=police("alegreya", 23), fill=(60, 44, 28, 255))
        # bouton et titre sur fond sombre
        b = bouton(col_w - 120, 78, "LEVER L'ANCRE" if titre != "pirata" else "Lever l'ancre", police(titre, 32 if titre != "pirata" else 38))
        im.alpha_composite(b, (x0 + 36, 572))
        f_hud = police("alegreya_noir", 44)
        texte_grave(im, (x0 + 40, 690), "1 250 doublons", police("alegreya_gras", 30), c("or_clair"), ancre="la")
        texte_grave(im, (x0 + 40, 735), "70 bois de coque · 40 fer noir", police("alegreya", 26), c("parchemin"), ancre="la")
        texte_grave(im, (x0 + 40, 790), "22", f_hud, c("or_clair"), ancre="la")
        texte_grave(im, (x0 + 110, 790), "44 !", f_hud, (255, 210, 90, 255), ancre="la")
        texte_grave(im, (x0 + 40, 850), "Salle 3 — Le Récif des Pendus", police(titre, 28 if titre != "pirata" else 34), c("or"), ancre="la")
        # légende
        texte_grave(im, (x0 + 10, 930), f"{lettre} — {nom}", police("alegreya_gras", 30), c("parchemin"), ancre="la")
        d.text((x0 + 10, 972), noms, font=police("alegreya", 23), fill=c("or_clair", 230))
        mots, ligne, y = desc.split(), "", 1004
        for m in mots:   # (sur deux lignes : la colonne est étroite)
            if d.textlength(ligne + " " + m, font=police("alegreya", 21)) > col_w - 40:
                d.text((x0 + 10, y), ligne, font=police("alegreya", 21), fill=c("parchemin", 190))
                ligne, y = m, y + 28
            else:
                ligne = (ligne + " " + m).strip()
        d.text((x0 + 10, y), ligne, font=police("alegreya", 21), fill=c("parchemin", 190))
    im.convert("RGB").save(chemin)


def planche_matieres(chemin):
    W, H = 1800, 1180
    im = fond_planche(W, H)
    d = ImageDraw.Draw(im)
    fi = police("alegreya", 22)
    fg = police("alegreya_gras", 24)
    d.text((40, 24), "Proposition — palette, matières fabriquées pour le jeu, et premiers éléments d'interface", font=fi,
           fill=c("parchemin", 200))
    # palette
    noms = [("charbon", "Noir charbon"), ("bois", "Bois vieilli"), ("cuir", "Cuir sombre"), ("parchemin", "Parchemin"),
            ("or", "Or vieilli"), ("rouge", "Rouge sombre"), ("vert_de_gris", "Vert-de-gris")]
    for i, (cle, nom) in enumerate(noms):
        x = 40 + i * 175
        d.rectangle([x, 70, x + 150, 150], fill=c(cle), outline=c("or_sombre"), width=2)
        d.text((x, 158), nom, font=fg, fill=c("parchemin"))
        d.text((x, 186), "#%02x%02x%02x" % PALETTE[cle], font=fi, fill=c("parchemin", 150))
    # matières
    tuiles = [("Bois usé", bois(220, 170, 31)), ("Cuir cousu", cuir(220, 170, 32)), ("Parchemin brûlé", parchemin(220, 170, 33)),
              ("Fer oxydé, rivets", metal(220, 170, 34)), ("Or vieilli", or_vieilli(220, 170, 35))]
    for i, (nom, t) in enumerate(tuiles):
        x = 40 + i * 245
        im.alpha_composite(t, (x, 240))
        d.text((x, 418), nom, font=fg, fill=c("parchemin"))
    im.alpha_composite(cordage(1180, 26), (40, 470))
    d.text((40, 500), "Cordage (bordures, séparations)", font=fg, fill=c("parchemin"))
    im.alpha_composite(rose_des_vents(210), (1290, 230))
    d.text((1300, 445), "Rose des vents", font=fg, fill=c("parchemin"))
    im.alpha_composite(sceau(150), (1560, 250))
    d.text((1560, 410), "Sceau de cire", font=fg, fill=c("parchemin"))
    # composants
    ft = police("fell_sc", 34)
    im.alpha_composite(plaque_titre(460, 74, "LA FORGE", police("fell_sc", 40)), (40, 560))
    d.text((40, 640), "Plaque de titre (fer oxydé)", font=fg, fill=c("parchemin"))
    im.alpha_composite(bouton(400, 84, "LEVER L'ANCRE", ft), (40, 690))
    im.alpha_composite(bouton(400, 84, "LEVER L'ANCRE", ft, appuye=True), (40, 790))
    d.text((40, 880), "Bouton : planche cerclée de fer (normal / appuyé)", font=fg, fill=c("parchemin"))
    im.alpha_composite(barre_vie(460, 44, 0.76, police("alegreya_gras", 24)), (40, 930))
    d.text((40, 982), "Barre de vie (cuir, crans de 10 %)", font=fg, fill=c("parchemin"))
    # panneau d'exemple, asymétrique : parchemin cloué, plaque de titre qui déborde, coins ornés
    px, py, pw, ph = 560, 560, 760, 560
    im.alpha_composite(panneau_parchemin(pw, ph, graine=51), (px, py))
    im.alpha_composite(plaque_titre(330, 64, "LA FORGE", police("fell_sc", 36)), (px - 18, py - 22))
    co = coin_ornement(70)
    im.alpha_composite(co.transpose(Image.FLIP_LEFT_RIGHT), (px + pw - 92, py + 22))
    im.alpha_composite(co.transpose(Image.FLIP_TOP_BOTTOM), (px + 22, py + ph - 92))
    fb = police("alegreya", 25)
    fbg = police("alegreya_gras", 27)
    d.text((px + 60, py + 70), "Améliorer   ·   Recycler   ·   Relancer", font=police("fell_sc", 30), fill=c("encre"))
    d.line([(px + 60, py + 112), (px + pw - 60, py + 112)], fill=c("parchemin_sombre"), width=2)
    lignes = [("Hache d'abordage", "Rare", (38, 74, 110, 255), "→ Épique · 160 doublons · 25 fer noir"),
              ("Coutelas du quartier-maître", "Épique", (96, 46, 120, 255), "Au plus haut"),
              ("Sabre d'abordage", "Commun", c("encre"), "→ Rare · 80 doublons · 10 fer noir")]
    for i, (nom, rar, col, info) in enumerate(lignes):
        y = py + 135 + i * 118
        d.text((px + 60, y), nom, font=fbg, fill=col)
        d.text((px + 60 + d.textlength(nom, font=fbg) + 12, y + 3), f"({rar})", font=fb, fill=col)
        d.text((px + 60, y + 38), info, font=fb, fill=c("encre"))
        b = bouton(200, 64, "FORGER", police("fell_sc", 28), graine=60 + i)
        im.alpha_composite(b, (px + pw - 270, y + 6))
        if i < 2:
            im.alpha_composite(cordage(pw - 120, 8, graine=70 + i), (px + 60, y + 96))
    im.alpha_composite(sceau(96), (px + pw - 120, py + ph - 128))
    d.text((px, py + ph + 12), "Panneau : parchemin cloué sur bois, plaque de titre qui déborde (composition asymétrique)",
           font=fg, fill=c("parchemin"))
    # carte d'objet sur cuir (infobulle)
    cx0, cy0 = 1350, 560
    carte = cuir(410, 300, 81)
    im.alpha_composite(carte, (cx0, cy0))
    texte_grave(im, (cx0 + 30, cy0 + 26), "Lame du Noyé", police("fell_sc", 36), c("vert_de_gris"), ancre="la")
    d.text((cx0 + 30, cy0 + 72), "Unique · Maudit", font=police("alegreya_sc", 24), fill=c("rouge_clair"))
    d.line([(cx0 + 30, cy0 + 108), (cx0 + 380, cy0 + 108)], fill=c("or_sombre"), width=2)
    for i, t in enumerate(["+30 % de dégâts", "La roulade laisse une traînée", "d'eau maudite qui blesse."]):
        d.text((cx0 + 30, cy0 + 124 + i * 34), t, font=police("alegreya", 25), fill=c("parchemin"))
    d.text((cx0 + 30, cy0 + 240), "▲ +12 % par rapport à ton arme", font=police("alegreya_gras", 23), fill=(150, 200, 140, 255))
    d.text((cx0, cy0 + 312), "Fiche d'objet (cuir cousu)", font=fg, fill=c("parchemin"))
    im.convert("RGB").save(chemin)


# ---------------------------------------------------------------- textures du jeu (thème Godot)
## Marges des textures « 9 cases » : à reprendre telles quelles dans tools/ui/fabriquer_theme.gd.
MARGES = {
    "bouton": (34, 12), "bouton_appuye": (34, 12), "bouton_desactive": (34, 12),
    "plaque": (28, 22), "panneau": (72, 72), "cuir": (24, 24), "onglet": (20, 16), "affiche": (48, 48),
}


def bouton_vide(w, h, etat="normal", graine=11):
    """Le bouton sans texte (le texte vient de Godot) : planche cerclée de fer, filet gravé."""
    teinte = {"normal": 1.0, "appuye": 0.78, "desactive": 0.6}[etat]
    im = bois(w, h, graine, planches=1, teinte=teinte)
    if etat == "desactive":
        a = np.asarray(im).astype(float)
        gris = a[..., :3].mean(axis=2, keepdims=True)
        a[..., :3] = a[..., :3] * 0.35 + gris * 0.65
        im = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")
    bande = 26
    for x0 in (0, w - bande):
        m = metal(bande, h, graine + 7, rivets=False, oxyde=0.8 if etat != "desactive" else 0.2)
        im.paste(m, (x0, 0))
        dessiner_rivet(im, x0 + bande // 2, h // 2 - 15, 4)
        dessiner_rivet(im, x0 + bande // 2, h // 2 + 15, 4)
    d = ImageDraw.Draw(im)
    d.rectangle([bande + 6, 7, w - bande - 7, h - 8], outline=(22, 14, 8, 200), width=2)
    d.rectangle([bande + 6, 9, w - bande - 7, h - 6], outline=(140, 104, 66, 60), width=1)
    d.rectangle([0, 0, w - 1, h - 1], outline=(10, 7, 4, 255), width=2)
    if etat == "appuye":
        ombre = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        ImageDraw.Draw(ombre).rectangle([bande, 2, w - bande, 9], fill=(0, 0, 0, 90))
        im.alpha_composite(ombre)
    return im


def onglet(w, h, graine=15):
    im = cuir(w, h, graine)
    ImageDraw.Draw(im).rectangle([0, 0, w - 1, h - 1], outline=(10, 7, 4, 255), width=2)
    return im


def cordage_raccordable(longueur, epaisseur):
    """Corde qui se raccorde à elle-même de gauche à droite (pour être répétée)."""
    pas = longueur / round(longueur / (epaisseur * 0.9))
    w, h = longueur, epaisseur
    y, x = np.mgrid[0:h, 0:w].astype(float)
    u = ((x + y * 1.1) % pas) / pas
    torsade = np.sin(np.pi * u) ** 0.7
    cyl = np.cos((y - h / 2) / (h / 2) * (np.pi / 2) * 0.95)
    lum = 0.25 + 0.75 * torsade * cyl
    return image(degrade(lum, (40, 28, 16), (190, 156, 104)), np.clip(cyl * 4, 0, 1) * 255)


def trait_encre(w, h=14, graine=16):
    """Séparateur à l'encre sur parchemin : un trait qui s'amincit aux bouts, un losange au milieu."""
    s = 4
    im = Image.new("RGBA", (w * s, h * s), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    cy = h * s / 2
    encre = (52, 34, 18, 230)
    for i in range(w * s):
        t = i / (w * s)
        ep = max(1, int(s * 1.6 * math.sin(math.pi * t) ** 0.6))
        d.line([(i, cy - ep / 2), (i, cy + ep / 2)], fill=encre)
    L = h * s * 0.42
    cx = w * s / 2
    d.polygon([(cx - L, cy), (cx, cy - L * 0.6), (cx + L, cy), (cx, cy + L * 0.6)], fill=(110, 30, 24, 240))
    return im.resize((w, h), Image.LANCZOS)


def sceau_marque(taille, texte="!", graine=17):
    """Petit sceau de cire avec une marque (pastille « ! » des lieux du repaire)."""
    im = sceau_lisse(taille, graine)
    s = 4
    T = taille * s
    grand = im.resize((T, T), Image.LANCZOS)
    d = ImageDraw.Draw(grand)
    f = police("fell_sc", int(T * 0.55))
    d.text((T / 2 + s, T / 2 + s), texte, font=f, fill=(70, 10, 8, 255), anchor="mm")
    d.text((T / 2, T / 2), texte, font=f, fill=(226, 120, 96, 255), anchor="mm")
    return grand.resize((taille, taille), Image.LANCZOS)


def sceau_lisse(taille, graine=18):
    """Sceau de cire sans dessin (fond des marques)."""
    s = 4
    T = taille * s
    im = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    rng = np.random.default_rng(graine)
    cx = cy = T / 2
    pts = [(cx + T * (0.44 + rng.uniform(-0.035, 0.035)) * math.cos(i / 40 * 2 * math.pi),
            cy + T * (0.44 + rng.uniform(-0.035, 0.035)) * math.sin(i / 40 * 2 * math.pi)) for i in range(40)]
    d = ImageDraw.Draw(im)
    d.polygon([(x + 2 * s, y + 3 * s) for x, y in pts], fill=(20, 5, 4, 140))
    d.polygon(pts, fill=c("rouge"))
    d.ellipse([cx - T * 0.32, cy - T * 0.32, cx + T * 0.32, cy + T * 0.32], fill=(118, 24, 21, 255),
              outline=(170, 50, 42, 255), width=2 * s)
    return im.filter(ImageFilter.GaussianBlur(s * 0.4)).resize((taille, taille), Image.LANCZOS)


def fond_ecran(w=640, h=360, graine=97):
    n = bruit(w, h, 220, None, graine)
    g = bruit(w, h, 3, None, graine + 1, octaves=1)
    lum = 0.32 + 0.4 * n + 0.06 * (g - 0.5)
    y, x = np.mgrid[0:h, 0:w].astype(float)
    v = ((x - w * 0.42) / (w * 0.75)) ** 2 + ((y - h * 0.45) / (h * 0.7)) ** 2
    lum *= np.clip(1.15 - v, 0.25, 1.0)
    return image(degrade(lum, (8, 7, 6), (52, 42, 33)))


def affiche(w, h, graine=19, appuye=False):
    """Une affiche (avis de recrutement) : parchemin brûlé, deux clous en haut ; appuyée, plus sombre."""
    im = parchemin(w, h, graine)
    if appuye:
        a = np.asarray(im).astype(float)
        a[..., :3] *= 0.82
        im = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")
    for x in (34, w - 35):
        dessiner_rivet(im, x, 30, 6)
    return im


def textures(dossier):
    dossier = Path(dossier)
    dossier.mkdir(parents=True, exist_ok=True)
    sorties = {
        "bouton": bouton_vide(320, 88, "normal"),
        "bouton_appuye": bouton_vide(320, 88, "appuye"),
        "bouton_desactive": bouton_vide(320, 88, "desactive"),
        "plaque": metal(320, 72, 12, rivets=True),
        "panneau": panneau_parchemin(512, 512, graine=13),
        "cuir": cuir(256, 256, 2),
        "onglet": onglet(220, 64),
        "cordage": cordage_raccordable(288, 14),
        "trait_encre": trait_encre(420),
        "fond": fond_ecran(),
        "rose_des_vents": rose_des_vents(256),
        "sceau": sceau(128),
        "sceau_lisse": sceau_lisse(96),
        "sceau_marque": sceau_marque(72),
        "coin": coin_ornement(96),
        "affiche": affiche(400, 300),
        "affiche_appuye": affiche(400, 300, appuye=True),
    }
    for nom, im in sorties.items():
        im.save(dossier / f"{nom}.png")
    print("Textures :", ", ".join(sorted(sorties)))


if __name__ == "__main__":
    if len(sys.argv) >= 3 and sys.argv[1] == "textures":
        textures(sys.argv[2])
    elif len(sys.argv) >= 3 and sys.argv[1] == "planches":
        dossier = Path(sys.argv[2])
        dossier.mkdir(parents=True, exist_ok=True)
        planche_polices(dossier / "planche_polices.png")
        planche_matieres(dossier / "planche_matieres.png")
        print("Planches :", dossier)
    else:
        print(__doc__)
