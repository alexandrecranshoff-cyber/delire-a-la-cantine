#!/usr/bin/env python3
"""Tourne un modèle GLB d'un quart de tour autour de la verticale : (x, y, z) -> (-z, y, x).

Les modèles sortis de Tripo (Higgsfield) regardent vers +X, alors que l'outil qui pose le squelette
(Meshy) attend un personnage qui regarde vers +Z. Sans ce quart de tour, le squelette est posé de
travers (jambes écartées d'avant en arrière, bras dans le torse). Usage :

    python3 tools/tourner_glb.py source.glb sortie.glb

Ne dépend que de la bibliothèque standard : le script peut tourner dans le bac à sable Higgsfield.
"""
import json
import struct
import sys

JSON_CHUNK = 0x4E4F534A
BIN_CHUNK = 0x004E4942


def turn(src, dst):
    data = open(src, "rb").read()
    offset = 12
    doc = None
    binary = bytearray()
    while offset < len(data):
        size, kind = struct.unpack("<II", data[offset:offset + 8])
        chunk = data[offset + 8:offset + 8 + size]
        if kind == JSON_CHUNK:
            doc = json.loads(chunk)
        elif kind == BIN_CHUNK:
            binary = bytearray(chunk)
        offset += 8 + size
    done = set()
    size_after = None
    for mesh in doc["meshes"]:
        for prim in mesh["primitives"]:
            for key in ("POSITION", "NORMAL"):
                index = prim["attributes"].get(key)
                if index is None or index in done:
                    continue
                done.add(index)
                acc = doc["accessors"][index]
                view = doc["bufferViews"][acc["bufferView"]]
                if acc["componentType"] != 5126 or acc["type"] != "VEC3":
                    raise SystemExit(f"{src} : attribut {key} dans un format inattendu")
                stride = view.get("byteStride", 12)
                base = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
                mins = [1e9] * 3
                maxs = [-1e9] * 3
                for i in range(acc["count"]):
                    at = base + i * stride
                    x, y, z = struct.unpack_from("<fff", binary, at)
                    v = (-z, y, x)
                    struct.pack_into("<fff", binary, at, *v)
                    for k in range(3):
                        mins[k] = min(mins[k], v[k])
                        maxs[k] = max(maxs[k], v[k])
                if key == "POSITION":
                    acc["min"], acc["max"] = mins, maxs
                    size_after = [round(maxs[k] - mins[k], 3) for k in range(3)]
    text = json.dumps(doc, separators=(",", ":")).encode("utf-8")
    text += b" " * (-len(text) % 4)
    binary += b"\0" * (-len(binary) % 4)
    with open(dst, "wb") as out:
        out.write(struct.pack("<4sII", b"glTF", 2, 12 + 8 + len(text) + 8 + len(binary)))
        out.write(struct.pack("<II", len(text), JSON_CHUNK))
        out.write(text)
        out.write(struct.pack("<II", len(binary), BIN_CHUNK))
        out.write(binary)
    return size_after


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    # Un personnage de face est plus large (x) que profond (z).
    print(sys.argv[2], "taille", turn(sys.argv[1], sys.argv[2]))
