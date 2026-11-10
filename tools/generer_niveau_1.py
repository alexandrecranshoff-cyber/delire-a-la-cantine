"""Génère data/niveaux/niveau_1.json : plan relevé sur le plateau du livret (pages 4 à 7).

Coordonnées du plan : x = colonne, y = ligne, murs extérieurs compris.
Salle : 30 colonnes x 27 lignes ; cuisine : 7 lignes ; comptoir avec les 3 bacs en bas.
"""
import json, pathlib

W, H = 32, 37
grid = [["#"] * W for _ in range(H)]

def put(c, r, s):  # c, r : coordonnées intérieures (sans le mur)
    grid[r + 1][c + 1] = s

for r in range(27):
    for c in range(30):
        put(c, r, ".")
for r in range(28, 35):
    for c in range(30):
        put(c, r, ",")
# Ouvertures entre salle et cuisine (ligne de mur 27).
for c in list(range(3, 8)) + list(range(22, 27)):
    put(c, 27, ".")

tables = {}
left, right = [1, 2, 7, 8], [5, 6, 3, 4]
for k in range(4):
    top = 5 + 4 * k
    for num, c0 in ((left[k], 4), (right[k], 16)):
        cells = [[c + 1, r + 1] for r in range(top, top + 3) for c in range(c0, c0 + 10)]
        for x, y in cells:
            grid[y][x] = "T"
        tables[str(num)] = cells

def mirror(cols):
    return [29 - c for c in cols]

seats = {}
neutrals = []
for k in range(4):
    above, below = 4 + 4 * k, 8 + 4 * k
    for num, outer, inner in ((left[k], [4, 5, 11, 12, 13], [7, 8, 9]),
                              (right[k], mirror([4, 5, 11, 12, 13]), mirror([7, 8, 9]))):
        seats[str(num)] = [[c + 1, above + 1] for c in outer] + [[c + 1, below + 1] for c in inner]
    for c in [6, 10] + mirror([6, 10]):
        neutrals.append([c + 1, above + 1])
for c in [5, 6, 12, 13] + mirror([5, 6, 12, 13]):
    neutrals.append([c + 1, 20 + 1])

doors = {
    "1": [[0, 32], [0, 33]],
    "2": [[0, 25], [0, 26]],
    "3": [[2, 0], [3, 0]],
    "4": [[28, 0], [29, 0]],
    "5": [[31, 25], [31, 26]],
    "6": [[31, 32], [31, 33]],
}
for cells in doors.values():
    for x, y in cells:
        grid[y][x] = "D"
for x, y in ([0, 13], [31, 13]):
    grid[y][x] = "R"
tubs = {"bac_puree": [[10, 36], [11, 36]], "bac_vaisselle": [[15, 36], [16, 36]], "bac_tripes": [[20, 36], [21, 36]]}
for name, cells in tubs.items():
    for x, y in cells:
        grid[y][x] = "V" if name == "bac_vaisselle" else "B"

level = {
    "_note": "Niveau 1 : cantine fidèle au plateau du livret. Plan généré par tools/generer_niveau_1.py. Légende : voir Board.SYMBOLS.",
    "nom": "Cantine du collège",
    "plan": ["".join(row) for row in grid],
    "tables": tables,
    "places": seats,
    "places_neutres": neutrals,
    "portes": doors,
    "bacs": tubs,
    "cuisinier": [16, 35],
    "chariots": {"chariot purée": [16, 33], "chariot tripes": [15, 30]},
    "repartition": {
        "4": [[1, 4], [5, 8], [2, 3], [6, 7]],
        "3": [[1, 3], [5, 7], [2, 6]],
        "2": [[1, 6], [2, 5]],
        "2_double": [[1, 2, 3, 4], [5, 6, 7, 8]],
    },
}
out = pathlib.Path(__file__).resolve().parent.parent / "data" / "niveaux" / "niveau_1.json"
out.write_text(json.dumps(level, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
print("\n".join(level["plan"]))
print(sum(len(v) for v in seats.values()), "places,", len(neutrals), "neutres")
