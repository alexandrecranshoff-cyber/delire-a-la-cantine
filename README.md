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

## Jouer (maquette)

Ouvrir le projet dans Godot et lancer la scène principale (F5), ou ouvrir la version web publiée à chaque fusion sur `main` (onglet Actions, workflow « Version web »).

- Clic gauche : choisir un élève de sa bande, puis une case (déplacement), une table au contact (monter), ou un pion (tir).
- R : basculer en arrosage (au contact d'un robinet). Clic sur un chariot au contact, puis une case : le pousser.
- Entrée : fin du tour. Clic droit ou molette enfoncée : déplacer la vue ; molette : zoom ; Q et E : tourner.

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
- Données de jeu : [`data/`](data/)
