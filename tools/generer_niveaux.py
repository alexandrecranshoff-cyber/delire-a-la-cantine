"""Génère data/niveaux/niveau_2.json et niveau_3.json (services de novembre et de décembre).

    python3 tools/generer_niveaux.py

Même cadre que le niveau 1 (tools/generer_niveau_1.py) : salle de 30 x 27 cases, cuisine de 7 rangées,
6 portes, 2 robinets, 3 bacs. Coordonnées du plan : x = colonne, y = ligne, murs extérieurs compris.
Ce qui change d'un niveau à l'autre : la disposition des tables, les flaques, le menu du jour et
l'habillage (images du décor).
"""
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
W, H = 32, 37


def frame():
    """Plan vide : salle, cuisine, ouvertures, portes, robinets, bacs (identiques au niveau 1)."""
    grid = [["#"] * W for _ in range(H)]

    def put(c, r, s):
        grid[r + 1][c + 1] = s

    for r in range(27):
        for c in range(30):
            put(c, r, ".")
    for r in range(28, 35):
        for c in range(30):
            put(c, r, ",")
    for c in list(range(3, 8)) + list(range(22, 27)):
        put(c, 27, ".")
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
    return grid, doors, tubs


def mirror(c):
    return 29 - c


def save(name, level):
    out = ROOT / "data" / "niveaux" / name
    out.write_text(json.dumps(level, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    seats = sum(len(v) for v in level["places"].values())
    print(name, ":", level["nom"], "-", seats, "places,", len(level["places_neutres"]), "neutres")
    print("\n".join(level["plan"]))


# --- Niveau 2 : « Jour du poisson » -------------------------------------------------
# Les 8 tables sont remises en long (3 colonnes x 10 rangées), en deux rangées de quatre séparées par
# une allée centrale. Les bandes se font face par de longs couloirs ; un chariot de poisson est resté
# au milieu de l'allée, seule réserve de munitions hors de la cuisine après le tour 4.

def niveau_2():
    grid, doors, tubs = frame()
    tables, seats, neutrals = {}, {}, []
    cols = [3, 10, 17, 24]          # colonne de gauche de chaque table (intérieur)
    rows = [2, 15]                  # rangée du haut de chaque table
    num = 1
    for r0 in rows:
        for c0 in cols:
            cells = [[c + 1, r + 1] for c in range(c0, c0 + 3) for r in range(r0, r0 + 10)]
            for x, y in cells:
                grid[y][x] = "T"
            tables[str(num)] = cells
            # 5 places sur le grand côté extérieur, 3 sur l'autre (comme au niveau 1), côtés miroirs à droite.
            left_half = c0 < 15
            outer = c0 - 1 if left_half else c0 + 3
            inner = c0 + 3 if left_half else c0 - 1
            seats[str(num)] = [[outer + 1, r0 + k + 1] for k in (0, 1, 7, 8, 9)] + [[inner + 1, r0 + k + 1] for k in (3, 4, 5)]
            neutrals += [[outer + 1, r0 + k + 1] for k in (2, 6)]
            num += 1
    for c in [4, 5, 11, 12]:
        neutrals += [[c + 1, 13 + 1], [mirror(c) + 1, 13 + 1]]
    return {
        "_note": "Niveau 2 (novembre, « Jour du poisson ») : tables en long, chariot de poisson dans l'allée, cuisine pop 80. Plan généré par tools/generer_niveaux.py. Légende : voir Board.SYMBOLS.",
        "nom": "Jour du poisson",
        "plan": ["".join(row) for row in grid],
        "tables": tables,
        "places": seats,
        "places_neutres": neutrals,
        "portes": doors,
        "bacs": tubs,
        "cuisinier": [16, 35],
        "chariots": {"chariot purée": [16, 33], "chariot tripes": [15, 30], "chariot poisson": [15, 14]},
        "repartition": {
            "4": [[1, 5], [4, 8], [2, 6], [3, 7]],
            "3": [[1, 7], [4, 6], [2, 8]],
            "2": [[1, 7], [4, 6]],
            "2_double": [[1, 2, 5, 6], [3, 4, 7, 8]],
        },
        "menu": {
            "nom": "Vendredi : poisson",
            "plats": {
                "_note": "Remplacent les lignes 3, 4, 6 et 9 de la table des projectiles (data/projectiles.json).",
                "3": {"nom": "poisson pané", "degats": {"d6": 2}, "cx": 2, "image": "poisson"},
                "4": {"nom": "épinards à la crème", "degats": {"d6": 1}, "cx": 0, "image": "epinards"},
                "6": {"nom": "semoule", "degats": {"demi": 1}, "cx": 2, "image": "semoule"},
                "9": {"nom": "brandade de morue", "degats": {"d6": 2}, "cx": 1, "image": "brandade"},
            },
        },
        "decor": {"sol_cuisine": "sol_cuisine_pop80.png", "mur_cuisine": "mur_cuisine_pop80.png"},
    }


# --- Niveau 3 : « Repas de Noël » ----------------------------------------------------
# La vieille salle du fond : tables du livret, mais le toit fuit. Des flaques (« ~ ») couvrent une
# partie des allées et coûtent 2 PA la case (regles_video.json, points_action.flaque).

PUDDLES = [
    # (colonne, rangée) intérieures, en flaques de quelques cases
    (13, 0), (14, 0), (15, 0), (16, 0), (14, 1), (15, 1), (13, 1),
    (1, 9), (2, 9), (1, 10), (2, 10), (3, 10), (2, 11),
    (27, 17), (28, 17), (27, 18), (26, 18), (27, 19), (28, 16),
    (14, 8), (15, 8), (14, 12), (15, 12), (15, 13), (14, 16), (15, 16),
    (6, 22), (7, 22), (8, 22), (7, 23), (8, 23), (6, 23),
    (21, 23), (22, 23), (22, 24), (23, 24), (21, 24),
    (10, 26), (11, 26), (18, 26), (19, 26),
]


def niveau_3():
    lv1 = json.loads((ROOT / "data" / "niveaux" / "niveau_1.json").read_text(encoding="utf-8"))
    grid = [list(row) for row in lv1["plan"]]
    reserved = {tuple(v) for t in lv1["places"].values() for v in t} | {tuple(v) for v in lv1["places_neutres"]}
    for c, r in PUDDLES:
        x, y = c + 1, r + 1
        assert grid[y][x] == ".", (c, r, grid[y][x])
        if (x, y) in reserved:
            continue  # une place reste sèche : on s'y assoit au début
        grid[y][x] = "~"
    level = dict(lv1)
    level["_note"] = "Niveau 3 (décembre, « Repas de Noël ») : plan du niveau 1 dans la cantine crade, flaques (~) à 2 PA la case, menu de Noël. Plan généré par tools/generer_niveaux.py. Légende : voir Board.SYMBOLS."
    level["nom"] = "Repas de Noël"
    level["plan"] = ["".join(row) for row in grid]
    level["menu"] = {
        "nom": "Menu de Noël",
        "plats": {
            "_note": "Remplacent les lignes 7 et 12 de la table des projectiles (data/projectiles.json).",
            "7": {"nom": "dinde aux marrons", "degats": {"d6": 2}, "cx": 1, "image": "dinde"},
            "12": {"nom": "bûche de Noël", "degats": {"d6": 3}, "cx": 2, "image": "buche"},
        },
    }
    level["decor"] = {"sol_salle": "sol_salle_crade.png", "mur_salle": "mur_salle_crade.png", "table": "table_crade.png",
                      "sol_cuisine": "sol_cuisine_chaotique.png", "mur_cuisine": "mur_cuisine_chaotique.png"}
    level["cuisine_en_desordre"] = True  # épluchures, marmites renversées, cagettes (BoardView)
    return level


if __name__ == "__main__":
    save("niveau_2.json", niveau_2())
    save("niveau_3.json", niveau_3())
