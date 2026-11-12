#!/usr/bin/env python3
"""Fabrique les masques d'habits des personnages 3D : où repeindre à la couleur de la bande.

La texture d'un modèle Tripo est un patchwork de morceaux : on ne peut pas y repérer le haut d'un
vêtement à l'œil. On repasse donc chaque triangle du modèle dans l'espace de la texture pour savoir,
pour chaque pixel, à quelle hauteur du corps il se trouve. Un pixel est un habit s'il est dans la
tranche du haut du corps choisie pour ce personnage et si sa couleur n'est ni de la peau ni des
cheveux.

Réglages par personnage dans data/habits.json. Sortie : assets/<hd|sd>/personnages/<image>_habits.png
(gris : 255 = habit à repeindre), et dans data/habits.json, « ref » : la luminosité médiane de
l'habit d'origine, que le shader ramène à la couleur de la bande.

    python3 tools/masques_habits.py [--apercu dossier]
"""
import argparse
import colorsys
import io
import json
import os
import struct
import sys

import numpy as np
from PIL import Image, ImageFilter

sys.path.insert(0, os.path.dirname(__file__))
from alleger_glb import read_glb  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

COMPONENTS = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
SIZES = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def accessor(doc, binary, index):
    acc = doc["accessors"][index]
    view = doc["bufferViews"][acc["bufferView"]]
    start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    dtype = COMPONENTS[acc["componentType"]]
    n = SIZES[acc["type"]]
    count = acc["count"]
    stride = view.get("byteStride", 0)
    item = np.dtype(dtype).itemsize * n
    if stride and stride != item:
        raw = np.frombuffer(binary, np.uint8, count * stride, start).reshape(count, stride)[:, :item]
        return np.frombuffer(raw.tobytes(), dtype).reshape(count, n)
    return np.frombuffer(binary, dtype, count * n, start).reshape(count, n)


def texture(doc, binary):
    view = doc["bufferViews"][doc["images"][0]["bufferView"]]
    start = view.get("byteOffset", 0)
    return Image.open(io.BytesIO(binary[start:start + view["byteLength"]])).convert("RGB")


def height_map(pos, uv, tri, size):
    """Hauteur relative (0..1) de chaque pixel de la texture, -1 hors du modèle."""
    h = np.full((size, size), -1.0, np.float32)
    y = (pos[:, 1] - pos[:, 1].min()) / max(1e-6, np.ptp(pos[:, 1]))
    px = uv * size  # glTF : v vers le bas, comme les lignes de l'image
    for a, b, c in tri:
        pa, pb, pc = px[a], px[b], px[c]
        x0, x1 = int(max(0, np.floor(min(pa[0], pb[0], pc[0])))), int(min(size - 1, np.ceil(max(pa[0], pb[0], pc[0]))))
        y0, y1 = int(max(0, np.floor(min(pa[1], pb[1], pc[1])))), int(min(size - 1, np.ceil(max(pa[1], pb[1], pc[1]))))
        if x1 < x0 or y1 < y0:
            continue
        gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        d = (pb[1] - pc[1]) * (pa[0] - pc[0]) + (pc[0] - pb[0]) * (pa[1] - pc[1])
        if abs(d) < 1e-9:
            continue
        wa = ((pb[1] - pc[1]) * (gx - pc[0]) + (pc[0] - pb[0]) * (gy - pc[1])) / d
        wb = ((pc[1] - pa[1]) * (gx - pc[0]) + (pa[0] - pc[0]) * (gy - pc[1])) / d
        wc = 1 - wa - wb
        inside = (wa >= -0.02) & (wb >= -0.02) & (wc >= -0.02)
        val = wa * y[a] + wb * y[b] + wc * y[c]
        sub = h[y0:y1 + 1, x0:x1 + 1]
        sub[inside] = val[inside]
    return h


def is_skin(rgb):
    """Peau des personnages : rose orangé clair, peu saturé."""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    hsv = np.array([colorsys.rgb_to_hsv(*p) for p in rgb.reshape(-1, 3)]).reshape(rgb.shape)
    hue, sat, val = hsv[..., 0] * 360, hsv[..., 1], hsv[..., 2]
    return (hue > 5) & (hue < 40) & (sat > 0.18) & (sat < 0.62) & (val > 0.55) & (r > g) & (g > b)


def build(image, reglage, size_out, preview):
    doc, binary = read_glb(os.path.join(ROOT, "assets/hd/personnages", image + ".glb"))
    prim = doc["meshes"][0]["primitives"][0]
    pos = accessor(doc, binary, prim["attributes"]["POSITION"]).astype(np.float64)
    uv = accessor(doc, binary, prim["attributes"]["TEXCOORD_0"]).astype(np.float64)
    tri = accessor(doc, binary, prim["indices"]).reshape(-1, 3)
    tex = texture(doc, binary)
    work = 512
    h = height_map(pos, uv, tri, work)
    rgb = np.asarray(tex.resize((work, work), Image.LANCZOS), np.float32) / 255.0
    hsv = np.array([colorsys.rgb_to_hsv(*p) for p in rgb.reshape(-1, 3)]).reshape(rgb.shape)
    # Peau : couleur relevée sur le visage (haut du corps, teinte chair), puis tout ce qui en est
    # proche. Un pull beige n'est pas pris pour de la peau, contrairement à un simple seuil de teinte.
    face = (h > 0.78) & (h < 0.95) & is_skin(rgb)
    skin = np.median(rgb[face], axis=0) if face.sum() > 50 else np.array([0.93, 0.72, 0.58])
    near_skin = np.linalg.norm(rgb - skin, axis=-1) < reglage.get("peau", 0.13)
    mask = (h >= reglage["bas"]) & (h <= reglage["haut"]) & ~near_skin
    for hue, spread, sat in reglage["garder"]:
        dh = np.abs(((hsv[..., 0] * 360 - hue) + 180) % 360 - 180)
        mask &= ~((dh < spread) & (hsv[..., 1] > sat))
    # Nettoyage : on bouche les petits trous (traits d'encre, reflets) et on retire les miettes.
    img = Image.fromarray((mask * 255).astype(np.uint8))
    img = img.filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.MinFilter(5)).filter(ImageFilter.MaxFilter(3))
    # Débord d'un pixel hors des morceaux, pour que le filtrage de la texture ne laisse pas de liseré.
    img = img.filter(ImageFilter.MaxFilter(3))
    final = np.asarray(img) > 127
    lum = rgb @ np.array([0.299, 0.587, 0.114])
    inside = final & (h >= 0)
    ref = float(np.median(lum[inside])) if inside.any() else 0.5
    soft = img.filter(ImageFilter.GaussianBlur(0.7))
    for quality, size in (("hd", size_out), ("sd", size_out // 2)):
        soft.resize((size, size), Image.LANCZOS).save(
            os.path.join(ROOT, "assets", quality, "personnages", image + "_habits.png"), optimize=True)
    if preview:
        over = rgb.copy()
        over[final] = over[final] * 0.4 + np.array([0.1, 1.0, 0.2]) * 0.6
        Image.fromarray((over * 255).astype(np.uint8)).save(os.path.join(preview, image + "_masque.jpg"), quality=85)
    return ref


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--apercu", default="")
    parser.add_argument("--taille", type=int, default=512)
    parser.add_argument("--seulement", default="")
    args = parser.parse_args()
    data_path = os.path.join(ROOT, "data", "habits.json")
    data = json.load(open(data_path, encoding="utf-8"))
    for image, reglage in data["personnages"].items():
        if args.seulement and image not in args.seulement.split(","):
            continue
        reglage["ref"] = round(build(image, reglage, args.taille, args.apercu), 3)
        print(image, reglage["ref"])
    lines = ["{", '  "_note": %s,' % json.dumps(data["_note"], ensure_ascii=False), '  "personnages": {']
    items = list(data["personnages"].items())
    for i, (image, reglage) in enumerate(items):
        body = json.dumps(reglage, ensure_ascii=False, separators=(", ", ": "))
        lines.append('    %s %s%s' % ((json.dumps(image) + ":").ljust(19), body, "," if i < len(items) - 1 else ""))
    lines += ["  }", "}"]
    open(data_path, "w", encoding="utf-8").write("\n".join(lines) + "\n")

if __name__ == "__main__":
    main()
