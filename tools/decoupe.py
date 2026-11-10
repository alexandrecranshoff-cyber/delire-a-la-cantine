"""Outils de détourage partagés par tools/preparer_assets.py.

Les visuels Higgsfield sont dessinés sur un fond clair uni, avec un contour à l'encre fermé :
on retire le fond par remplissage depuis les bords, puis on sépare les dessins d'une planche.
"""
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage


def load_rgb(path):
    return np.asarray(Image.open(path).convert("RGB")).astype(np.int16)


def background_mask(rgb, tolerance=26, extra_colors=()):
    """Masque du fond : pixels proches de la couleur du fond et reliés au bord de l'image."""
    h, w, _ = rgb.shape
    border = np.concatenate([rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]])
    bg = np.median(border, axis=0)
    near = np.abs(rgb - bg).max(axis=2) <= tolerance
    for color, tol in extra_colors:
        near |= np.abs(rgb - np.array(color)).max(axis=2) <= tol
    labels, _ = ndimage.label(near)
    edge = np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))
    edge = edge[edge != 0]
    return np.isin(labels, edge)


def cutout(rgb, tolerance=26, extra_colors=(), feather=1.2):
    """Image RGBA détourée (fond transparent, bord légèrement adouci)."""
    bg = background_mask(rgb, tolerance, extra_colors)
    alpha = (~bg).astype(np.float32)
    # On rogne d'un pixel le liseré clair puis on adoucit.
    alpha = ndimage.binary_erosion(alpha > 0.5, iterations=1).astype(np.float32)
    alpha = ndimage.gaussian_filter(alpha, feather)
    alpha = np.clip((alpha - 0.25) / 0.5, 0, 1)
    out = np.dstack([rgb.astype(np.uint8), (alpha * 255).astype(np.uint8)])
    return Image.fromarray(out, "RGBA")


def components(img, min_area=1500, merge=18):
    """Boîtes englobantes des dessins d'une planche détourée (les miettes proches sont regroupées)."""
    alpha = np.asarray(img)[:, :, 3] > 40
    grown = ndimage.binary_dilation(alpha, iterations=merge)
    labels, n = ndimage.label(grown)
    boxes = []
    for i, sl in enumerate(ndimage.find_objects(labels), start=1):
        part = alpha[sl] & (labels[sl] == i)
        area = int(part.sum())
        if area < min_area:
            continue
        ys, xs = np.nonzero(part)
        boxes.append((sl[1].start + xs.min(), sl[0].start + ys.min(), sl[1].start + xs.max() + 1, sl[0].start + ys.max() + 1, area, i))
    return boxes, labels


def crop_component(img, labels, box, pad=0):
    """Découpe un dessin en effaçant ses voisins."""
    x0, y0, x1, y1, _, idx = box
    arr = np.asarray(img).copy()
    arr[:, :, 3] = np.where(labels == idx, arr[:, :, 3], 0)
    out = Image.fromarray(arr, "RGBA").crop((x0, y0, x1, y1))
    if pad:
        canvas = Image.new("RGBA", (out.width + 2 * pad, out.height + 2 * pad), (0, 0, 0, 0))
        canvas.paste(out, (pad, pad))
        out = canvas
    return out


def bleed(img, iterations=6):
    """Étend les couleurs du bord dans la zone transparente, pour éviter un halo clair au filtrage."""
    arr = np.asarray(img).astype(np.float32)
    rgb, a = arr[:, :, :3], arr[:, :, 3]
    solid = a > 128
    cur = rgb * solid[:, :, None]
    weight = solid.astype(np.float32)
    for _ in range(iterations):
        blurred = ndimage.uniform_filter(cur, size=(5, 5, 1))
        wb = ndimage.uniform_filter(weight, size=5)
        fill = (wb > 1e-4) & (weight < 0.5)
        cur[fill] = blurred[fill] / wb[fill][:, None]
        weight[fill] = 1.0
    out = np.where(solid[:, :, None], rgb, cur)
    return Image.fromarray(np.dstack([out, a]).astype(np.uint8), "RGBA")


def fit(img, height):
    w = max(1, round(img.width * height / img.height))
    return img.resize((w, height), Image.LANCZOS)
