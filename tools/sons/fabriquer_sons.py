"""Fabrique les sons qui n'existent pas dans les packs libres (06/11, jalon 6, choix de Téo : ambiances, pas de musique
continue) : souffles de lame, magie de l'Occultiste, explosions, canon, os qui éclatent, et les ambiances en boucle
(ressac, houle, vent, gouttes dans la grotte, torches). Tout est calculé (bruits filtrés, sons purs, enveloppes) :
aucun enregistrement, donc aucun droit à respecter. Les sons Kenney (CC0) choisis sont copiés à côté.

Usage : tools/sons/telecharger_kenney.sh puis python3 tools/sons/fabriquer_sons.py   (pip install numpy scipy soundfile)
Sortie : assets/sons/fabriques/*.ogg et assets/sons/kenney/*.ogg (puis : godot --headless --path . --import)
Les ambiances bouclent par leur réglage d'import (loop=true dans leur .ogg.import, versionné : il reste quand on
refabrique les sons).
Rien n'a été écouté par celui qui l'a écrit : Téo juge à l'oreille, on retouche les réglages ici.
"""
import glob
import os

import numpy as np
import soundfile as sf
from scipy import signal

TAUX = 44100
RACINE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SORTIE = os.path.join(RACINE, "assets", "sons", "fabriques")
KENNEY = os.path.join(RACINE, "assets", "sons", "kenney")
rng = np.random.default_rng(7)


# ---------------------------------------------------------------- briques
def t(duree):
    return np.arange(int(duree * TAUX)) / TAUX


def bruit(n):
    return rng.standard_normal(n)


def brun(n):
    b = np.cumsum(rng.standard_normal(n))
    b = signal.sosfilt(signal.butter(1, 20, "hp", fs=TAUX, output="sos"), b)
    return b / (np.abs(b).max() + 1e-9)


def passe_bas(x, f, ordre=2):
    return signal.sosfilt(signal.butter(ordre, f, "lp", fs=TAUX, output="sos"), x)


def passe_haut(x, f, ordre=2):
    return signal.sosfilt(signal.butter(ordre, f, "hp", fs=TAUX, output="sos"), x)


def passe_bande(x, f1, f2, ordre=2):
    return signal.sosfilt(signal.butter(ordre, [f1, f2], "bp", fs=TAUX, output="sos"), x)


def bande_glissante(x, centres, q=1.6):
    """Filtre passe-bande dont le centre suit `centres` (une fréquence par échantillon) : filtre d'état variable."""
    y = np.zeros_like(x)
    bas = bande = 0.0
    for i in range(len(x)):
        f = 2.0 * np.sin(np.pi * min(centres[i], TAUX / 6) / TAUX)
        haut = x[i] - bas - bande / q
        bande += f * haut
        bas += f * bande
        y[i] = bande
    return y


def enveloppe(n, attaque, chute, forme=2.0):
    e = np.ones(n)
    a = max(1, int(attaque * TAUX))
    e[:a] = np.linspace(0, 1, a)
    c = min(n - a, int(chute * TAUX))
    if c > 0:
        e[n - c:] *= np.linspace(1, 0, c) ** forme
    return e


def cloche(n):
    return np.sin(np.linspace(0, np.pi, n)) ** 2


def normaliser(x, crete=0.89):
    return x / (np.abs(x).max() + 1e-9) * crete


def ecrire(nom, x, crete=0.89):
    os.makedirs(SORTIE, exist_ok=True)
    x = normaliser(np.asarray(x, dtype=np.float64), crete)
    _ecrire_ogg(os.path.join(SORTIE, nom + ".ogg"), x, TAUX)
    print("son", nom, "%.2f s" % (len(x) / TAUX))


def _ecrire_ogg(chemin, x, taux):
    """Écrit un OGG, sauf si le fichier déjà là contient exactement le même son : chaque écriture OGG porte un numéro
    tiré au hasard, et git verrait tous les sons changés à chaque passage du script."""
    temporaire = chemin + ".tmp.ogg"
    sf.write(temporaire, np.asarray(x, dtype=np.float32), taux, format="OGG", subtype="VORBIS")
    if os.path.exists(chemin):
        neuf, _ = sf.read(temporaire)
        ancien, _ = sf.read(chemin)
        if neuf.shape == ancien.shape and np.abs(neuf - ancien).max() < 1e-7:
            os.remove(temporaire)
            return
    os.replace(temporaire, chemin)


def boucle(x, fondu=1.0):
    """Rend une ambiance bouclable sans à-coup : la fin se fond dans le début."""
    f = int(fondu * TAUX)
    debut, corps = x[:f], x[f:]
    rampe = np.linspace(0, 1, f)
    corps[-f:] = corps[-f:] * (1 - rampe) + debut * rampe
    return corps


# ---------------------------------------------------------------- combat
def souffle(duree, f_bas, f_haut, graine):
    """Une lame qui fend l'air : un bruit dont la hauteur monte puis redescend."""
    global rng
    rng = np.random.default_rng(graine)
    n = int(duree * TAUX)
    p = np.linspace(0, 1, n)
    centres = f_bas + (f_haut - f_bas) * np.sin(np.pi * p) ** 1.5
    return passe_bas(bande_glissante(bruit(n), centres, 3.5), 4500, 4) * cloche(n) ** 0.8


def lames():
    for i, (d, b, h) in enumerate([(0.24, 500, 2600), (0.21, 650, 3000), (0.27, 450, 2300)]):
        ecrire("lame_%d" % (i + 1), souffle(d, b, h, 10 + i))
    # moulinet : deux passages autour du corps
    n = int(0.6 * TAUX)
    p = np.linspace(0, 1, n)
    centres = 600 + 2000 * np.abs(np.sin(2 * np.pi * p)) ** 1.3
    ecrire("moulinet", passe_bas(bande_glissante(bruit(n), centres, 3.5), 4500, 4) * cloche(n) ** 0.5 * (0.6 + 0.4 * np.abs(np.sin(2 * np.pi * p))))


def os_eclat():
    """Un squelette qui éclate : une volée de petits chocs secs (os sur os, os sur pierre)."""
    for k in range(2):
        global rng
        rng = np.random.default_rng(30 + k)
        n = int(0.42 * TAUX)
        x = np.zeros(n)
        temps = np.sort(np.concatenate([[0.0, 0.012], rng.uniform(0.02, 0.45, 11) ** 1.4]))
        for j, t0 in enumerate(temps):
            d = int(rng.uniform(0.012, 0.03) * TAUX)
            f = rng.uniform(900, 2600)
            c = passe_bande(bruit(d), f * 0.7, min(f * 1.5, 19000), 2) * np.exp(-np.linspace(0, 9, d))
            i0 = int(t0 * TAUX)
            x[i0:i0 + d] += c[: n - i0] * (1.0 if j < 2 else rng.uniform(0.25, 0.7)) / (1 + 0.15 * j)
        ecrire("os_%d" % (k + 1), x)


def magie():
    # tir maudit : une plainte grave qui glisse, un souffle, un frisson
    tt = t(0.42)
    n = len(tt)
    freq = 190 * np.exp(-tt * 2.2) + 70
    phase = 2 * np.pi * np.cumsum(freq) / TAUX
    ton = np.sin(phase) + 0.5 * np.sin(2.01 * phase) + 0.25 * np.sin(3.03 * phase)
    souffle_ = passe_bande(bruit(n), 300, 1400) * 0.6
    frisson = passe_bande(bruit(n), 3000, 7000) * 0.25 * np.exp(-tt * 9)
    ecrire("tir_maudit", (ton * 0.7 + souffle_ + frisson) * enveloppe(n, 0.012, 0.3))
    # explosion maudite : un coup sourd, un souffle qui retombe, des éclats verts (aigus brefs)
    tt = t(0.85)
    n = len(tt)
    sourd = np.sin(2 * np.pi * np.cumsum(70 * np.exp(-tt * 3) + 38) / TAUX) * np.exp(-tt * 7)
    corps = bande_glissante(bruit(n), 2500 * np.exp(-tt * 5) + 250, 0.9) * np.exp(-tt * 4.5)
    eclats = passe_haut(bruit(n), 5000) * np.exp(-tt * 18) * 0.3
    ecrire("explosion_maudite", (sourd * 1.2 + corps + eclats) * enveloppe(n, 0.003, 0.4))
    # téléportation : un souffle qui s'aspire puis un scintillement
    tt = t(0.5)
    n = len(tt)
    p = tt / tt[-1]
    aspire = bande_glissante(bruit(n), 300 + 3500 * p ** 2, 2.0) * p ** 2 * (1 - p) ** 0.3
    scint = sum(np.sin(2 * np.pi * f * tt + 3 * np.sin(2 * np.pi * 7 * tt)) for f in (1760, 2350, 3140)) / 3
    ecrire("teleport", aspire + scint * 0.18 * np.exp(-((p - 0.75) ** 2) / 0.02))
    # chaînes : des maillons de fer qui s'entrechoquent (sons inharmoniques très brefs)
    global rng
    rng = np.random.default_rng(50)
    n = int(0.8 * TAUX)
    x = np.zeros(n)
    for t0 in np.sort(rng.uniform(0.0, 0.55, 14)):
        d = int(0.09 * TAUX)
        tt2 = np.arange(d) / TAUX
        base = rng.uniform(1800, 2600)
        clic = sum(np.sin(2 * np.pi * base * r * tt2) * a for r, a in ((1.0, 1.0), (1.58, 0.6), (2.37, 0.4), (3.11, 0.25)))
        clic *= np.exp(-tt2 * rng.uniform(35, 60))
        i0 = int(t0 * TAUX)
        x[i0:i0 + d] += clic[: n - i0] * rng.uniform(0.4, 1.0)
    grave = passe_bas(bruit(n), 400) * enveloppe(n, 0.02, 0.4) * 0.5
    ecrire("chaines", x + grave)
    # marque : un accord sourd et tremblant
    tt = t(0.8)
    n = len(tt)
    trem = 0.75 + 0.25 * np.sin(2 * np.pi * 9 * tt)
    ton = np.sin(2 * np.pi * 110 * tt) + 0.7 * np.sin(2 * np.pi * 164.8 * tt) + 0.4 * np.sin(2 * np.pi * 233 * tt)
    ecrire("marque", (ton * trem + passe_bande(bruit(n), 200, 900) * 0.4) * enveloppe(n, 0.01, 0.55))


def explosions():
    # tonneau de poudre : grosse détonation et crépitement
    tt = t(1.5)
    n = len(tt)
    sourd = np.sin(2 * np.pi * np.cumsum(90 * np.exp(-tt * 4) + 32) / TAUX) * np.exp(-tt * 3.5)
    corps = passe_bas(bande_glissante(bruit(n), 2200 * np.exp(-tt * 4) + 150, 0.8), 3500) * np.exp(-tt * 2.5)
    global rng
    rng = np.random.default_rng(60)
    crep = np.zeros(n)
    for t0 in rng.uniform(0.08, 1.2, 40):
        d = int(0.006 * TAUX)
        i0 = int(t0 * TAUX)
        crep[i0:i0 + d] += bruit(d)[: n - i0] * np.exp(-t0 * 2.5)
    ecrire("explosion_poudre", (sourd * 1.6 + corps + passe_bande(crep, 1200, 5000) * 0.35) * enveloppe(n, 0.002, 0.6))
    # coup de canon (bordée) : une détonation lourde et un grondement qui roule
    tt = t(1.8)
    n = len(tt)
    sourd = np.sin(2 * np.pi * np.cumsum(70 * np.exp(-tt * 5) + 28) / TAUX) * np.exp(-tt * 2.2)
    souffle_ = passe_bas(bruit(n), 900) * np.exp(-tt * 3.0)
    roule = passe_bas(brun(n), 160) * np.exp(-tt * 1.4) * 0.8
    ecrire("canon", (sourd * 1.5 + souffle_ + roule) * enveloppe(n, 0.002, 0.8))


def essence():
    """Essence maudite ramassée : un petit tintement vert."""
    tt = t(0.45)
    n = len(tt)
    x = sum(np.sin(2 * np.pi * f * tt) * a for f, a in ((1318, 1.0), (1976, 0.6), (2637, 0.35)))
    ecrire("essence", x * np.exp(-tt * 7) * enveloppe(n, 0.004, 0.1), 0.6)


# ---------------------------------------------------------------- ennemis (06/11, choix de Téo)
def ennemis():
    global rng
    # squelette qui sort de terre : la terre qui se soulève (grondement), des cailloux qui roulent, puis un cliquetis
    # d'os quand il se redresse
    rng = np.random.default_rng(110)
    tt = t(1.1)
    n = len(tt)
    p = tt / tt[-1]
    terre = passe_bas(brun(n), 320) * np.sin(np.pi * np.clip(p * 1.3, 0, 1)) ** 1.5
    cailloux = np.zeros(n)
    for t0 in np.sort(rng.uniform(0.0, 0.7, 26)):
        d = int(rng.uniform(0.006, 0.02) * TAUX)
        f = rng.uniform(700, 2600)
        c = passe_bande(bruit(d), f * 0.7, f * 1.4) * np.exp(-np.linspace(0, 8, d))
        i0 = int(t0 * TAUX)
        cailloux[i0:i0 + d] += c[: n - i0] * rng.uniform(0.2, 0.8) * (1.0 - t0)
    os_ = np.zeros(n)
    for t0 in rng.uniform(0.72, 0.95, 5):
        d = int(0.02 * TAUX)
        c = passe_bande(bruit(d), 1500, 4500) * np.exp(-np.linspace(0, 9, d))
        i0 = int(t0 * TAUX)
        os_[i0:i0 + d] += c[: n - i0] * rng.uniform(0.3, 0.6)
    ecrire("sortie_terre", (terre * 0.9 + cailloux + os_) * enveloppe(n, 0.05, 0.2))

    # cri du Bosco (sa rage à mi-vie) : une gorge vide qui gronde ; hauteur qui monte puis retombe, voix rauque
    # (harmoniques secouées), trois « formants » de bouche, un peu de souffle, saturé doucement
    rng = np.random.default_rng(120)
    tt = t(1.5)
    n = len(tt)
    p = tt / tt[-1]
    f0 = 85 + 55 * np.sin(np.pi * np.clip(p * 1.15, 0, 1)) ** 0.7
    f0 = f0 * (1 + 0.025 * passe_bas(bruit(n), 30) / 0.05)
    phase = 2 * np.pi * np.cumsum(f0) / TAUX
    source = np.zeros(n)
    for k in range(1, 28):
        secousse = 1 + 0.35 * passe_bas(bruit(n), 40) / 0.05
        source += np.sin(k * phase) / k ** 0.9 * secousse
    souffle_ = passe_bande(bruit(n), 300, 3500) * (0.5 + 0.5 * np.sin(phase)) * 0.6
    voix = source + souffle_ * np.abs(source).mean() * 2
    bouche = (passe_bande(voix, 450, 800) * 1.0 + passe_bande(voix, 950, 1400) * 0.7
              + passe_bande(voix, 2200, 2900) * 0.35 + passe_bas(voix, 250) * 0.5)
    bouche = np.tanh(normaliser(bouche) * 2.2)
    grave = np.sin(2 * np.pi * np.cumsum(f0 / 2) / TAUX) * 0.35
    ecrire("cri_bosco", (bouche + grave) * enveloppe(n, 0.09, 0.45, 1.6))

    # prêtre noyé qui relève les morts : un accord sourd et faux qui enfle, l'eau qui gargouille (bulles)
    rng = np.random.default_rng(130)
    tt = t(1.7)
    n = len(tt)
    p = tt / tt[-1]
    accord = sum(np.sin(2 * np.pi * f * tt + 0.4 * np.sin(2 * np.pi * 0.7 * tt)) * a
                 for f, a in ((55.0, 1.0), (58.3, 0.8), (82.4, 0.6), (116.5, 0.35), (174.6, 0.2)))
    accord *= (np.sin(np.pi * p) ** 1.2) * (0.8 + 0.2 * np.sin(2 * np.pi * 5.5 * tt))
    bulles = np.zeros(n)
    t0 = 0.05
    while t0 < 1.5:
        d = int(rng.uniform(0.04, 0.09) * TAUX)
        tt2 = np.arange(d) / TAUX
        f = rng.uniform(250, 600)
        b = np.sin(2 * np.pi * np.cumsum(f * (1 + 2.5 * tt2 / tt2[-1])) / TAUX) * np.exp(-tt2 * 30)
        i0 = int(t0 * TAUX)
        bulles[i0:i0 + d] += b[: n - i0] * rng.uniform(0.2, 0.7) * np.sin(np.pi * t0 / 1.6)
        t0 += rng.exponential(0.06)
    eau = passe_bas(brun(n), 500) * np.sin(np.pi * p) * 0.4
    ecrire("relever", (accord * 0.8 + bulles * 0.6 + eau) * enveloppe(n, 0.1, 0.4))


# ---------------------------------------------------------------- ambiances (en boucle, stéréo)
def ecrire_stereo(nom, g, d, crete=0.89):
    os.makedirs(SORTIE, exist_ok=True)
    x = np.stack([g, d], axis=1)
    x = x / (np.abs(x).max() + 1e-9) * crete
    _ecrire_ogg(os.path.join(SORTIE, nom + ".ogg"), x, TAUX)
    print("ambiance", nom, "%.2f s" % (len(x) / TAUX))


def ambiances():
    """Chaque ambiance a deux oreilles faites de bruits différents (sinon le son paraît « dans la tête ») mais qui
    suivent les mêmes vagues, le même vent : l'espace s'ouvre sans que les deux côtés se contredisent."""
    L = 20.0   # durée d'une boucle (s) : toutes les modulations font un nombre entier de tours en L
    tt = t(L + 1.0)
    n = len(tt)

    def lent(tours, phase=0.0):
        return 0.5 + 0.5 * np.sin(2 * np.pi * tours * tt / L + phase)

    global rng
    # ressac (repaire, écran titre) : des vagues qui viennent et repartent, l'écume au sommet (un peu décalée
    # d'une oreille à l'autre : la vague roule le long du rivage)
    cotes = []
    for k in range(2):
        rng = np.random.default_rng(70 + k)
        vague = lent(3, 0.25 * k) ** 2.2 * 0.75 + lent(5, 1.3 + 0.3 * k) ** 3 * 0.25
        fond = passe_bas(brun(n), 700) * (0.35 + 0.65 * vague)
        ecume = passe_bande(bruit(n), 2500, 8000) * vague ** 4 * 0.22
        cotes.append(boucle(fond + ecume))
    ecrire_stereo("ressac", *cotes, crete=0.5)
    # houle (chaloupe) : plus forte, plus grave, plus serrée, des coups de mer contre la coque
    cotes = []
    for k in range(2):
        rng = np.random.default_rng(74 + k)
        vague = lent(6, 0.2 * k) ** 1.6 * 0.7 + lent(9, 0.7 + 0.2 * k) ** 2.5 * 0.3
        fond = passe_bas(brun(n), 500) * (0.25 + 0.75 * vague) + passe_bas(brun(n), 90) * 0.5
        ecume = passe_bande(bruit(n), 1800, 7000) * vague ** 3 * 0.3
        cotes.append(boucle(fond + ecume))
    ecrire_stereo("houle", *cotes, crete=0.6)
    # vent (expédition) : un souffle qui siffle doucement et change de hauteur
    cotes = []
    for k in range(2):
        rng = np.random.default_rng(76 + k)
        centres = 350 + 450 * lent(2, 0.15 * k) + 200 * lent(7, 2.0)
        vent = bande_glissante(bruit(n), centres, 3.0) * (0.45 + 0.55 * lent(3, 0.4) ** 1.5)
        cotes.append(boucle(vent + passe_bas(brun(n), 200) * 0.3))
    ecrire_stereo("vent", *cotes, crete=0.35)
    # gouttes (grotte du repaire) : des gouttes espacées, chacune d'un côté, et un grondement très grave
    rng = np.random.default_rng(80)
    g = passe_bas(brun(n), 120) * 0.12
    d = passe_bas(brun(n), 120) * 0.12
    t0 = 0.4
    while t0 < L - 0.5:
        dd = int(0.16 * TAUX)
        tt2 = np.arange(dd) / TAUX
        f0 = rng.uniform(1100, 2300)
        goutte = np.sin(2 * np.pi * np.cumsum(f0 * (1 + 0.6 * np.exp(-tt2 * 60))) / TAUX) * np.exp(-tt2 * 28)
        i0 = int(t0 * TAUX)
        a = rng.uniform(0.3, 1.0)
        cote = rng.uniform(0.1, 0.9)   # 0 = à gauche, 1 = à droite
        g[i0:i0 + dd] += goutte * a * (1 - cote)
        d[i0:i0 + dd] += goutte * a * cote
        e0 = i0 + int(0.09 * TAUX)   # (l'écho de la grotte revient de l'autre côté)
        g[e0:e0 + dd] += goutte * a * 0.25 * cote
        d[e0:e0 + dd] += goutte * a * 0.25 * (1 - cote)
        t0 += rng.uniform(0.9, 2.6)
    ecrire_stereo("gouttes", boucle(g), boucle(d), crete=0.35)
    # torches : le feu qui ronfle, et des braises qui claquent (petits chocs brefs, pas un grésillement)
    cotes = []
    for k in range(2):
        rng = np.random.default_rng(90 + k)
        feu = passe_bas(brun(n), 380) * (0.6 + 0.4 * lent(11, 0.2 + k) * lent(4, k))
        crep = np.zeros(n)
        t0 = 0.0
        while t0 < L + 0.9:
            dd = int(rng.uniform(0.004, 0.012) * TAUX)
            i0 = int(t0 * TAUX)
            claque = passe_bande(bruit(dd), 700, rng.uniform(2500, 5000)) * np.exp(-np.linspace(0, 7, dd))
            crep[i0:i0 + dd] += claque[: n - i0] * rng.uniform(0.15, 1.0) ** 2
            t0 += rng.exponential(0.11)
        cotes.append(boucle(feu * 0.7 + crep * 0.6))
    ecrire_stereo("torches", *cotes, crete=0.3)


# ---------------------------------------------------------------- sons Kenney choisis (CC0)
KENNEY_CHOIX = {
    # combat
    "coup_1": "impact_wood_medium_000", "coup_2": "impact_wood_medium_001", "coup_3": "impact_wood_medium_002",
    "coup_lourd": "impact_wood_heavy_000", "critique": "impact_punch_heavy_000",
    "touche_1": "impact_punch_medium_000", "touche_2": "impact_punch_medium_001",
    "parade_1": "impact_metal_medium_000", "parade_2": "impact_metal_medium_001",
    "parade_parfaite": "impact_bell_heavy_000",
    "sol_lourd": "impact_mining_000", "terre": "impact_soft_heavy_000",
    # butin, repaire, interface
    "bois": "impact_plank_medium_000", "fer": "impact_metal_light_000",
    "clic": "impact_wood_light_000", "clic_2": "impact_wood_light_001",
    "enclume": "impact_metal_heavy_000", "marteau_1": "impact_plank_medium_001", "marteau_2": "impact_plank_medium_002",
    "objet_rare": "impact_bell_heavy_001",
}
KENNEY_RPG = {
    "roulade_1": "cloth_1", "roulade_2": "cloth_2", "tomber": "cloth_belt",
    "pieces_1": "handle_coins", "pieces_2": "handle_coins_2", "objet": "handle_small_leather",
    "parchemin": "book_open", "parchemin_ferme": "book_close", "page": "book_flip_1",
    "porte": "door_open_1", "coffre": "creak_1", "loquet": "metal_latch", "carreau": "knife_slice_2",
}

JINGLES = {
    "victoire": "jingles_pizzi_10",   # ré mi fa# sol : monte et se pose sur la tonique (sol majeur)
    "defaite": "jingles_pizzi_7",     # fa mi ré# ré : descend d'un demi-ton à chaque note, lentement
}


def kenney():
    os.makedirs(KENNEY, exist_ok=True)
    src_impact = glob.glob(os.path.join(RACINE, "third_party", "sons", "kenney-impact-sounds-for-godot", "**", "*.ogg"),
                           recursive=True)
    src_rpg = glob.glob(os.path.join(RACINE, "third_party", "sons", "kenney-rpg-audio-for-godot", "**", "*.ogg"),
                        recursive=True)
    for choix, sources in ((KENNEY_CHOIX, src_impact), (KENNEY_RPG, src_rpg)):
        par_nom = {os.path.basename(s)[:-4]: s for s in sources}
        for nom, src in choix.items():
            if src not in par_nom:
                raise SystemExit("introuvable dans les packs Kenney : " + src)
            _copier(par_nom[src], nom)
    # les deux petites musiques de fin d'expédition (pizzicato : cordes pincées, plus « pirate maudit » que le
    # 8-bit, le saxophone ou les steel-drums ; voir le choix dans docs/avancement.md)
    jingles = glob.glob(os.path.join(RACINE, "third_party", "sons", "kenney-music-jingles-for-godot", "**", "*.ogg"),
                        recursive=True)
    par_nom = {os.path.basename(s)[:-4]: s for s in jingles}
    for nom, src in JINGLES.items():
        _copier(par_nom[src], nom, mono=False)
    print("Kenney :", len(KENNEY_CHOIX) + len(KENNEY_RPG) + len(JINGLES), "sons copiés")


def _copier(src, nom, mono=True):
    """Copie un son Kenney : en mono pour les sons placés dans l'espace, à la même crête que les sons fabriqués
    (les originaux vont de 0,2 à 1,08 : certains saturaient, d'autres étaient presque muets)."""
    x, taux = sf.read(src)
    if mono and x.ndim > 1:
        x = x.mean(axis=1)
    x = x / (np.abs(x).max() + 1e-9) * 0.89
    _ecrire_ogg(os.path.join(KENNEY, nom + ".ogg"), x, taux)


if __name__ == "__main__":
    lames()
    os_eclat()
    magie()
    explosions()
    essence()
    ennemis()
    ambiances()
    kenney()
