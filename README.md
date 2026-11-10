# Délire à la cantine

Jeu de stratégie tactique 3D au tour par tour, jouable dans le navigateur : 2 à 4 bandes d'élèves s'affrontent à coups de purée, de tripes et de yaourts dans une cantine, pendant que les profs tentent d'évacuer les chahuteurs et que le cuisinier défend sa cuisine.

## Prérequis

- [Godot 4.6](https://godotengine.org/download)
- [Git LFS](https://git-lfs.com/) (`git lfs install` une fois sur la machine)
- [Blender](https://www.blender.org/) pour les assets 3D

## Démarrer

```bash
git clone https://github.com/alexandrecranshoff-cyber/delire-a-la-cantine
cd delire-a-la-cantine
git lfs pull
```

Puis ouvrir le dossier dans Godot (Importer > `project.godot`).

## Jouer

Ouvrir le projet dans Godot et lancer la scène principale (F5), ou prendre une des deux versions construites à chaque fusion sur `main` (onglet Actions, workflow « Versions du jeu ») :

- **Version web** : textures allégées (`assets/sd`), environ 19 Mo de données, publiée aussi sur GitHub Pages.
- **Version PC** (Windows et Linux) : textures deux fois plus fines (`assets/hd`), anticrénelage 4x, musique en meilleure qualité.

Le menu propose le solo contre l'ordinateur (trois difficultés : Récré, Cantine, Conseil de discipline) ou deux joueurs sur le même écran.

- Clic gauche : choisir un élève de sa bande (ou Tab), puis une case (déplacement), une table au contact (monter), ou un pion (tir).
- Cases vertes : il restera de quoi tirer. Jaunes : déplacement seul. Rouges : à portée d'un prof ou du cuisinier.
- R : arroser (au contact d'un robinet). P : projeter un adversaire dans un bac. Clic sur un chariot au contact, puis une case : le pousser.
- Entrée : fin du tour. V : vitesse. F1 : aide.
- Caméra : clic droit maintenu pour tourner librement, boutons ou touches Q et E pour tourner par huitièmes de tour ; molette pour zoomer ; flèches ou molette enfoncée pour déplacer la vue.

## Construire les deux versions

```bash
mkdir -p build/web build/pc && touch build/.gdignore
godot --headless --path . --import
godot --headless --path . --export-release "Web" build/web/index.html
godot --headless --path . --export-release "Windows" build/pc/delire_a_la_cantine.exe
godot --headless --path . --export-release "Linux" build/pc/delire_a_la_cantine.x86_64
```

La version web se lance derrière un petit serveur (`python3 -m http.server` dans `build/web`).

## Régler la difficulté

```bash
godot --headless --path . -s tools/simuler_parties.gd -- parties=24 difficulte=difficile joueur=normal
```

Fait jouer l'ordinateur contre lui-même et affiche victoires, durée et sorties par bande. Les réglages sont dans `data/difficulte.json`.

## Assets

- `assets/reference/` : visuels de référence validés (non exportés).
- `assets/hd/` et `assets/sd/` : images du jeu en deux qualités, produites par `tools/preparer_assets.py` à partir des références.
- `assets/*/personnages/` : les onze personnages en 3D avec squelette ; `assets/animations/` : marche, repos, lancer et touché, partagés par tous. La fabrication est décrite dans [docs/personnages-3d.md](docs/personnages-3d.md).
- Le mobilier (plateaux-repas, chariots, lavabos, portemanteaux, comptoir) est modelé par le code, dans `scripts/ui/props.gd`.
- `assets/audio/sfx/` et musiques (`assets/*/musique/`) : générés avec Higgsfield.
- `assets/fonts/` : Bangers et Patrick Hand, sous licence SIL Open Font License (textes joints).

## Tests

Le moteur de règles (`scripts/rules/`) est testé sans affichage :

```bash
godot --headless --path . --import
godot --headless --path . -s tests/run_tests.gd
```

Les tests tournent aussi sur GitHub à chaque PR.

## Documentation

- [Règles du prototype](docs/regles-originales.md)
- [Interprétations des règles](docs/interpretations-regles.md)
- [Personnages 3D : de la fiche au pion animé](docs/personnages-3d.md)
- Données de jeu : [`data/`](data/)
