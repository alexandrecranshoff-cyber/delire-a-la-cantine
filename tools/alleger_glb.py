#!/usr/bin/env python3
"""Allège un modèle GLB : réduit ses textures embarquées (et, au besoin, retire ses animations).

Les modèles sortis de Higgsfield embarquent une texture de 2 à 4 Mo, bien trop lourde pour un
pion haut de quelques dizaines de pixels. Usage :

    python3 tools/alleger_glb.py source.glb sortie.glb --taille 1024 [--qualite 88] [--sans-animation]
"""
import argparse
import io
import json
import struct

from PIL import Image

JSON_CHUNK = 0x4E4F534A
BIN_CHUNK = 0x004E4942


def read_glb(path):
    data = open(path, "rb").read()
    magic, version, _length = struct.unpack("<4sII", data[:12])
    if magic != b"glTF" or version != 2:
        raise SystemExit(f"{path} n'est pas un GLB version 2")
    offset = 12
    doc = None
    binary = b""
    while offset < len(data):
        size, kind = struct.unpack("<II", data[offset:offset + 8])
        chunk = data[offset + 8:offset + 8 + size]
        if kind == JSON_CHUNK:
            doc = json.loads(chunk)
        elif kind == BIN_CHUNK:
            binary = chunk
        offset += 8 + size
    return doc, binary


def write_glb(path, doc, binary):
    text = json.dumps(doc, separators=(",", ":")).encode("utf-8")
    text += b" " * (-len(text) % 4)
    binary += b"\0" * (-len(binary) % 4)
    total = 12 + 8 + len(text) + 8 + len(binary)
    with open(path, "wb") as out:
        out.write(struct.pack("<4sII", b"glTF", 2, total))
        out.write(struct.pack("<II", len(text), JSON_CHUNK))
        out.write(text)
        out.write(struct.pack("<II", len(binary), BIN_CHUNK))
        out.write(binary)


def shrink_image(raw, size, quality):
    img = Image.open(io.BytesIO(raw))
    if max(img.size) > size:
        ratio = size / max(img.size)
        img = img.resize((max(1, round(img.width * ratio)), max(1, round(img.height * ratio))), Image.LANCZOS)
    out = io.BytesIO()
    if img.mode in ("RGBA", "LA", "P"):
        img.save(out, "PNG", optimize=True)
        return out.getvalue(), "image/png"
    img.convert("RGB").save(out, "JPEG", quality=quality, optimize=True)
    return out.getvalue(), "image/jpeg"


def slim(src, dst, size, quality=88, drop_animations=False):
    doc, binary = read_glb(src)
    views = doc.get("bufferViews", [])
    replaced = {}
    for image in doc.get("images", []):
        if "bufferView" not in image:
            continue
        view = views[image["bufferView"]]
        start = view.get("byteOffset", 0)
        raw = binary[start:start + view["byteLength"]]
        replaced[image["bufferView"]], image["mimeType"] = shrink_image(raw, size, quality)
    if drop_animations:
        doc.pop("animations", None)
    # Reconstruit le tampon : chaque vue est recopiée (ou remplacée) à la suite, alignée sur 4 octets.
    # Les vues devenues inutiles (animations retirées) restent : leur poids est négligeable.
    out = bytearray()
    for index, view in enumerate(views):
        start = view.get("byteOffset", 0)
        chunk = replaced.get(index, binary[start:start + view["byteLength"]])
        out += b"\0" * (-len(out) % 4)
        view["byteOffset"] = len(out)
        view["byteLength"] = len(chunk)
        out += chunk
    doc["buffers"] = [{"byteLength": len(out) + (-len(out) % 4)}]
    write_glb(dst, doc, bytes(out))
    return len(out)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("source")
    parser.add_argument("sortie")
    parser.add_argument("--taille", type=int, default=1024, help="plus grand côté des textures, en pixels")
    parser.add_argument("--qualite", type=int, default=88, help="qualité JPEG")
    parser.add_argument("--sans-animation", action="store_true")
    args = parser.parse_args()
    weight = slim(args.source, args.sortie, args.taille, args.qualite, args.sans_animation)
    print(f"{args.sortie} : {weight / 1024:.0f} Ko")
