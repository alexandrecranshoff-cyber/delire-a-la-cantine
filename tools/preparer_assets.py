"""Fabrique les images du jeu à partir des visuels de référence (assets/reference/).

    python3 tools/preparer_assets.py            # tout
    python3 tools/preparer_assets.py pions      # une seule famille

Deux qualités sont produites : assets/hd/ (version PC) et assets/sd/ (version web, deux fois plus petite).
Dépendances : Pillow, numpy, scipy.
"""
import json
import pathlib
import random
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

import decoupe as d

ROOT = pathlib.Path(__file__).resolve().parent.parent
REF = ROOT / "assets" / "reference"
QUALITIES = {"hd": 1.0, "sd": 0.5}
INK = (29, 29, 29)


def out_path(quality, family, name):
    p = ROOT / "assets" / quality / family
    p.mkdir(parents=True, exist_ok=True)
    return p / name


def save_all(img, family, name, hd_height=None, hd_width=None):
    """Enregistre l'image aux deux qualités (hauteur ou largeur HD donnée)."""
    for quality, factor in QUALITIES.items():
        if hd_height:
            h = max(8, round(hd_height * factor))
            w = max(8, round(img.width * h / img.height))
        else:
            w = max(8, round((hd_width or img.width) * factor))
            h = max(8, round(img.height * w / img.width))
        small = img.resize((w, h), Image.LANCZOS)
        if small.mode == "RGBA":
            small = d.bleed(small)
        small.save(out_path(quality, family, name), optimize=True)


# --- Personnages -------------------------------------------------------------

def split_views(img, count=5):
    """Sépare les vues d'une fiche : les colonnes vides entre les dessins servent de coupes."""
    alpha = np.asarray(img)[:, :, 3] > 60
    cols = alpha.sum(axis=0)
    width = alpha.shape[1]
    # Coupes : au creux le plus marqué autour de chaque frontière attendue.
    filled = np.nonzero(cols > 0)[0]
    x0, x1 = filled.min(), filled.max()
    step = (x1 - x0) / count
    smooth = ndimage.uniform_filter1d(cols.astype(np.float32), 9)
    cuts = [0]
    for k in range(1, count):
        guess = int(x0 + step * k)
        lo, hi = max(0, guess - int(step * 0.3)), min(width - 1, guess + int(step * 0.3))
        cuts.append(lo + int(np.argmin(smooth[lo:hi])))
    cuts.append(width)
    views = []
    for k in range(count):
        part = img.crop((cuts[k], 0, cuts[k + 1], img.height))
        a = np.asarray(part)[:, :, 3] > 60
        # On ne garde que le plus gros morceau et ce qui le touche presque (lacets, mèches).
        labels, n = ndimage.label(ndimage.binary_dilation(a, iterations=10))
        if n > 1:
            sizes = ndimage.sum(a, labels, range(1, n + 1))
            keep = labels == (1 + int(np.argmax(sizes)))
            arr = np.asarray(part).copy()
            arr[:, :, 3] = np.where(keep, arr[:, :, 3], 0)
            part = Image.fromarray(arr, "RGBA")
            a = np.asarray(part)[:, :, 3] > 60
        ys, xs = np.nonzero(a)
        views.append(part.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)))
    return views


def open_legs(view):
    """Retire le blanc du fond resté enfermé entre les jambes (moitié basse du dessin seulement)."""
    arr = np.asarray(view).copy()
    rgb = arr[:, :, :3].astype(np.int16)
    white = (rgb.min(axis=2) >= 244) & (arr[:, :, 3] > 200)
    labels, n = ndimage.label(white)
    h = arr.shape[0]
    for i, sl in enumerate(ndimage.find_objects(labels), start=1):
        area = int((labels[sl] == i).sum())
        if sl[0].start > h * 0.52 and area > 500:
            region = ndimage.binary_dilation(labels == i, iterations=2)
            arr[:, :, 3] = np.where(region, 0, arr[:, :, 3])
    return Image.fromarray(arr, "RGBA")


def build_pawns():
    look = json.loads((ROOT / "data" / "apparence.json").read_text(encoding="utf-8"))
    entries = list(look["eleves"].values()) + list(look["autres"].values()) + look["neutres"]
    meta = {}
    cell_h = 640
    pad = 40
    for e in entries:
        name = e["image"]
        rgb = d.load_rgb(REF / "personnages" / f"fiche_{name}.png")
        views = [open_legs(v) for v in split_views(d.cutout(rgb))]
        for k in e.get("vues_a_retourner", []):
            views[k] = views[k].transpose(Image.FLIP_LEFT_RIGHT)
        tallest = max(v.height for v in views)
        scale = (cell_h - 2 * pad) / tallest
        views = [v.resize((max(1, round(v.width * scale)), max(1, round(v.height * scale))), Image.LANCZOS) for v in views]
        cell_w = max(v.width for v in views) + 2 * pad
        cell_w += cell_w % 2
        atlas = Image.new("RGBA", (cell_w * 5, cell_h), (0, 0, 0, 0))
        for k, v in enumerate(views):
            atlas.alpha_composite(v, (k * cell_w + (cell_w - v.width) // 2, cell_h - pad - v.height))
        save_all(atlas, "pions", f"{name}.png", hd_height=cell_h)
        meta[name] = {"aspect": round(cell_w / cell_h, 4), "marge": round(pad / cell_h, 4)}
        # Portrait : le haut de la vue de face, dans un carré.
        front = views[0]
        side = round(front.height * e["portrait"])
        cx = front.width // 2
        box = (cx - side // 2, 0, cx - side // 2 + side, side)
        portrait = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        portrait.alpha_composite(front.crop((max(0, box[0]), 0, min(front.width, box[2]), side)), (max(0, -box[0]), 0))
        save_all(portrait, "portraits", f"{name}.png", hd_height=256)
        print("pion", name, atlas.size)
    (ROOT / "data" / "pions_images.json").write_text(json.dumps(
        {"_note": "Généré par tools/preparer_assets.py : proportions des planches de pions (5 vues côte à côte).", "images": meta},
        ensure_ascii=False, indent=1) + "\n", encoding="utf-8")


# --- Accessoires, projectiles, effets ----------------------------------------

def pick(boxes, x, y):
    """Dessin dont le centre est le plus proche du point attendu (coordonnées de la planche)."""
    return min(boxes, key=lambda b: ((b[0] + b[2]) / 2 - x) ** 2 + ((b[1] + b[3]) / 2 - y) ** 2)


def remove_enclosed_white(img, min_area=600):
    arr = np.asarray(img).copy()
    rgb = arr[:, :, :3].astype(np.int16)
    white = (rgb.min(axis=2) >= 248) & (arr[:, :, 3] > 200)
    labels, n = ndimage.label(white)
    for i, sl in enumerate(ndimage.find_objects(labels), start=1):
        if int((labels[sl] == i).sum()) > min_area:
            region = ndimage.binary_dilation(labels == i, iterations=2)
            arr[:, :, 3] = np.where(region, 0, arr[:, :, 3])
    return Image.fromarray(arr, "RGBA")


def build_props():
    rgb = d.load_rgb(REF / "elements" / "accessoires.png")
    sheet = d.cutout(rgb, extra_colors=[((200, 185, 166), 14)])
    boxes, labels = d.components(sheet, merge=10)
    wanted = {  # nom : (centre attendu, hauteur HD, retirer le blanc enfermé)
        "bac": ((1870, 370), 512, True),
        "chariot": ((2400, 410), 512, True),
        "lavabo": ((360, 1100), 512, True),
        "plateau_rouge": ((1710, 900), 128, False),
        "plateau_bleu": ((2340, 915), 128, False),
        "assiettes": ((1605, 1270), 160, False),
        "pichet": ((2010, 1230), 192, False),
        "verre": ((2160, 1345), 96, False),
    }
    for name, (center, height, holes) in wanted.items():
        img = d.crop_component(sheet, labels, pick(boxes, *center))
        if holes:
            img = remove_enclosed_white(img)
        a = np.asarray(img)[:, :, 3] > 60
        ys, xs = np.nonzero(a)
        img = img.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
        save_all(img, "accessoires", f"{name}.png", hd_height=height)
        print("accessoire", name, img.size)


def build_projectiles():
    rgb = d.load_rgb(REF / "elements" / "projectiles.png")
    sheet = d.cutout(rgb)
    boxes, labels = d.components(sheet, merge=22, min_area=6000)
    keys = [["2", "3", "4", "5"], ["6", "7", "8", "9"], ["10", "11", "12", "robinet"]]
    for r in range(3):
        for c in range(4):
            box = pick(boxes, 2752 * (c + 0.5) / 4, 1536 * (r + 0.5) / 3)
            img = d.crop_component(sheet, labels, box)
            save_all(img, "projectiles", f"projectile_{keys[r][c]}.png", hd_height=192)
    print("projectiles", len(boxes))
    # Plats des menus du jour (niveaux 2 et 3) : planche de 4 x 3, on garde six dessins.
    rgb = d.load_rgb(REF / "elements" / "projectiles_menus.png")
    sheet = d.cutout(rgb)
    boxes, labels = d.components(sheet, merge=22, min_area=6000)
    wanted = {"poisson": (0, 0), "epinards": (1, 0), "semoule": (2, 0), "brandade": (0, 1), "dinde": (1, 1), "buche": (3, 1)}
    for name, (c, r) in wanted.items():
        box = pick(boxes, 2752 * (c + 0.5) / 4, 1536 * (r + 0.5) / 3)
        img = d.crop_component(sheet, labels, box)
        save_all(img, "projectiles", f"projectile_{name}.png", hd_height=192)
    print("projectiles des menus", len(boxes))


def build_effects():
    rgb = d.load_rgb(REF / "elements" / "effets_bd.png")
    sheet = d.cutout(rgb)
    boxes, labels = d.components(sheet, merge=14, min_area=4000)
    wanted = {
        "splatch": ((524, 303), 320), "bloup": ((473, 760), 300), "floc": ((1266, 778), 300),
        "paf": ((377, 1235), 320), "schlurp": ((1147, 1248), 300),
        "tache_orange": ((1283, 291), 256), "tache_verte": ((2493, 178), 160), "tache_creme": ((2460, 419), 160),
        "tache_marron": ((2420, 793), 256), "nuage": ((1927, 1342), 160),
        "bulle_cri": ((1897, 314), 320), "bulle_ovale": ((1896, 761), 256), "bulle_pensee": ((2423, 1251), 256),
    }
    for name, (center, height) in wanted.items():
        img = d.crop_component(sheet, labels, pick(boxes, *center))
        if name.startswith("bulle") or name == "nuage":
            # L'intérieur des bulles est du même blanc que le fond : on le rend opaque et blanc.
            a = np.asarray(img)[:, :, 3] > 60
            filled = ndimage.binary_fill_holes(a)
            arr = np.asarray(img).copy()
            inside = filled & ~a
            arr[inside] = (255, 255, 255, 255)
            img = Image.fromarray(arr, "RGBA")
        save_all(img, "effets", f"{name}.png", hd_height=height)
    print("effets", len(boxes))


# --- Écrans --------------------------------------------------------------------

def build_screens():
    title = Image.open(REF / "interface" / "ecran_titre.png").convert("RGB")
    for quality, width in (("hd", 1920), ("sd", 1280)):
        img = title.resize((width, round(title.height * width / title.width)), Image.LANCZOS)
        img.save(out_path(quality, "ecrans", "titre.webp"), quality=86 if quality == "hd" else 78, method=6)
    print("ecrans")


# --- Textures dessinées -------------------------------------------------------

def speckle(img, rng, count, colors, size=(1, 3)):
    draw = ImageDraw.Draw(img, "RGBA")
    for _ in range(count):
        x, y = rng.randrange(img.width), rng.randrange(img.height)
        r = rng.uniform(*size)
        draw.ellipse((x - r, y - r, x + r, y + r), fill=rng.choice(colors))


def checker(tiles, px, color_a, color_b, grout, rng, stains=()):
    """Carrelage en damier (raccordable), avec joints à l'encre, nuances et petites taches."""
    size = tiles * px
    img = Image.new("RGB", (size, size), grout)
    draw = ImageDraw.Draw(img, "RGBA")
    g = max(2, px // 28)
    for ty in range(tiles):
        for tx in range(tiles):
            base = color_a if (tx + ty) % 2 == 0 else color_b
            k = rng.uniform(-9, 9)
            col = tuple(int(max(0, min(255, c + k))) for c in base)
            x, y = tx * px, ty * px
            draw.rectangle((x + g, y + g, x + px - g - 1, y + px - g - 1), fill=col)
            # Reflet clair en haut à gauche, ombre en bas à droite : aplat BD.
            draw.line((x + g + 2, y + g + 2, x + px - g - 4, y + g + 2), fill=(255, 255, 255, 70), width=max(1, g // 2))
            draw.line((x + g + 2, y + px - g - 3, x + px - g - 3, y + px - g - 3), fill=(0, 0, 0, 38), width=max(1, g // 2))
            if rng.random() < 0.18:  # éclat ou fêlure
                x0, y0 = x + rng.randrange(g * 2, px - g * 2), y + rng.randrange(g * 2, px - g * 2)
                draw.line((x0, y0, x0 + rng.randrange(-px // 4, px // 4), y0 + rng.randrange(-px // 4, px // 4)), fill=(*INK, 110), width=1)
    speckle(img, rng, size * size // 900, [(0, 0, 0, 26), (255, 255, 255, 30)])
    for color, count in stains:
        for _ in range(count):
            x, y, r = rng.randrange(size), rng.randrange(size), rng.uniform(px * 0.12, px * 0.4)
            blob = Image.new("RGBA", (size, size), (0, 0, 0, 0))
            bd = ImageDraw.Draw(blob)
            for _ in range(6):
                ox, oy, rr = rng.uniform(-r, r) * 0.6, rng.uniform(-r, r) * 0.6, r * rng.uniform(0.4, 0.9)
                bd.ellipse((x + ox - rr, y + oy - rr, x + ox + rr, y + oy + rr), fill=color)
            img.paste(blob, (0, 0), blob.filter(ImageFilter.GaussianBlur(1.2)))
    return img


def halftone(img, color, spacing, radius):
    draw = ImageDraw.Draw(img, "RGBA")
    row = 0
    for y in range(0, img.height + spacing, spacing):
        off = spacing // 2 if row % 2 else 0
        for x in range(-spacing, img.width + spacing, spacing):
            draw.ellipse((x + off - radius, y - radius, x + off + radius, y + radius), fill=color)
        row += 1


def build_textures():
    rng = random.Random(1984)
    floor = checker(8, 128, (88, 184, 181), (245, 236, 208), (58, 104, 108), rng, stains=[((120, 110, 80, 40), 5)])
    save_all(floor, "textures", "sol_salle.png", hd_width=1024)
    kitchen = checker(8, 128, (62, 62, 66), (238, 232, 214), (40, 40, 42), rng,
                      stains=[((150, 120, 40, 70), 10), ((110, 130, 50, 60), 5), ((120, 60, 30, 60), 4)])
    save_all(kitchen, "textures", "sol_cuisine.png", hd_width=1024)

    # Mur de la salle : jaune, trame de points, bande turquoise en bas, plinthe sombre. Raccord horizontal.
    wall = Image.new("RGB", (512, 512), (244, 200, 74))
    halftone(wall, (226, 160, 40, 90), 16, 3)
    wd = ImageDraw.Draw(wall, "RGBA")
    wd.rectangle((0, 300, 512, 512), fill=(86, 176, 172))
    wd.line((0, 300, 512, 300), fill=INK, width=5)
    wd.rectangle((0, 470, 512, 512), fill=(52, 96, 100))
    wd.line((0, 470, 512, 470), fill=INK, width=4)
    speckle(wall, rng, 260, [(0, 0, 0, 24), (255, 255, 255, 34)], (1, 2.5))
    save_all(wall, "textures", "mur_salle.png", hd_width=512)

    # Mur de la cuisine : faïence blanche et coulures.
    tiles = Image.new("RGB", (512, 512), (236, 234, 224))
    td = ImageDraw.Draw(tiles, "RGBA")
    for k in range(0, 513, 64):
        td.line((k, 0, k, 512), fill=(120, 124, 120), width=3)
        td.line((0, k, 512, k), fill=(120, 124, 120), width=3)
    for _ in range(14):
        x, y, length = rng.randrange(512), rng.randrange(380), rng.randrange(40, 130)
        td.line((x, y, x + rng.randrange(-4, 4), y + length), fill=(150, 130, 60, 80), width=rng.randrange(3, 8))
    td.rectangle((0, 470, 512, 512), fill=(70, 70, 74))
    td.line((0, 470, 512, 470), fill=INK, width=4)
    save_all(tiles, "textures", "mur_cuisine.png", hd_width=512)

    # Nappe (10 × 3 cases) : damier pastel rose et jaune par case comme sur le plateau du livret,
    # ourlet à l'encre et liseré clair. 128 px par case en HD.
    cell = 128
    table = Image.new("RGB", (10 * cell, 3 * cell), (246, 170, 190))
    bd = ImageDraw.Draw(table, "RGBA")
    shades = [(247, 164, 188), (252, 226, 150), (250, 196, 206), (253, 214, 170)]
    for ty in range(3):
        for tx in range(10):
            base = shades[1 + 2 * (tx % 2)] if (tx + ty) % 2 else shades[2 * ((tx + ty) // 2 % 2)]
            k = rng.uniform(-6, 6)
            col = tuple(int(max(0, min(255, c + k))) for c in base)
            bd.rectangle((tx * cell, ty * cell, (tx + 1) * cell - 1, (ty + 1) * cell - 1), fill=col)
    for k in range(1, 10):
        bd.line((k * cell, 0, k * cell, 3 * cell), fill=(214, 110, 140, 150), width=3)
    for k in range(1, 3):
        bd.line((0, k * cell, 10 * cell, k * cell), fill=(214, 110, 140, 150), width=3)
    bd.rectangle((0, 0, 10 * cell - 1, 3 * cell - 1), outline=INK, width=9)
    bd.rectangle((11, 11, 10 * cell - 12, 3 * cell - 12), outline=(255, 240, 244), width=5)
    speckle(table, rng, 260, [(180, 90, 115, 40), (255, 255, 255, 60)], (1, 2.2))
    save_all(table, "textures", "table.png", hd_width=10 * cell)

    # Bois (bancs, portes), inox (bacs, pieds).
    wood = Image.new("RGB", (256, 256), (150, 96, 56))
    od = ImageDraw.Draw(wood, "RGBA")
    for y in range(0, 256, 6):
        od.line((0, y + rng.randrange(-2, 2), 256, y + rng.randrange(-2, 2)), fill=(110, 66, 36, rng.randrange(60, 150)), width=rng.randrange(1, 3))
    for k in range(0, 257, 64):
        od.line((0, k, 256, k), fill=INK, width=3)
    save_all(wood, "textures", "bois.png", hd_width=256)
    steel = Image.new("RGB", (256, 256), (176, 186, 192))
    sd_ = ImageDraw.Draw(steel, "RGBA")
    for x in range(0, 256, 3):
        sd_.line((x, 0, x, 256), fill=(255, 255, 255, rng.randrange(0, 46)), width=1)
    for _ in range(5):
        x = rng.randrange(256)
        sd_.line((x, 0, x + 60, 256), fill=(255, 255, 255, 60), width=rng.randrange(6, 18))
    save_all(steel, "textures", "inox.png", hd_width=256)

    # Porte battante verte à hublots, vue de face (2 cases de large).
    door = Image.new("RGB", (512, 540), (96, 150, 96))
    dd = ImageDraw.Draw(door, "RGBA")
    dd.rectangle((0, 0, 511, 539), outline=INK, width=12)
    dd.rectangle((14, 14, 497, 525), outline=(70, 116, 72), width=8)
    dd.line((256, 0, 256, 540), fill=INK, width=8)
    for cx in (140, 372):
        dd.ellipse((cx - 62, 90, cx + 62, 214), fill=(150, 160, 160), outline=INK, width=8)
        dd.ellipse((cx - 44, 108, cx + 44, 196), fill=(170, 220, 232), outline=INK, width=5)
        dd.line((cx - 26, 170, cx + 14, 126), fill=(255, 255, 255, 200), width=7)
        dd.rectangle((cx - 90, 430, cx + 90, 512), fill=(176, 186, 192), outline=INK, width=5)
    dd.rectangle((214, 250, 240, 330), fill=(176, 186, 192), outline=INK, width=5)
    dd.rectangle((272, 250, 298, 330), fill=(176, 186, 192), outline=INK, width=5)
    speckle(door, rng, 220, [(0, 0, 0, 34), (255, 255, 255, 30)], (1, 3))
    save_all(door, "textures", "porte.png", hd_width=512)

    # Papier de cahier à petits carreaux (raccordable) pour l'interface.
    paper = Image.new("RGB", (256, 256), (251, 247, 232))
    pd = ImageDraw.Draw(paper, "RGBA")
    for k in range(0, 256, 32):
        pd.line((k, 0, k, 256), fill=(150, 190, 215, 120), width=1)
        pd.line((0, k, 256, k), fill=(150, 190, 215, 120), width=1)
    for k in range(0, 256, 128):
        pd.line((0, k, 256, k), fill=(120, 160, 200, 170), width=2)
    speckle(paper, rng, 160, [(120, 100, 60, 16)], (1, 4))
    save_all(paper, "textures", "papier.png", hd_width=256)
    build_level_textures(rng)
    print("textures")


def peel(img, rng, count, color, size):
    """Plâtre écaillé : taches claires irrégulières cernées d'encre (mur de la cantine crade)."""
    draw = ImageDraw.Draw(img, "RGBA")
    for _ in range(count):
        x, y = rng.randrange(img.width), rng.randrange(int(img.height * 0.55))
        pts = []
        n = rng.randrange(6, 10)
        r0 = rng.uniform(*size)
        for k in range(n):
            a = 2 * 3.14159 * k / n
            r = r0 * rng.uniform(0.55, 1.15)
            pts.append((x + r * np.cos(a) * 1.4, y + r * np.sin(a)))
        draw.polygon(pts, fill=color, outline=(*INK, 150))


def zigzag(draw, y, width, color, amp, step, line_width):
    pts = [(x, y + (amp if (x // step) % 2 else -amp)) for x in range(0, width + step, step)]
    draw.line(pts, fill=color, width=line_width)


def build_level_textures(rng):
    """Habillages des niveaux 2 et 3 (data/niveaux/*.json, clé « decor »), d'après les visuels
    assets/reference/decors/cantine_2_crade.png et cuisine_3_pop80.png."""
    # Cantine crade : damier turquoise passé et crème jauni, fêlures, auréoles et traces.
    floor = checker(8, 128, (96, 160, 150), (226, 218, 184), (58, 84, 82), rng,
                    stains=[((120, 96, 50, 70), 14), ((90, 110, 60, 50), 6), ((60, 50, 40, 50), 6)])
    fd = ImageDraw.Draw(floor, "RGBA")
    for _ in range(26):  # fêlures supplémentaires
        x, y = rng.randrange(1024), rng.randrange(1024)
        pts = [(x, y)]
        for _ in range(rng.randrange(2, 5)):
            x += rng.randrange(-40, 40)
            y += rng.randrange(-40, 40)
            pts.append((x, y))
        fd.line(pts, fill=(*INK, 120), width=2)
    save_all(floor, "textures", "sol_salle_crade.png", hd_width=1024)

    # Mur crade : moutarde délavée, plâtre écaillé, coulures, soubassement turquoise sale.
    wall = Image.new("RGB", (512, 512), (214, 170, 78))
    halftone(wall, (180, 130, 50, 70), 16, 3)
    peel(wall, rng, 7, (236, 214, 160), (14, 34))
    wd = ImageDraw.Draw(wall, "RGBA")
    for _ in range(10):
        x, y, length = rng.randrange(512), rng.randrange(260), rng.randrange(40, 120)
        wd.line((x, y, x + rng.randrange(-3, 3), y + length), fill=(120, 90, 40, 70), width=rng.randrange(3, 7))
    wd.rectangle((0, 300, 512, 512), fill=(78, 140, 132))
    wd.line((0, 300, 512, 300), fill=INK, width=5)
    for _ in range(8):
        x = rng.randrange(512)
        wd.rectangle((x, 304 + rng.randrange(0, 60), x + rng.randrange(12, 40), 304 + rng.randrange(70, 150)), fill=(150, 150, 120, 90))
    wd.rectangle((0, 470, 512, 512), fill=(48, 72, 72))
    wd.line((0, 470, 512, 470), fill=INK, width=4)
    speckle(wall, rng, 420, [(0, 0, 0, 34), (255, 255, 255, 30), (90, 70, 30, 40)], (1, 3))
    save_all(wall, "textures", "mur_salle_crade.png", hd_width=512)

    # Nappe crade : formica rose passé, sans damier, rayures et ronds de verre.
    cell = 128
    table = Image.new("RGB", (10 * cell, 3 * cell), (226, 160, 160))
    bd = ImageDraw.Draw(table, "RGBA")
    for _ in range(60):
        x, y = rng.randrange(10 * cell), rng.randrange(3 * cell)
        bd.line((x, y, x + rng.randrange(-60, 60), y + rng.randrange(-12, 12)), fill=(255, 235, 235, 90), width=1)
    for _ in range(14):
        x, y, r = rng.randrange(10 * cell), rng.randrange(3 * cell), rng.randrange(14, 26)
        bd.ellipse((x - r, y - r, x + r, y + r), outline=(150, 90, 70, 80), width=3)
    bd.rectangle((0, 0, 10 * cell - 1, 3 * cell - 1), outline=INK, width=9)
    bd.rectangle((11, 11, 10 * cell - 12, 3 * cell - 12), outline=(240, 200, 200), width=4)
    speckle(table, rng, 340, [(140, 80, 80, 50), (255, 255, 255, 50)], (1, 2.5))
    save_all(table, "textures", "table_crade.png", hd_width=10 * cell)

    # Cuisine pop 80 : damier rose et turquoise, quelques taches de sauce.
    kitchen = checker(8, 128, (64, 178, 168), (240, 150, 178), (40, 70, 80), rng,
                      stains=[((200, 90, 50, 70), 6), ((240, 230, 200, 70), 5), ((110, 150, 60, 60), 4)])
    save_all(kitchen, "textures", "sol_cuisine_pop80.png", hd_width=1024)

    # Mur de la cuisine pop 80 : faïence jaune, zigzags et confettis Memphis, plinthe turquoise.
    tiles = Image.new("RGB", (512, 512), (246, 222, 120))
    td = ImageDraw.Draw(tiles, "RGBA")
    for k in range(0, 513, 64):
        td.line((k, 0, k, 512), fill=(196, 170, 80), width=3)
        td.line((0, k, 512, k), fill=(196, 170, 80), width=3)
    zigzag(td, 40, 512, (230, 70, 140), 10, 16, 6)
    zigzag(td, 40, 512, INK, 10, 16, 2)
    for _ in range(26):
        x, y = rng.randrange(512), rng.randrange(80, 280)
        col = rng.choice([(230, 70, 140), (40, 180, 200), (110, 70, 190), (250, 140, 40)])
        if rng.random() < 0.5:
            td.rectangle((x, y, x + 10, y + 4), fill=col)
        else:
            td.polygon([(x, y), (x + 10, y + 3), (x + 2, y + 10)], fill=col)
    td.rectangle((0, 300, 512, 470), fill=(64, 178, 168, 255))
    td.line((0, 300, 512, 300), fill=INK, width=5)
    for k in range(0, 513, 64):
        td.line((k, 300, k, 470), fill=(40, 120, 120), width=3)
    td.rectangle((0, 470, 512, 512), fill=(150, 60, 120))
    td.line((0, 470, 512, 470), fill=INK, width=4)
    speckle(tiles, rng, 200, [(0, 0, 0, 22), (255, 255, 255, 40)], (1, 2.5))
    save_all(tiles, "textures", "mur_cuisine_pop80.png", hd_width=512)


def build_chaotic_kitchen():
    """Cuisine chaotique (niveau 3), d'après assets/reference/decors/cuisine_2_chaotique.png :
    damier jaune et vert d'eau, sol jonché d'épluchures, faïence coulée de graisse et tuyau."""
    rng = random.Random(1225)
    floor = checker(8, 128, (232, 214, 120), (104, 176, 164), (52, 86, 84), rng,
                    stains=[((140, 160, 50, 80), 10), ((120, 90, 40, 70), 8), ((200, 200, 210, 70), 4)])
    fd = ImageDraw.Draw(floor, "RGBA")
    for _ in range(70):  # épluchures, rondelles de carotte, miettes
        x, y = rng.randrange(1024), rng.randrange(1024)
        kind = rng.random()
        if kind < 0.35:
            r = rng.randrange(5, 9)
            fd.ellipse((x - r, y - r, x + r, y + r), fill=(236, 120, 40), outline=INK, width=2)
        elif kind < 0.7:
            pts = [(x + rng.randrange(-14, 14), y + rng.randrange(-8, 8)) for _ in range(4)]
            fd.line(pts, fill=(196, 160, 90), width=5)
            fd.line(pts, fill=(*INK, 160), width=1)
        else:
            fd.polygon([(x, y), (x + rng.randrange(6, 14), y + 3), (x + 4, y + rng.randrange(6, 12))],
                       fill=(110, 160, 60), outline=INK)
    save_all(floor, "textures", "sol_cuisine_chaotique.png", hd_width=1024)

    wall = Image.new("RGB", (512, 512), (52, 86, 84))
    wd = ImageDraw.Draw(wall, "RGBA")
    t = 32
    for ty in range(0, 300 // t + 1):
        for tx in range(512 // t):
            col = (238, 222, 128) if (tx + ty) % 2 == 0 else (110, 184, 172)
            k = rng.uniform(-8, 8)
            col = tuple(int(max(0, min(255, c + k))) for c in col)
            wd.rectangle((tx * t + 2, ty * t + 2, tx * t + t - 3, min(ty * t + t - 3, 296)), fill=col)
    for _ in range(12):  # coulées de graisse depuis le haut
        x, length = rng.randrange(512), rng.randrange(40, 160)
        w = rng.randrange(4, 9)
        wd.line((x, 0, x, length), fill=(150, 140, 60, 110), width=w)
        wd.ellipse((x - w, length - w, x + w, length + w // 2), fill=(150, 140, 60, 110))
    # Tuyau gris en travers, avec colliers.
    wd.rectangle((0, 34, 512, 52), fill=(150, 156, 160))
    wd.line((0, 34, 512, 34), fill=INK, width=3)
    wd.line((0, 52, 512, 52), fill=INK, width=3)
    wd.line((0, 39, 512, 39), fill=(220, 224, 226), width=2)
    for x in range(40, 512, 128):
        wd.rectangle((x, 30, x + 10, 56), fill=(110, 116, 120), outline=INK, width=2)
    wd.rectangle((0, 296, 512, 470), fill=(92, 160, 150))
    wd.line((0, 296, 512, 296), fill=INK, width=5)
    for k in range(0, 513, 64):
        wd.line((k, 296, k, 470), fill=(60, 112, 106), width=3)
    for _ in range(9):  # éclaboussures sur le soubassement
        x, y, r = rng.randrange(512), rng.randrange(310, 460), rng.randrange(6, 16)
        wd.ellipse((x - r, y - r, x + r, y + r), fill=(140, 160, 50, 90))
    wd.rectangle((0, 470, 512, 512), fill=(44, 60, 60))
    wd.line((0, 470, 512, 470), fill=INK, width=4)
    speckle(wall, rng, 360, [(0, 0, 0, 30), (255, 255, 255, 34), (110, 90, 40, 40)], (1, 3))
    save_all(wall, "textures", "mur_cuisine_chaotique.png", hd_width=512)


# --- Décor mural -----------------------------------------------------------------

def build_decor():
    """Manteaux aux patères et objets muraux (planches assets/reference/decors/planche_*.png)."""
    sheets = {
        "planche_manteaux.png": (5, 2, 288, ["manteau_%d" % i for i in range(10)]),
        "planche_mural.png": (4, 2, 320, ["horloge", "menu", "extincteur", "panneau_liege",
                                          "radiateur", "photo_classe", "affiche_mains", "fenetre"]),
    }
    for file, (cols, rows, height, names) in sheets.items():
        rgb = d.load_rgb(REF / "decors" / file)
        sheet = d.cutout(rgb, tolerance=14)
        boxes, labels = d.components(sheet, merge=16, min_area=8000)
        h, w = rgb.shape[:2]
        for r in range(rows):
            for c in range(cols):
                img = d.crop_component(sheet, labels, pick(boxes, w * (c + 0.5) / cols, h * (r + 0.5) / rows))
                save_all(img, "decor", f"{names[r * cols + c]}.png", hd_height=height)
        print("decor", file, len(boxes))


BUILDERS = {
    "pions": build_pawns, "accessoires": build_props, "projectiles": build_projectiles,
    "effets": build_effects, "ecrans": build_screens, "textures": build_textures, "decor": build_decor,
    "cuisine_chaotique": build_chaotic_kitchen,
}

if __name__ == "__main__":
    for key in (sys.argv[1:] or BUILDERS.keys()):
        BUILDERS[key]()
